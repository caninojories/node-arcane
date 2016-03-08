package export cartridge.view

import system.Middleware
# import system.Sync

import fs
import path
import harmony-proxy

import tools.wait

class view extends Middleware

	@render: require "#{__dirname}/../../../../core/Template.js"
	@template_404: ''
	@template_500: ''

	__init: () ->

		Object.defineProperty global, 'Render', get: ->
			target_file = "#{require('path').dirname(__stack[1].getFileName())}/"
			(data, opt) ->
				target_file = if arguments.length isnt 2 then "#{target_file}view.html" else "#{target_file}#{data}.html"
				opt = data if arguments.length isnt 2
				return ['render', target_file, opt]

		Object.defineProperty global, 'Display', get: ->
			target_file = "#{require('path').dirname(__stack[1].getFileName())}/"
			(data, opt) ->
				target_file = if arguments.length isnt 2 then "#{target_file}view.html" else "#{target_file}#{data}.html"
				opt = data if arguments.length isnt 2
				return ['display', target_file, opt]


	__middle: ($config, $res, $req, $lib) ->
		interpolate_default = {
			scriptStart: '{%'
			scriptEnd: '%}'
			varStart: '{{'
			varEnd: '}}'
		}

		obj = {
			display: view.display $res, {req: $req, res: $res, lib: $lib, body: '', helper: $config.all('helper')}, $config.all('view')?.interpolate ? interpolate_default
			render: view.rend $res, {req: $req, res: $res, lib: $lib, body: '', helper: $config.all('helper')}, $config.all('view')?.interpolate ? interpolate_default
			load: view.load $res, {req: $req, res: $res, lib: $lib, body: '', helper: $config.all('helper')}, $config.all('view')?.interpolate ? interpolate_default
		}

		return view.view_handler $res, obj, $config.all('view')?.interpolate ? interpolate_default

	@display: ($res, context, interpolate) ->
		return (args...) ->
			cntr = args.length - 1
			file = 'default'
			code = 200
			data = context
			exact = false

			callback = (err) ->
				throw new Error err if err

			if args[cntr] and args[cntr].constructor.name is 'Function'
				callback = args[cntr]
				cntr--

			if args[cntr] and args[cntr].constructor.name is 'Boolean'
				exact = args[cntr]
				cntr--

			if args[cntr] and args[cntr].constructor.name is 'Object'
				for i of args[cntr]
					data[i] = args[cntr][i]
				cntr--

			if args[cntr] and args[cntr].constructor.name is 'String'
				file = args[cntr]
				cntr--

			if args[cntr] and args[cntr].constructor.name is 'Number'
				code = args[cntr]
				cntr--

			view.load($res, context, interpolate) file, data, exact, (err, result) ->
				if err
					throw new Error err if err
					return
				data.body = result
				if exact and file is 'default'
					throw [404, data]
				else if typeof data.body is 'string'
					view.load($res, context, interpolate) 'template', data, false, (_err, _result) ->
						throw new Error _err if _err
						data.res.statusCode = code
						data.res.send _result
						callback null, true
						return
				else
					callback null, false
				return
			return

	@load: ($res, context, interpolate) ->
		return (file, data, exact_file, callback) ->

			for i of context
				data[i] = context[i]

			data.ArcSocketIO_js = "<script type=\"text/javascript\" src=\"#{data.req.baseUrl}/socket.io\"></script>"

			filename = if exact_file then file else "#{data.req.root}/views/#{file}.html"
			if (fs.existsSync(filename) and fs.lstatSync(filename).isFile()) or (exact_file and file is 'default')

				if not data.req.form_error?
					data.req.form_error = ->
						return ''

				if not callback?
					callback = (err) ->
						if err then err

				if exact_file and file is 'default'
					throw [404, data]

				html = wait.for view.render, filename, data, interpolate

				callback null, html
			else
				console.log "#{filename} >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
				throw new Error "ERROR: File '#{filename}' not found."


	@rend: ($res, context, interpolate) ->
		return (filename, d, ex) ->
			throw [400, {}] if not filename? or not fs.existsSync filename

			data = d or {}
			exact = ex or false
			result = wait.for view.load($res, context, interpolate), filename, data, exact
			context.res.statusCode = data.__status ? 200
			context.res.send result


	@view_handler: ($res, obj, context, interpolate)->
		return harmonyProxy (->
		), {
			get: (proxy, name) ->
				return obj[name] if obj[name]?
				return null
			set: (proxy, name, value) ->

			apply: (target, thisArg, argumentsList) ->
				if argumentsList[0].length is 3
					if argumentsList[0][0] is 'render'
						$res.send wait.for obj.load, argumentsList[0][1], argumentsList[0][2], true
					else if argumentsList[0][0] is 'display'
						wait.for obj.display, argumentsList[0][1], argumentsList[0][2], true
					else
						throw new Error('Invalid View Module type.')
				else
					throw new Error('Invalid View Module parameters.')
		}
