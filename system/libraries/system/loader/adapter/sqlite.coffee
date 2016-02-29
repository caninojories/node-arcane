package export SQLite

import sqli

class SQLite

	@sqlite: sqli.getDriver 'sqlite'

	@extra_options: (opt) ->
		ret = ''
		if opt.pk != 0
			ret += ' PRIMARY KEY AUTOINCREMENT'
		if opt.notnull != 0
			ret += ' NOT NULL'
		if opt.dflt_value
			ret += ' DEFAULT \'' + opt.dflt_value + '\''
		ret

	dialect: 'sqlite'

	constructor: ->
		@types =
			String: type: 'TEXT'
			Number: type: 'INTEGER'
			Object: type: 'TEXT'
			Array: type: 'TEXT'
			Buffer: type: 'BLOB'
			Date: type: 'DATE'
		@autoincrement = 'AUTOINCREMENT'
		@primarykey = 'PRIMARY KEY'
		@unique = 'UNIQUE'

	connect: (options, resolve, readonly) ->
		self = @
		if !options
			throw new Error('SQLITE Driver: Options are not defined.')
		@opt = options
		connection = ':memory:'
		if !options.hasOwnProperty('memory') and options.hasOwnProperty('file')
			connection = if /^\/.*$/g.exec(options.file) then options.file else options.root + '/' + options.file
		pool = SQLite.sqlite.createPool(connection, options.maxConnection or 50, options.timeout or 10000)
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

			conn = do pool.get

			cb_called = false
			_cb = (err, result) ->
				if !cb_called
					cb_called = true
					cb err, result

			if /^INSERT\sINTO/g.test query
				conn.exec(query, data).then (err) ->
					if err
						if err.code is 100
							do conn.resume
						else
							conn.resume true
						# if not /already\sexists/g.test err.stack
						# 	console.log err.code, err.stack
						_cb err, []

				query = 'SELECT last_insert_rowid() AS `last_insert_id`'
				data= []

			conn.exec(query, data).all((rows) ->
				do conn.close
				_cb null, rows
				return
			).then (err) ->
				if err

					if err.code is 100
						do conn.resume
					else
						conn.resume true

					# if not /already\sexists/g.test err.stack
					# 	console.log err.code, err.stack

				else
					do conn.close

				_cb err, []
				return
			return

		resolve null, true
		return

	last_insert_id: (callback) ->
		if @db
			@db.query 'SELECT last_insert_rowid() AS `last_insert_id`', callback
		return

	table: (table_name, data, model_list, callback) ->
		table_name = do table_name.toLowerCase
		self = this
		selfArgs = arguments
		if !callback
			callback = model_list
			model_list = null
		if self.db
			self.db.query 'SELECT `name` FROM `sqlite_master` WHERE `name` LIKE ?', [ self.prefix + table_name ], (err, result) ->
				if err
					if err.code == 'SQLITE_BUSY'
						self.table.apply self, selfArgs
						return
					console.error err
					callback null, false
					return
				if result.length == 0
					construct_fields = self.generateFields(data, model_list)
					#if (self.unique_keys.length !== 0) construct_fields.push('UNIQUE(' + self.unique_keys + ')');
					if construct_fields
						self.db.query 'CREATE TABLE `' + self.prefix + table_name + '` (' + construct_fields.join(', ') + ')', (err, _result) ->
							if err
								if err.code == 'SQLITE_BUSY'
									self.table.apply self, selfArgs
									return
								console.error err
								callback null, false
								return
							callback null, 'onCreate'
							return
					else
						callback 'ERROR: Can\'t create table.'
				else
					self.db.query 'PRAGMA table_info(`' + self.prefix + table_name + '`)', (err, _result) ->
						if err
							if err.code == 'SQLITE_BUSY'
								self.table.apply self, selfArgs
								return
							if err.code != 'SQLITE_MISUSE'
								console.error err
							callback null, false
							return

						current_fields = []

						for i of _result
							current_fields.push _result[i].name + ' ' + _result[i].type + SQLite.extra_options(_result[i])

						construct_fields = self.generateFields(data, model_list)
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

							# query.push 'BEGIN TRANSACTION'
							# query.push 'CREATE TABLE `' + self.prefix + table_name + '_new` (' + construct_fields.join(', ') + ')'
							# query.push 'INSERT INTO `' + self.prefix + table_name + '_new` (' + new_fields.join(', ') + ') SELECT ' + old_fields.join(', ') + ' FROM `' + self.prefix + table_name + '`'
							# query.push 'DROP TABLE `' + self.prefix + table_name + '`'
							# query.push 'ALTER TABLE `' + self.prefix + table_name + '_new` RENAME TO `' + self.prefix + table_name + '`'
							# query.push 'COMMIT;'

							self.db.query 'CREATE TABLE `' + self.prefix + table_name + '_new` (' + construct_fields.join(', ') + ')', (err, _ret) ->
								# if err then console.log err
								self.db.query 'INSERT INTO `' + self.prefix + table_name + '_new` (' + new_fields.join(', ') + ') SELECT ' + old_fields.join(', ') + ' FROM `' + self.prefix + table_name + '`', (err, _ret) ->
									# if err then console.log err
									self.db.query 'DROP TABLE `' + self.prefix + table_name + '`', (err, _ret) ->
										# if err then console.log err
										self.db.query 'ALTER TABLE `' + self.prefix + table_name + '_new` RENAME TO `' + self.prefix + table_name + '`', (err, _ret) ->
											# if err then console.log err
											callback null, result

								# callback null, result
								# return









						else
							callback null, result
						return
				return
		else
			callback null, {}
		return

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
					console.log err
					args.callback null, []
					return
				args.callback null, result ? []
				return
		else
			console.log 'Warning: @db is not initialized.'
			args.callback null, []
		return

	close: ->
