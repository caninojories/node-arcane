#!package export system.SocketIO

#!import system.core.*
#!import system.Core
#!import system.tools.params
#!import path
#!import crypto
#!import harmony-proxy
#!import tools.wait
#!import events

class SocketIO extends core.WObject

	constructor: (@server) ->
		http_server = @server
		# SocketIO.synchro ->
		wait.launchFiber ->
			WebSocketServer = require(path.resolve "#{__dirname}/../../../node_modules/websocket").server

			wsServer = new WebSocketServer {
				httpServer: http_server
				autoAcceptConnections: false
			}

			vhost = Core.modules['vhost']

			originIsAllowed = (origin) ->
				origin = origin.replace(/http\:\/\//g, '').replace(/https\:\/\//g, '').split('/')[0]
				unless vhost.host_map[origin]? or vhost.host_map_normal[origin]?
					console.log "Permission denied for '#{origin}'"
					return false
				return true

			# console.log Core.loaded_modules['vhost']

			socket_list = {}
			globalTimer_list = {}
			socket_info = {}

			process.on 'message', (data) ->
				if data.command? and data.command is 'broadcast' and data.sessionID? and socket_list[data.sessionID]?
					for socket_id, socket_data of socket_list[data.sessionID]
						socket_data.$socket.trigger data.info.command, data.info.data
				else if data.command? and data.command is 'globalTimer-call' and data.sessionID? and globalTimer_list[data.sessionID]?
					if (data.func is 'clearInterval' or data.func is 'clearTimeout') and globalTimer_list[data.sessionID][data.name]?
						global[data.func] globalTimer_list[data.sessionID][data.name]
						delete globalTimer_list[data.sessionID][data.name]
				else if data.command? and data.command is 'socket-connect'
					if not socket_info[data.sessID]? then socket_info[data.sessID] = count: 0
					socket_info[data.sessID].count++
				else if data.command? and data.command is 'socket-disconnect'
					if not socket_info[data.sessID]? then socket_info[data.sessID] = count: 0
					if socket_info[data.sessID].current?
						socket_info[data.sessID].current = null
					else
						socket_info[data.sessID].count--

			wsServer.on "request", (req) ->
				# SocketIO.synchro ->
				req.events = new events()
				wait.launchFiber ->
					try
						unless originIsAllowed(req.origin)
							# Make sure we only accept requests from an allowed origin
							req.reject()
							# console.log (new Date()) + " Connection from origin " + req.origin + " rejected."
							return

						connection = req.accept("", req.origin)

						if /\/\:\:1\~\@debug\:\:trace(|\/)/g.test req.httpRequest.url
							req.root = path.resolve("#{__dirname}/../../debug")
						else if vhost.host_map[req.host]? and root = vhost.findSegment req, req.host, req.httpRequest.url
							req.root = vhost.host_map[req.host][root]
						else if vhost.host_map_normal[req.host]?
							req.root = vhost.host_map_normal[req.host]

						consfigs = Core.loaded_modules['config'][req.root]

						dparam = {
							$req: req
							$config: consfigs
							$socket: connection
							$model: Core.nmodules['model'].__socket req, consfigs, SocketIO.app
							$globalTimer: harmonyProxy {}, {
								get: (target, name) ->
									return harmonyProxy {}, {
										get: (target, func) ->
											process.send {
												command: 'globalTimer-call'
												sessionID: req.sessionID
												name: name
												func: func
											}
									}
								set: (target, name, value) ->
									globalTimer_list[req.sessionID] = {} if not globalTimer_list[req.sessionID]?
									globalTimer_list[req.sessionID][name] = value
							}
							$form: Core.nmodules['form'].__socket req, consfigs, SocketIO.app
							$app: SocketIO.app
						}
						dparam.$session = Core.nmodules['session'].__socket req, consfigs, SocketIO.app, dparam

						if not socket_info[dparam.$req.sessionID]? then socket_info[dparam.$req.sessionID] = count: 0
						connection.info = socket_info[dparam.$req.sessionID]

						process.send command: 'socket-connect', sessID: dparam.$req.sessionID

						# console.log dparam.$req.sessionID

						socket_list[dparam.$req.sessionID] = {} if not socket_list[dparam.$req.sessionID]?

						md5sum = crypto.createHash 'md5'
						md5sum.update "#{((new Date()) / 1000)}~#{req.root}~#{req.baseUrl}~#{process.pid}"
						socket_connection = md5sum.digest 'hex'

						socket_list[dparam.$req.sessionID][socket_connection] = dparam


						connection.trigger = (command, data) ->
							connection.sendUTF JSON.stringify { command: command, data: data }

						connection.broadcast = (command, data) ->
							process.send {
								command: 'broadcast'
								sessionID: dparam.$req.sessionID
								PID: process.pid
								info: { command: command, data: data }
							}

						if dparam.$config.socket?.connected?.index?
							SocketIO.app dparam.$config.socket.connected.index, dparam.$config.socket.connected, dparam

						connection.on "close", (reasonCode, description) ->
							socket_info[dparam.$req.sessionID].current = true
							socket_info[dparam.$req.sessionID].count--
							process.send command: 'socket-disconnect', sessID: dparam.$req.sessionID
							# SocketIO.synchro ->
							wait.launchFiber ->
								try
									connection.broadcast = (command, data) ->
									connection.trigger = (command, data) ->
									delete socket_list[dparam.$req.sessionID][socket_connection]
									if dparam.$config.socket?.disconnect?.index?
										SocketIO.app dparam.$config.socket.disconnect.index, dparam.$config.socket.disconnect, dparam

									req.events.emit 'request-complete'
									do gc
								catch err
									console.log err?.stack ? err if err
							# , (err) ->
							# 	if err?.stack?
							# 		console.log err.stack

						connection.on "message", (message) ->
							# SocketIO.synchro ->
							wait.launchFiber ->
								try
									if message.type is "utf8"
										utf_data = JSON.parse message.utf8Data
										if dparam.$config?.socket?[do utf_data.command.toLowerCase]?.index?
											dparam.$data = utf_data.data
											SocketIO.app dparam.$config.socket[do utf_data.command.toLowerCase].index, dparam.$config.socket[do utf_data.command.toLowerCase], dparam
											req.events.emit 'request-complete'
								catch err
									console.log err?.stack ? err if err
							# , (err) ->
							# 	if err?.stack?
							# 		console.log err.stack
					catch err
						console.log err?.stack ? err if err
				# , (err) ->
				# 	console.log err?.stack ? err if err


	@app: (call, classn, dparam) ->
		array_param = []
		param_results = params.get call
		for param in param_results
			if dparam[param]?
				array_param.push dparam[param]
			else
				array_param.push null
		return call.apply classn, array_param
