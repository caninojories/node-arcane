package export cartridge.controller

import system.Middleware

import fs
import path

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

	__onDeleted: (root, name, filename) ->
		delete controller.list[root][do name.toLowerCase]

	@list: {}
		
