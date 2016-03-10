#!package export Sync

#!import fibers

###
	Copyright 2011 Yuriy Bogdanov <chinsay@gmail.com>

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to
	deal in the Software without restriction, including without limitation the
	rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
	sell copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
	IN THE SOFTWARE.
###

# use node-fibers module
#var Fiber = require('../../fibers');
# Fiber = require('fibers')

###*
# sync() method simply turns any asynchronous function to synchronous one
# It receives context object as first param (like Function.prototype.call)
#
###

###*
# Future object itself
###

Fiber = fibers

SyncFuture = (timeout) ->
	self = this
	@resolved = false
	@fiber = Fiber.current
	@yielding = false
	@timeout = timeout
	@time = null
	@_timeoutId = null
	@_result = undefined
	@_error = null
	@_start = +new Date
	Sync.stat.totalFutures++
	Sync.stat.activeFutures++
	# Create timeout error to capture stack trace correctly
	self.timeoutError = new Error
	Error.captureStackTrace self.timeoutError, arguments.callee

	@ticket = ->
		# clear timeout if present
		if self._timeoutId
			clearTimeout self._timeoutId
		# measure time
		self.time = new Date - (self._start)
		# forbid to call twice
		if self.resolved
			return
		self.resolved = true
		# err returned as first argument
		err = arguments[0]
		if err
			self._error = err
		else
			self._result = arguments[1]
		# remove self from current fiber
		self.fiber.removeFuture self.ticket
		Sync.stat.activeFutures--
		if self.yielding and Fiber.current != self.fiber
			self.yielding = false
			self.fiber.run()
		else if self._error
			throw self._error
		return

	@ticket.__proto__ = this

	@ticket.yield = ->
		while !self.resolved
			self.yielding = true
			if self.timeout
				self._timeoutId = setTimeout((->
					self.timeoutError.message = 'Future function timed out at ' + self.timeout + ' ms'
					self.ticket self.timeoutError
					return
				), self.timeout)
			Fiber.yield()
		if self._error
			throw self._error
		self._result

	@ticket.__defineGetter__ 'result', ->
		@yield()
	@ticket.__defineGetter__ 'error', ->
		if self._error
			return self._error
		try
			@result
		catch e
			return e
		null
	@ticket.__defineGetter__ 'timeout', ->
		self.timeout
	@ticket.__defineSetter__ 'timeout', (value) ->
		self.timeout = value
		return
	# append self to current fiber
	@fiber.addFuture @ticket
	@ticket

Function::sync = (obj) ->
	fiber = Fiber.current
	err = undefined
	result = undefined
	yielded = false

	###if /^\//g.test(__stack[1].getFileName()) and !/node_modules/g.test(__stack[1].getFileName())
		if global.last_function.length >= 10
			global.last_function.shift()
		global.last_function.push
			function: __stack[1].getFunctionName()
			line: __stack[1].getLineNumber()
			file: __stack[1].getFileName()###
	# Create virtual callback

	syncCallback = (callbackError, callbackResult, otherArgs) ->
		# forbid to call twice
		if syncCallback.called
			return
		syncCallback.called = true
		if callbackError
			err = callbackError
		else if otherArgs
			# Support multiple callback result values
			result = []
			i = 1
			l = arguments.length
			while i < l
				result.push arguments[i]
				i++
		else
			result = callbackResult
		# Resume fiber if yielding
		if yielded
			fiber.run()
		return

	# Prepare args (remove first arg and add callback to the end)
	# The cycle is used because of slow v8 arguments materialization
	i = 1
	args = []
	l = arguments.length
	while i < l
		args.push arguments[i]
		i++
	args.push syncCallback
	# call async function
	@apply obj, args
	# wait for result
	if !syncCallback.called
		yielded = true
		Fiber.yield()
	# Throw if err
	if err
		throw err
	result

Function::sync2 = (obj, args) ->
	fiber = Fiber.current
	err = undefined
	result = undefined
	yielded = false

	###if /^\//g.test(__stack[1].getFileName()) and !/node_modules/g.test(__stack[1].getFileName())
		if global.last_function.length >= 10
			global.last_function.shift()
		global.last_function.push
			function: __stack[1].getFunctionName()
			line: __stack[1].getLineNumber()
			file: __stack[1].getFileName()###
	# Create virtual callback

	syncCallback = (callbackError, callbackResult, otherArgs) ->
		# forbid to call twice
		if syncCallback.called
			return
		syncCallback.called = true
		if callbackError
			err = callbackError
		else if otherArgs
			# Support multiple callback result values
			result = []
			i = 1
			l = arguments.length
			while i < l
				result.push arguments[i]
				i++
		else
			result = callbackResult
		# Resume fiber if yielding
		if yielded
			fiber.run()
		return

	# Prepare args (remove first arg and add callback to the end)
	# The cycle is used because of slow v8 arguments materialization
	# i = 1
	# args = []
	# l = arguments.length
	# while i < l
	# 	args.push arguments[i]
	# 	i++
	args.push syncCallback
	# call async function
	@apply obj, args
	# wait for result
	if !syncCallback.called
		yielded = true
		Fiber.yield()
	# Throw if err
	if err
		throw err
	result

###*
# Sync module itself
###

Sync = (fn, callback) ->
	if fn instanceof Function
		return Sync.Fiber(fn, callback)
	# TODO: we can also wrap any object with Sync, in future..
	return

Sync.stat =
	totalFibers: 0
	activeFibers: 0
	totalFutures: 0
	activeFutures: 0

###*
# This function should be used when you need to turn some peace of code fiberized
# It just wraps your code with Fiber() logic in addition with exceptions handling
###

Sync.FiberCheck = ->
	parent = Fiber.current
	return parent?

