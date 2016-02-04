package export system.core.MiddlewareHandler

# import system.tools.params
import tools.wait
import sqli

class Store
	@stack: []
	@flow: {}
	@settings: {}

push_params = (handler) ->
	ret = []
	param_list = MiddlewareHandler.parm.get handler

	for i in param_list
		name = i.replace ///^\$///g, ''

		ret.push name

		if not Store.flow[name]? and MiddlewareHandler.core.modules_list?[name]?
			Store.flow[name] = true
			Store.flow[name] = push_params MiddlewareHandler.core.modules_list[name].__middle
			Store.stack.push [name, MiddlewareHandler.core.modules_list[name].__middle, MiddlewareHandler.core.modules_list[name]]

	return ret
	# console.log param_list

class MiddlewareHandler

	settings: {}
	loaded: {}

	@midd: null
	@core: null
	@parm: null

	constructor: (@name) ->

		# console.log @name
		# 
	
	flow: (req, res) ->
		# console.log req.url, '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'

		res.req = req
		req.res = res

		self = this
		self.loaded = {
			$req: req
			$res: res
			$app: @
			$stime: do process.hrtime
			$wait: wait
			$process: MiddlewareHandler.midd.process
			$sqlite: sqli.getDriver 'sqlite'
		}

		for i in Store.stack
			# new_p = Store.flow[i[0]].map (data) ->
			# 	self.loaded["$#{data}"]

			# console.log 'testing'

			# console.time req.last_seq = i[0]

			new_p = []
			for j in Store.flow[i[0]]
				new_p.push self.loaded["$#{j}"] ? null

			self.loaded["$#{i[0]}"] = i[1].apply i[2], new_p

			# console.timeEnd req.last_seq

		# console.log Store.stack
		# console.log Store.flow
		
	use: (handler, result) ->
		# console.log 'USE USE USE'
		# console.log (new Error).stack
		# self = this
		
		# console.log typeof handler

		if typeof handler is 'function'
			param_list = MiddlewareHandler.parm.get handler

			new_p = []
			for i in param_list
				new_p.push @loaded[i] ? null

			# new_p = param_list.map (data) ->
			# 	self.loaded[data]

			try
				ret = handler.apply null, new_p

				# console.log ret

				result(null, ret) if typeof result is 'function' 
			catch err
				throw err if typeof err is 'string'
				# console.log err, '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
				result(err) if typeof result is 'function'

			return ret

	get: (name) ->


	set: (name, value) ->


	@use: (name, handler) ->
		handle = handler if typeof handler is 'function' or typeof name is 'object'
		handle = name if typeof name is 'function' or typeof name is 'object'
		n = name if typeof name is 'string'

		if handle instanceof MiddlewareHandler.midd and typeof handle.__middle is 'function'
			Store.flow[handle.name] = true
			Store.flow[handle.name] = push_params handle.__middle
			Store.stack.push [handle.name, handle.__middle, handle]
		else if handle and n
			Store.flow[n] = true
			Store.flow[n] = push_params handle
			Store.stack.push [n, handle, null]

		# console.log Store.stack

		# console.log handle

	@get: (name) ->


	@set: (name, value) ->


