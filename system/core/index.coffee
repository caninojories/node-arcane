###
#
###
package System

###
#
###
import system.Core
import system.Middleware
# import system.Sync
import system.SocketIO

import http
import https

import tools.wait

import tools.fibby
import tools.fib-connect

import system.core.MiddlewareHandler
import system.tools.params

import tools.http.stream
import tools.http.cors

###
#
###
class System extends Core

	app: fibConnect(handler: Middleware.handle, app: MiddlewareHandler)

	constructor: ->
		console.log 'Initialize Core'

		do Core.init_modules

		https.globalAgent.maxSockets = 100000
		http.globalAgent.maxSockets = 100000

		MiddlewareHandler.midd = Middleware
		MiddlewareHandler.core = Core
		MiddlewareHandler.parm = params

		Middleware.process.send = (name, data) ->
			process.send name: 'emitter', data: {
				name: name
				data: data
			}

		Middleware.process.on = (name, cb) ->
			if Middleware.process.events_on[name]?
				Middleware.process.events.removeListener name, Middleware.process.events_on[name]
			Middleware.process.events_on[name] = cb
			Middleware.process.events.on name, cb

		Middleware.process.exists = (name) ->
			Middleware.process.events_on[name]?

		process.on 'message', (data) ->
			if typeof data is 'object' and data.name? and data.name is 'emitter'
				if Middleware.process.exists data.data.name
					Middleware.process.events.emit data.data.name, data.data.data ? null

	server: (modules, callback) ->
		self = this
		wait.launchFiber ->
			try
				if Object.keys(Core.loaded_modules).length is 0
					wait.forMethod Core, 'load_modules', modules

				if Middleware.autoload.length is 0
					Middleware.autoload = modules

				setInterval gc, 30000

				self.app.use Core.modules_list['http']
				self.app.use Core.modules_list['vhost']

				self.app.use 'cors', ($req, $res, $config) ->
					cors_config = $config.all 'cors'
					wait.for cors(cors_config ? {}), $req, $res

				self.app.use 'stream', ($req, $res) ->
					wait.for stream(), $req, $res

				self.app.use Core.modules_list['assets']
				self.app.use Core.modules_list['console']
				self.app.use Core.modules_list['session']
				self.app.use Core.modules_list['model']
				self.app.use Core.modules_list['bodyparser']
				self.app.use Core.modules_list['form']
				self.app.use Core.modules_list['validator']
				self.app.use Core.modules_list['route']

				callback null, true
			catch err
				console.log err.stack ? err
				callback err

	initialize: (https_option) ->
		# Sync ->
		# wait.launchFiber ->
		# app = fibConnect(handler: Middleware.handle)
		# try
		if https_option?
			http_server = https.createServer https_option, @app
		else
			http_server = http.createServer @app

		Middleware.http http_server

		# temporary
		socket_io = new SocketIO(http_server)
		
		# return http_server
		return http_server
		# catch err
		# 	throw err
			# console.log err.stack ? err
			# callback err
		# , (err, result) ->
		# 	if err then throw err
		# 	callback err, result