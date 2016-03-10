#!package export cartridge.vhost

#!import system.Middleware
#!import os
#!import path

class vhost extends Middleware

	__init: () ->
		ifaces = os.networkInterfaces()
		vhost.ip_address = ''
		vhost_project_list = []

		for v of ifaces
			if v is 'lo' then continue
			vhost.ip_address = ifaces[v][0].address

		for index of __arc_engine.vhost
			if /\//g.test index
				splitted = index.split '/'
				url = index.replace splitted[0], ''
				if not vhost.host_map[splitted[0]]?
					vhost.host_map[splitted[0]] = {}

				vhost.host_map[splitted[0]][url] = __arc_engine.vhost[index].DocumentRoot
			else
				vhost.host_map_normal[index] = __arc_engine.vhost[index].DocumentRoot

			if vhost_project_list.indexOf(__arc_engine.vhost[index].DocumentRoot) is -1
				vhost_project_list.push __arc_engine.vhost[index].DocumentRoot

		vhost_project_list.push path.resolve("#{__dirname}/../../../../debug")

		return vhost_project_list

	__middle: ($req, $res, $app) ->
		$res.__set = {}

		found = false

		if /\/\:\:1\~\@debug\:\:trace(|\/)/g.test $req.url
			__url__data = $req.url.split '/::1~@debug::trace'
			$req.baseUrl = "#{__url__data[0]}/::1~@debug::trace"
			$req.root = path.resolve("#{__dirname}/../../../../debug")
			$req.url = __url__data[1] or '/'
			found = true
		else if $req.url is '/favicon.ico'
			found = true

		unless found
			for i, v of vhost.host_map[$req.get 'Host'] ? {}
				if ($req.url.length is i.length and $req.url.indexOf(i) is 0) or $req.url.indexOf("#{i}/") is 0
					found = true
					$req.root = v
					$req.baseUrl = i.replace /\/$/g, ''
					$req.url = $req.url.replace new RegExp("^#{i.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")}", 'g'), ''
					break
				break if found

		unless found is true
			if vhost.host_map_normal[$req.get 'Host']?
				$req.root = vhost.host_map_normal[$req.get 'Host']
				$req.baseUrl = ''
				found = true

		throw 404 unless found


		# $req.baseUrl = ''

		# regex = /^\/\:system\~arcane\/(.*)$/g.exec $req.url.split('?')[0]
		# if regex? #or /^\/favicon.ico/g.test $req.url.split('?')[0]
		# 	$app.use ($config, $assets) ->
		# else if /\/\:\:1\~\@debug\:\:trace(|\/)/g.test $req.url
		# 	__url__data = $req.url.split '/::1~@debug::trace'
		# 	$req.baseUrl = "#{__url__data[0]}/::1~@debug::trace"
		# 	$req.root = path.resolve("#{__dirname}/../../../../debug")
		# 	$req.url = __url__data[1] or '/'
		# 	vhost.exec $req, $app
		# else
		# 	# if ($req.headers.host is 'localhost' || $req.headers.host is '127.0.0.1' || $req.headers.host is vhost.ip_address)
		# 	# 	if config.localhost?.DocumentRoot?
		# 	# 		$req.root = config[i].DocumentRoot.replace ///\/+$///, ''
		# 	# 		exec $req, $app
		# 	# else
		# 	if vhost.host_map[$req.headers.host]? and root = vhost.findSegment $req, $req.headers.host, $req.url
		# 		$req.root = vhost.host_map[$req.headers.host][root]
		# 		vhost.exec $req, $app
		# 	else if vhost.host_map_normal[$req.headers.host]?
		# 		$req.root = vhost.host_map_normal[$req.headers.host]
		# 		vhost.exec $req, $app
		# 	else
		# 		throw 404

	###
	# Private function and variables
	###

	@ip_address: ''
	@host_map_normal: {}
	@host_map: {}
	@encrypt: require __dirname + '/../../../../core/Encryption.js'

	@findSegment: ($req, host, url) ->
		url_tmp = url.replace(/// ^\/ | \/$ ///g, '')
		segments = url_tmp.split '/'
		url = ''
		for segment in segments
			url = url + '/' + segment
			if vhost.host_map[host][url]?
				$req.baseUrl = if url is '/' then '' else url
				$req.url = "/#{url_tmp.substr url.length}"
				return url
		return false

	@exec: ($req, $app) ->
		$req.socketIO = vhost.encrypt.md5 $req.root
		$app.use ($req, $res, $assets, $config, $url, $session, $bodyparser, $model) ->
			$res.__set = {}
			config = $config.all 'http'

			if config?.middleWare?
				$app.use config.middleWare
			else
				do $app.next
