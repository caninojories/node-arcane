#!package export system.Middleware

#!import system.core.*
#!import system.tools.params
#!import events
#!import threads
#!import path
#!import tools.wait

class Middleware extends core.WObject

	@list: {}
	@loaded: {}
	@autoload: []
	@handlers: {}
	@socketIO: null
	@sqli: require 'sqli'
	@sqlite: Middleware.sqli.getDriver 'sqlite'
	@log: console.log
	@process:
		events: new events.EventEmitter()
		events_on: {}
	@paramCache: {}

	# constructor: (@name) ->
	# 	console.log @name

	# 	if @__middle?
	# 		Middleware.list[@name] = @


	init: (@name) ->
		if @__middle?
			Middleware.list[@name] = @

	get: (name) ->


	set: (name, value) ->


	@app: (handlers, loaded) ->
		{
			use: (call, callback, handler) ->
				param_results = params.get call
				param_data = Middleware.loader param_results, handlers, loaded
				ret = call.apply handler, param_data
				if callback? and typeof callback is 'function'
					callback null, ret
				return ret
			next: ->
				@use ($route) ->
					Middleware.display_404 handlers, loaded
		}

	@display_404: (handlers, loaded) ->
		if loaded['config']?
			$view = loaded['view']
			$config = loaded['config'].all 'route'
			if $config[404]?
				$view.render $config[404], { __status: 404 }, true
			else
				handlers.$res.writeHead 404
				handlers.$res.end '404 error'
				Middleware.log 'Not Found Request: ', handlers.$req.url
				Middleware.log handlers.$req.headers
		else
			handlers.$res.writeHead 404
			handlers.$res.end '404 error'
			Middleware.log 'Not Found Request: ', handlers.$req.url
			Middleware.log handlers.$req.headers

	@display_500: (error, is_normalize, loaded, handlers) ->
		$view = loaded['view']
		$config = loaded['config'].all 'route'
		if $config[500]? and $view?.render?
			$view.render $config[500], { __status: 500, error_msg: error, is_normalize: is_normalize }, true
		else
			handlers.$res.send error.replace(/\</g, '&gt;').replace(/\>/g, '&lg;').replace(/\n/g, '<br/>').replace(/\s/g, '&nbsp;')

	@loader: (parameters, handlers, loaded) ->
		result = []

		for i of parameters
			cartridge_name = parameters[i].replace ///^\$///g, ''

			# console.log cartridge_name

			if handlers["$#{cartridge_name}"]?
				result.push handlers["$#{cartridge_name}"]

			else if loaded[cartridge_name]?
				result.push loaded[cartridge_name]

			else if Middleware.list[cartridge_name]?
				middle_class = Middleware.list[cartridge_name]
				Middleware.paramCache[cartridge_name] ?= params.get middle_class.__middle
				# param_result = params.get middle_class.__middle
				param_data = Middleware.loader Middleware.paramCache[cartridge_name], handlers, loaded

				# console.log middle_class.name

				result.push loaded[cartridge_name] = middle_class.__middle.apply middle_class, param_data
			else
				result.push {}



		return result


	# @use: (name, handler) ->
	# 	handle = handler if typeof handler is 'function'
	# 	handle = name if typeof name is 'function'

	# 	# if typeof name isnt 'string' and handle


	# @apply: (name, handler) ->


	# @load_end: (parameters) ->

	@type: [ 'done', 'server:streaming', 'assets', 'stream' ]

	@handle: (req, res, app) ->
		original_url = req.url

		timeout_handler = setTimeout ->
			res.statusCode = 500
			res.end 'Timeout Request'
			# throw 'connection:timeout'
			console.info '- CONNECTION TIMEOUT:', req.ip
			console.info '-', req.headers.host, original_url
			process.exit 0
		, 60000

		req.on 'close', ->
			clearTimeout timeout_handler

		res.on 'close', ->
			clearTimeout timeout_handler

		req.__response = ->
			clearTimeout timeout_handler

		try
			req.events = new events()
			app = new app

			# req.setTimeout 5000, ->

			# 	console.log "Timeout Request in #{req.url}"

			# 	res.statusCode = 500
			# 	res.send 'Timeout Request'

			#	# throw 'connection:timeout'


			# res.on 'finish', ->
			# 	clearTimeout timeout_handler

			# req.on 'end', ->
			# 	clearTimeout timeout_handler
			# 	throw 'server:end'

			# res.socket.removeAllListeners 'timeout'
			# res.socket.setTimeout 90000
			# res.socket.once 'timeout', ->

			# 	Middleware.log "Timeout Request in #{req.url}"

			# 	# res.writeHead(500, {'Content-Type': 'text/plain'})
			# 	res.statusCode = 500
			# 	res.end 'Timeout Request'

			# 	throw 'connection:timeout'

			# res_socket = res.socket
			# res.on 'finish', ->
			# # 	Middleware.log this.socket
			# # 	# Middleware.log this.socket
			# # 	# res.socket.removeAllListeners('timeout')
			# 	res_socket.removeAllListeners 'timeout'

			# 	throw 'server:finish'

			# req.on 'end', ->
			# 	res_socket.removeAllListeners 'timeout'
			# 	throw 'server:end'













			app.flow req, res














			# console.log app

			# console.log Middleware.list, Middleware.handle.length

			# Middleware.apply '$req', req
			# Middleware.apply '$res', res
			# Middleware.apply '$fib', fib


			# Middleware.use '$req', req
			# Middleware.use '$res', res
			# Middleware.use '$fib', fib

			# Middleware.use ($req, $res, $fib) ->
			#
			# 	return 'testing'


			# res.req = req
			# req.res = res


			# handlers = {
			# 	$req: req
			# 	$res: res
			# 	$fib: fib
			# 	# $redis: require __dirname + '/../../core/redis'
			# 	$process: Middleware.process
			# 	# $stack: []
			# 	# $sqlite: Middleware.sqlite
			# 	# $thread: threads.spawn
			# 	$stime: {
			# 		start: process.hrtime()
			# 	}
			# 	# $wait: wait
			# }

			# console.log 'testing'
			# res.end '---------'


			# req.on 'end', ->
				# console.log 'ended'
			# 	do gc


			# loaded = {}
			# handlers.$app = Middleware.app handlers, loaded

			# res.end Middleware.autoload[...4].toString()

			# console.log req.root
			# res.send '<img src="http://localhost:8222/favicon.ico" />'


			throw 404
		catch err
			if typeof err is 'string' or typeof err is 'number'
				clearTimeout timeout_handler
				req.events.emit err
				req.events.emit 'request-complete'

				if err not in Middleware.type
					unless res.finished
						if /\<fieldset\s/g.test err
							try
								$config = app.loaded.$config.all 'route'
								if $config[500]?
									app.loaded.$view.render $config[500], { __status: 500, error_msg: err, is_normalize: true }, true
								else
									res.statusCode = 500
									res.end err.replace(/\</g, '&gt;').replace(/\>/g, '&lg;').replace(/\n/g, '<br/>').replace(/\s/g, '&nbsp;')
							catch errr
								console.log errr
						else if typeof err is 'number'
							switch err
								when 404
									if app.loaded.$config?
										$config = app.loaded.$config.all 'route'
										if $config[404]?
											app.loaded.$view.render $config[404], { __status: 404 }, true
										else
											res.statusCode = 404
											res.send '404 error'
											Middleware.log 'Not Found Request: ', req.url
											Middleware.log handlers.$req.headers
									else
										res.statusCode = 404
										res.end '404 error'
										Middleware.log 'Not Found Request: ', req.url
										Middleware.log req.headers

								when 500
									res.statusCode = 500
									res.end "500 error \n#{err.stack}"

				# res.statusCode = 500
				# res.end err.stack ? err
			else
				clearTimeout timeout_handler

				console.log req.url
				console.log err.stack ? err
				res.statusCode = 500
				res.end err.stack ? err



		# console.timeEnd req.last_seq

		# do gc


		# return

		# handlers = {}
		# loaded = {}

		# res.req = req
		# req.res = res

		# res.handlers = []
		# res.onEnd = (func) ->
		# 	@.handlers.push func

		# timeout_controller = setTimeout ->
		# 	console.log "Request Timeout: http://#{req.headers.host}#{req.url}"
		# 	if req.headers.host?
		# 		try
		# 			$res.redirect "http://#{req.headers.host}#{req.url}"
		# 	do gc
		# 	process.exit 0
		# , 30000

		# t = process.hrtime()

		# # Middleware.synchro ->
		# try
		# 	handlers = {
		# 		$req: req
		# 		$res: res
		# 		$redis: require __dirname + '/../../core/redis'
		# 		$process: Middleware.process
		# 		$stack: []
		# 		$sqlite: Middleware.sqlite
		# 		$thread: threads.spawn
		# 		$stime: {
		# 			start: t
		# 		}
		# 		$wait: wait
		# 	}

		# 	# console.log "http://#{req.headers.host}#{req.url} - >>>>>>>>>>>>>"

		# 	# console.info "%dms", (process.hrtime(t)[1]/1000000).toFixed(4)

		# 	req.on 'end', ->
		# 		do gc
		# 		# Middleware.log "Request: #{req.method} http://#{req.headers.host}#{req.url} - #{Number(new Date) - Number(handlers.$stime.start)}ms"

		# 	handlers.$app = Middleware.app handlers, loaded

		# 	result = Middleware.load_middle Middleware.autoload[...4], handlers, loaded

		# 	Middleware.display_404 handlers, loaded
		# # , (err) ->
		# catch err
		# 	try
		# 		# close that handler here
		# 		for u in res.handlers
		# 			if u.constructor.name is 'Function'
		# 				do u

		# 		clearTimeout timeout_controller

		# 		if err.constructor.name is 'String'
		# 			if err is 'stream'
		# 				# req.on 'end', ->
		# 					# console.log 'Streaming... [DONE]'

		# 			else if /\<fieldset\s/g.test err
		# 				Middleware.display_500 err, true, loaded, handlers
		# 			else
		# 				Middleware.log "Request: [http://#{req.headers.host}#{req.url}]\n #{err}" if err isnt 'done' and err isnt 'assets' and err isnt 'redirect'
		# 		else if err.constructor.name is 'Array'
		# 			if err[0] is 404 then Middleware.display_404 handlers, loaded
		# 		else if err.constructor.name is 'Number'
		# 			if err is 404 then Middleware.display_404 handlers, loaded
		# 		else if err.stack?
		# 			Middleware.log "Request: [http://#{req.headers.host}#{req.url}]\n #{err.stack}"
		# 			Middleware.display_500 err.stack || err, false, loaded, handlers
		# 		else
		# 			Middleware.log "Request: [http://#{req.headers.host}#{req.url}]\n #{err}"
		# 			res.send 'unknown'

		# 		# console.log 'done', req.url

		# 		# do gc
		# 	catch err
		# 		console.log err.stack ? err

		# 		clearTimeout timeout_controller
		# 		# do gc
		# 		# console.log 'done', req.url
		# 		if err.stack
		# 			Middleware.log "Request: [http://#{req.headers.host}#{req.url}]\n #{err.stack ? err}"
		# 			res.end err.toString()

	@events: (http) ->


	@http: (http_server)->
		# Middleware.log 'Initialize Server Socket'
		# WebSocket = require(path.resolve "#{__dirname}/../../../node_modules/websocket").server
		# wsServer = new WebSocket {
		# 	httpServer: http_server
		# 	autoAcceptConnections: false
		# }

		# wsServer.on "request", (req) ->

		# 	# is allowed origin condition
		# 	# req.reject()

		# 	console.log 'Connected'

		# 	connection = req.accept("", req.origin)


		# 	connection.on "close", (reasonCode, description) ->
		# 		console.log 'Disconnected'



		# 	connection.on "message", (message) ->
		# 		console.log message
