package export Postgre

import sqli
import jsondiffpatch

class Postgre

	@postgres: sqli.getDriver 'postgres'

	@extra_options: (opt) ->
		ret = ''
		if opt.pk != 0
			ret += ' PRIMARY KEY AUTOINCREMENT'
		if opt.notnull != 0
			ret += ' NOT NULL'
		if opt.dflt_value
			ret += ' DEFAULT \'' + opt.dflt_value + '\''
		ret

	dialect: 'postgresql'

	constructor: ->
		@types =
			String: type: 'VARCHAR'
			Number: type: 'INT4'
			Object: type: 'TEXT'
			Array: type: 'TEXT'
			Buffer: type: 'BYTEA'
			Date: type: 'DATE'
			Float: type: 'FLOAT4'
		@autoincrement = 'SERIAL'
		@primarykey = 'PRIMARY KEY'
		@unique = 'UNIQUE'

	connect: (options, resolve, readonly) ->

		# console.log options

		connection = "tcp://#{if options.password then "#{options.user}:#{options.password}" else "#{options.user}"}@#{options.host}/#{options.database}"

		pool = Postgre.postgres.createPool(connection, options.maxConnection ? 50, options.timeout ? 10000)


		# self = @
		# if !options
		# 	throw new Error('Posgres Driver: Options are not defined.')
		# @opt = options

		# connection = ':memory:'

		# if !options.hasOwnProperty('memory') and options.hasOwnProperty('file')
		# 	connection = if /^\/.*$/g.exec(options.file) then options.file else options.root + '/' + options.file
		# pool = Postgre.postgres.createPool(connection, options.maxConnection or 50, options.timeout or 10000)

		# conn.error (err) ->
		# 	if err.code == 100
		# 		conn.resume()
		# 	else
		# 		conn.resume true
		# 	console.log err.code, err.stack
		# 	return
		@db = query: ->
			args = [].slice.call(arguments)
			cntr = args.length - 1
			query = undefined
			data = undefined
			cb = undefined
			if args[cntr] and typeof args[cntr] == 'function'
				cb = args[cntr]
				cntr--
			if args[cntr] and typeof args[cntr] == 'object'
				data = args[cntr]
				cntr--
			if args[cntr] and typeof args[cntr] == 'string'
				query = args[cntr]
				cntr--

			if /INSERT\sINTO/g.test do query.toUpperCase
				query += ' RETURNING id'

			conn = do pool.get
			conn.exec(query, data).all((rows) ->
				do conn.close
				cb null, rows
				return
			).then (err) ->
				if err

					if err.code is 100
						do conn.resume
					else
						conn.resume true

					# console.log err.code, err.stack

					cb err, null
				return
			return

		resolve null, true
		return

	last_insert_id: (callback) ->
		if @db
			# @db.query 'SELECT last_insert_rowid() AS `last_insert_id`', callback
			callback null, [last_insert_id: 0]
		return

	table: (table_name, data, model_list, callback) ->
		self = this
		self.db?.query? "SELECT  table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_name = '#{self.prefix}#{table_name}' AND  table_schema NOT IN ('pg_catalog', 'information_schema')", [], (err, result) ->
			if err
				console.log err, result

			if result.length is 0
				construct_fields = self.generateFields(data, model_list, notNullID: false, IDHasType: false, postgres: true, noSizeID: true)
				if construct_fields
					self.db.query "CREATE TABLE #{self.prefix}#{table_name} (#{construct_fields.join(', ')})", (err, _result) ->
						if err then console.log err.stack ? err
						callback null, 'onCreate'
				else
					callback 'ERROR: Can\'t create table.'
			else
				self.db.query "SELECT column_name, udt_name, character_maximum_length, numeric_precision, column_default, is_nullable FROM information_schema.columns WHERE table_name = '#{self.prefix}#{table_name}'", (err, _result) ->
					if err then console.log err.stack ? err

					current_fields = []
					for i in _result
						if /^nextval\(\'/g.test i.column_default
							current_fields.push "#{i.column_name} SERIAL PRIMARY KEY"
						else
							current_fields.push "#{i.column_name} #{do i.udt_name.toUpperCase}#{if i.character_maximum_length? then "(#{i.character_maximum_length})" else ""} #{if i.is_nullable is 'NO' then 'NOT NULL' else ''}".trim ' '

					construct_fields = self.generateFields(data, model_list, notNullID: false, IDHasType: false, postgres: true, noSizeID: true)

					field_diff = self.field_diff(current_fields, construct_fields)

					if field_diff
						query = []
						old_fields = []
						new_fields = []
						for j of construct_fields
							field_pattern = /^(.+?)\s/g.exec(construct_fields[j])
							if field_pattern
								if field_diff.add[field_pattern[1]]
									continue
								new_fields.push field_pattern[1]
								if field_diff.rename[field_pattern[1]]
									old_fields.push field_diff.rename[field_pattern[1]][1]
								else
									old_fields.push field_pattern[1]

						self.db.query 'CREATE TABLE ' + self.prefix + table_name + '_new (' + construct_fields.join(', ') + ')', (err, _ret) ->
							if err then console.log err
							self.db.query 'INSERT INTO ' + self.prefix + table_name + '_new (' + new_fields.join(', ') + ') SELECT ' + old_fields.join(', ') + ' FROM ' + self.prefix + table_name, (err, _ret) ->
								if err then console.log err
								self.db.query 'DROP TABLE ' + self.prefix + table_name, (err, _ret) ->
									if err then console.log err
									self.db.query 'ALTER TABLE ' + self.prefix + table_name + '_new RENAME TO ' + self.prefix + table_name, (err, _ret) ->
										if err then console.log err
										callback null, result
					else
						callback null, {}

		if not self.db?
			callback null, {}

	@mapper: (obj) ->
		tmp = {}
		regex = /^(.+?)\s(.*)/g.exec obj
		if regex
			tmp[regex[1]] = regex[2]
		return tmp

	query: ->
		self = this
		selfArgs = arguments
		args = p_args(arguments,
			query: [
				'string'
				''
			]
			data: [
				Array
				[]
			]
			callback: [
				'function'
				(err, result) ->
			])

		if @db and args.query.length isnt 0
			@db.query args.query, args.data, (err, result) ->
				if err
					# console.error err
					args.callback err, null
					return
				args.callback null, result or []
				return
		else
			args.callback null, []
		return

	close: ->