Sync.Fiber = (fn, callback) ->
	parent = Fiber.current
	Sync.stat.totalFibers++
	traceError = new Error
	if parent
		traceError.__previous = parent.traceError
	fiber = Fiber(->
		`var fiber`
		Sync.stat.activeFibers++
		fiber = Fiber.current
		result = undefined
		error = undefined
		# Set id to fiber
		fiber.id = Sync.stat.totalFibers
		# Save the callback to fiber
		fiber.callback = callback
		# Register trace error to the fiber
		fiber.traceError = traceError
		# Initialize scope
		fiber.scope = {}
		# Assign parent fiber
		fiber.parent = parent
		# Fiber string representation

		fiber.toString = ->
			'Fiber#' + fiber.id

		# Fiber path representation

		fiber.getPath = ->
			(if fiber.parent then fiber.parent.getPath() + ' > ' else '') + fiber.toString()

		# Inherit scope from parent fiber
		if parent
			fiber.scope.__proto__ = parent.scope
		# Add futures support to a fiber
		fiber.futures = []

		fiber.waitFutures = ->
			results = []
			while fiber.futures.length
				results.push fiber.futures.shift().result
			results

		fiber.removeFuture = (ticket) ->
			index = fiber.futures.indexOf(ticket)
			if ~index
				fiber.futures.splice index, 1
			return

		fiber.addFuture = (ticket) ->
			fiber.futures.push ticket
			return

		# Run body
		try
			# call fn and wait for result
			result = fn(Fiber.current)
			# if there are some futures, wait for results
			fiber.waitFutures()
		catch e
			error = e
		Sync.stat.activeFibers--
		# return result to the callback
		if callback instanceof Function
			callback error, result
		else if error and parent and parent.callback
			parent.callback error
		else if error
			# TODO: what to do with such errors?
			# throw error;
		else
		return
	)
	fiber.run()
	return

SyncFuture::__proto__ = Function
Sync.Future = SyncFuture

###*
# Calls the function asynchronously and yields only when 'value' or 'error' getters called
# Returs Future function/object (promise)
#
###

Function::future = (obj) ->
	fn = this
	future = new SyncFuture
	# Prepare args (remove first arg and add callback to the end)
	# The cycle is used because of slow v8 arguments materialization
	i = 1
	args = []
	l = arguments.length
	while i < l
		args.push arguments[i]
		i++
	# virtual future callback, push it as last argument
	args.push future
	# call async function
	fn.apply obj, args
	future

###*
# Use this method to make asynchronous function from synchronous one
# This is a opposite function from .sync()
###

Function::async = (context) ->
	fn = this
	fiber = Fiber.current
	# Do nothing on async again

	asyncFunction = ->
		# Prepare args (remove first arg and add callback to the end)
		# The cycle is used because of slow v8 arguments materialization
		i = 0
		args = []
		l = arguments.length
		while i < l
			args.push arguments[i]
			i++
		obj = context or this
		cb = args.pop()
		async = true
		if typeof cb != 'function'
			args.push cb
			if Fiber.current
				async = false
		Fiber.current = Fiber.current or fiber
		# Call asynchronously
		if async
			Sync (->
				fn.apply obj, args
			), cb
		else
			return fn.apply(obj, args)
		return

	asyncFunction.async = ->
		asyncFunction

	# Override sync call

	asyncFunction.sync = (obj) ->
		i = 1
		args = []
		l = arguments.length
		while i < l
			args.push arguments[i]
			i++
		fn.apply obj or context or this, args

	# Override toString behavior

	asyncFunction.toString = ->
		fn + '.async()'

	asyncFunction

###*
# Used for writing synchronous middleware-style functions
#
# throw "something" --> next('something')
# return --> next()
# return null --> next()
# return undefined --> next()
# return true --> void
###

Function::asyncMiddleware = (obj) ->
	fn = @async(obj)
	# normal (req, res) middleware
	if @length == 2
		return (req, res, next) ->
			fn.call this, req, res, (err, result) ->
				if err
					return next(err)
				if result != true
					next()
				return

	else if @length == 3
		return (err, req, res, next) ->
			fn.call this, err, req, res, (err, result) ->
				if err
					return next(err)
				if result != true
					next()
				return

	return

###*
# Sleeps current fiber on given value of millis
###

Sync.sleep = (ms) ->
	fiber = Fiber.current
	if !fiber
		throw new Error('Sync.sleep() can be called only inside of fiber')
	setTimeout (->
		fiber.run()
		return
	), ms
	Fiber.yield()
	return

###*
# Logs sync result
###

Sync.log = (err, result) ->
	if err
		return console.error(err.stack or err)
	if arguments.length == 2
		if result == undefined
			return
		return console.log(result)
	console.log Array.prototyle.slice.call(arguments, 1)
	return

###*
# Synchronous repl implementation: each line = new fiber
###

Sync.repl = ->
	repl = require('repl')
	# Start original repl
	r = repl.start.apply(repl, arguments)
	# Wrap line watchers with Fiber
	newLinsteners = []
	r.rli.listeners('line').map (f) ->
		newLinsteners.push (a) ->
			Sync (->
				require.cache[__filename] = module
				f a
				return
			), Sync.log
			return
		return
	r.rli.removeAllListeners 'line'
	while newLinsteners.length
		r.rli.on 'line', newLinsteners.shift()
	# Assign Sync to repl context
	r.context.Sync = Sync
	r

# TODO: document
Sync.__defineGetter__ 'scope', ->
	Fiber.current and Fiber.current.scope
# TODO: document

Sync.waitFutures = ->
	if Fiber.current
		Fiber.current.waitFutures()
	return

# Expose Fibers
Sync.Fibers = Fiber
#module.exports = exports = Sync

# ---
# generated by js2coffee 2.1.0
