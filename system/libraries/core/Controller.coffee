package export core.Controller

import harmony-proxy
import util
import path
import fs
import tools.typescript

class Controller

	@annotation: ->
		old = @prototype
		angular_data = {}
		angular_option = {
			"target": 1
			"module": 4
			"moduleResolution": 2
			"emitDecoratorMetadata": true
			"experimentalDecorators": true
			"removeComments": false
			"noImplicitAny": false
		}
		old['//controller-route~'] = {}

		@prototype = harmonyProxy util._extend({}, @prototype),
			get: (target, name) ->
				old[name]

			set: (target, name, value) ->
				for i in old['//controller-route~'].tmp?.method ? ['*']
					for j in old['//controller-route~'].tmp?.url ? [["/[[{controller}]]#{if name is 'index' then '' else "/#{name}"}", 'text/html']]
						old['//controller-route~'].source ?= []
						old['//controller-route~'].source.push {
							re: String("#{j[0].replace(/\/+$|\/$/g, '')}").trim()
							option: {
								action: name
								'content-type': j[1]
							}
							method: i
						}

				delete old['//controller-route~'].tmp if old['//controller-route~'].tmp?
				old[name] = value
			apply: ->
				console.log 'test ---------------'

		Object.defineProperty @, 'Path',
			get: ->
				return (url, content_type = 'text/html') ->
					old['//controller-route~'].tmp ?= {}
					old['//controller-route~'].tmp.url ?= []
					old['//controller-route~'].tmp.url.push [url, content_type]

		Object.defineProperty @, 'GET',
			get: ->
				old['//controller-route~'].tmp ?= {}
				old['//controller-route~'].tmp.method ?= []
				old['//controller-route~'].tmp.method.push 'GET'

		Object.defineProperty @, 'POST',
			get: ->
				old['//controller-route~'].tmp ?= {}
				old['//controller-route~'].tmp.method ?= []
				old['//controller-route~'].tmp.method.push 'POST'

		Object.defineProperty @, 'DELETE',
			get: ->
				old['//controller-route~'].tmp ?= {}
				old['//controller-route~'].tmp.method ?= []
				old['//controller-route~'].tmp.method.push 'DELETE'

		Object.defineProperty @, 'MERGE',
			get: ->
				old['//controller-route~'].tmp ?= {}
				old['//controller-route~'].tmp.method ?= []
				old['//controller-route~'].tmp.method.push 'MERGE'

		Object.defineProperty @, 'PUT',
			get: ->
				old['//controller-route~'].tmp ?= {}
				old['//controller-route~'].tmp.method ?= []
				old['//controller-route~'].tmp.method.push 'PUT'

		Object.defineProperty @, 'HEAD',
			get: ->
				old['//controller-route~'].tmp ?= {}
				old['//controller-route~'].tmp.method ?= []
				old['//controller-route~'].tmp.method.push 'HEAD'

		Object.defineProperty @, 'TRACE',
			get: ->
				old['//controller-route~'].tmp ?= {}
				old['//controller-route~'].tmp.method ?= []
				old['//controller-route~'].tmp.method.push 'TRACE'

		Object.defineProperty @, 'CONNECT',
			get: ->
				old['//controller-route~'].tmp ?= {}
				old['//controller-route~'].tmp.method ?= []
				old['//controller-route~'].tmp.method.push 'CONNECT'

		Object.defineProperty @, 'PATCH',
			get: ->
				old['//controller-route~'].tmp ?= {}
				old['//controller-route~'].tmp.method ?= []
				old['//controller-route~'].tmp.method.push 'PATCH'

		Object.defineProperty @, 'OPTIONS',
			get: ->
				old['//controller-route~'].tmp ?= {}
				old['//controller-route~'].tmp.method ?= []
				old['//controller-route~'].tmp.method.push 'OPTIONS'

		Object.defineProperty @, 'Angular',
			get:  ->
				caller = Controller.getCaller()
				return (url) ->
					ts_filename = "#{path.dirname(caller.getFileName())}/#{url}"
					return ($req, $res)->
						if fs.existsSync("#{ts_filename}.ts")
							ts_filename = "#{ts_filename}.ts"
						else if not fs.existsSync(ts_filename)
							throw new Error "#{ts_filename} is not exists."

						file_info = fs.statSync(ts_filename)
						if not angular_data[ts_filename]? or (angular_data[ts_filename].mtime isnt file_info.mtime)
							angular_data[ts_filename] = source: typescript.transpile(fs.readFileSync(ts_filename).toString('utf-8'), angular_option), mtime: file_info.mtime

						$res.set 'Content-Type', 'text/javascript'
						$res.send angular_data[ts_filename].source


	@getCaller: ->
		stack = Controller.getStack()
		stack.shift()
		stack.shift()
		stack[1]


	@getStack: ->
		# Save original Error.prepareStackTrace
		origPrepareStackTrace = Error.prepareStackTrace
		# Override with function that just returns `stack`

		Error.prepareStackTrace = (_, stack) ->
			stack

		err = new Error
		stack = err.stack
		Error.prepareStackTrace = origPrepareStackTrace
		stack.shift()
		stack
