package export cartridge.model

import system.Middleware
# import system.Sync


import fs
import harmony-proxy
import path

import tools.wait

import tools.iced

import util

import model.ModelComparators

class model extends Middleware

	@Query: require path.resolve "#{__dirname}/../../../../core/sql-query"
	@Validator: require path.resolve "#{__dirname}/../../../../core/validator"

	__init: ($vhost, $connector) ->
		model.connection_raw = $connector

		for vhost in $vhost
			apps_dir = "#{vhost}/apps"
			mdls_dir = "#{vhost}/models"

			if not model.models[vhost]?
				model.models[vhost] = {}

			if not model.global_model[vhost]?
				model.global_model[vhost] = {}

			if fs.existsSync apps_dir
				apps = fs.readdirSync apps_dir
				for app in apps
					models_dir = "#{vhost}/apps/#{app}/models"
					if fs.existsSync models_dir
						models = fs.readdirSync models_dir
						for mods in models
							target_file = "#{vhost}/apps/#{app}/models/#{mods}"
							class_name = /^(.+?)\.coffee$|^(.+?)\.js$/g.exec mods

							if model.models[vhost][class_name]?
								continue

							model.scan $connector, vhost, mods, target_file, class_name

			if fs.existsSync mdls_dir
				models = fs.readdirSync mdls_dir
				for mods in models
					target_file = "#{mdls_dir}/#{mods}"
					class_name = /^(.+?)\.coffee$|^(.+?)\.js$/g.exec mods

					if model.models[vhost][class_name]?
						continue

					model.scan $connector, vhost, mods, target_file, class_name


		Object.defineProperty global, '__model', {
			get: ->
				current_filename = do __stack[1].getFileName
				current_directory = null

				for vhost in $vhost
					if current_filename.indexOf(vhost) is 0
						current_directory = vhost

				if current_directory? and model.models[current_directory]?
					return model.ModelExec current_directory
				else
					return model.virtual_model
		}

		return model.global_model


	__middle: ($req) ->
		model.current_doc = $req.root
		return model.models[$req.root]

	__socket: ($req, $connector) ->
		model.current_doc = $req.root
		return model.ModelExec $req.root

	__onModified: (root, name, filename, $connector, primary) ->
		@__onCreated root, name, filename, $connector, primary

	__onCreated: (root, name, filename, $connector, primary) ->
		model.models[root][name] = {}

		cl = __require "#{root}/#{filename}"
		# cl[d] = v for d, v of new cl

		orm = util._extend {__proto__: cl.prototype}, {} #model.orm

		orm.migrate = cl.migrate ? null
		orm.connection = cl.connection ? null
		orm.attributes = cl.attributes ? null


		if orm.attributes?
			if not orm.connection?
				throw new Error "'connection' are not declared in '#{name}'."

		if orm.connection?
			if $connector[root][orm.connection]?
				orm.conn = $connector[root][orm.connection]
			else
				orm.conn = null

			orm.table = (if orm.conn? then orm.conn.prefix else 'tbl_') + do name.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase
			orm.$root = root
			orm.con = model.connectionChange

			# for v of model.orm then cl[v] = model.orm[v]

			if $connector[orm.connection]?
				orm.query = orm.conn.query
			else
				orm.query = ->
					throw 'Query on empty connection.'
					return

		else if not $connector[orm.connection]?
			throw new Error "No connection declared such as #{orm.connection}"

		if primary then wait.launchFiber ->
			try
				orm.con root, $connector[root], orm.connection

				if orm.migrate and orm.migrate isnt 'safe'
					if orm.conn.$
						wait.for orm.conn.$

					init = wait.forMethod orm.conn, 'table', name.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase(), orm.attributes, model.global_model[root]
					if init and init is 'onCreate' && orm.hasOwnProperty init
						do orm[init]
			catch err
				console.log err.stack or err if err?


		_cl = new cl
		_cl.__proto__ = orm

		model.global_model[root][name] = model.models[root][name].cl = _cl

	__onDeleted: (root, name, filename, $connector) ->
		delete model.models[root][name]

	@models: {}
	@global_model: {}
	@current_doc: null
	@connection_raw: {}

	@model_connection_setup = {}

	@virtual_model: harmonyProxy {}, {
		get: (target, name) ->
			return model.virtual_model
		set: (target, name, value) ->
	}

	@init_connection: (self, cb) ->
		try if self.conn
			if self.conn.$
				self.conn.$ ->
					self.is_init = true
					if self.migrate and self.migrate isnt 'safe'
						await self.conn.table self.table.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase().replace(new RegExp("^#{self.conn.prefix}"), ''), self.attributes, model.global_model[self.$root], defer d_err, init
						throw d_err if d_err

						if init and init is 'onCreate' && self.hasOwnProperty init
							do table[init]
					cb null, true
			else if not self.is_init?
				self.is_init = true
				if self.migrate and self.migrate isnt 'safe'
					await self.conn.table self.table.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase().replace(new RegExp("^#{self.conn.prefix}"), ''), self.attributes, model.global_model[self.$root], defer d_err, init
					throw d_err if d_err

					if init and init is 'onCreate' && self.hasOwnProperty init
						do table[init]

				cb null, true
			else
				cb null, true
		else
			cb 'ERROR: Can\'t query without connection'
		catch err
			cb err

	@qparam_conditions: {
		contains: (value) ->
			ModelComparators.like("%#{value}%")

		startswith: (value) ->
			ModelComparators.like("#{value}%")

		endswith: (value) ->
			ModelComparators.like("%#{value}")

		range: (value) ->
			if value.constructor.name is 'Array'
				ModelComparators.between.apply ModelComparators, value
			else
				throw new Error 'Range is not a valid Array type.'

		not_range: (value) ->
			if value.constructor.name is 'Array'
				ModelComparators.not_between.apply ModelComparators, value
			else
				throw new Error 'Range is not a valid Array type.'

		isnull: (value) ->
			if value
				ModelComparators.eq(null)
			else
				ModelComparators.ne(null)

		in: (value) ->
			if value.constructor.name is 'Array'
				return value
			else
				throw new Error 'Range is not a valid Array type.'

		eq: ModelComparators.eq
		ne: ModelComparators.ne
		gt: ModelComparators.gt
		gte: ModelComparators.gte
		lt: ModelComparators.lt
		lte: ModelComparators.lte
		not_in: ModelComparators.not_in
	}

	@qparam_add: (name, value, condition) ->
		condition[name] = value

	@qparam_builder: (model_data, builder, params, condition, model_list, exclude) ->

		tmp_condition = {}
		table_join = []

		for i in condition
			if i[0] is 'from'
				table_join.push i[1][0]

		for i, v of params
			condition_list = i.split '__'
			do_third_operation = false

			if condition_list.length is 1
				if model_data.attributes[condition_list[0]]? or condition_list[0] is 'id'

					tmp_condition[model_data.table] = [] unless tmp_condition[model_data.table]
					tmp_condition[model_data.table].push [condition_list[0], v]

				else
					console.log "Unknwon field '#{condition_list[0]}'"

			else if condition_list.length is 2
				add_condition = []
				if model_data.attributes[condition_list[0]]? or condition_list[0] is 'id'
					add_condition = [condition_list[0], v]
				else
					console.log 'check for relations'

				if add_condition.length isnt 0 and model.qparam_conditions[condition_list[1]]?

					tmp_condition[model_data.table] = [] unless tmp_condition[model_data.table]
					tmp_condition[model_data.table].push [condition_list[0], model.qparam_conditions[condition_list[1]](add_condition[1])]

				else
					do_third_operation = true

			if condition_list.length > 2 or do_third_operation
					last_model = model_data

					if table_join.length is 0
						condition.push ['select', ['id']]
						condition.push ['as', ['id']]

						for z, a of last_model.attributes
							condition.push ['select', [z]]
							condition.push ['as', [z]]

					for y, x of condition_list
						if typeof model_data.attributes[x] is 'object' and model_data.attributes[x].model? and model_list[model_data.attributes[x].model]?
							last_model = model_list[model_data.attributes[x].model]

							if table_join.indexOf(last_model.table) is -1
								condition.push ['from', [last_model.table, 'id', x]]
								table_join.push last_model.table

						else if typeof last_model.attributes[x] isnt 'undefined'
							tmp_condition[last_model.table] = [] unless tmp_condition[last_model.table]

							found_condition = false

							if ((condition_list.length - 1) - y) is 1 and model.qparam_conditions[condition_list[-1..]]?
								found_condition = true
								tmp_condition[last_model.table].push [x, model.qparam_conditions[condition_list[-1..]](v)]
							else
								tmp_condition[last_model.table].push [x, v]

							break if found_condition

							if ((condition_list.length - 1) - y) is 1 and not found_condition
								console.log "ERROR: condition '#{condition_list[-1..]}' not found."
								break
						else
							console.log "ERROR: Unknown Column in MODEL '#{x}'."


		if Object.keys(tmp_condition).length is 1
			for i, v of tmp_condition
				tmp = {}
				for x in v

					if tmp[x[0]]?
						tmp = {not: [tmp]} if exclude
						condition.push ['where', [tmp]]
						tmp = {}

					tmp[x[0]] = x[1]

				tmp = {not: [tmp]} if exclude
				condition.push ['where', [tmp]]

		else if Object.keys(tmp_condition).length isnt 0
			args = []
			for i, v of tmp_condition
				tmp = {}

				for x in v
					if tmp[x[0]]?
						args.push i
						tmp = {not: [tmp]} if exclude
						args.push tmp
						tmp = {}

					tmp[x[0]] = x[1]

				if Object.keys(tmp).length isnt 0
					args.push i
					tmp = {not: [tmp]} if exclude
					args.push tmp

			condition.push ['where', args]

	@build_query_model: (model_data, builder, object, resource, model_list) ->
		type = if object? then 'create' else 'update'

		object_data = {
			is_one: false
			data_build: object ? {}
			data_resource: resource ? {}
			data_rows: []
			data_condition: {}
			query: null
			result_length: 0
		}

		update_rows = (return_query) ->
			if object_data.query? and object_data.data_rows.length is 0
				query = builder.select().from(model_data.table)
				for i in object_data.query
					query = query[i[0]].apply query, i[1]

				if return_query
					return query.build()

				try
					model.init_connection.sync null, model_data
				catch err
					console.log err.stack ? err

				try
					result = model_data.conn.query.sync model_data.conn, query.build()
				catch err
					console.log err.stack ? err

				object_data.result_length = result.length

				# if object_data.is_one and result.length isnt 1
				# 	throw new Error "Model: Error 'get' function should return 1 row, result: #{result.length}"

				for i in result
					object_data.data_rows.push model.build_query_model model_data, builder, i, {id: i.id}, model_list

				if object_data.data_rows.length isnt 0
					object_data.data_build = result[0]

		check_field = (value) ->
			if value and Object.getOwnPropertyDescriptor(value, 'information')?.value is '_ARC__MODEL_'
				return value.id
			else
				return value

		build_query_array = ->
			if arguments.length is 1
				model.qparam_builder model_data, builder, arguments[0], object_data.query, model_list, @.exclude
			else if arguments.length > 1
				__or = []

				for i in arguments
					old_length = object_data.query.length
					model.qparam_builder model_data, builder, i, object_data.query, model_list, @.exclude

					__query = object_data.query.slice(0)
					__removed_query = 0

					for j in [old_length...object_data.query.length] when __query[j][0] is 'where'
						if typeof __query[j][1][0] is 'object'
							__or.push __query[j][1][0]
						else
							console.log __query[j]

						object_data.query.splice j - __removed_query, 1
						__removed_query++

				object_data.query.push ['where', [or: __or]]

			object_data.data_rows = []

		build_query = harmonyProxy (->), {
			get: (target, name) ->

				# console.info name

				switch name
					when 'get_or_create'
						return (build)->
							is_created = false
							__build = util._extend {}, build
							__defaults = util._extend {}, build.defaults ? {}
							delete __build.defaults if __build.defaults
							try
								build_query.get(__build)
								ret = build_query
							catch err
								if object_data.result_length is 0
									for i, v of __build
										__defaults[i] = v
									ret = build_query.create(__defaults)
									is_created = true
								else
									throw err

							return [ret, is_created]

					when 'update_or_create'
						return (build)->
							is_created = false
							__build = util._extend {}, build
							__defaults = util._extend {}, build.defaults ? {}
							delete __build.defaults if __build.defaults
							try
								a = build_query.get(__defaults)
								a.update(__build)
								ret = build_query
							catch err
								if object_data.result_length is 0
									for i, v of __build
										__defaults[i] = v
									ret = build_query.create(__defaults)
									is_created = true
								else
									throw err

							return [ret, is_created]

					when 'latest'
						return (field_date)->

							#return latest data

					when 'earliest'
						return (field_date)->

							#return latest data

					when 'create'
						return (build) ->
							d = {}
							for x, y of build
								d[x] = check_field y
							r = model.build_query_model model_data, builder, d, null, model_list
							do r.save
							return r

					when 'add'
						return ->
							console.log arguments

					when 'save'
						delete object_data.data_build.id if object_data.data_build.id?
						return ->
							try
								model.init_connection.sync null, model_data
							catch err
								console.log err.stack ? err
							if type is 'create'
								try
									object_data.data_resource = {}
									result = model_data.conn.query.sync model_data.conn, builder.insert().into(model_data.table).set(object_data.data_build).build()
									object_data.data_resource.id = object_data.data_build.id = result?[0]?.last_insert_id ? result?[0]?.id
								catch err
									console.log err.stack ? err
								type = 'update'
							else if type is 'update' and object_data.data_resource?.id?
								model_data.conn.query.sync model_data.conn, builder.update().into(model_data.table).set(object_data.data_build).where(object_data.data_resource).build()
								object_data.data_build.id = object_data.data_resource.id
							else if type is 'update' and object_data.query?
								build_query.update object_data.data_build

					when 'filter'
						object_data.query = [] unless object_data.query?
						return ->
							build_query_array.apply {exclude: false}, arguments
							return build_query

					when 'exclude'
						object_data.query = [] unless object_data.query?
						return ->
							build_query_array.apply {exclude: true}, arguments
							return build_query

					when 'get'
						# object_data.is_one = true
						return ->
							build_query.filter.apply build_query, arguments

							if build_query.length isnt 1
								throw new Error "Model: Error 'get' function should return 1 row, result: #{object_data.result_length}"

							return build_query

					when 'all'
						object_data.query = []
						return ->
							return build_query

					when 'delete'
						object_data.query = [] unless object_data.query?
						return ->
							query = builder.remove().from(model_data.table)
							for i in object_data.query
								query = query[i[0]].apply query, i[1]

							try
								model.init_connection.sync null, model_data
							catch err
								console.log err.stack ? err

							try
								model_data.conn.query.sync model_data.conn, query.build()
							catch err
								console.log err.stack ? err

					when 'update'
						object_data.query = [] unless object_data.query?
						return (new_data) ->
							d = {}

							for x, y of new_data
								d[x] = check_field y

							query = builder.update().into(model_data.table).set(d)
							for i in object_data.query
								query = query[i[0]].apply query, i[1]
							try
								model.init_connection.sync null, model_data
							catch err
								console.log err.stack ? err

							try
								model_data.conn.query.sync model_data.conn, query.build()
							catch err
								console.log err.stack ? err

					when 'order_by'
						object_data.query = [] unless object_data.query?
						return (field) ->
							if field[0] is '-'
								object_data.query.push ['order', [field.replace(/^\-/g, ''), 'Z']]
							else
								object_data.query.push ['order', [field, 'A']]

							return build_query

					when 'count'
						object_data.query = [] unless object_data.query?
						return ->
							object_data.query.push ['count', arguments]
							return build_query

					when 'length'
						do update_rows
						return object_data.data_rows.length

					when 'query'
						return update_rows true

					when 'toString', 'valueOf'
						return ->
							if typeof model_data.__unicode__ is 'function'
								return String model_data.__unicode__.apply build_query, []
							else
								do update_rows
								return JSON.stringify object_data.data_rows
							# return 'EMPTY STRING'

					when 'slice'
						return ->
							object_data.query.push ['offset', [arguments[0]]]
							if arguments[1]?
								object_data.query.push ['limit', [arguments[1] - 1]]
							return build_query

					when 'exists'
						return ->
							return build_query.length isnt 0

					when 'aggregate'
						dummy = builder.select().from(model_data.table)
						object_data.query = [] unless object_data.query?
						return (build) ->

							for i, v of build
								if model_data.attributes[v]?
									agregate = i.split '__'
									tmp_alias_field = ''
									for y, x of agregate

										if parseInt(y) isnt 0 and typeof dummy[x] is 'function'
											if (agregate.length - 1) is parseInt(y)
												object_data.query.push [x, [v, i]]
											else
												object_data.query.push [x, []]
										else if parseInt(y) isnt 0
											throw new Error "Unknown function '#{x}' in table '#{model_data.table}'."

								else
									throw new Error "Unknown column '#{v}' in table '#{model_data.table}'."

							return build_query

					else
						if not isNaN(parseFloat(name)) and isFinite(name)
							return object_data.data_rows[name]
						else if regex = /^___queryset_get_([0-9]+?)$/g.exec(name)
							return object_data.data_rows[regex[1]]
						else if name isnt 'constructor'
							do update_rows

							if typeof model_data.attributes[name] is 'object' and model_data.attributes[name].model? and model_list[model_data.attributes[name].model]?
								r = model.build_query_model model_list[model_data.attributes[name].model], builder, null, null, model_list
								return r.filter(id: object_data.data_build[name])

							# condition for manytomany

							if object_data.data_build[name]?
								return object_data.data_build[name]
							else
								# console.log name
								return null
						else
							console.info name
							return null


			set: (target, name, value) ->
				if model_data.attributes[name]?
					object_data.data_build[name] = check_field value

			apply: (target, thisArg, argumentsList) ->

			getOwnPropertyDescriptor: (target, prop) ->
				if prop is 'information'
					return { configurable: true, enumerable: true, value: '_ARC__MODEL_' }
				else
					return {configurable: true, enumerable: true}

			enumerate: (target) ->
				do update_rows
				return ("___queryset_get_#{x}" for x in [0...object_data.data_rows.length])
		}

		return build_query

	@ModelExec: ($root) ->
		return harmonyProxy {}, {
			get: (target, name) ->
				if model.global_model[$root][name]?

					# if name isnt'objects'
					# 	return model.global_model[$root][name]

					target_model = model.global_model[$root][name]

					return harmonyProxy (->), {
						get: (target, name) ->
							# console.log name
							switch do name.toLowerCase
								when 'objects'
									query_b = new model.Query.Query dialect: target_model.conn.dialect
									return model.build_query_model target_model, query_b, null, null, model.global_model[$root]
								else
									# console.log name
									if typeof target_model[name] is 'function'
										query_b = new model.Query.Query dialect: target_model.conn.dialect
										db = model.build_query_model target_model, query_b, null, null, model.global_model[$root]
										return ->
											target_model[name].apply db, arguments

						set: (target, name, value) ->
							console.log name, value

						apply: (target, thisArg, argumentsList) ->
							query_b = new model.Query.Query dialect: target_model.conn.dialect
							# tmp = query_b.insert().into(target_model.table).set argumentsList[0]
							return model.build_query_model target_model, query_b, (argumentsList[0] ? {}), null, model.global_model[$root]
					}

				else
					throw new Error "Undefined model '#{name}'."
					# return model.virtual_model

			set: (target, name, value) ->
				if not model.model_connection_setup.hasOwnProperty $root
					model.model_connection_setup[$root] = {}

				if not model.model_connection_setup[$root].hasOwnProperty(name)
					model.model_connection_setup[$root][name] = null

				if model.model_connection_setup[$root][name] isnt value
					model.model_connection_setup[$root][name] = value

					table = model.global_model[$root][name]

					table.$root = $root
					table.con $root, model.connection_raw[$root], value

					if table.migrate and table.migrate isnt 'safe'
						if table.conn.$
							wait.for table.conn.$

						init = wait.forMethod table.conn, 'table', name.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, ''), table.attributes, model.global_model[$root]
						if init and init is 'onCreate' && table.hasOwnProperty init
							do table[init]
		}

	@scan: ($connector, vhost, mods, target_file, class_name) ->
		class_name = class_name[1] || class_name[2]

		model.models[vhost][class_name] = {}

		if /\.coffee$/g.test mods
			cl = __require target_file

			# console.log i for i, v of cl

			orm = util._extend {__proto__: cl.prototype}, {} #model.orm

			orm.migrate = cl.migrate ? null
			orm.connection = cl.connection ? null
			orm.attributes = cl.attributes ? null

			if orm.attributes?
				if not orm.connection?
					throw new Error "'connection' are not declared in '#{class_name}'."

			if orm.connection?
				if $connector[vhost][orm.connection]?
					orm.conn = $connector[vhost][orm.connection]
				else
					orm.conn = null

				orm.table = (if orm.conn? then orm.conn.prefix else 'tbl_') + do class_name.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase
				orm.$root = vhost
				orm.con = model.connectionChange

				# for v of model.orm then cl[v] = model.orm[v]

				if $connector[orm.connection]?
					orm.query = orm.conn.query
				else
					orm.query = ->
						throw 'Query on empty connection.'
						return

			else if not $connector[orm.connection]?
				throw new Error "No connection declared such as #{orm.connection}"


			_cl = new cl
			_cl.__proto__ = orm

			model.global_model[vhost][class_name] = model.models[vhost][class_name].cl = _cl

	@connectionChange: ($root, $connector, name) ->
		if $connector[$root]?.hasOwnProperty(name)
			@conn = $connector[$root][name]
			@query = @conn.query
		else if $connector?.hasOwnProperty(name)
			@conn = $connector[name]
			@query = @conn.query
		else
			throw new Error "No connection declared such as #{name}"
		return

	@validator:
		required: (value) ->
			not model.Validator.isNull value

		alpha: (value) ->
			model.Validator.isAlpha value

		alphadashed: (value) ->
			/^[a-zA-Z\-]$/g.test value

		alphanumeric: (value) ->
			model.Validator.isAlphanumeric value

		alphanumericdashed: (value) ->
			/^[a-zA-Z0-9\-]$/g.test value

		creditcard: (value) ->
			model.Validator.isCreditCard value

		email: (value) ->
			model.Validator.isEmail value

		url: (value) ->
			model.Validator.isURL value

		macaddress: (value) ->
			model.Validator.isMACAddress value

		ip: (value) ->
			model.Validator.isIP value

		fqdn: (value) ->
			model.Validator.isFQDN value

		boolean: (value) ->
			model.Validator.isBoolean value

		decimal: (value) ->
			model.Validator.isDecimal value

		hexadecimal: (value) ->
			model.Validator.isHexadecimal value

		hexcolor: (value) ->
			model.Validator.isHexColor value

		lowercase: (value) ->
			model.Validator.isLowercase value

		uppercase: (value) ->
			model.Validator.isUppercase value

		# int: (value) ->
		# 	model.Validator.isInt value

		float: (value) ->
			model.Validator.isFloat value

		# divisibleby: (value) ->
		# 	model.Validator.isDivisibleBy value

		length: (value) ->
			model.Validator.isLength value

		uuid: (value) ->
			model.Validator.isUUID value

		date: (value) ->
			model.Validator.isDate value

		unique: (value) ->
			search = {}
			search[@__field] = value
			result = do @find(search).commit

			result.length is 0

		# after: (value) ->
		# 	model.Validator.isAfter value

		# before: (value) ->
		# 	model.Validator.isBefore value

	@validationMessages:
		required: '{{label}} is required.'
		alpha: '{{label}} is not a valid Alpha characters.'
		alphadashed: '{{label}} is not a valid Alpha dashes characters.'
		alphanumeric: '{{label}} is not a valid Alphanumeric characters.'
		alphanumericdashed: '{{label}} is not a valid Alphanumeric characters.'
		creditcard: '{{label}} is not a valid Creditcard.'
		email: '{{label}} is not a valid Email-Address.'
		url: '{{label}} is not a valid URL.'
		macaddress: '{{label}} is not a valid Mac-Address.'
		ip: '{{label}} is not a valid IP-Address.'
		fqdn: ''
		boolean: '{{label}} is not a Boolean type.'
		decimal: '{{label}} is not a Decimal type.'
		hexadecimal: '{{label}} is not a Hexadecimal type.'
		hexcolor: '{{label}} is invalid color type.'
		lowercase: '{{label}} is not all lowercase.'
		uppercase: '{{label}} is not all uppercase.'
		float: '{{label}} is not a Float type.'
		length: '{{label}} is invalid length.'
		uuid: '{{label}} is not a valid UUID.'
		date: '{{label}} is invalid Date format.'
		unique: '{{label}} is already exists.'


	@orm:
		# create: (obj) ->
		# 	if @migrate != 'safe'
		# 		obj.date_added = obj.date_modified = Math.round(+new Date / 1000)
		# 	@_query = insert: obj
		# 	this
		#
		# sum: (param, as) ->
		# 	if not @_query then @_query = {}
		# 	if not @_query.sum then @_query.sum = []
		# 	if not @_query.select then @_query.select = []
		#
		# 	@_query.sum.push [(param ? true), as]
		#
		# 	this
		#
		# find: (obj) ->
		# 	select = []
		# 	if @_query and @_query.select
		# 		select = @_query.select
		# 	@_query =
		# 		select: select
		# 		where: obj
		# 	this
		#
		# update: (update_obj, where_obj) ->
		# 	if @migrate != 'safe'
		# 		update_obj.date_modified = Math.round(+new Date / 1000)
		# 	@_query =
		# 		update: update_obj
		# 		where: where_obj
		# 	this
		#
		# findOne: (number) ->
		# 	select = []
		# 	if @_query and @_query.select
		# 		select = @_query.select
		# 	@_query =
		# 		select: select
		# 		limit: number or 1
		# 		findOne: true
		# 	this
		#
		# destroy: (where_obj) ->
		# 	@_query =
		# 		delete: true
		# 		where: where_obj
		# 	this
		#
		# count: (where_obj) ->
		# 	@_query =
		# 		count: true
		# 		where: where_obj
		# 	this
		#
		# populate: (field) ->
		# 	if !@_query
		# 		@_query = {}
		# 	if !@_query.select
		# 		@_query.select = []
		# 	@_query.select.push field
		# 	this
		#
		# stream: ->
		# 	this
		#
		# populateAll: ->
		# 	if !@_query.select
		# 		@_query.select = []
		# 	@_query.select = '*'
		# 	this
		#
		# sort: (property, order) ->
		# 	unless Array.isArray @_query.order
		# 		@_query.order = []
		#
		# 	if property[0] is "-"
		# 		@_query.order.push [ property.substr(1), "Z" ]
		# 	else
		# 		@_query.order.push [ property, (if order && order.toUpperCase() is "Z" then "Z" else "A") ]
		#
		# 	this
		#
		# where: (obj) ->
		# 	@_query.where = obj
		# 	this
		#
		# limit: (limit) ->
		# 	@_query.limit = limit
		# 	this
		#
		# offset: (offset) ->
		# 	@_query.offset = offset
		# 	this
		#
		# group: (group) ->
		# 	@_query.group = group
		# 	this

		##################################################################################################################################

		# validate: (params) ->
		# 	self = this
		# 	if typeof params is 'object'
		# 		current_field = null
		# 		current_label = null
		# 		handler = harmonyProxy params,
		# 			get: (proxy, name) ->
		# 				if params[name]
		# 					params[name]
		# 				else if self[name]
		# 					self[name]
		# 				else if name is '__label'
		# 					current_label
		# 				else if name is '__field'
		# 					current_field
		#
		# 			set: (proxy, name, value) ->
		# 				params[name] = value
		#
		# 		for i, v of params
		# 			label = i.replace /\_.|\-./g, (match) ->
		# 				do match.replace(/\_|\-/g, ' ').toUpperCase
		# 			label = label.replace /^./g, (match) ->
		# 				match.toUpperCase
		#
		# 			current_field = i
		#
		# 			if @attributes[i]?
		# 				if typeof @attributes[i] is 'object' and @attributes[i].validation?
		# 					if typeof @attributes[i].validation.label is 'string'
		# 						current_label = @attributes[i].validation.label
		#
		# 					if typeof @attributes[i].validation.minLength is 'number' and v.length > @attributes[i].validation.minLength
		# 						throw field: i, error: "model.validation.#{i}.minLength", label: current_label, message: ''
		#
		# 					if typeof @attributes[i].validation.maxLength is 'number' and v.length < @attributes[i].validation.maxLength
		# 						throw field: i, error: "model.validation.#{i}.maxLength", label: current_label, message: ''
		#
		# 					if typeof @attributes[i].validation.pattern is 'string'
		# 						for j in @attributes[i].validation.pattern.split '|'
		# 							if model.validator[j]
		# 								if not model.validator[j].call handler, v
		# 									error_message = null
		# 									if @validationMessages?[i]?[j]
		# 										error_message = @validationMessages[i][j].replace /\{\{label\}\}/g, current_label
		# 									else if model.validationMessages[j]
		# 										error_message = model.validationMessages[j].replace /\{\{label\}\}/g, current_label
		#
		# 									throw field: i, error: "model.validation.#{i}.#{j}", label: current_label, message: error_message
		# 							else if typeof @types is 'object' and typeof @types[j] is 'function'
		# 								if not @types[j].call handler, v
		# 									error_message = null
		# 									if @validationMessages?[i]?[j]
		# 										error_message = @validationMessages[i][j].replace /\{\{label\}\}/g, current_label
		# 									else if model.validationMessages[j]
		# 										error_message = model.validationMessages[j].replace /\{\{label\}\}/g, current_label
		#
		# 									throw field: i, error: "model.validation.#{i}.#{j}", label: current_label, message: ''
		#
		# 			# else
		# 			# 	throw "Column '#{i}' is no exists."
		#
		# 		# console.log @attributes
		#
		# 	this

		##################################################################################################################################

		# validateAndCreate: (params) ->
		#
		# 	this
		#
		# validateAndUpdate: (params) ->
		#
		# 	this
		#
		# commit: ->
		# 	result = wait.forMethod @, 'exec'
		#
		# 	self = this
		# 	if !result
		# 		return null
		#
		# 	return harmonyProxy result,
		# 		get: (proxy, name) ->
		# 			if name is 'inspect'
		# 				return result
		# 			else if name is 'toString'
		# 				->
		# 					if self.hasOwnProperty('__unicode') and typeof self.__unicode == 'function'
		# 						self.__unicode.call self, result
		# 					else
		# 						JSON.stringify result, null, 4
		# 			else
		# 				if result and result.hasOwnProperty(name)
		# 					result[name]
		# 				else
		# 					null
		# 		set: (proxy, name, value) ->
		# 		# apply: (target, thisArg, argumentsList) ->
		# 		# 	->
		#
		# exec: (cb) ->
		# 	self = this
		# 	# model.Query
		#
		# 	types = null
		# 	pending_fields = []
		# 	global_where = @_query?.where
		#
		# 	unless @__query_c
		# 		@__query_c = new model.Query.Query dialect: @conn.dialect
		#
		# 	if @_query.select
		# 		tmp = @__query_c.select().from @table
		#
		# 		if @_query.select isnt '*' and Array.isArray(@_query.select) and @_query.select.length isnt 0
		# 			tmp.select @_query.select
		#
		# 		if @_query.where and Object.keys(@_query.where).length isnt 0
		# 			tmp.where @_query.where
		#
		# 		for i in @_query.sum ? []
		# 			if typeof i[0] is 'string'
		# 				_tmp = tmp.sum i[0]
		# 				if i[1] then _tmp.as i[1]
		# 			else
		# 				do tmp.sum
		#
		# 		types = 1
		# 	else if @_query.update
		# 		tmp = @__query_c.update().into(@table).set @_query.update
		#
		# 		if @_query.where and Object.keys(@_query.where).length isnt 0
		# 			tmp.where @_query.where
		#
		# 		types = 2
		# 	else if @_query.insert
		# 		tmp = @__query_c.insert().into(@table).set @_query.insert
		#
		# 		types = 3
		# 	else if @_query.delete
		# 		tmp = @__query_c.remove().from @table
		#
		# 		if @_query.where and Object.keys(@_query.where).length isnt 0
		# 			tmp.where @_query.where
		#
		# 		types = 4
		#
		# 	# console.log @_query
		#
		# 	if @_query.limit then tmp.limit @_query.limit
		# 	if @_query.offset then tmp.offset @_query.offset
		#
		# 	if @_query.order
		# 		for i in @_query.order
		# 			tmp.order i[0], i[1]
		#
		# 	if @_query.group then tmp.groupBy @_query.group
		#
		# 	is_one_result = @_query.findOne or false
		#
		# 	@_query = null
		#
		# 	# console.log do tmp.build
		#
		#
		#
		# 	do_query = (err) ->
		# 		# count++
		# 		# console.log 'called >>>>>>>>>>>>.', count, query
		# 		# console.log (new Error).stack
		#
		# 		if err
		# 			console.error err.stack ? err
		# 			cb err, null
		# 			return
		#
		# 		# console.log tmp.build()
		#
		# 		self.conn.query tmp.build(), [], (err, result) ->
		# 			throw err if err
		# 				# cb err, false
		# 				# return
		#
		# 			# model.synchro ->
		# 			# wait.launchFiber ->
		#
		# 			try
		# 				x = undefined
		# 				y = undefined
		# 				_find = undefined
		# 				q = undefined
		# 				__find = undefined
		# 				ret_cval = undefined
		# 				f = undefined
		# 				r = undefined
		# 				t_fields = undefined
		# 				w = undefined
		# 				vals = undefined
		# 				insert_result = undefined
		# 				last_insert_id = null
		#
		# 				###,
		# 				raw_lii = null;
		# 				###
		#
		# 				try
		# 					if types == 3
		# 						if result[0]?.id
		# 							# last_insert_id = result[0].id
		# 							cb null, last_insert_id: result[0].id
		# 						else
		# 							last_insert_id = self.conn.last_insert_id (err, ret) ->
		# 								if err
		# 									console.log err.stack ? err
		# 								else
		# 									cb null, last_insert_id: ret[0].last_insert_id
		# 				catch e
		# 					console.log e.stack ? e
		#
		# 				# console.log 'teeererer'
		#
		# 				# try
		# 				for x of result
		#
		# 					if result.hasOwnProperty(x)
		#
		# 						for y of result[x]
		#
		# 							if result[x].hasOwnProperty(y)
		#
		# 								_find = {}
		#
		# 								if typeof self.attributes[y] == 'object' and self.attributes[y].collection and self.attributes[y].via
		#
		# 									_find = {}
		# 									_find[self.attributes[y].via] = result[x][y]
		#
		# 									# console.log 'Request query first'
		# 									await model.global_model[self.$root][self.attributes[y].collection].find(_find).exec defer err_d, result[x][y]
		# 									throw err_d if err_d
		#
		#
		# 									if result[x][y].length is 1
		# 										result[x][y] = result[x][y][0]
		# 									else if result[x][y].length is 0
		# 										result[x][y] = null
		# 								else if typeof self.attributes[y] == 'object' and self.attributes[y].model
		#
		# 									# console.log 'teeererer 8888888888888888'
		#
		# 									if result[x][y]
		# 										_find = {}
		# 										_find.id = result[x][y]
		#
		# 										# console.log 'teeererer 99999999999999999'
		#
		# 										if not model.global_model[self.$root][self.attributes[y].model]?
		# 											throw new Error "MODEL file of 'tbl_#{self.attributes[y].model}' is not found."
		#
		# 										# console.log 'Request query second'
		# 										await model.global_model[self.$root][self.attributes[y].model].findOne().where(_find).exec defer err_d, result[x][y]
		# 										throw err_d if err_d
		#
		# 				if is_one_result
		# 					result = result[0] or null
		#
		#
		# 				if types == 2 #and pending_fields.length != 0
		# 					# update
		#
		# 					for q of self.attributes
		#
		# 						if self.attributes.hasOwnProperty(q)
		#
		# 							# __find = {}
		# 							if typeof self.attributes[q] == 'object' and (self.attributes[q].collection and self.attributes[q].via or self.attributes[q].model)
		#
		# 								await self.find(global_where).exec defer err_d, ret_cval
		# 								throw err_d if err_d
		#
		#
		# 				cb null, result
		# 			catch err
		# 				cb err
		# 			# , (err) ->
		# 			# 	console.log err.stack ? err
		#
		# 			return
		#
		# 		return
		#
		# 	try if @conn
		# 		if @conn.$
		# 			self = @
		# 			@conn.$ ->
		# 				self.is_init = true
		# 				if self.migrate and self.migrate isnt 'safe'
		# 					# init = wait.forMethod self.conn, 'table', self.table.replace(new RegExp("^#{self.conn.prefix}"), ''), self.attributes, model.global_model[self.$root]
		# 					await self.conn.table self.table.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase().replace(new RegExp("^#{self.conn.prefix}"), ''), self.attributes, model.global_model[self.$root], defer d_err, init
		# 					throw d_err if d_err
		#
		# 					if init and init is 'onCreate' && self.hasOwnProperty init
		# 						do table[init]
		# 				do do_query
		# 		else if not @is_init?
		# 			@is_init = true
		# 			if @migrate and @migrate isnt 'safe'
		# 				# init = wait.forMethod @conn, 'table', @table.replace(new RegExp("^#{@conn.prefix}"), ''), @attributes, model.global_model[self.$root]
		# 				await @conn.table @table.replace(new RegExp("^#{@conn.prefix}"), ''), @attributes, model.global_model[self.$root], defer d_err, init
		# 				throw d_err if d_err
		#
		# 				if init and init is 'onCreate' && @hasOwnProperty init
		# 					do table[init]
		#
		# 			do do_query
		# 		else
		# 			do do_query
		# 	else
		# 		cb 'ERROR: Can\'t query without connection'
		# 		console.error 'ERROR: Can\'t query without connection'
		# 	catch err
		# 		cb err
		#
		# 	return

	@escapeRegExp: (str) ->
		str.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, '\\$&'
