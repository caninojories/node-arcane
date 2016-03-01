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

import ObjectDoesNotExist in core.Exceptions

import fieldManyToMany, fieldOneToOne in core.Model


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

		for vhost in $vhost
			try for i, v of model.global_model[vhost]
				model.init_connection.sync(null, v, model.global_model[vhost])

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

			# console.log console.log orm.conn.prefix, name, orm.connection

			orm.table = (if orm.conn? then orm.conn.prefix else 'tbl_') + do name.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase
			orm.alias = name
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


			try
				orm.con root, $connector[root], orm.connection

				if orm.migrate and orm.migrate isnt 'safe'
					if orm.conn.$
						wait.for orm.conn.$

					init = wait.forMethod orm.conn, 'table', name.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase(), orm.attributes, model.global_model[root]
					if init and init is 'onCreate' && orm.hasOwnProperty init
						do orm[init]
			catch err
				# console.log err.stack or err if err?
				throw err


		_cl = new cl
		_cl.__proto__ = orm

		model.global_model[root][name] = model.models[root][name].cl = _cl

		wait.launchFiber ->
			model.init_connection.sync(null, model.global_model[root][name], model.global_model[root])

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

	@init_relations: (self, model_list, cb) ->
		a = null
		for i, v of self.attributes
			if v and typeof v is 'object' and Object.getOwnPropertyDescriptor(v, 'sql_function')?.value is 'many_to_many'
				# console.log self.table, i, v

				v.target_table = table_name = "#{self.table.replace self.conn.prefix, ''}_#{v.collection}".toLowerCase()

				self.__many_to_many ?= {}
				tmp_obj = self.__many_to_many[table_name] = {
					connection: self.connection
					migrate: 'alter'
					attributes: {}
				}

				tmp_obj.attributes[v.target_column = "#{self.table.replace self.conn.prefix, ''}_id"] = Number #fieldOneToOne(self.alias)
				tmp_obj.attributes[v.related_column = "#{v.collection.toLowerCase()}_id"] = Number #fieldOneToOne(v.collection)

				tmp_obj.table = "#{self.conn.prefix ? ''}#{table_name}"
				tmp_obj.con = model.connectionChange
				tmp_obj.conn = self.conn
				tmp_obj.query = tmp_obj.conn.query

				model_list[v.collection].set_lists ?= {}
				model_list[v.collection].set_lists["#{self.table.replace self.conn.prefix, ''}_set"] = {
					model: tmp_obj
					field: v.related_column
					target: self
					source: v.target_column
				}

				await model.init_connection tmp_obj, model_list, defer d_err, ret
				throw d_err if d_err?

			else if v and typeof v is 'object' and Object.getOwnPropertyDescriptor(v, 'sql_function')?.value is 'one_to_many'
				# console.log self.table, i, v
				a = null
			else if v and typeof v is 'object' and Object.getOwnPropertyDescriptor(v, 'sql_function')?.value is 'one_to_one'
				# console.log self.table, i, v
				a = null

		cb(null, true)

	@init_connection: (self, model_list, cb) ->
		try if self.conn
			if self.conn.$
				self.conn.$ ->
					self.is_init = true
					if self.migrate and self.migrate isnt 'safe'
						init = wait.forMethod self.conn, 'table', self.table.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase().replace(new RegExp("^#{self.conn.prefix}"), ''), self.attributes, model_list #, defer d_err, init
						# throw d_err if d_err

						wait.for model.init_relations, self, model_list #, defer d_err, ret
						# throw d_err if d_err

						if init and init is 'onCreate' && typeof self[init] is 'function'
							wait.launchFiber ->
								query_b = new model.Query.Query dialect: self.conn.dialect
								self[init].apply model.build_query_model(null, self, query_b, null, null, model_list), []
							, (err, result) ->
								throw err if err?

					cb null, true
			else if not self.is_init?
				self.is_init = true
				if self.migrate and self.migrate isnt 'safe'
					init = wait.forMethod self.conn, 'table', self.table.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase().replace(new RegExp("^#{self.conn.prefix}"), ''), self.attributes, model_list #, defer d_err, init
					# throw d_err if d_err

					wait.for model.init_relations, self, model_list #, defer d_err, ret
					# throw d_err if d_err

					if init and init is 'onCreate' && typeof self[init] is 'function'
						wait.launchFiber ->
							query_b = new model.Query.Query dialect: self.conn.dialect
							self[init].apply model.build_query_model(null, self, query_b, null, null, model_list), []
						, (err, result) ->
							throw err if err?

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
			if value.constructor?.name is 'Array'
				return value
			else if typeof value is 'function' and Object.getOwnPropertyDescriptor(value, 'information')?.value is '_ARC__MODEL_'
				related_column = Object.getOwnPropertyDescriptor(value, 'settings')?.value?.target_column
				if related_column
					return (i[related_column] for i in value)
				else
					return (i.id for i in value)
			else
				throw new Error 'List is not a valid Array type.'

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

	@qparam_builder: (model_data, builder, params, condition, model_list, exclude, relationship) ->

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
					in_relation = false

					if table_join.length is 0
						condition.push ['select', ['id']]
						condition.push ['as', ['id']]

						for z, a of last_model.attributes
							if typeof a is 'object' and Object.getOwnPropertyDescriptor(a, 'sql_function')?.value is 'many_to_many'
								continue
							condition.push ['select', [z]]
							condition.push ['as', [z]]

					for y, x of condition_list
						if typeof model_data.attributes[x] is 'object' and Object.getOwnPropertyDescriptor(model_data.attributes[x], 'sql_function')?.value is 'one_to_one'
							last_model = model_list[model_data.attributes[x].model]

							if table_join.indexOf(last_model.table) is -1
								condition.push ['from', [last_model.table, 'id', x]]
								table_join.push last_model.table

						else if typeof model_data.attributes[x] is 'object' and Object.getOwnPropertyDescriptor(model_data.attributes[x], 'sql_function')?.value is 'one_to_many'
							last_model = model_list[model_data.attributes[x].collection]

							if table_join.indexOf(last_model.table) is -1
								condition.push ['from', [last_model.table, model_data.attributes[x].via, x]]
								table_join.push last_model.table

						else if typeof model_data.attributes[x] is 'object' and Object.getOwnPropertyDescriptor(model_data.attributes[x], 'sql_function')?.value is 'many_to_many'
							# wait.for model.init_connection, model_data, model_list
							last_model = model_list[model_data.attributes[x].collection]

							tbl_name = model_data.__many_to_many[model_data.attributes[x].target_table].table
							if table_join.indexOf(tbl_name) is -1
								condition.push ['from', [tbl_name, model_data.attributes[x].target_column, model_data.attributes[x].via]]
								table_join.push tbl_name

							tbl_name2 = model_list[model_data.attributes[x].collection].table
							if table_join.indexOf(tbl_name2) is -1
								condition.push ['from', [tbl_name2, model_data.attributes[x].via, model_data.attributes[x].related_column]]
								table_join.push tbl_name2

							in_relation = true

						else if typeof last_model.attributes[x] isnt 'undefined'
							tmp_condition[last_model.table] = [] unless tmp_condition[last_model.table]

							found_condition = false

							value = ''
							if ((condition_list.length - 1) - y) is 1 and model.qparam_conditions[condition_list[-1..]]?
								found_condition = true
								value = model.qparam_conditions[condition_list[-1..]](v)
							else
								value = v

							if in_relation
								relationship.query[last_model.table] ?= []
								# relationship.query[last_model.table].push ['where', [x, value]]
								relationship.query[last_model.table].push [(if found_condition then "#{x}__#{condition_list[-1..]}" else x), v]

							tmp_condition[last_model.table].push [x, value]

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

	@check_field = (value) ->
		try
			if value and typeof value is 'function' and Object.getOwnPropertyDescriptor(value, 'information')?.value is '_ARC__MODEL_'
				return value.id
			else
				return value
		catch
			return value

	@build_query_array = ->
		if arguments.length is 1
			model.qparam_builder @model_data, @builder, arguments[0], @data_query, @model_list, @exclude, @relationship
		else if arguments.length > 1
			__or = []

			for i in arguments
				old_length = @data_query.length
				model.qparam_builder @model_data, @builder, i, @data_query, @model_list, @exclude, @relationship

				__query = @data_query.slice(0)
				__removed_query = 0

				for j in [old_length...@data_query.length] when __query[j][0] is 'where'
					if typeof __query[j][1][0] is 'object'
						__or.push __query[j][1][0]
					else
						console.log __query[j]

					@data_query.splice j - __removed_query, 1
					__removed_query++

			@data_query.push ['where', [or: __or]]

	@update_rows = (return_query, object_data, builder, model_data, model_list) ->
		if object_data.query? and object_data.data_rows.length is 0
			query = builder.select().from(model_data.table)
			for i in object_data.query
				query = query[i[0]].apply query, i[1]

			if return_query
				return query.build()

			# try
			# 	model.init_connection.sync null, model_data, model_list
			# catch err
			# 	console.info err.stack ? err

			try
				# console.info query.build()
				# dt = Number new Date
				result = model_data.conn.query.sync model_data.conn, query.build()
				# console.log Number(new Date) - dt, 'Query Time >>>>>'
			catch
				throw _error

			# if object_data.is_one and result.length isnt 1
			# 	throw new Error "Model: Error 'get' function should return 1 row, result: #{result.length}"

			object_data.data_rows = result
			# for i in result
			# 	object_data.data_rows.push model.build_query_model null, model_data, builder, i, {id: i.id}, model_list

			object_data.result_length = object_data.data_rows.length

			if object_data.data_rows.length isnt 0
				if result[0].constructor?.name is 'Object'
					object_data.data_build = result[0]
				else
					for i, v of result[0]
						object_data.data_build[i] = v

	@model_proxy_get: (self, target, name, build_query) ->
		switch name
			when 'get_or_create'
				self.objects.data_rows = []
				return (build) ->
					is_created = false
					__build = util._extend {}, build
					__defaults = util._extend {}, build.defaults ? {}
					delete __build.defaults if __build.defaults
					try
						ret = self.get(target, 'get') __build
					catch
						if _error.code is ObjectDoesNotExist
							for i, v of __build
								__defaults[i] = v
							try
								ret = self.get(target, 'create') __defaults
							catch err
								throw err
							is_created = true
						else
							throw _error

					return [ret, is_created]

			when 'update_or_create'
				self.objects.data_rows = []
				return (build) ->
					is_created = false
					__build = util._extend {}, build
					__defaults = util._extend {}, build.defaults ? {}
					delete __build.defaults if __build.defaults
					try
						ret = self.get(target, 'get') __defaults
						ret.update(__build)
					catch
						# console.info _error.stack ? _error
						if _error.code is ObjectDoesNotExist
							for i, v of __build
								__defaults[i] = v
							try
								ret = self.get(target, 'create') __defaults
							catch err
								throw err
							is_created = true
						else
							throw _error

					return [ret, is_created]

			when 'latest'
				self.objects.data_rows = []
				return (field_date)->
					return self.get(target, 'order_by') field_date

			when 'earliest'
				return (field_date)->
					return self.get(target, 'order_by') "-#{field_date}"

			when 'create'
				self.objects.data_rows = []
				return (build) ->
					d = {}
					extended = {}
					for x, y of build
						if typeof y in ['array', 'object']
							extended[x] = y
						else
							d[x] = model.check_field y
					r = model.build_query_model null, self.params.model_data, self.params.builder, d, null, self.params.model_list, true
					try
						do r.save
					catch
						throw _error

					for i, j of extended
						if r[i]? and Object.getOwnPropertyDescriptor(r[i], 'information')?.value is '_ARC__MODEL_'
							for k in j
								r[i].add(k)

					return r

			when 'add'
				if self.objects.settings.relation?
					return (val) ->
						obj = {}
						obj[self.objects.settings.target_field] = self.objects.settings.relation
						obj[self.objects.settings.target_field2] = model.check_field val
						return model.build_query_model(null, self.objects.settings.target_model, self.params.builder, null, null, self.params.model_list).create(obj)

			when 'save'
				delete self.objects.data_build.id if self.objects.data_build.id?
				self.objects.data_rows = []
				return ->
					# try
					# 	model.init_connection.sync null, self.params.model_data, self.params.model_list
					# catch err
					# 	console.log err.stack ? err
					if self.objects.type is 'create'
						try
							self.objects.data_resource = {}
							self.objects.query = [] unless self.objects.query?
							result = self.params.model_data.conn.query.sync self.params.model_data.conn, self.params.builder.insert().into(self.params.model_data.table).set(self.objects.data_build).build()
							self.objects.data_resource.id = self.objects.data_build.id = result?[0]?.last_insert_id ? result?[0]?.id ? result.insertId
							self.objects.query.push ['where', [{'id': self.objects.data_resource.id}]]
						catch
							throw _error
						self.objects.type = 'update'
					else if self.objects.type is 'update' and self.objects.data_resource?.id?
						try
							self.params.model_data.conn.query.sync self.params.model_data.conn, self.params.builder.update().into(self.params.model_data.table).set(self.objects.data_build).where(self.objects.data_resource).build()
							self.objects.data_build.id = self.objects.data_resource.id
						catch
							throw _error
					else if self.objects.type is 'update' and self.objects.query?
						self.get(target, 'update') self.objects.data_build

			when 'filter'
				self.objects.query = self.objects.default_query unless self.objects.query?
				self.objects.data_rows = []
				return ->
					tmp_obj_relation = {query: {}}
					tmp_query = self.objects.query.slice(0)
					model.build_query_array.apply {relationship: tmp_obj_relation, exclude: false, data_query: tmp_query, model_data: self.params.model_data, model_list: self.params.model_list, builder: self.params.builder}, arguments
					r = model.build_query_model tmp_query, self.params.model_data, self.params.builder, null, null, self.params.model_list
					r.___settings_model = relation: tmp_obj_relation
					return r

			when 'exclude'
				self.objects.query = self.objects.default_query unless self.objects.query?
				self.objects.data_rows = []
				return ->
					tmp_obj_relation = {query: []}
					tmp_query = self.objects.query.slice(0)
					model.build_query_array.apply {relationship: tmp_obj_relation, exclude: true, data_query: tmp_query, model_data: self.params.model_data, model_list: self.params.model_list, builder: self.params.builder}, arguments
					r = model.build_query_model tmp_query, self.params.model_data, self.params.builder, null, null, self.params.model_list
					r.___settings_model = relation: tmp_obj_relation
					return r

			when 'get'
				self.objects.data_rows = []
				return ->
					try
						l = self.get(target, 'filter').apply(self, arguments)
					catch
						throw _error

					if (length_data = l.length) isnt 1
						err = new Error "Model: Error 'get' function should return 1 row, result: #{length_data}"
						err.code = ObjectDoesNotExist
						throw err

					return l

			when 'all'
				self.objects.query = self.objects.default_query
				self.objects.data_rows = []
				return ->
					return build_query

			when 'delete'
				self.objects.query = self.objects.default_query unless self.objects.query?
				self.objects.data_rows = []
				return ->
					query = self.params.builder.remove().from(self.params.model_data.table)
					for i in self.objects.query
						query = query[i[0]].apply query, i[1]

					# try
					# 	model.init_connection.sync null, self.params.model_data, self.params.model_list
					# catch err
					# 	console.log err.stack ? err

					try
						self.params.model_data.conn.query.sync self.params.model_data.conn, query.build()
					catch err
						# console.log err.stack ? err
						throw err

			when 'update'
				self.objects.query = self.objects.default_query unless self.objects.query?
				self.objects.data_rows = []
				return (new_data) ->
					d = {}

					for x, y of new_data
						d[x] = model.check_field y

					query = self.params.builder.update().into(self.params.model_data.table).set(d)
					for i in self.objects.query
						if typeof query[i[0]] is 'function'
							query = query[i[0]].apply query, i[1]

					# try
					# 	model.init_connection.sync null, self.params.model_data, self.params.model_list
					# catch err
					# 	console.log err.stack ? err

					try
						self.params.model_data.conn.query.sync self.params.model_data.conn, query.build()
					catch err
						# console.log err.stack ? err
						throw err

			when 'order_by'
				self.objects.query = self.objects.default_query unless self.objects.query?
				self.objects.data_rows = []
				return (field) ->
					tmp_query = self.objects.query.slice(0)

					if field[0] is '-'
						tmp_query.push ['order', [field.replace(/^\-/g, ''), 'Z']]
					else
						tmp_query.push ['order', [field, 'A']]

					return model.build_query_model tmp_query, self.params.model_data, self.params.builder, null, null, self.params.model_list

			when 'count'
				self.objects.query = self.objects.default_query unless self.objects.query?
				return ->
					tmp_query = self.objects.query.slice(0)
					tmp_query.push ['count', arguments]
					return model.build_query_model tmp_query, self.params.model_data, self.params.builder, null, null, self.params.model_list

			when 'length'
				if self.objects.data_rows.length is 0
					tmp_objects = util._extend {}, self.objects
					model.update_rows false, tmp_objects, self.params.builder, self.params.model_data, self.params.model_list
					self.objects.result_length = tmp_objects.result_length
					self.objects.data_rows = tmp_objects.data_rows
					self.objects.data_build = tmp_objects.data_build

				return self.objects.data_rows.length

			when 'query'
				return model.update_rows true, self.objects, self.params.builder, self.params.model_data, self.params.model_list

			when 'toString', 'valueOf'
				return ->
					if typeof self.params.model_data.__unicode__ is 'function'
						return String self.params.model_data.__unicode__.apply build_query, [build_query]
					else
						if self.objects.data_rows.length is 0
							tmp_objects = util._extend {}, self.objects
							model.update_rows false, tmp_objects, self.params.builder, self.params.model_data, self.params.model_list
							self.objects.result_length = tmp_objects.result_length
							self.objects.data_rows = tmp_objects.data_rows
							self.objects.data_build = tmp_objects.data_build

						if self.objects.data_rows.length is 0
							return 'null'
						else if self.objects.data_rows.length is 1
							tmp = id: self.objects.data_rows[0].id
							for i, v of self.params.model_data.attributes
								tmp[i] = self.objects.data_rows[0][i]
							return JSON.stringify(tmp, null, 4).replace(/\"([^"]+)\":/g,"$1:").replace(/\uFFFF/g,"\\\"")
						else
							tmp = []
							for i in self.objects.data_rows
								tmp.push i.toJSON()
							return "[#{tmp.join ', '}]"

			when 'slice'
				self.objects.data_rows = []
				return ->
					tmp_query = self.objects.query.slice(0)
					tmp_query.push ['offset', [arguments[0]]]
					if arguments[1]?
						tmp_query.push ['limit', [arguments[1] - 1]]
					return model.build_query_model tmp_query, self.params.model_data, self.params.builder, null, null, self.params.model_list

			when 'exists'
				return ->
					return self.get(target, 'length') isnt 0

			when 'values_list'
				return (field, options) ->
					return []

			when 'aggregate'
				self.objects.query = self.objects.default_query unless self.objects.query?
				self.objects.data_rows = []
				return ->
					tmp_query = self.objects.query.slice(0)
					parse_val = (value, func, alias, set_alias) ->
						args = []
						for x, v of value
							if typeof v is 'object' and target_func = Object.getOwnPropertyDescriptor(v, 'sql_function')?.value
								tmp_query.push [func, []]
								parse_val(v.val, target_func, "#{alias}__#{target_func}", set_alias)
								break
							else
								args.push v

						if not target_func and args.length isnt 0
							tmp_query.push [func, args]
							tmp_query.push ['as', [set_alias ? "#{args[0]}__#{alias}"]]
						else if not target_func and args.length is 0
							tmp_query.push [func, [null, alias]]

					if arguments.length is 1
						if typeof arguments[0] is 'object' and not Object.getOwnPropertyDescriptor(arguments[0], 'sql_function')?.value
							for i, v of arguments[0]
								if typeof v is 'object' and target_func = Object.getOwnPropertyDescriptor(v, 'sql_function')?.value
									parse_val(v.val, target_func, target_func, i)
								else
									throw new Error 'Not a valid aggregate function.'

						else if typeof arguments[0] is 'object' and target_func = Object.getOwnPropertyDescriptor(arguments[0], 'sql_function')?.value
							parse_val(arguments[0].val, target_func, target_func)
					else if arguments.length > 1
						for i in arguments
							if typeof i is 'object' and target_func = Object.getOwnPropertyDescriptor(i, 'sql_function')?.value
								parse_val(i.val, target_func, target_func)
							else
								throw new Error 'Not a valid aggregate function.'

					return model.build_query_model tmp_query, self.params.model_data, self.params.builder, null, null, self.params.model_list

			when 'toJSON'
				return ->
					if typeof self.params.model_data.__unicode__ is 'function'
						return self.params.model_data.__unicode__.apply build_query, [build_query]
					else
						return "< #{self.params.model_data.table} >"

			when 'select_related'
				return (table) ->


			else
				if not isNaN(parseFloat(name)) and isFinite(name)
					length = self.get(target, 'length')
					if length isnt 0
						return model.build_query_model null, self.params.model_data, self.params.builder, self.objects.data_rows[name], {id: self.objects.data_rows[name].id}, self.params.model_list
						# return self.objects.data_rows[name]
					else
						return null
				else if regex = /^___queryset_get_([0-9]+?)$/g.exec(name)
					# return self.objects.data_rows[regex[1]]
					return model.build_query_model null, self.params.model_data, self.params.builder, self.objects.data_rows[regex[1]], {id: self.objects.data_rows[regex[1]].id}, self.params.model_list
				else if name isnt 'constructor'
					if self.objects.data_rows.length is 0
						tmp_objects = util._extend {}, self.objects
						model.update_rows false, tmp_objects, self.params.builder, self.params.model_data, self.params.model_list
						self.objects.result_length = tmp_objects.result_length
						self.objects.data_rows = tmp_objects.data_rows
						self.objects.data_build = tmp_objects.data_build

					if typeof self.params.model_data.attributes[name] is 'object' and Object.getOwnPropertyDescriptor(self.params.model_data.attributes[name], 'sql_function')?.value is 'one_to_one' #self.params.model_data.attributes[name].model? and self.params.model_list[self.params.model_data.attributes[name].model]?
						r = model.build_query_model null, self.params.model_list[self.params.model_data.attributes[name].model], self.params.builder, null, null, self.params.model_list
						return r.filter(id: self.objects.data_build[name])
					else if typeof self.params.model_data.attributes[name] is 'object' and Object.getOwnPropertyDescriptor(self.params.model_data.attributes[name], 'sql_function')?.value is 'one_to_many'
						r = model.build_query_model null, self.params.model_list[self.params.model_data.attributes[name].collection], self.params.builder, null, null, self.params.model_list
						tmp_obj = {}
						tmp_obj[self.params.model_data.attributes[name].via] = self.objects.data_build[name]
						return r.filter(tmp_obj)
					else if typeof self.params.model_data.attributes[name] is 'object' and Object.getOwnPropertyDescriptor(self.params.model_data.attributes[name], 'sql_function')?.value is 'many_to_many'
						if not self.objects.data_build[name]?
							tmodel = self.params.model_list[self.params.model_data.attributes[name].collection]
							unless tmodel.___model_fields?
								tmodel.___model_fields = []
								tmodel.___model_fields.push ['select', ['id']]
								tmodel.___model_fields.push ['as', ['id']]
								for z, a of tmodel.attributes
									if typeof a is 'object' and Object.getOwnPropertyDescriptor(a, 'sql_function')?.value is 'many_to_many'
										continue
									tmodel.___model_fields.push ['select', [z]]
									tmodel.___model_fields.push ['as', [z]]
							query_chain = tmodel.___model_fields.slice(0)
							relation_table = self.params.model_data.__many_to_many[self.params.model_data.attributes[name].target_table]
							query_chain.push ['from', [relation_table.table, self.params.model_data.attributes[name].related_column, 'id']]
							tmp_obj = {}
							tmp_obj[self.params.model_data.attributes[name].target_column] = self.objects.data_build.id
							query_chain.push ['where', [relation_table.table, tmp_obj]]
							if relation_query = self.objects.settings.relation?.query?[self.params.model_list[self.params.model_data.attributes[name].collection].table]
								for z in relation_query
									tmp_obj = {}
									tmp_obj[z[0]] = z[1]
									query_chain.push ['where', [self.params.model_list[self.params.model_data.attributes[name].collection].table, tmp_obj]]
							r = self.objects.data_build[name] = model.build_query_model(query_chain, tmodel, self.params.builder, null, null, self.params.model_list)
							r.___settings_model = target_model: relation_table, target_field:self.params.model_data.attributes[name].target_column, target_field2:self.params.model_data.attributes[name].related_column, relation: self.objects.data_build.id
							return r

					if self.objects.data_build[name]?
						return self.objects.data_build[name]
					else if self.params?.model_data?.set_lists?[name]? and self.get(target, 'length') isnt 0
						tmodel = self.params.model_data.set_lists[name].target
						unless tmodel.___model_fields?
							tmodel.___model_fields = []
							tmodel.___model_fields.push ['select', ['id']]
							tmodel.___model_fields.push ['as', ['id']]
							for z, a of tmodel.attributes
								if typeof a is 'object' and Object.getOwnPropertyDescriptor(a, 'sql_function')?.value is 'many_to_many'
									continue
								tmodel.___model_fields.push ['select', [z]]
								tmodel.___model_fields.push ['as', [z]]
						query_chain = tmodel.___model_fields.slice(0)
						relation_table = self.params.model_data.set_lists[name].model
						query_chain.push ['from', [relation_table.table, self.params.model_data.set_lists[name].source, 'id']]
						tmp_obj = {}
						tmp_obj[self.params.model_data.set_lists[name].field] = self.objects.data_build.id
						query_chain.push ['where', [relation_table.table, tmp_obj]]
						r = self.objects.data_build[name] = model.build_query_model(query_chain, self.params.model_data.set_lists[name].target, self.params.builder, null, null, self.params.model_list)
						# r.___settings_model = target_model: relation_table, target_field: self.params.model_data.set_lists[name].source, target_field2: self.params.model_data.set_lists[name].field, relation: build_query.id
						return r
					else
						return null
				else
					# throw new Error 'Constrcutor'
					# console.info name
					return null

	@build_query_model: (chain_query, model_data, builder, object, resource, model_list, is_cnewd = false) ->

		object_data = {
			is_one: false
			data_build: object ? {}
			data_resource: resource ? {}
			data_rows: if object? then [object] else []
			data_condition: {}
			query: chain_query ? null
			result_length: if object? then 1 else 0
			type: if is_cnewd then 'create' else 'update'
			settings: {}
			default_query: chain_query ? []
		}

		build_query = harmonyProxy (->),
			objects: object_data
			params: model_data: model_data, builder: builder, model_list: model_list
			get: (target, name) ->
				return model.model_proxy_get(this, target, name, build_query)

			set: (target, name, value) ->
				if @params.model_data?.attributes[name]?
					@objects.data_build[name] = model.check_field value
				else if name is '___settings_model'
					object_data.settings = value

			apply: ->

			getOwnPropertyDescriptor: (target, prop) ->
				if prop is 'information'
					return { configurable: true, enumerable: true, value: '_ARC__MODEL_' }
				else if prop is 'settings'
					return { configurable: true, enumerable: true, value: object_data.settings }
				else
					return {configurable: true, enumerable: true}

			enumerate: (target) ->
				model.update_rows false, object_data, builder, model_data, model_list
				return ("___queryset_get_#{x}" for x in [0...object_data.data_rows.length])

		return build_query

	@ModelExec: ($root) ->
		return harmonyProxy {}, {
			get: (target, name) ->
				if model.global_model[$root][name]?
					target_model = model.global_model[$root][name]

					return harmonyProxy (->), {
						get: (target, name) ->
							switch do name.toLowerCase
								when 'objects'
									query_b = new model.Query.Query dialect: target_model.conn.dialect
									return model.build_query_model null, target_model, query_b, null, null, model.global_model[$root]
								else
									if typeof target_model[name] is 'function'
										query_b = new model.Query.Query dialect: target_model.conn.dialect
										db = model.build_query_model null, target_model, query_b, null, null, model.global_model[$root]
										return ->
											target_model[name].apply db, arguments

						set: (target, name, value) ->
							console.log name, value

						apply: (target, thisArg, argumentsList) ->
							query_b = new model.Query.Query dialect: target_model.conn.dialect
							return model.build_query_model null, target_model, query_b, (argumentsList[0] ? {}), null, model.global_model[$root], true
					}

				else
					throw new Error "Undefined model '#{name}'."

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

				# console.log orm.conn.prefix, class_name, orm.connection

				orm.table = (if orm.conn? then orm.conn.prefix else 'tbl_') + do class_name.replace(/[A-Z]/g, (match) -> "_#{do match.toLowerCase}").replace(/^_/, '').toLowerCase
				orm.alias = class_name
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

	@escapeRegExp: (str) ->
		str.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, '\\$&'
