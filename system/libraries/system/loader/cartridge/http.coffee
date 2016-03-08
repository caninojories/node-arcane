package export cartridge.httpServer

import system.Middleware

import http-proxy
import fs
import path
import url

import http

import net

import tools.http.fresh
import tools.http.parseurl
import tools.http.proxy-addr
import tools.http.type-is
import tools.http.accepts
import tools.http.range-parser
import tools.http.vary
import tools.http.content-type
import tools.http.etag
import tools.http.mime
import tools.http.cookie
import tools.http.cookie-signature
import tools.http.utils-merge

class httpServer extends Middleware

	charsetRegExp = /;\s*charset\s*=/

	res_serv =
		__proto__: http.ServerResponse.prototype

	req_serv =
		__proto__: http.IncomingMessage.prototype

	@proxy: httpProxy.createProxyServer({})


	__init: () ->
		fn = (err, data) ->
			if (err) then throw err
			httpServer.config = {}
			httpServer.rules = {}
			_data = JSON.parse data
			for i, value of _data
				if i is '@base'
					httpServer.config[i] = value
				else
					httpServer.rules[i] = value

		fs.watchFile "#{__tmp_location}/htaccess.json", {
			interval: 1000
		}, (curr, prev) ->
			readConfig fn

		fs.readFile "#{__tmp_location}/htaccess.json", "utf8", fn


	__middle: ($req, $res, $stime) ->
		$req.__proto__ = req_serv
		$res.__proto__ = res_serv

		$req.secret = 'd8aae46eba9976b0cbb399444e710f4b'

		$res.set 'Server', "Arc-Engine v#{require("#{__dirname}/../../../../../package.json").version}"

		return {
			config: () ->

		}

	###
	# Private variable and functions
	###

	@header_response: http.STATUS_CODES

	@rules: {}
	@config: {}

	@getHost: (url_) ->
		hostname = ///http\:\/\/([0-9a-zA-Z.:-]*)///g.exec url_
		if hostname
			return hostname[1]
		return false

	@getURL: (url_) ->
		_url = /http\:\/\/([0-9a-zA-Z.:-]*)\/(.+?)$/g.exec url_
		if _url
			return "/#{_url[2]}"
		return false

	# @initFunctions: ($req, $res, $stime) ->
	# 	headers = {}

	__etag = (body, encoding) ->
		buf = if !Buffer.isBuffer(body) then new Buffer(body, encoding) else body
		etag buf, weak: false

	__wetag = (body, encoding) ->
		buf = if !Buffer.isBuffer(body) then new Buffer(body, encoding) else body
		etag buf, weak: true


	setCharset = (type, charset) ->
		if !type or !charset
			return type
		# parse type
		parsed = contentType.parse(type)
		# set charset
		parsed.parameters.charset = charset
		# format type
		contentType.format parsed

	acceptParams = (str, index) ->
		parts = str.split(RegExp(' *; *'))
		ret =
			value: parts[0]
			quality: 1
			params: {}
			originalIndex: index
		i = 1
		while i < parts.length
			pms = parts[i].split(RegExp(' *= *'))
			if 'q' == pms[0]
				ret.quality = parseFloat(pms[1])
			else
				ret.params[pms[0]] = pms[1]
			++i
		ret

	normalizeType = (type) ->
		if ~type.indexOf('/') then acceptParams(type) else
			value: mime.lookup(type)
			params: {}

	normalizeTypes = (types) ->
		ret = []
		i = 0
		while i < types.length
			ret.push normalizeType(types[i])
			++i
		ret

	escapeHtml = (html) ->
		String(html).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;').replace(/</g, '&lt;').replace />/g, '&gt;'

	# http.IncomingMessage.prototype.testing123 = ->
	# 	console.log 'heloloolooloolo'

	res_serv.moveFileUpload = (name, to, cb) ->
		if $req.files and $req.files[name]
			try
				fs.unlinkSync $req.root + to
			catch err
				throw err

			source = fs.createReadStream $req.files[name].path
			dest = fs.createWriteStream $req.root + to
			source.pipe dest
			source.on 'end', () ->
				if cb and typeof cb is 'function' then cb null, true

			source.on 'error', (err) ->
				if cb and typeof cb is 'function' then cb err, null

	res_serv.download = (_mime, filename, file) ->
		@set 'Content-disposition', "attachment; filename=#{encodeURIComponent filename}"
		@set 'Content-type', _mime
		@updateHeaders 200

		filestream = fs.createReadStream file
		filestream.pipe @

		throw 'stream'

	res_serv.sendStatus = (statusCode) ->
		body = httpServer.header_response[statusCode] or String(statusCode)
		@statusCode = statusCode
		@type 'txt'
		@send body

	res_serv.status = (code) ->
		@statusCode = code
		return @

	res_serv.get = (field) ->
		@getHeader field

	res_serv.set =
	res_serv.header = (field, val) ->
		throw 'done' if @finished

		if arguments.length == 2
			value = if Array.isArray(val) then val.map(String) else String(val)
			# add charset to content-type
			if field.toLowerCase() == 'content-type' and !charsetRegExp.test(value)
				charset = mime.charsets.lookup(value.split(';')[0])
				if charset
					value += '; charset=' + charset.toLowerCase()
			@setHeader field, value
		else
			for key of field
				@set key, field[key]
		this

	res_serv.location = (url) ->
		loc = url
		# "back" is an alias for the referrer
		if url == 'back'
			loc = @req.get('Referrer') or '/'
		# set location
		@set 'Location', loc

		# throw 'location'
		this

	res_serv.redirect = (url) ->
		address = url
		body = undefined
		status = 302
		# allow status / url
		if arguments.length == 2
			if typeof arguments[0] == 'number'
				status = arguments[0]
				address = arguments[1]
			else
				console.log 'res.redirect(url, status): Use res.redirect(status, url) instead'
				status = arguments[1]
		# Set location header
		@location address
		address = @get('Location')
		# Support text/{plain,html} by default
		@format
			text: ->
				body = httpServer.header_response[status] + '. Redirecting to ' + encodeURI(address)
				return
			html: ->
				u = escapeHtml(address)
				body = '<p>' + httpServer.header_response[status] + '. Redirecting to <a href="' + u + '">' + u + '</a></p>'
				return
			default: ->
				body = ''
				return
		# Respond

		# body = statusCodes[status] + '. Redirecting to ' + encodeURI(address)

		###################################

		@statusCode = status
		@set 'Content-Length', Buffer.byteLength(body)
		if @req.method == 'HEAD'
			@end()
		else
			@end body

		throw 'redirect'
		return

	res_serv.send = (body) ->
		# console.log (new Error).stack
		chunk = body
		encoding = undefined
		len = undefined
		req = @req
		type = undefined
		# settings
		app = @app
		# allow status / body
		if arguments.length == 2
			# res.send(body, status) backwards compat
			if typeof arguments[0] != 'number' and typeof arguments[1] == 'number'
				# console.log 'res.send(body, status): Use res.status(status).send(body) instead'
				@statusCode = arguments[1]
			else
				# console.log 'res.send(status, body): Use res.status(status).send(body) instead'
				@statusCode = arguments[0]
				chunk = arguments[1]
		# disambiguate res.send(status) and res.send(status, num)
		if typeof chunk == 'number' and arguments.length == 1
			# res.send(status) will set status message as text string
			if !@get('Content-Type')
				@type 'txt'
			# console.log 'res.send(status): Use res.sendStatus(status) instead'
			@statusCode = chunk
			chunk = httpServer.header_response[chunk]
		switch typeof chunk
			# string defaulting to html
			when 'string'
				if !@get('Content-Type')
					@type 'html'
			when 'boolean', 'number', 'object'
				if chunk == null
					chunk = ''
				else if Buffer.isBuffer(chunk)
					if !@get('Content-Type')
						@type 'bin'
				else
					return @json(chunk)
		# write strings in utf-8
		if typeof chunk == 'string'
			encoding = 'utf8'
			type = @get('Content-Type')
			# reflect this in content-type
			if typeof type == 'string'
				@set 'Content-Type', setCharset(type, 'utf-8')
		# populate Content-Length
		if chunk != undefined
			if !Buffer.isBuffer(chunk)
				# convert chunk to Buffer; saves later double conversions
				chunk = new Buffer(chunk, encoding)
				encoding = undefined
			len = chunk.length
			@set 'Content-Length', len
		# populate ETag
		# etag = undefined
		generateETag = len != undefined and __etag # app.get('etag fn')
		if typeof generateETag == 'function' and !@get('ETag')
			if _etag = generateETag(chunk, encoding)
				@set 'ETag', _etag
		# freshness
		if req.fresh
			@statusCode = 304
		# strip irrelevant headers
		if 204 == @statusCode or 304 == @statusCode
			@removeHeader 'Content-Type'
			@removeHeader 'Content-Length'
			@removeHeader 'Transfer-Encoding'
			chunk = ''
		if req.method == 'HEAD'
			# skip body for HEAD
			@end()
		else
			# respond
			@end chunk, encoding

		throw 'done'

		this


	res_serv.contentType =
	res_serv.type = (type) ->
		ct = if type.indexOf('/') == -1 then mime.lookup(type) else type
		@set 'Content-Type', ct


	res_serv.format = (obj) ->
		req = @req
		# next = req.next
		fn = obj.default
		if fn
			delete obj.default
		keys = Object.keys(obj)
		key = if keys.length > 0 then req.accepts(keys) else false
		@vary 'Accept'
		if key
			@set 'Content-Type', normalizeType(key).value
			obj[key] req, this #, next
		else if fn
			fn()
		else
			throw new Error 'Not Acceptable'
			# err = new Error('Not Acceptable')
			# err.status = err.statusCode = 406
			# err.types = normalizeTypes(keys).map((o) ->
			# 	o.value
			# )
			# next err
		this

	res_serv.vary = (field) ->
		# checks for back-compat
		if !field or Array.isArray(field) and !field.length
			# deprecate 'res.vary(): Provide a field name'
			return this
		vary this, field
		this


	res_serv.json = (obj) ->
		val = obj
		# allow status / body
		if arguments.length == 2
			# res.json(body, status) backwards compat
			if typeof arguments[1] == 'number'
				# deprecate 'res.json(obj, status): Use res.status(status).json(obj) instead'
				@statusCode = arguments[1]
			else
				# deprecate 'res.json(status, obj): Use res.status(status).json(obj) instead'
				@statusCode = arguments[0]
				val = arguments[1]
		# settings
		# app = @app
		# replacer = app.get('json replacer')
		# spaces = app.get('json spaces')
		body = JSON.stringify(val, null, 4)
		# content-type
		if !@get('Content-Type')
			@set 'Content-Type', 'application/json'

		@send body


	# res_serv.fileStream = (url)->
	# 	stat = fs.statSync(url)

	# 	@set 'Content-Type', mime.lookup(url)
	# 	@set 'Content-Length', stat.size

	# 	if @req.get('range')?
	# 		range = @req.range stat.size
	# 		chunksize = (range[0].end - range[0].start) + 1

	# 		@set "Content-Range",	"#{range.type} #{range[0].start}-#{range[0].end}/#{stat.size}"
	# 		@set "Accept-Ranges",	"#{range.type}"
	# 		@set "Content-Length",	chunksize

	# 	@status 206

	# 	self = this
	# 	stream = fs.createReadStream(url, (range?[0] ? null)).on "open", ->
	# 		stream.pipe self
	# 	.on "error", (err) ->
	# 		self.end err

	# 	throw 'stream'


	res_serv.cookie = (name, value, options) ->
		opts = utilsMerge({}, options)
		secret = @req.secret
		signed = opts.signed
		if signed and !secret
			throw new Error('cookieParser("secret") required for signed cookies')
		val = if typeof value == 'object' then 'j:' + JSON.stringify(value) else String(value)
		if signed
			val = 's:' + cookieSignature.sign(val, secret)
		if 'maxAge' of opts
			opts.expires = new Date(Date.now() + opts.maxAge)
			opts.maxAge /= 1000
		if opts.path == null
			opts.path = '/'
		@append 'Set-Cookie', cookie.serialize(name, String(val), opts)
		this

	res_serv.append = (field, val) ->
		prev = @get(field)
		value = val
		if prev
			# concat the new and prev vals
			value = if Array.isArray(prev) then prev.concat(val) else if Array.isArray(val) then [ prev ].concat(val) else [
				prev
				val
			]
		@set field, value

	res_serv.clearCookie = (name, options) ->
		opts = utilsMerge({
			expires: new Date(1)
			path: '/'
		}, options)
		@cookie name, '', opts

	###*
	# Helper function for creating a getter on an object.
	#
	# @param {Object} obj
	# @param {String} name
	# @param {Function} getter
	# @private
	###

	defineGetter = (obj, name, getter) ->
		Object.defineProperty obj, name,
			configurable: true
			enumerable: true
			get: getter
		return


	req_serv.is = (types) ->
		arr = types
		# support flattened arguments
		if !Array.isArray(types)
			arr = new Array(arguments.length)
			i = 0
			while i < arr.length
				arr[i] = arguments[i]
				i++
		typeIs this, arr


	req_serv.accepts = ->
		accept = accepts(this)
		accept.types.apply accept, arguments


	req_serv.acceptsEncodings = ->
		accept = accepts(this)
		accept.encodings.apply accept, arguments

	req_serv.acceptsLanguages = ->
		accept = accepts(this)
		accept.languages.apply accept, arguments

	req_serv.get =
	req_serv.header = (name) ->
		lc = name.toLowerCase()
		switch lc
			when 'referer', 'referrer'
				return @headers.referrer or @headers.referer
			else
				return @headers[lc]
		return

	req_serv.range = (size) ->
		range = @get('Range')
		if !range
			return
		rangeParser size, range

	###*
	# Compile "proxy trust" value to function.
	#
	# @param	{Boolean|String|Number|Array|Function} val
	# @return {Function}
	# @api private
	###
	compileTrust = (val) ->
		if typeof val == 'function'
			return val
		if val == true
			# Support plain true/false
			return ->
				true

		if typeof val == 'number'
			# Support trusting hop count
			return (a, i) ->
				i < val

		if typeof val == 'string'
			# Support comma-separated values
			val = val.split(RegExp(' *, *'))
		proxyAddr.compile val or []

	defineGetter req_serv, 'protocol', ->
		proto = if @connection.encrypted then 'https' else 'http'
		# compileTrust(false) default value 'false' posible value ['192.168.1.0', '192.168.1.255']
		if !compileTrust(false)(@connection.remoteAddress, 0)
			return proto
		# Note: X-Forwarded-Proto is normally only ever a
		#			 single value, but this is to be safe.
		proto = @get('X-Forwarded-Proto') or proto
		proto.split(/\s*,\s*/)[0]


	defineGetter req_serv, 'secure', ->
		@protocol is 'https'


	defineGetter req_serv, 'ip', ->
		# compileTrust(false) default value 'false' posible value ['192.168.1.0', '192.168.1.255']
		proxyAddr this, compileTrust(false)


	defineGetter req_serv, 'ips', ->
		# compileTrust(false) default value 'false' posible value ['192.168.1.0', '192.168.1.255']
		addrs = proxyAddr.all(this, compileTrust(false))
		addrs.slice(1).reverse()

	defineGetter req_serv, 'subdomains', ->
		hostname = @hostname
		if !hostname
			return []
		subdomains = if !net.isIP(hostname) then hostname.split('.').reverse() else [ hostname ]
		# offset to get the sub domain, 2 default
		subdomains.slice 2

	defineGetter req_serv, 'hostname', ->
		host = @get('X-Forwarded-Host')
		# compileTrust(false) default value 'false' posible value ['192.168.1.0', '192.168.1.255']
		if !host or !compileTrust(false)(@connection.remoteAddress, 0)
			host = @get('Host')
		if !host
			return
		# IPv6 literal support
		offset = if host[0] == '[' then host.indexOf(']') + 1 else 0
		index = host.indexOf(':', offset)
		if index != -1 then host.substring(0, index) else host

	defineGetter req_serv, 'path', ->
		parseurl(this).pathname

	defineGetter req_serv, 'fresh', ->
		method = @method
		s = @res.statusCode
		# GET or HEAD for weak freshness validation only
		if 'GET' != method and 'HEAD' != method
			return false
		# 2xx or 304 as per rfc2616 14.26
		if s >= 200 and s < 300 or 304 == s
			return fresh(@headers, @res._headers or {})
		false

	defineGetter req_serv, 'stale', ->
		!@fresh

	defineGetter req_serv, 'xhr', ->
		val = @get('X-Requested-With') or ''
		val.toLowerCase() == 'xmlhttprequest'

	defineGetter req_serv, 'base_url', ->
		@baseUrl ? ''
