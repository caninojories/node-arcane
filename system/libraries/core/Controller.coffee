package export core.Controller

import harmony-proxy
import util

class Controller

	@annotation: ->
		old = @prototype

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


		# return harmonyProxy @,
		# 	get: (target, name) ->
		# 		console.log name
		#
		# 	set: (target, name, value) ->
		# 		console.log name, value
		#
		# 	apply: ->
		# 		console.log 'test ---------------'

# class Controller
# 	console.log @prototype
#
# 	Object.defineProperty @, 'path',
# 		get: (name) ->
# 			console.log name
# 			return ->
# 				console.log '=>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
#
# 		set: (name, value) ->
# 			console.log name, value


# Controller = do ->
# 	_Controller = ->
#
# 	__store = {}
#
# 	# _Controller.path = ->
# 	# 	console.log '======================================='
#
# 	# Object.defineProperty _Controller, 'path',
# 	# 	get: (name) ->
# 	# 		console.log name
# 	# 		return ->
# 	# 			console.log '=>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
# 	#
# 	# 	set: (name, value) ->
# 	# 		console.log name, value
#
# 	# _Controller.prototype.constructor = harmonyProxy _Controller.prototype.constructor,
# 	# 	get: (target, name) ->
# 	# 		switch name
# 	# 			when 'apply'
# 	# 				return target[name]
# 	# 			else
# 	# 				console.log name
# 	#
# 	# 	set: (target, name, value) ->
# 	# 		console.log name, value
# 	#
# 	# 	apply: ->
# 	# 		# console.log 'testing asjkdhaksjdhajksdas'
# 	#
# 	# 		return @
# 	#
# 	# 	hasOwn: (target, name) ->
# 	# 		console.info name, '---'
# 	# 		return true
# 	#
# 	# _Controller.prototype = harmonyProxy _Controller.prototype,
# 	# 	get: (target, name) ->
# 	# 		switch name
# 	# 			when 'constructor'
# 	# 				return target.constructor
# 	# 			else
# 	# 				console.log name
# 	#
# 	# 	set: (target, name, value) ->
# 	# 		console.log name, value
# 	#
# 	# 	hasOwn: (target, name) ->
# 	# 		console.info name, '---'
# 	# 		return true
#
# 	return harmonyProxy _Controller,
# 		get: (target, name) ->
# 			switch name
# 				when 'prototype'
# 					return target.prototype
# 				when 'path'
# 					return ->
# 						console.log arguments
# 				else
# 					console.log name
#
# 		set: (target, name, value) ->
# 			console.log name, value
#
# 		hasOwn: (target, name) ->
# 			# console.info name, '---'
# 			return true
#
# 		enumerate: (target) ->
# 			return ['path', 'GET', 'POST', 'DELETE', 'MERGE', 'PUT']
#
# 		apply: ->
# 			console.log '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
#
# 	# return harmonyProxy (->),
# 	# 	get: (target, name) ->
# 	# 		# console.log name
# 	# 		switch name
# 	# 			when 'prototype'
# 	# 				# return _Controller.prototype
# 	# 				return harmonyProxy _Controller.prototype,
# 	# 					get: (target, name) ->
# 	# 						# console.log name
# 	# 						switch name
# 	# 							when 'constructor'
# 	#
# 	# 								return harmonyProxy target.constructor,
# 	# 									get: (target, name) ->
# 	# 										console.log name
# 	#
# 	# 									set: (target, name, value) ->
# 	# 										console.log name, value
# 	#
# 	# 									apply: ->
# 	# 										console.log '=============================================='
# 	#
# 	# 							else
# 	# 								console.log name
# 	#
# 	# 					set: (target, name, value) ->
# 	# 						console.log name, value
# 	#
# 	# 			else
# 	# 				return __store[name]
# 	#
# 	# 	set: (target, name, value) ->
# 	# 		console.log name, value
# 	# 		__store[name] = value
# 	#
# 	# 	apply: ->
# 	# 		console.log '=============================================='
#
# 	return _Controller


# Controller = do ->
# 	_Controller = ->
#
# 	return harmonyProxy (->),
# 		get: (target, name) ->
# 			console.log name
# 			switch name
# 				when 'prototype'
# 					return _Controller.prototype
# 				else
# 					return __store[name]
#
# 		set: (target, name, value) ->
# 			console.log name, value
# 			__store[name] = value
#
# 		apply: ->
# 			console.log '=============================================='



# _C = ->
# 	Controller = ->
#
# 	__store = {}
#
# 	propertyMissingHandler =
# 		get: (target, name) ->
# 			console.log name
# 			return __store[name]
#
# 		set: (target, name, value) ->
# 			console.log name, value
# 			__store[name] = value
#
# 		apply: ->
# 			console.log '=============================================='
#
# 	Controller.path = ->
# 		console.log 'ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo'
#
# 	# return harmonyProxy Controller, propertyMissingHandler
# 	return Controller
#
# 	# return Controller

# class Controller
#
# 	@path: ->
# 		console.log '===================================================================='
#
# 	path: ->
# 		console.log 'PATH SET >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
#
# 	harmonyProxy @,
# 		get: (target, name) ->
# 			console.log name
# 			return __store[name]
#
# 		set: (target, name, value) ->
# 			console.log name, value
# 			__store[name] = value
#
# 		apply: ->
# 			console.log '=============================================='

#
# 	# __store: {}
# 	#
# 	# propertyMissingHandler =
# 	# 	get: (target, name) ->
# 	# 		console.log name
# 	#
# 	# 	set: (target, name, value) ->
# 	# 		console.log name, value
# 	# 		target.__store[name] = value
# 	#
# 	# constructor: ->
# 	# 	return harmonyProxy @, propertyMissingHandler



# class Controller
#
# 	# @test: ->
# 	# 	console.log "called"
