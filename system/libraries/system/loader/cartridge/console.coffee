#!package export cartridge.SysConsole

#!import system.Middleware

class SysConsole extends Middleware

	__init: () ->

		# consolling = {}
		# _logging = console.error

		# Object.defineProperty console, "error",
		# 	get: ->
		# 		consolling.error

		# Object.defineProperty console, "warning",
		# 	get: ->
		# 		consolling.warning

		# stack = null
		# Object.defineProperty console, "stack",
		# 	get: ->
		# 		stack


	__middle: ($req, $res, $stack, $sqlite) ->
		self = this

		timeList = {}
		stack = $stack
		consolling =
			query: (filename, query, param, cb) ->
				self.doReadRecords $sqlite, filename, query, param, cb

			clear: (filename, target, cb) ->
				self.clearRecords $sqlite, filename, target, cb

			trace: (functionName, message) ->

			error: (message) ->
				console.log message.trace or message
				global.last_error = message
				location = $req.root or "/var/log/"
				return	if not message or message.length is 0
				err = new Error("TRACE: Error Log")
				self.doRecordLogs $sqlite, location + "/.logs.sqlite3", "Errors", "", err.stack + "\n\n" + message

			warning: (message) ->
				location = $req.root or "/var/log/"
				return	if not message or message.length is 0
				self.doRecordLogs $sqlite, location + "/.logs.sqlite3", "Warnings", "", message

			log: (message) ->
				location = $req.root or "/var/log/"
				return	if not message or message.length is 0
				self.doRecordLogs $sqlite, location + "/.logs.sqlite3", "Logs", "", message

			cartridges: (data) ->
				location = $req.root or "/var/log/"

			timeEnd: (name, message, date) ->
				location = $req.root or "/var/log/"
				if date and date instanceof Date
					date = Number((new Date()) - date)
				else
					date = Number((new Date()) - timeList[name])
				return	if timeList.hasOwnProperty(name)
				self.doRecordLogs $sqlite, location + "/.logs.sqlite3", "TimeLogs", name, message or "", date
				delete timeList[name]	if timeList.hasOwnProperty(name)

			referal: (name, message, date) ->
				location = $req.root or "/var/log/"
				if date and date instanceof Date
					date = Number((new Date()) - date)
				else
					date = Number((new Date()) - timeList[name])
				return	if timeList.hasOwnProperty(name)
				self.doRecordLogs $sqlite, location + "/.logs.sqlite3", "Referals", name, message or "", date
				delete timeList[name]	if timeList.hasOwnProperty(name)

			traceClose: ->

		$res.console = consolling
		consolling


	doRecordLogs: (sqlite, filename, table, name, message, time) ->
		try
			pool = sqlite.createPool(filename, 5, 10000)
			conn = pool.get()

			conn.error (err) ->

				if err.code is 100
					conn.resume()
				else
					conn.resume true

			if table is "Cartridge"

			else if table isnt "TimeLogs"
				conn.exec "CREATE TABLE IF NOT EXISTS `" + table + "` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT, `execution` INTEGER, `message` TEXT, `dateAdded` DATETIME)"
				conn.exec "INSERT INTO `" + table + "` VALUES (NULL, ?, ?, ?, DateTime('now'))", [ name, time or 0, message ]
			else
				splitted_msg = message.split("|")
				conn.exec "CREATE TABLE IF NOT EXISTS `" + table + "` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT, `execution` INTEGER, `status_code` TEXT, `method` TEXT, `ip` TEXT, `browser` TEXT, `os` TEXT, `dateAdded` DATETIME)"
				conn.exec "INSERT INTO `" + table + "` VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, DateTime('now'))", [ name, time or 0, splitted_msg[0], splitted_msg[1], splitted_msg[2], splitted_msg[3], splitted_msg[4] ]

		catch err
			console.log err

	doReadRecords: (sqlite, filename, query, param, cb) ->
		pool = sqlite.createPool(filename, 50, 10000)
		conn = pool.get()
		conn.error (err) ->
			if err.code is 100
				conn.resume()
			else
				conn.resume true

		try
			conn.exec(query, param).all((rows) ->
				cb null, rows
			).then (err) ->
				cb err	if err

		catch err
			cb err

	clearRecords: (sqlite, filename, target, cb) ->
		pool = sqlite.createPool(filename, 50, 10000)
		conn = pool.get()
		conn.error (err) ->
			if err.code is 100
				conn.resume()
			else
				conn.resume true
			console.log err

		try
			conn.exec("DELETE FROM `" + target + "`").then (err) ->
				cb null, null

		catch err
			cb err
