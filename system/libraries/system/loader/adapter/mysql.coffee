package export MySQL

import mysql
import util

class MySQL

	@obj_clone: (obj) ->
		if null == obj or 'object' != typeof obj
			return obj
		copy = obj.constructor()
		attr = undefined
		for attr of obj
			if obj.hasOwnProperty(attr)
				copy[attr] = obj[attr]
		copy

	@extra_options: (extra, opt) ->
		ret = ''
		if extra.indexOf('auto_increment') != -1
			ret += ' AUTO_INCREMENT'
		if opt.unique
			ret += ' UNIQUE KEY'
		if opt.Null == 'NO' or typeof opt.Null == 'boolean' and !opt.Null
			ret += ' NOT NULL'
		if opt.Default
			ret += ' DEFAULT ' + opt.Default
		ret

	constructor: ->
		@types =
			String:
				type: 'VARCHAR'
				size: '50'
			Number:
				type: 'INT'
				size: '11'
			Object: type: 'TEXT'
			Array: type: 'TEXT'
			Buffer: type: 'BLOB'
			Date: type: 'DATETIME'
			Float: type: 'FLOAT'
			DateTime: type: 'DATETIME'
			Enumerate: type: 'ENUM'
		@autoincrement = 'AUTO_INCREMENT'
		@unique = 'UNIQUE KEY'
		@primary_keys = []

	dialect: 'mysql'

	connect: (options, resolve) ->
		self = this
		properties = util._extend {}, options
		delete properties.adapter

		properties.connectionLimit ?=  5
		properties.acquireTimeout ?= 30000

		self.pool = mysql.createPool(properties)


		self.db =
			query: ->
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

				if not self.connection_time?
					self.current_connection = self.pool.getConnection.sync(self.pool)
				else
					clearTimeout self.connection_time

				self.connection_time = setTimeout ->
					# console.info 'Connection Release'
					self.current_connection.release()
					self.connection_time = null
				, 30000

				# self.pool.query query, data, (err, rows, fields) ->
				# 	if err
				# 		console.info err.stack ? err
				# 		cb err, null
				# 		return
				# 	cb null, rows
				# 	return

				self.current_connection.query query, data, (err, rows, fields) ->
					if err
						console.info err.stack ? err
						self.current_connection.release()
						self.connection_time = null
						cb err, null
						return
					cb null, rows

		resolve null, true

		# properties = MySQL.obj_clone(options)
		# delete properties.adapter
		#
		# properties.connectionLimit = properties.connectionLimit or 5
		# properties.acquireTimeout = properties.acquireTimeout or 30000
		# # console.log 'Connection Pool @:' + properties.host + '\n user:' + properties.user + '\n database:' + properties.database
		# self.pool = mysql.createPool(properties)
		# self.db =
		# 	query: ->
		# 		args = [].slice.call(arguments)
		# 		cntr = args.length - 1
		# 		query = undefined
		# 		data = undefined
		# 		cb = undefined
		# 		if args[cntr] and typeof args[cntr] == 'function'
		# 			cb = args[cntr]
		# 			cntr--
		# 		if args[cntr] and typeof args[cntr] == 'object'
		# 			data = args[cntr]
		# 			cntr--
		# 		if args[cntr] and typeof args[cntr] == 'string'
		# 			query = args[cntr]
		# 			cntr--
		# 		self.pool.getConnection (err, connection) ->
		# 			if err
		# 				console.error err.stack
		# 				return
		# 			#console.log(query, data);
		#
		# 			connection.query query, data, (err, rows) ->
		# 				if err?
		# 					connection.release()
		# 					# console.log 'LAST QUERY: ' + String(query)
		# 					# console.log err.stack ? err
		# 					cb err, null
		# 					return
		#
		# 				if /^INSERT\sINTO/g.test query
		# 					connection.query 'SELECT LAST_INSERT_ID() AS `last_insert_id`', (err, result) ->
		# 						connection.release()
		# 						if err?
		# 							# console.log 'LAST QUERY: ' + String(query)
		# 							# console.log err.stack ? err
		# 							cb err, null
		# 							return
		#
		# 						cb null, result
		# 				else
		# 					connection.release()
		# 					cb null, rows
		# 				return
		# 			return
		# 		return
		# 	close: ->
		# 		self.pool.end (err) ->
		# 			# all connections in the pool have ended
		# 			return
		# 		return



		# resolve null, true
		return

	table: (table_name, data, model_list, callback) ->
		self = this
		if !callback
			callback = model_list
			model_list = null
		if @db
			@db.query 'SHOW TABLES', (err, result) ->
				if err
					#console.error(err.stack);
					callback null, false
					return
				is_found = false
				x = undefined
				y = undefined
				for x of result
					if result.hasOwnProperty(x)
						for y of result[x]
							if result[x][y] == self.prefix + table_name
								is_found = true
				construct_fields = undefined
				if !is_found
					construct_fields = self.generateFields(data, model_list)
					construct_fields.push 'PRIMARY KEY(' + self.primary_keys.join(',') + ')'
					self.query 'CREATE TABLE `' + self.prefix + table_name + '` (' + construct_fields.join(', ') + ')', (err) ->
						if err
							console.error 'ERROR: Creating table, ' + err
							callback null, false
							return
						callback null, 'onCreate'
						return
				else
					self.query 'SHOW COLUMNS FROM `' + self.prefix + table_name + '`', (err, result) ->
						if err
							console.error 'ERROR: Show Columns in `' + self.prefix + table_name + '`, ', err
							callback null, false
							return
						current_fields = []
						primaries = []
						i = undefined
						extra = undefined
						_keys = undefined
						for i of result
							if result.hasOwnProperty(i)
								extra = result[i].Extra.split(',')
								_keys = result[i].Key.split(',')
								if _keys.indexOf('PRI') != -1
									primaries.push result[i].Field
								if _keys.indexOf('UNI') != -1
									extra.unique = true
								current_fields.push result[i].Field + ' ' + result[i].Type.toUpperCase() + MySQL.extra_options(extra, result[i])
						current_fields.push 'PRIMARY KEY(' + primaries.join(',') + ')'
						construct_fields = self.generateFields(data, model_list)
						construct_fields.push 'PRIMARY KEY(' + self.primary_keys.join(',') + ')'
						field_diff = self.field_diff(current_fields, construct_fields)
						if field_diff
							field_mapping = self.field_mapping(construct_fields)
							query = 'ALTER TABLE `' + self.prefix + table_name + '` '
							uquery = []
							l = undefined
							k = undefined
							m = undefined
							for l of field_diff.rename
								if field_diff.rename.hasOwnProperty(l)
									uquery.push 'CHANGE `' + field_diff.rename[l][1] + '` ' + field_diff.rename[l][0]
							for k of field_diff.add
								if field_diff.add.hasOwnProperty(k)
									if field_diff.delete[k]
										#console.log('re-update ' + k);
										uquery.push 'CHANGE `' + k + '` ' + field_diff.add[k]
										delete field_diff.delete[k]
									else
										uquery.push 'ADD COLUMN ' + field_diff.add[k] + (if !field_mapping[k][0] then ' BEFORE `' + field_mapping[k][1] + '`' else ' AFTER `' + field_mapping[k][0] + '`')
							for m of field_diff.delete
								if field_diff.delete.hasOwnProperty(m)
									uquery.push 'DROP COLUMN `' + m + '`'
							primary_update = self.primary_field_diff(field_diff.primary)
							if primary_update.add.length != 0
								uquery.push 'ADD PRIMARY KEY(' + primary_update.add.join(',') + ')'
							if primary_update.remove.length != 0
								uquery.push 'DROP PRIMARY KEY(' + primary_update.remove.join(',') + ')'
							self.query query + uquery.join(', '), (err) ->
								if err
									console.error 'ERROR: Updating table `' + self.prefix + table_name + '`, ', err
									callback null, false
									return
								callback null, false
								return
						else
							callback null, false
						return
				return
		return

	last_insert_id: (callback) ->
		if @db
			@db.query 'SELECT LAST_INSERT_ID() AS `last_insert_id`', (err, result) ->
				if err
					callback err, null
					return
				callback null, result
				return
		return

	query: ->
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
				->
					undefined
			])
		if @db and args.query.length != 0
			#console.log(args.query, args.data);
			#console.log('MySQL QUERY: ' + args.query, args.data);
			@db.query args.query, args.data, (err, result) ->
				#console.log(err, result[0]);
				if err
					if err.stack and err.code is 'ER_TABLE_EXISTS_ERROR'
						args.callback null, []
					else
						args.callback err, null
					return
				args.callback null, result ? []
				return
		else
			args.callback null, []
		return

	close: ->
		if @db
			try
				@db.close()
			catch err
		return
