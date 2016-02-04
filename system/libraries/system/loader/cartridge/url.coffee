package export cartridge.urlmid

import system.Middleware

import url

class urlmid extends Middleware

	__init: () ->


	__middle: ($req, $res, $config) ->
		pattern = /([^?=&]+)(?:$|[&#]|=([^&#]*))/g
		ret = url.parse($req.url, true)

		$req.query = ret.query ? {}

		$req.param = (name) ->
			if $req.query and $req.query[name]?
				$req.query[name]
			else 
				null

		# if url.parse($req.url).query?
		# 	query = decodeURI url.parse($req.url).query
		# 	while match = pattern.exec(query)
		# 		$req.query[match[1]] = match[2]
			
		# if Object.keys($req.query).length is 0
		# 	$req.query = null
		ret.query = $req.query

		# $res.redirect = (new_url) ->
		# 	$res.setHeader 'Location', new_url
		# 	$res.send 302
		# 	throw 'redirect'

		$req.url = $req.url.split('?')[0]

		try
			ret.pathname = decodeURI ret.pathname
		catch err
			console.log err.stack if err.stack?
			console.log err if not err.stack?

		return ret
		