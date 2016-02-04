package export cartridge.cookies

import system.Middleware

class cookies extends Middleware

	@cache: {}

	__init: () ->


	__middle: ($req) ->
		
		{
			options:
				maxAge: 14 * 24 * 3600000
				domain: $req.hostname
				path: '/'
			get: cookies.get
		}

		# ret = {}
		# if typeof $req.headers.cookie isnt 'undefined'

		# 	cookie_pattern = /([0-9a-zA-Z_\.-]+?)\=(.+?)(?:\;|$)/g
		# 	_match = null

		# 	while _match = cookie_pattern.exec $req.headers.cookie
		# 		# if not ret[_match[1]]?
		# 		ret[_match[1]] = _match[2]

		# {
		# 	maxAge: 14 * 24 * 3600000
		# 	list: ret
		# }


	@get: ($req, name) ->
		if header_cookies = $req.headers?.cookie
			match = header_cookies.match cookies.getPattern 'ArcEngine'
			return match?[1] ? null

		null
		
	@getPattern: (name) ->
		return cookies.cache[name] if cookies.cache[name]?
		cookies.cache[name] = new RegExp "(?:^|;) *#{name.replace /[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&"}=([^;]*)"