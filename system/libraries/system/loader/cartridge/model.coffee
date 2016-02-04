package export cartridge.model

import system.Middleware
# import system.Sync


import fs
import harmony-proxy
import path

import tools.wait

import tools.iced

import util

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

		orm = util._extend {__proto__: cl.prototype}, model.orm

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

			orm.table = (if orm.conn? then orm.conn.prefix else 'tbl_') + do name.toLowerCase
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

					init = wait.forMethod orm.conn, 'table', name, orm.attributes, model.global_model[root]
					if init and init is 'onCreate' && orm.hasOwnProperty init
						do orm[init]
			catch err
				console.log err.stack or err if err?


		_cl = new cl
		_cl.__proto__ = orm

		model.global_model[root][name] = model.models[root][name].cl = _cl

		# if cl.attributes?
		# 	if not cl.connection?
		# 		throw new Error "'connection' are not declared in '#{name}'."

		# if cl.connection?
		# 	if $connector[root][cl.connection]?
		# 		cl.conn = $connector[root][cl.connection]
		# 	else 
		# 		cl.conn = null

		# 	cl.table = (if cl.conn? then cl.conn.prefix else 'tbl_') + do name.toLowerCase
		# 	cl.$root = root
		# 	cl.con = model.connectionChange

		# 	for v of model.orm then cl[v] = model.orm[v]

		# 	if $connector[cl.connection]?
		# 		cl.query = cl.conn.query
		# 	else
		# 		cl.query = ->
		# 			throw 'Query on empty connection.'
		# 			return

		# else if not $connector[cl.connection]?
		# 	throw new Error "No connection declared such as #{cl.connection}"

		# if primary then wait.launchFiber ->
		# 	try
		# 		cl.con root, $connector[root], cl.connection

		# 		if cl.migrate and cl.migrate isnt 'safe'
		# 			if cl.conn.$
		# 				wait.for cl.conn.$

		# 			init = wait.forMethod cl.conn, 'table', name, cl.attributes, model.global_model[root]
		# 			if init and init is 'onCreate' && cl.hasOwnProperty init
		# 				do cl[init]
		# 	catch err
		# 		console.log err.stack or err if err?

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

	@ModelExec: ($root) ->
		return harmonyProxy {}, {
			get: (target, name) ->
				if model.global_model[$root][name]?
					return model.global_model[$root][name]
				else
					return model.virtual_model

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

						init = wait.forMethod table.conn, 'table', name, table.attributes, model.global_model[$root]
						if init and init is 'onCreate' && table.hasOwnProperty init
							do table[init]
		}

	@scan: ($connector, vhost, mods, target_file, class_name) ->
		class_name = class_name[1] || class_name[2]

		model.models[vhost][class_name] = {}

		if /\.coffee$/g.test mods
			cl = __require target_file

			# console.log i for i, v of cl

			orm = util._extend {__proto__: cl.prototype}, model.orm

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

				orm.table = (if orm.conn? then orm.conn.prefix else 'tbl_') + do class_name.toLowerCase
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

			# cl[d] = v for d, v of new cl
		# else
		# 	cl = model.models[vhost][class_name].cl = new __require target_file

		# model.global_model[vhost][class_name] = cl

		# if cl.attributes?
		# 	if not cl.connection?
		# 		throw new Error "'connection' are not declared in '#{class_name}'."

		# if cl.connection?
		# 	if $connector[vhost][cl.connection]?
		# 		cl.conn = $connector[vhost][cl.connection]
		# 	else 
		# 		cl.conn = null

		# 	cl.table = (if cl.conn? then cl.conn.prefix else 'tbl_') + do class_name.toLowerCase
		# 	cl.$root = vhost
		# 	cl.con = model.connectionChange

		# 	# for v of model.orm then cl[v] = model.orm[v]

		# 	if $connector[cl.connection]?
		# 		cl.query = cl.conn.query
		# 	else
		# 		cl.query = ->
		# 			throw 'Query on empty connection.'
		# 			return

		# else if not $connector[cl.connection]?
		# 	throw new Error "No connection declared such as #{cl.connection}"


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

	# @parseWhere: (list, obj, raw, column, status) ->
	# 	i = undefined
	# 	tmp_list = undefined
	# 	key = undefined
	# 	_column = undefined
	# 	_status = undefined
	# 	_and = undefined
	# 	x = undefined
	# 	for i of obj
	# 		if obj.hasOwnProperty(i)
	# 			if i.toLowerCase() == 'or' and Object::toString.call(obj[i]) == '[object Array]'
	# 				model.parseWhere list, { '=': obj[i] }, raw, column or i, 'OR'
	# 			else if i.toLowerCase() == 'or' and Object::toString.call(obj[i]) == '[object Object]'
	# 				tmp_list = []
	# 				model.parseWhere tmp_list, obj[i], raw, column or i, 'OR'
	# 				list.push '(' + tmp_list.join(' OR ') + ')'
	# 			else if Object::toString.call(obj[i]) == '[object Object]'
	# 				model.parseWhere list, obj[i], raw, column or i
	# 			else if typeof obj[i] == 'string' or typeof obj[i] == 'number' or Object::toString.call(obj[i]) == '[object Array]'
	# 				key = i.toLowerCase()
	# 				_column = column
	# 				_status = status or 'AND'
	# 				if _column
	# 					if key == '!'
	# 						key = 'NOT LIKE'
	# 					else if key == 'like'
	# 						key = 'LIKE'
	# 					else if [
	# 							'>'
	# 							'>='
	# 							'<'
	# 							'<='
	# 							'<>'
	# 						].indexOf(key) == -1
	# 						key = '='
	# 				else
	# 					_column = i
	# 					key = '='
	# 				if Object::toString.call(obj[i]) == '[object Array]'
	# 					_and = []
	# 					for x of obj[i]
	# 						if obj[i].hasOwnProperty(x)
	# 							_and.push _column + ' ' + key + ' ?'
	# 							raw.push obj[i][x]
	# 					list.push '(' + _and.join(' ' + String(_status).toUpperCase() + ' ') + ')'
	# 				else
	# 					list.push _column + ' ' + key + ' ?'
	# 					raw.push obj[i]
	# 	return

	# @field_unzip: (arr) ->
	# 	ret = {}
	# 	x = undefined
	# 	for x of arr[0]
	# 		if arr[0].hasOwnProperty(x)
	# 			ret[arr[0][x]] = arr[1][x]
	# 	ret

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
		create: (obj) ->
			if @migrate != 'safe'
				obj.date_added = obj.date_modified = Math.round(+new Date / 1000)
			@_query = insert: obj
			this

		sum: (param, as) ->
			if not @_query then @_query = {}
			if not @_query.sum then @_query.sum = []
			if not @_query.select then @_query.select = []

			@_query.sum.push [(param ? true), as]

			this

		find: (obj) ->
			select = []
			if @_query and @_query.select
				select = @_query.select
			@_query =
				select: select
				where: obj
			this

		update: (update_obj, where_obj) ->
			if @migrate != 'safe'
				update_obj.date_modified = Math.round(+new Date / 1000)
			@_query =
				update: update_obj
				where: where_obj
			this

		findOne: (number) ->
			select = []
			if @_query and @_query.select
				select = @_query.select
			@_query =
				select: select
				limit: number or 1
				findOne: true
			this

		destroy: (where_obj) ->
			@_query =
				delete: true
				where: where_obj
			this

		count: (where_obj) ->
			@_query =
				count: true
				where: where_obj
			this

		populate: (field) ->
			if !@_query
				@_query = {}
			if !@_query.select
				@_query.select = []
			@_query.select.push field
			this

		stream: ->
			this

		populateAll: ->
			if !@_query.select
				@_query.select = []
			@_query.select = '*'
			this

		sort: (property, order) ->
			unless Array.isArray @_query.order
				@_query.order = []
			
			if property[0] is "-"
				@_query.order.push [ property.substr(1), "Z" ]
			else
				@_query.order.push [ property, (if order && order.toUpperCase() is "Z" then "Z" else "A") ]
			
			this

		where: (obj) ->
			@_query.where = obj
			this

		limit: (limit) ->
			@_query.limit = limit
			this

		offset: (offset) ->
			@_query.offset = offset
			this

		group: (group) ->
			@_query.group = group
			this

		validate: (params) ->
			self = this
			if typeof params is 'object'
				current_field = null
				current_label = null
				handler = harmonyProxy params,
					get: (proxy, name) ->
						if params[name]
							params[name]
						else if self[name]
							self[name]
						else if name is '__label'
							current_label
						else if name is '__field'
							current_field

					set: (proxy, name, value) ->
						params[name] = value

				for i, v of params
					label = i.replace /\_.|\-./g, (match) ->
						do match.replace(/\_|\-/g, ' ').toUpperCase
					label = label.replace /^./g, (match) ->
						match.toUpperCase

					current_field = i

					if @attributes[i]?
						if typeof @attributes[i] is 'object' and @attributes[i].validation?
							if typeof @attributes[i].validation.label is 'string'
								current_label = @attributes[i].validation.label

							if typeof @attributes[i].validation.minLength is 'number' and v.length > @attributes[i].validation.minLength
								throw field: i, error: "model.validation.#{i}.minLength", label: current_label, message: ''

							if typeof @attributes[i].validation.maxLength is 'number' and v.length < @attributes[i].validation.maxLength
								throw field: i, error: "model.validation.#{i}.maxLength", label: current_label, message: ''

							if typeof @attributes[i].validation.pattern is 'string'
								for j in @attributes[i].validation.pattern.split '|'
									if model.validator[j]
										if not model.validator[j].call handler, v
											error_message = null
											if @validationMessages?[i]?[j]
												error_message = @validationMessages[i][j].replace /\{\{label\}\}/g, current_label
											else if model.validationMessages[j]
												error_message = model.validationMessages[j].replace /\{\{label\}\}/g, current_label

											throw field: i, error: "model.validation.#{i}.#{j}", label: current_label, message: error_message
									else if typeof @types is 'object' and typeof @types[j] is 'function'
										if not @types[j].call handler, v
											error_message = null
											if @validationMessages?[i]?[j]
												error_message = @validationMessages[i][j].replace /\{\{label\}\}/g, current_label
											else if model.validationMessages[j]
												error_message = model.validationMessages[j].replace /\{\{label\}\}/g, current_label

											throw field: i, error: "model.validation.#{i}.#{j}", label: current_label, message: ''

					# else
					# 	throw "Column '#{i}' is no exists."

				# console.log @attributes

			this

		validateAndCreate: (params) ->

			this

		validateAndUpdate: (params) ->

			this

		commit: ->
			result = wait.forMethod @, 'exec'

			self = this
			if !result
				return null

			return harmonyProxy result,
				get: (proxy, name) ->
					if name is 'inspect'
						return result
					else if name is 'toString'
						->
							if self.hasOwnProperty('__unicode') and typeof self.__unicode == 'function'
								self.__unicode.call self, result
							else
								JSON.stringify result, null, 4
					else
						if result and result.hasOwnProperty(name)
							result[name]
						else
							null
				set: (proxy, name, value) ->
				# apply: (target, thisArg, argumentsList) ->
				# 	->

		exec: (cb) ->
			self = this
			# model.Query
			 
			types = null
			pending_fields = []
			global_where = @_query?.where
			
			unless @__query_c
				@__query_c = new model.Query.Query dialect: @conn.dialect

			if @_query.select
				tmp = @__query_c.select().from @table

				if @_query.select isnt '*' and Array.isArray(@_query.select) and @_query.select.length isnt 0
					tmp.select @_query.select

				if @_query.where and Object.keys(@_query.where).length isnt 0
					tmp.where @_query.where

				for i in @_query.sum ? []
					if typeof i[0] is 'string'
						_tmp = tmp.sum i[0]
						if i[1] then _tmp.as i[1]
					else
						do tmp.sum

				types = 1
			else if @_query.update
				tmp = @__query_c.update().into(@table).set @_query.update

				if @_query.where and Object.keys(@_query.where).length isnt 0
					tmp.where @_query.where

				types = 2
			else if @_query.insert
				tmp = @__query_c.insert().into(@table).set @_query.insert

				types = 3
			else if @_query.delete
				tmp = @__query_c.remove().from @table

				if @_query.where and Object.keys(@_query.where).length isnt 0
					tmp.where @_query.where

				types = 4

			# console.log @_query

			if @_query.limit then tmp.limit @_query.limit
			if @_query.offset then tmp.offset @_query.offset

			if @_query.order
				for i in @_query.order
					tmp.order i[0], i[1]

			if @_query.group then tmp.groupBy @_query.group

			is_one_result = @_query.findOne or false

			@_query = null

			# console.log do tmp.build



			do_query = (err) ->
				# count++
				# console.log 'called >>>>>>>>>>>>.', count, query
				# console.log (new Error).stack

				if err
					console.error err.stack ? err
					cb err, null
					return

				# console.log tmp.build()

				self.conn.query tmp.build(), [], (err, result) ->
					throw err if err
						# cb err, false
						# return

					# model.synchro ->
					# wait.launchFiber ->
					
					try
						x = undefined
						y = undefined
						_find = undefined
						q = undefined
						__find = undefined
						ret_cval = undefined
						f = undefined
						r = undefined
						t_fields = undefined
						w = undefined
						vals = undefined
						insert_result = undefined
						last_insert_id = null

						###,
						raw_lii = null;
						###

						try
							if types == 3
								if result[0]?.id
									# last_insert_id = result[0].id
									cb null, last_insert_id: result[0].id
								else
									last_insert_id = self.conn.last_insert_id (err, ret) ->
										if err
											console.log err.stack ? err
										else
											cb null, last_insert_id: ret[0].last_insert_id
						catch e
							console.log e.stack ? e

						# console.log 'teeererer'

						# try
						for x of result

							# console.log 'teeererer 22222222'

							if result.hasOwnProperty(x)

								# console.log 'teeererer 33333333333'

								for y of result[x]

									# console.log 'teeererer 4444444444'

									if result[x].hasOwnProperty(y)

										# console.log 'teeererer 555555555'

										_find = {}

										# console.log 'teeererer 6666666666666'

										if typeof self.attributes[y] == 'object' and self.attributes[y].collection and self.attributes[y].via

											# console.log 'teeererer 7777777777777'

											_find = {}
											_find[self.attributes[y].via] = result[x][y]

											# console.log 'teeererer 8888888888888888888888'

											# result[x][y] = do model.global_model[self.$root][self.attributes[y].collection].find(_find).commit
											
											# console.log 'Request query first'
											await model.global_model[self.$root][self.attributes[y].collection].find(_find).exec defer err_d, result[x][y]
											throw err_d if err_d


											if result[x][y].length is 1
												result[x][y] = result[x][y][0]
											else if result[x][y].length is 0
												result[x][y] = null
										else if typeof self.attributes[y] == 'object' and self.attributes[y].model

											# console.log 'teeererer 8888888888888888'

											if result[x][y]
												_find = {}
												_find.id = result[x][y]

												# console.log 'teeererer 99999999999999999'

												if not model.global_model[self.$root][self.attributes[y].model]?
													throw new Error "MODEL file of 'tbl_#{self.attributes[y].model}' is not found."

												# result[x][y] = do model.global_model[self.$root][self.attributes[y].model].findOne().where(_find).commit

												# console.log 'Request query second'
												await model.global_model[self.$root][self.attributes[y].model].findOne().where(_find).exec defer err_d, result[x][y]
												throw err_d if err_d

										# console.log 'teeererer 10000000000000000000'

						# console.log 'teeererer 111111 1111111111 11111111111'

						if is_one_result
							# console.log 'RESULT 11111111111111111'
							result = result[0] or null


						# catch e
						# 	console.log 'ERRORR 11111111111111111'
						# 	console.log e.stack ? e

						# console.log 'teeererer 2222 22 22 22 2222 22 222 22'

						if types == 2 #and pending_fields.length != 0
							# update
							
							# console.log 'teeererer 333 3 33 3333 33 33 3333333 333'

							for q of self.attributes

								# console.log 'teeererer 44 444444 44 4 4 4 44 44 4 4 444'

								if self.attributes.hasOwnProperty(q)

									# console.log 'teeererer 555 5 55 5 5555 5 55 5 5 5 555 5 5 5 5'

									# __find = {}
									if typeof self.attributes[q] == 'object' and (self.attributes[q].collection and self.attributes[q].via or self.attributes[q].model)
										# ret_cval = wait.forMethod self.find(global_where), 'exec'
										
										# console.log 'teeererer 666 66 6 6 6 666 66 6 6 6 6 6 6 66 6 6 6 6 6 6 '

										await self.find(global_where).exec defer err_d, ret_cval
										throw err_d if err_d




										# for f of ret_cval
										# 	if ret_cval.hasOwnProperty(f)
										# 		for r of ret_cval[f][q]
										# 			if ret_cval[f][q].hasOwnProperty(r)
										# 				if !__find.or
										# 					__find.or = []
										# 				__find.or.push id: ret_cval[f][q][r].id

										###if (Object.keys(__find).length !== 0) {
												global_model[self.attributes[q].model || self.attributes[q].collection].update(field_unzip([pending_fields, pending_value]), __find).exec.sync(global_model[self.attributes[q].model || self.attributes[q].collection]);
										}
										###

						# else if types == 3 and pending_fields.length != 0
						# 	#insert
						# 	t_fields = {}
						# 	try
						# 		for w of self.attributes
						# 			if typeof self.attributes[w] == 'object' and (self.attributes[w].collection and self.attributes[w].via or self.attributes[w].model)
						# 				vals = model.field_unzip([
						# 					pending_fields
						# 					pending_value
						# 				])
						# 				insert_result = model.global_model[self.$root][self.attributes[w].model or self.attributes[w].collection].create(vals).exec.sync(model.global_model[self.$root][self.attributes[w].model or self.attributes[w].collection])
						# 				if insert_result.last_insert_id
						# 					if self.attributes[w].model
						# 						t_fields[w] = insert_result.last_insert_id
						# 					else
						# 						if self.attributes[w].via == 'id'
						# 							t_fields[w] = insert_result.last_insert_id
						# 						else
						# 							t_fields[w] = vals[self.attributes[w].via]
						# 		if Object.keys(t_fields).length != 0
						# 			self.update(t_fields, id: last_insert_id).exec.sync self
						# 	catch er
						# 		console.log er.stack or er
						# if types == 3
						# 	result = last_insert_id: last_insert_id

						# try
						# 	cb null, result
						# catch err_cb
						# 	console.log err_cb.stack ? err

						# console.log 'teeererer 77 77 7 7 77 777 77 7 7 77 7 7 77 777'

						cb null, result
					catch err
						cb err
					# , (err) ->
					# 	console.log err.stack ? err

					return

				return

			try if @conn
				if @conn.$
					self = @
					@conn.$ ->
						self.is_init = true
						if self.migrate and self.migrate isnt 'safe'
							# init = wait.forMethod self.conn, 'table', self.table.replace(new RegExp("^#{self.conn.prefix}"), ''), self.attributes, model.global_model[self.$root]
							await self.conn.table self.table.replace(new RegExp("^#{self.conn.prefix}"), ''), self.attributes, model.global_model[self.$root], defer d_err, init
							throw d_err if d_err

							if init and init is 'onCreate' && self.hasOwnProperty init
								do table[init]
						do do_query
				else if not @is_init?
					@is_init = true
					if @migrate and @migrate isnt 'safe'
						# init = wait.forMethod @conn, 'table', @table.replace(new RegExp("^#{@conn.prefix}"), ''), @attributes, model.global_model[self.$root]
						await @conn.table @table.replace(new RegExp("^#{@conn.prefix}"), ''), @attributes, model.global_model[self.$root], defer d_err, init
						throw d_err if d_err

						if init and init is 'onCreate' && @hasOwnProperty init
							do table[init]

					do do_query
				else
					do do_query
			else
				cb 'ERROR: Can\'t query without connection'
				console.error 'ERROR: Can\'t query without connection'
			catch err
				cb err

			return

		# exec_old: (cb) ->
		# 	query = ''
		# 	raw = []
		# 	tmp = []
		# 	pending_fields = []
		# 	pending_value = []
		# 	types = null
		# 	i = undefined
		# 	j = undefined
		# 	k = undefined
		# 	fields = undefined
		# 	append = undefined
		# 	list = undefined
		# 	self = this
		# 	is_one_result = undefined
		# 	last_insert_id = undefined
		# 	global_where = undefined

		# 	if @_query.select
		# 		query += 'SELECT '
		# 		if @_query.select.length == 0
		# 			query += '* '
		# 		else
		# 			fields = []
		# 			for i of @_query.select
		# 				if @_query.select.hasOwnProperty(i)
		# 					if @_query.select[i] != 'id' and @_query.select[i] != 'date_added' and @_query.select[i] != 'date_modified' and !@attributes[@_query.select[i]]
		# 						pending_fields.push @_query.select[i]
		# 						continue
		# 					fields.push @_query.select[i]
		# 			query += fields.join(', ') + ' '
		# 		query += 'FROM ' + @table + ' '
		# 		types = 1
		# 		@_query.select = []
		# 	else if @_query.update
		# 		tmp = []
		# 		query += 'UPDATE ' + @table + ' SET '
		# 		for j of @_query.update
		# 			if @_query.update.hasOwnProperty(j)
		# 				if j != 'id' and j != 'date_added' and j != 'date_modified' and !@attributes[j]
		# 					pending_fields.push j
		# 					pending_value.push @_query.update[j]
		# 					continue
		# 				tmp.push j + ' = ?'
		# 				raw.push @_query.update[j]
		# 		query += tmp.join(', ') + ' '
		# 		types = 2
		# 		@_query.update = null
		# 	else if @_query.insert
		# 		append = []
		# 		tmp = []
		# 		query += 'INSERT INTO ' + @table + ' '
		# 		for k of @_query.insert
		# 			if @_query.insert.hasOwnProperty(k)
		# 				if k != 'id' and k != 'date_added' and k != 'date_modified' and !@attributes[k]
		# 					pending_fields.push k
		# 					pending_value.push @_query.insert[k]
		# 					continue
		# 				tmp.push k
		# 				raw.push @_query.insert[k]
		# 				append.push '?'
		# 		query += '(' + tmp.join(',') + ') VALUES (' + append.join(',') + ') '
		# 		types = 3
		# 		@_query.insert = null
		# 	else if @_query.delete
		# 		query += 'DELETE FROM ' + @table + ' '
		# 		types = 4
		# 		@_query.delete = null
		# 	if query.length != 0 and !@_query.insert
		# 		if @_query.where and Object.keys(@_query.where).length != 0
		# 			query += 'WHERE '
		# 			list = []
		# 			model.parseWhere list, @_query.where, raw
		# 			query += list.filter(Boolean).join(' AND ')
		# 			global_where = @_query.where
		# 			@_query.where = null
		# 		if @_query.group
		# 			if Array.isArray @_query.group
		# 				if @_query.group.length >= 1
		# 					query += ' GROUP BY ' + @_query.group.join(', ')
		# 			else
		# 				query += ' GROUP BY ' + @_query.group
		# 		if @_query.order_by
		# 			if Array.isArray @_query.order_by
		# 				if @_query.order_by.length >= 1
		# 					query += ' ORDER BY ' + @_query.order_by.join(', ')
		# 			else
		# 				query += ' ORDER BY ' + @_query.order_by
		# 		if @_query.limit
		# 			query += ' LIMIT ' + @_query.limit
		# 	is_one_result = @_query.findOne or false

		# 	count = 0

		# 	do_query = (err) ->
		# 		# count++
		# 		# console.log 'called >>>>>>>>>>>>.', count, query
		# 		# console.log (new Error).stack

		# 		if err
		# 			console.error err.stack ? err
		# 			cb err, null
		# 			return

		# 		self.conn.query query, raw, (err, result) ->
		# 			throw err if err
		# 				# cb err, false
		# 				# return

		# 			model.synchro ->
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

		# 				###,
		# 				raw_lii = null;
		# 				###

		# 				try
		# 					if types == 3
		# 						if result[0]?.id
		# 							last_insert_id = result[0].id
		# 						else
		# 							last_insert_id = self.conn.last_insert_id.sync(self.conn)[0].last_insert_id
		# 				catch e
		# 					console.log e.stack ? e

		# 				try
		# 					for x of result
		# 						if result.hasOwnProperty(x)
		# 							for y of result[x]
		# 								if result[x].hasOwnProperty(y)
		# 									_find = {}
		# 									if typeof self.attributes[y] == 'object' and self.attributes[y].collection and self.attributes[y].via
		# 										_find = {}
		# 										_find[self.attributes[y].via] = result[x][y]
		# 										result[x][y] = do model.global_model[self.$root][self.attributes[y].collection].find(_find).commit
		# 									else if typeof self.attributes[y] == 'object' and self.attributes[y].model
		# 										if result[x][y]
		# 											_find = {}
		# 											_find.id = result[x][y]

		# 											if not model.global_model[self.$root][self.attributes[y].model]?
		# 												throw new Error "MODEL file of 'tbl_#{self.attributes[y].model}' is not found."

		# 											result[x][y] = do model.global_model[self.$root][self.attributes[y].model].findOne().where(_find).commit
		# 					if is_one_result
		# 						result = result[0] or null
		# 				catch e
		# 					console.log e.stack ? e
		# 				if types == 2 and pending_fields.length != 0
		# 					# update
		# 					for q of self.attributes
		# 						if self.attributes.hasOwnProperty(q)
		# 							__find = {}
		# 							if typeof self.attributes[q] == 'object' and (self.attributes[q].collection and self.attributes[q].via or self.attributes[q].model)
		# 								ret_cval = self.find(global_where).exec.sync(self)
		# 								for f of ret_cval
		# 									if ret_cval.hasOwnProperty(f)
		# 										for r of ret_cval[f][q]
		# 											if ret_cval[f][q].hasOwnProperty(r)
		# 												if !__find.or
		# 													__find.or = []
		# 												__find.or.push id: ret_cval[f][q][r].id

		# 								###if (Object.keys(__find).length !== 0) {
		# 										global_model[self.attributes[q].model || self.attributes[q].collection].update(field_unzip([pending_fields, pending_value]), __find).exec.sync(global_model[self.attributes[q].model || self.attributes[q].collection]);
		# 								}
		# 								###

		# 				else if types == 3 and pending_fields.length != 0
		# 					#insert
		# 					t_fields = {}
		# 					try
		# 						for w of self.attributes
		# 							if typeof self.attributes[w] == 'object' and (self.attributes[w].collection and self.attributes[w].via or self.attributes[w].model)
		# 								vals = model.field_unzip([
		# 									pending_fields
		# 									pending_value
		# 								])
		# 								insert_result = model.global_model[self.$root][self.attributes[w].model or self.attributes[w].collection].create(vals).exec.sync(model.global_model[self.$root][self.attributes[w].model or self.attributes[w].collection])
		# 								if insert_result.last_insert_id
		# 									if self.attributes[w].model
		# 										t_fields[w] = insert_result.last_insert_id
		# 									else
		# 										if self.attributes[w].via == 'id'
		# 											t_fields[w] = insert_result.last_insert_id
		# 										else
		# 											t_fields[w] = vals[self.attributes[w].via]
		# 						if Object.keys(t_fields).length != 0
		# 							self.update(t_fields, id: last_insert_id).exec.sync self
		# 					catch er
		# 						console.log er.stack or er
		# 				if types == 3
		# 					result = last_insert_id: last_insert_id

		# 				# try
		# 				# 	cb null, result
		# 				# catch err_cb
		# 				# 	console.log err_cb.stack ? err
		# 				return result

		# 			, cb

		# 			return
		# 		return

		# 	try if @conn
		# 		if @conn.$
		# 			self = @
		# 			@conn.$ ->
		# 				self.is_init = true
		# 				if self.migrate and self.migrate isnt 'safe'
		# 					init = self.conn.table.sync self.conn, self.table.replace(new RegExp("^#{self.conn.prefix}"), ''), self.attributes, model.global_model[self.$root]
		# 					if init and init is 'onCreate' && self.hasOwnProperty init
		# 						do table[init]

		# 				do do_query
		# 		else if not @is_init?
		# 			@is_init = true
		# 			if @migrate and @migrate isnt 'safe'
		# 				init = @conn.table.sync @conn, @table.replace(new RegExp("^#{@conn.prefix}"), ''), @attributes, model.global_model[self.$root]
		# 				if init and init is 'onCreate' && @hasOwnProperty init
		# 					do table[init]

		# 			do do_query
		# 		else
		# 			do do_query
		# 	else
		# 		cb 'ERROR: Can\'t query without connection'
		# 		console.error 'ERROR: Can\'t query without connection'
		# 	catch err
		# 		cb err

		# 	return

	@escapeRegExp: (str) ->
		str.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, '\\$&'