package export cartridge.config

import system.Middleware

import fs
import path
import harmony-proxy
import events

class config extends Middleware

	@file_lists: {}
	@events: new events.EventEmitter

	__init: ($vhost) ->
		for DocumentRoot in $vhost

			if fs.existsSync "#{DocumentRoot}/config"
				config.loadConfigFile DocumentRoot, "#{__dirname}/../../../../../config"
				config.loadConfigFile DocumentRoot, "#{DocumentRoot}/config"
					
			if fs.existsSync "#{DocumentRoot}/template"
				template_list = fs.readdirSync "#{DocumentRoot}/template"
				for templ in template_list
					config.set DocumentRoot, 'template', templ.replace(///\.html$///g, ''),  fs.readFileSync "#{DocumentRoot}/template/#{templ}", 'utf8'

			if fs.existsSync "#{DocumentRoot}/socketio"
				socket_list = fs.readdirSync "#{DocumentRoot}/socketio"
				for sock in socket_list
					config.set DocumentRoot, 'socket', sock.replace(///\.coffee$///g, ''),  __require "#{DocumentRoot}/socketio/#{sock}"

		# return config.data
		return harmonyProxy {}, {
			get: (target, name) ->
				
				if name is 'event'
					return config.events
				else if config.data[name]?
					return config.data[name]

			set: (target, name, value) ->

		}


	__middle: ($req, $res) ->
		return {
			set: (group, name, value) ->
				if config.data[$req.root]?
					config.set $req.root, group, name, value

			get: (group, name) ->
				if config.data[$req.root]?
					config.get $req.root, group, name

			all: (group) ->
				if config.data[$req.root]?
					config.all $req.root, group
		}

	__onModified: (root, name, filename) ->
		@__onCreated root, name, filename

	__onCreated: (root, name, filename) ->
		if fs.existsSync "#{root}/config"
			config.data[root] = {}
			config.loadConfigFile.call @, root, "#{__dirname}/../../../../../config"
			config.loadConfigFile.call @, root, "#{root}/config"

		if fs.existsSync "#{root}/template"
				template_list = fs.readdirSync "#{root}/template"
				for templ in template_list
					config.set root, 'template', templ.replace(///\.html$///g, ''),  fs.readFileSync "#{root}/template/#{templ}", 'utf8'

		if fs.existsSync "#{root}/socketio"
			socket_list = fs.readdirSync "#{root}/socketio"
			for sock in socket_list
				config.set root, 'socket', sock.replace(///\.coffee$///g, ''),  __require "#{root}/socketio/#{sock}"

	__onDeleted: (root, name, filename) ->
		@__onCreated root, name, filename
		
	###
	# Private function and variables
	###

	@data: {}

	@loadConfigFile: (DocumentRoot, url) ->
		for confl in fs.readdirSync url
			tmp = __require "#{url}/#{confl}"
			if ///.coffee$///g.test confl
				if tmp.name? and typeof tmp.name is 'string' and tmp.name is 'Configuration'
					n_class = new tmp
					for o of n_class
						config.set DocumentRoot, tmp.group, o, n_class[o]
					if @constructor.name is 'config'
						config.events.emit tmp.group, [DocumentRoot, config.data[DocumentRoot][tmp.group]]
			else if ///.js$///g.test confl
				if typeof tmp is 'object'
					for v of tmp
						for o of tmp[v]
							config.set DocumentRoot, v, o, tmp[v][o]
						config.events.emit v, [DocumentRoot, config.data[DocumentRoot][v]] if @constructor.name is 'config'

	@set: (root, group, name, value) ->

		if not config.data[root]?
			config.data[root] = {}

		if not config.data[root][group]?
			config.data[root][group] = {}

		if group is 'route'
			name = name.replace ///\s+///g, ' '
			name = name.replace ///^([a-zA-Z]+?)\s///, ($1) ->
				return $1.toUpperCase()

		config.data[root][group][name] = value

	@get: (root, group, name) ->
		if config.data[root]?[group]?[name]
			return config.data[root][group][name]
		return null

	@all: (root, group) ->
		if config.data[root]?[group]
			return config.data[root][group]
		return null

	@addEvent: (root, target) ->

