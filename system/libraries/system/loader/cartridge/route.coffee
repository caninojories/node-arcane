package export cartridge.route

import system.Middleware
import system.tools.pathToRegexp

import harmony-proxy

import tools.wait
import util

class route extends Middleware

	@method_map: ['GET', 'HEAD', 'POST', 'TRACE', 'CONNECT', 'PATCH', 'DELETE', 'OPTIONS', 'PUT', 'MERGE']
	@url_tree: {}
	@req: null

	__init: ($vhost, $config) ->

		$config.event.on 'route', (config) ->
			route.url_tree[config[0]] = []
			init_routes config[0], config[1]
			do gc

		init_routes = (root, routes) ->
			for _route of routes
				method = ''
				method_url = _route.split ' '

				if route.method_map.indexOf(method_url[0]) isnt -1
					method = method_url[0]
					do method_url.shift
					url = method_url.join ' '
				else
					method = '*'
					url = _route.replace(/\/+$|\/$/g, '')

				re = pathToRegexp(url)
				tmp = {
					re: re
					option: routes[_route]
					method: method
				}

				route.url_tree[root].push tmp

		for vhost in $vhost
			if not route.url_tree[vhost]?
				route.url_tree[vhost] = []

			routes = $config[vhost]['route']
			init_routes vhost, routes



	__middle: ($url, $app, $config, $req, $res, $view, $controller) ->
		http = util._extend {}, $config.all 'http'
		skip_controller = []

		if typeof http?.routeMiddleWare isnt 'function'
			http.routeMiddleWare = ($req) ->
				return null

		# exec_middle = ->
		route.req = $req

		loader = null
		value = null

		if not route.url_tree[$req.root]
			throw 404

		for i, v of $controller when v['//controller-route~']?.source?
			skip_controller.push i
			for router in v['//controller-route~']?.source
				if router.method is $req.method or router.method is '*'
					if value = router.re.exec $req.url
						is_found = true
						loader = util._extend {}, router
						break

		unless is_found
			for router in route.url_tree[$req.root]
				if router.method is $req.method or router.method is '*'
					if value = router.re.exec $req.url
						is_found = true
						loader = util._extend {}, router
						break

		if loader?
			$res.set 'Content-Type', loader.option['content-type'] if loader.option?['content-type']?

			route.setQueryValue $req, value, loader.re.keys
			if loader.option.view? or loader.option.render? or typeof loader.option is 'string'

				if typeof loader.option is 'string'
					view_template = loader.option
				else if loader.option.view?
					view_template = loader.option.view
				else if loader.option.render?
					view_template = "#{$req.root}/views/#{loader.option.render}"
				if $res.__set.hasOwnProperty 'view'
					for i of $res.__set.view
						view_template = view_template.replace new RegExp('\\{\\{'+i+'\\}\\}', 'g'), $res.__set.view[i]

				$app.use http.routeMiddleWare, (err, result) ->
					throw err if err

					if loader.option.render?
						$view ['render', view_template, JSON.parse(JSON.stringify((loader.option.params ? {})))]
					else
						wait.for $view.display, view_template, JSON.parse(JSON.stringify((loader.option.params ? {})))

			else if loader.option.controller and loader.option.action
				if typeof $controller[loader.option.controller]?[loader.option.action] is 'function'
					$req.controllerName = loader.option.controller

					$app.use http.routeMiddleWare, (err, result) ->
						throw err if err

						$app.use $controller[loader.option.controller][loader.option.action], (err, result) ->
							throw err if err?
							if result?.constructor.name is 'Object'
								# $res.send $res.view.sync(null, $controller[loader.option.controller]['//view-path~'], result, true)
								result[n] ?= v for n, v of JSON.parse(JSON.stringify(loader.option.params ? {}))
								$view ['display', $controller[loader.option.controller]['//view-path~'], result]
		else
			segment = $req.url.replace(/\/+$|\/$/g, '').split '/'
			org_url = segment.slice 0

			do org_url.shift
			do org_url.shift

			if org_url.length is 0
				org_url = 'index'
			else
				org_url = org_url.join '/'

			if segment[1] not in skip_controller and typeof $controller[segment[1]]?[org_url] is 'function'
				$req.controllerName = segment[1]

				func = $controller[segment[1]][org_url]
				if func.index?
					func = func.index

				$app.use http.routeMiddleWare, (err, result) ->
					throw err if err

					$app.use func, (err, result) ->
						throw err if err?
						if result?.constructor.name is 'Object'
							# $res.send $res.view.sync(null, $controller[segment[1]]['//view-path~'], result, true)
							$view ['display', $controller[segment[1]]['//view-path~'], result]

		# if typeof http?.routeMiddleWare is 'function'
		# 	$app.use http?.routeMiddleWare, (err, result) ->
		# 		# console.log err.stack ? err if err
		# 		throw err if err
		# 		do exec_middle
		# else
		# 	do exec_middle







	@setQueryValue: ($req, value, keys) ->
		if value.length > 0
			$req.query = {} unless $req.query
			for val, i in value[1...]
				$req.query[keys[i].name] = val
