#!package export cartridge.assets

#!import system.Middleware
#!import fs
#!import path
#!import crypto

#!import tools.http.etag
#!import tools.http.mime

class assets extends Middleware

	__init: () ->


	__middle: ($config, $req, $res, $stime, $wait) ->
		regex = /^\/\:system\~arcane\/(.*)$/g.exec $req.url.split('?')[0]
		if $req.url.split('?')[0] is '/socket.io'

			request_file = path.resolve "#{__dirname}/../../../../extra/assets/js/socket.io.js"

			source = fs.readFileSync request_file
			source = String(source).replace(/\{\{req\.headers\.host\}\}/g, $req.headers.host).replace(/\{\{req\.baseUrl\}\}/g, $req.baseUrl)

			md5sum = crypto.createHash 'md5'
			md5sum.update source

			request_file = "/tmp/#{md5sum.digest('hex')}.js"

			if not fs.existsSync(request_file)
				fs.writeFileSync request_file, source

		else if regex
			request_file = path.resolve "#{__dirname}/../../../../extra/assets/#{regex[1]}"
		else if /^\/favicon.ico/g.test $req.url
			if $req.root?
				request_file = path.resolve "#{$req.root}/assets/favicon.ico"
			else
				request_file = path.resolve "#{__dirname}/../../../../extra/assets/favicon.ico"
		else
			request_file = "#{$req.root}/assets#{$req.url.split('?')[0]}"
		#p = require(__dirname + '/../core/ua-parser')

		if request_file? and fs.existsSync(request_file) and fs.lstatSync(request_file).isFile()

			# $res.end 'tst'

			# throw 'assets'

			# if $req._timeoutProcess
			# 	clearTimeout $req._timeoutProcess
			# 	$req._timeoutProcess = null
			stats = fs.statSync(request_file)
			# assets.RequestFileStaticFile.sync null, $req, $res, request_file, stats
			result = $wait.for assets.RequestFileStaticFile, $req, $res, request_file, stats
			#$res.console.timeEnd('http://' + $req.headers.host + $req.url, $req.method + '|' + $req.connection.remoteAddress.replace(/\:\:ffff\:/g, '') + '|' + p.parseUA($req.headers['user-agent']).toString() + '|' + p.parseOS($req.headers['user-agent']).toString(), $stime.start);
			throw 'assets'

		false

	###
	# Private functions and variables
	###

	# @etag: require __dirname + '/../../../../core/Etag.js'
	# @mime: require __dirname + '/../../../../../lib/mime'
	@onFinished: require __dirname + '/../../../../core/OnFinished.js'
	@ReadStream: fs.ReadStream

	@rangeParser: (size, str) ->
		valid = true
		i = str.indexOf('=')
		if -1 == i
			return -2
		arr = str.slice(i + 1).split(',').map((range) ->
			_range = range.split('-')
			start = parseInt(_range[0], 10)
			end = parseInt(_range[1], 10)
			# -nnn
			if isNaN(start)
				start = size - end
				end = size - 1
				# nnn-
			else if isNaN(end)
				end = size - 1
			# limit last-byte-pos to current length
			if end > size - 1
				end = size - 1
			# invalid
			if isNaN(start) or isNaN(end) or start > end or start < 0
				valid = false
			{
				start: start
				end: end
			}
		)
		arr.type = str.slice(0, i)
		if valid then arr else -1

	@RequestFileStaticFile: (req, res, path, stat, cb) ->
		len = stat.size
		options = {}
		opts = {}
		ranges = req.headers.range
		offset = options.start or 0
		#debug('pipe "%s"', path);
		# set header fields
		assets._setHeader res, path, stat
		# set content-type
		if res.getHeader('Content-Type')
			cb null, true
			return
		type = mime.lookup(path)
		charset = mime.charsets.lookup(type)
		res.set 'Content-Type', type + (if charset then '; charset=' + charset else '')
		#------------------------------------------------------------------------------------------//
		# conditional GET support
		if assets.isConditionalGET(req) and assets.isCachable(res) and assets.isFresh(req, res, stat)
			#console.log('ERROR: not modified ' + path);
			cb null, true
			return assets.notModified(res)
		#-----------------------------------------------------------------------------------------//
		# adjust len to start/end options
		len = Math.max(0, len - offset)
		if options.end != undefined
			bytes = options.end - offset + 1
			if len > bytes
				len = bytes
		#-----------------------------------------------------------------------------------------//
		# Range support
		if ranges
			ranges = assets.rangeParser(len, ranges)
			# If-Range support
			if !assets.isRangeFresh(req, res)
				#debug('range stale');
				ranges = -2
			# unsatisfiable
			if -1 == ranges
				#debug('range unsatisfiable');
				res.set 'Content-Range', 'bytes */' + stat.size
				assets.serverError 416
				cb null, true
				return
			# valid (syntactically invalid/multiple ranges are treated as a regular response)
			if -2 != ranges and ranges.length == 1
				#debug('range %j', ranges);
				# Content-Range
				res.status 206
				res.set 'Content-Range', 'bytes ' + ranges[0].start + '-' + ranges[0].end + '/' + len
				offset += ranges[0].start
				len = ranges[0].end - (ranges[0].start) + 1
		#---------------------------------------------------------------------------------------//
		# clone options
		for prop of options
			opts[prop] = options[prop]
		#--------------------------------------------------------------------------------------//
		# set read options
		opts.start = offset
		opts.end = Math.max(offset, offset + len - 1)
		#---------------------------------------------------------------------------------------//
		# content-length
		res.set 'Content-Length', len
		# HEAD support
		if 'HEAD' == req.method
			res.send res.statusCode
			cb null, true
			return
		# res.updateHeaders res.statusCode
		assets.ServerStream req, res, path, opts, cb
		return

	@_setHeader: (res, path, stat) ->
		if !res.get('Accept-Ranges')
			res.set 'Accept-Ranges', 'bytes'
		if !res.get('Date')
			res.set 'Date', (new Date).toUTCString()
		if !res.get('Cache-Control')
			res.set 'Cache-Control', 'public, max-age=31536000'
		if !res.get('Last-Modified')
			modified = stat.mtime.toUTCString()
			res.set 'Last-Modified', modified
		if !res.get('ETag')
			val = etag(stat)
			res.set 'ETag', val
		return

	@isConditionalGET: (req) ->
		req.headers['if-none-match'] or req.headers['if-modified-since']

	@isCachable: (res) ->
		res.statusCode >= 200 and res.statusCode < 300 or 304 == res.statusCode

	@isFresh: (req, res, stat) ->
		assets.fresh req.headers, res._headers, stat

	@fresh: (req, res, stat) ->
		mtime = Date.parse(stat.mtime)
		headers = {}
		clientETag = req['if-none-match']
		clientMTime = Date.parse(req['if-modified-since'])
		length = stat.size
		(clientMTime or clientETag) and (!clientETag or clientETag == etag(stat)) and (!clientMTime or clientMTime >= mtime)

	@notModified: (res) ->
		assets.removeContentHeaderFields res
		res.sendStatus 304
		return

	@removeContentHeaderFields: (res) ->
		headers = [
			'Content-Encoding'
			'Content-Language'
			'Content-Length'
			'Content-Location'
			'Content-MD5'
			'Content-Range'
			'Content-Type'
			'Expires'
			'Last-Modified'
		]
		for i of headers
			res.removeHeader headers[i]
		return

	@isRangeFresh: (req, res) ->
		ifRange = req.headers['if-range']
		if !ifRange
			return true
		if ~ifRange.indexOf('"') then ~ifRange.indexOf(req.headers.etag) else Date.parse(req.headers['last-modified']) <= Date.parse(ifRange)

	@serverError: (res, status) ->
		msg = http.STATUS_CODES[status]
		res._headers = undefined
		res.send status, msg
		return

	@ServerStream: (req, res, path, options, cb) ->
		# TODO: this is all lame, refactor meeee
		finished = false
		# pipe
		_stream = fs.createReadStream(path, options)
		#this.emit('stream', _stream);
		_stream.pipe res
		# response finished, done with the fd
		assets.onFinished res, ->
			finished = true
			assets._destroy _stream
			cb null, 'assets:finish'
			return
		# error handling code-smell
		_stream.on 'error', (err) ->
			# request already finished
			if finished
				cb null, 'assets:already-finish'
				return
			# clean up stream
			finished = true
			assets._destroy _stream
			# error
			#self.onStatError(err);
			notfound = [
				'ENOENT'
				'ENAMETOOLONG'
				'ENOTDIR'
			]
			if ~notfound.indexOf(err.code)
				cb null, true
				return assets.serverError(404, err)
			assets.serverError res, 500, err
			cb null, true
			return
		# end
		_stream.on 'end', ->
			#self.emit('end');
			#res.send(res.statusCode);
			return
		do req.__response
		return

	@_destroy: (stream) ->
		if stream instanceof assets.ReadStream
			return assets.destroyReadStream(stream)
		if !(stream instanceof Stream)
			return stream
		if typeof stream.destroy == 'function'
			stream.destroy()
		stream

	@destroyReadStream: (stream) ->
		stream.destroy()
		if typeof stream.close == 'function'
			# node.js core bug work-around
			stream.on 'open', assets.onopenClose
		stream

	@onopenClose: ->
		if typeof @fd == 'number'
			# actually close down the fd
			@close()
		return
