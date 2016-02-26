package export cartridge.connector

import system.Middleware
# import system.Core

import jsondiffpatch
import path
import fs

class connector extends Middleware

	__init: ($config, $vhost) ->

		$config.event.on 'connector', (config) ->
			connector.list_config[config[0]] = {}
			init_connections config[0], config[1]
			do gc

		init_connections = (root, connections) ->
			for connection of connections
				options = connections[connection]
				if options.adapter?
					options.root = root
					adapter = path.resolve "#{__dirname}/../adapter/#{options.adapter}.coffee"
					functions = ['table', 'query', 'all', 'get', 'set', 'insert', 'delete', 'drop']

					if fs.existsSync adapter
						adapter_drv = __require adapter
						if adapter_drv.name?
							adapter_drv::generateFields = connector.generateFields
							adapter_drv::field_mapping = connector.field_mapping
							adapter_drv::field_diff = connector.field_diff
							adapter_drv::primary_field_diff = connector.primary_field_diff

							tmp_func = (adapdrv, opt) ->
								cl_driver = new adapdrv
								cl_driver.prefix = "#{if opt.hasOwnProperty('prefix') then opt.prefix else 'tbl_'}"

								cl_driver.$ = (callback) ->
									cl_driver.$ = null
									cl_driver.connect opt, (err, result) ->
										if err
											callback err, null
										else
											callback null, cl_driver
										return
									return

								cl_driver.reconnect = (callback) ->
									cl_driver.connect opt, (err, result) ->
										if err
											callback err, null
										else
											callback null, cl_driver
										return
									return

								return cl_driver

								# app.onClose ->
								# 	adapter_drv.close()
								# 	return

							connector.list_config[root][connection] = tmp_func adapter_drv, options

					else console.log "ERROR: Connector adapter '#{adapter}' not found."

		for value in $vhost

			if not connector.list_config[value]?
				connector.list_config[value] = {}

			if $config[value]?
				init_connections value, $config[value]['connector']



		Object.defineProperty global, 'Enumerate', get: ->
			class Enumerate
			->
				ret =
					type: Enumerate
					size: ''
				tmp_length = []
				for argument of arguments
					if typeof argument is 'string'
						tmp_length.push "'#{connector.escapeRegExp argument}'"
				ret.size = tmp_length.join ','
				return ret

		class Float
		global.Float = Float

		class DateTime
		global.DateTime = DateTime

		return connector.list_config


	__middle: ($req) ->
		return connector.list_config[$req.root]

	__socket: ($req) ->
		return connector.list_config[$req.root]

	###
	# Private function and variables
	###

	@list_config: {}

	@escapeRegExp: (str) ->
		str.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, '\\$&'

	@field_extender: (index, types) ->
		ret = ''
		if not types.noSize
			if types.size
				ret += '(' + types.size + ')'
		if types.isPostgre
			if types.increment
				ret += ' ' + @autoincrement
		if types.primary
			if @primary_keys
				@primary_keys.push index
			else
				ret += ' ' + @primarykey
		if not types.isPostgre
			if types.increment
				ret += ' ' + @autoincrement
		if types.unique
			if @unique_keys
				@unique_keys.push index
			else
				ret += ' ' + @unique
		if types.notNull
			ret += ' NOT NULL'
		if types.default
			ret += ' DEFAULT \'' + types.default + '\''
		ret

	@field_mapping: (construct_fields) ->
		last_field_map = null
		ret = {}
		l = undefined
		field_name_map = undefined
		for l of construct_fields
			if construct_fields.hasOwnProperty(l)
				field_name_map = /^(.+?)\s/g.exec(construct_fields[l])
				if field_name_map
					ret[field_name_map[1]] = [ last_field_map ]
					if last_field_map
						ret[last_field_map].push field_name_map[1]
					last_field_map = field_name_map[1]
		ret

	@field_diff: (current_fields, construct_fields) ->
		diffResult = jsondiffpatch.diff(current_fields, construct_fields)
		ret = null
		if diffResult
			add_fields = {}
			delete_fields = {}
			rename_fields = {}
			primary_field = []
			execpt_delete = {}
			j = undefined
			field_pattern = undefined
			primary_keys_pattern = undefined
			tmp_pattern = undefined
			for j of diffResult
				if diffResult.hasOwnProperty(j)
					field_pattern = /^(.+?)\s(.*)$/g.exec(diffResult[j][0])
					primary_keys_pattern = /^PRIMARY\sKEY\((.+?)\)$/.exec(diffResult[j][0])
					if /^[0-9]*$/g.exec(j)
						if field_pattern
							if diffResult['_' + j]
								tmp_pattern = /^(.+?)\s(.*)$/g.exec(diffResult['_' + j][0])
								if tmp_pattern and field_pattern and field_pattern[2] == tmp_pattern[2]
									rename_fields[field_pattern[1]] = [
										diffResult[j][0]
										tmp_pattern[1]
									]
									execpt_delete['_' + j] = true
									continue
							add_fields[field_pattern[1]] = diffResult[j][0]
						else if primary_keys_pattern
							primary_field = primary_keys_pattern[1].split(',')
					else if /^_[0-9]*$/g.exec(j)
						if field_pattern
							if execpt_delete[j]
								continue
							delete_fields[field_pattern[1]] = diffResult[j][0]
						else if primary_keys_pattern
							primary_field = jsondiffpatch.diff(primary_keys_pattern[1].split(','), primary_field)
			ret =
				add: add_fields
				delete: delete_fields
				rename: rename_fields
				primary: primary_field
		ret

	@primary_field_diff: (primary) ->
		primary_add = []
		primary_remove = []
		n = undefined
		for n of primary
			if primary.hasOwnProperty(n)
				if /^[0-9]*$/g.exec(n)
					primary_add.push primary[n][0]
				else if /^_[0-9]*$/g.exec(n)
					primary_remove.push primary[n][0]
		{
			add: primary_add
			remove: primary_remove
		}

	@generateFields: (data, model_list, options = {}) ->
		options.IDHasType ?= true
		options.postgres ?= false
		options.noSizeID ?= false

		fields = []
		i = undefined
		tp = undefined
		if @unique_keys
			@unique_keys = []
		if @primary_keys
			@primary_keys = []
		fields.push ('id ' + (if options.IDHasType then @types.Number.type else '') + connector.field_extender.call(this, 'id',
			size: @types.Number.size or false
			increment: options.incrementID ? true
			primary: options.primaryID ? true
			notNull: options.notNullID ? true
			isPostgre: options.postgres
			noSize: options.noSizeID )).replace /\s+/g, ' '
		for i of data
			if data.hasOwnProperty(i)
				if data[i] and data[i].isBuffer
					fields.push i + ' ' + @types.Buffer.type + connector.field_extender.call(this, i, @types.Buffer)
				else if typeof data[i] == 'object' and data[i].type and (!data[i].collection or !data[i].model)
					tp = data[i].type
					if typeof tp == 'function'
						tp = (new tp).name || (new tp).constructor.name
						if typeof @types[tp] != 'undefined'
							fields.push i + ' ' + @types[tp].type + connector.field_extender.call(this, i, data[i])
						else
							console.log data
							throw new Error '#1 Invalid type of \'' + tp + '\'.'
					else if typeof tp == 'string'
						fields.push i + ' ' + data[i].type + connector.field_extender.call(this, i, data[i])
					else
						throw new Error '#2 Invalid type of \'' + tp.toString() + '\'.'
				else if typeof data[i] == 'function'
					type = (new (data[i])).constructor.name
					if typeof @types[type] != 'undefined'
						fields.push i + ' ' + @types[type].type + connector.field_extender.call(this, i, @types[type])
					else
						throw new Error '#3 Invalid type of \'' + type + '\'.'
				else if typeof data[i] == 'object' and Object.getOwnPropertyDescriptor(data[i], 'sql_function')?.value is 'one_to_one'
					# console.info typeof data[i].model, typeof data[i].collection, data[i]
					# console.info String Object.keys(model_list ? {})
					if model_list and data[i].model in Object.keys(model_list)#model_list.hasOwnProperty(data[i].model)
						fields.push i + ' ' + @types.Number.type + connector.field_extender.call(this, i, @types.Number)
					else
						throw new Error 'Can\'t initialize field \'' + i + '\', model \'' + data[i].model + '\' is not found.'
				else if typeof data[i] is 'object' and Object.getOwnPropertyDescriptor(data[i], 'sql_function')?.value is 'many_to_many'
					continue
				else if typeof data[i] == 'object' and data[i].collection and data[i].via
					if model_list[data[i].collection]
						if model_list[data[i].collection].attributes[data[i].via] or data[i].via is 'id'

							# create table for relational here.
							# console.log typeof model_list[data[i].collection].attributes[data[i].via]

							if typeof model_list[data[i].collection].attributes[data[i].via] in ['function', 'object']
								_type = (new (model_list[data[i].collection].attributes[data[i].via])).constructor.name
								if typeof @types[_type] isnt 'undefined'
									fields.push i + ' ' + @types[_type].type + connector.field_extender.call(this, i, @types[_type])
								else
									throw new Error '#4 Invalid type of \'' + _type + '\'.'
							else if data[i].via is 'id'
								fields.push i + ' ' + @types['Number'].type + connector.field_extender.call(this, i, @types['Number'])
							else
								throw new Error '#5 Invalid type in \'' + i + '\'.'
						else
							throw new Error 'Can\'t initialize field \'' + i + '\', model attribute \'' + data[i].via + '\' is not found on \'' + data[i].collection + '\'.'
					else
						throw new Error 'Can\'t initialize field \'' + i + '\', model \'' + data[i].collection + '\' in not found.'
					#Open Model File
				else
					throw new Error 'Unknown type of field \'' + i + '\'. >> ', data[i]
					return false
		# fields.push 'date_modified ' + @types.Number.type + connector.field_extender.call(this, i, @types.Number)
		# fields.push 'date_added ' + @types.Number.type + connector.field_extender.call(this, i, @types.Number)
		# console.log fields
		fields
