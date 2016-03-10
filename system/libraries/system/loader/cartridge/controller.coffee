#!package export cartridge.controller

#!import system.Middleware

#!import fs
#!import path

#!import system.tools.pathToRegexp

class controller extends Middleware

	__init: ($vhost) ->
		for vhost in $vhost

			if not controller.list[vhost]?
				controller.list[vhost] = {}
			else
				continue

			ctrler_dir = "#{vhost}/apps"
			if fs.existsSync ctrler_dir
				ctrlers = fs.readdirSync ctrler_dir
				for ctrler in ctrlers
					ctrler_file = "#{ctrler_dir}/#{ctrler}/index"
					controller_name = /^(.+?)Controller$/g.exec ctrler
					if controller_name? and fs.existsSync "#{ctrler_file}.coffee"
						controller.list[vhost][do controller_name[1].toLowerCase] = __require "#{ctrler_file}.coffee"
						controller.list[vhost][do controller_name[1].toLowerCase]['//view-path~'] = "#{ctrler_dir}/#{ctrler}/view.html"
						controller.list[vhost][do controller_name[1].toLowerCase]['//form-path~'] = "#{ctrler_dir}/#{ctrler}/form.coffee"
						tmp = controller.list[vhost][do controller_name[1].toLowerCase]['//controller-route~']
						if tmp?.source?
							for i in tmp.source
								i.option.controller = do controller_name[1].toLowerCase
								i.re = pathToRegexp(i.re.replace(/\[\[\{controller\}\]\]/g, do controller_name[1].toLowerCase))
							controller.list[vhost][do controller_name[1].toLowerCase]['//controller-route~'] = tmp
						# for i, v of tmp when v
						# 	v.controller = do controller_name[1].toLowerCase
						# 	if /\[\[\{controller\}\]\]/g.test(i)
						# 		tmp[i.replace(/\[\[\{controller\}\]\]/g, do controller_name[1].toLowerCase)] = v
						# 		delete tmp[i]
					else if controller_name? and fs.existsSync "#{ctrler_file}.js"
						controller.list[vhost][do controller_name[1].toLowerCase] = __require "#{ctrler_file}.js"
						controller.list[vhost][do controller_name[1].toLowerCase]['//view-path~'] = "#{ctrler_dir}/#{ctrler}/view.html"
						controller.list[vhost][do controller_name[1].toLowerCase]['//form-path~'] = "#{ctrler_dir}/#{ctrler}/form.js"

		return controller.list

	__middle: ($req, $res) ->
		return controller.list[$req.root]

	__onModified: (root, name, filename) ->
		@__onCreated root, name, filename

	__onCreated: (root, name, filename) ->
		controller.list[root][do name.toLowerCase] = __require "#{root}/#{filename}"
		controller.list[root][do name.toLowerCase]['//view-path~'] = "#{root}/#{path.dirname(filename)}/view.html"
		controller.list[root][do name.toLowerCase]['//form-path~'] = "#{root}/#{path.dirname(filename)}/form.coffee"
		tmp = controller.list[root][do name.toLowerCase]['//controller-route~']
		if tmp?.source?
			for i in tmp.source
				i.option.controller = do name.toLowerCase
				i.re = pathToRegexp(i.re.replace(/\[\[\{controller\}\]\]/g, do name.toLowerCase))
			controller.list[root][do name.toLowerCase]['//controller-route~'] = tmp
		# for i, v of tmp when v
		# 	v.controller = do name.toLowerCase
		# 	if /\[\[\{controller\}\]\]/g.test(i)
		# 		tmp[i.replace(/\[\[\{controller\}\]\]/g, do name.toLowerCase)] = v
		# 		delete tmp[i]
	__onDeleted: (root, name, filename) ->
		delete controller.list[root][do name.toLowerCase]

	@list: {}
