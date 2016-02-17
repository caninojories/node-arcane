package export Core

import system.core.*

import system.tools.params
import system.loader.*
# import system.Sync

import fs
import path

import tools.wait
import tools.hound

class Core extends core.WObject

	@modules_list: {}
	@module_parameter: {}
	@loaded_modules: {}
	@modules: {}
	@nmodules: {}
	@log: console.log

	@find_updated_modules: (root, fname) ->
		result = []
		if global.import_tree["#{root}/#{fname}"]
			for v in global.import_tree["#{root}/#{fname}"]
				if /libraries/g.test v
					ret = Core.find_updated_modules root, v.replace "#{root}/", ''
					for x in ret
						if result.indexOf(x) is -1
							result.push x
				else
					fn = v.replace "#{root}/", ''
					if result.indexOf(fn) is -1
						result.push fn
		return result


	@init_modules: ->
		fsmonitor = require path.resolve "#{__dirname}/../../core/fsmonitor"
		is_watches = {}

		if process.env.worker_leader then for i of __arc_engine.vhost
			if not is_watches[__arc_engine.vhost[i].DocumentRoot]
				((index) ->
					monitor = fsmonitor.watch __arc_engine.vhost[index].DocumentRoot, {
						matches: (relpath) ->
							# if relpath.match /\.js$|\.coffee$/i
							# 	console.log __arc_engine.vhost[i].DocumentRoot, relpath

							relpath.match(/\.js$|\.coffee$/i) isnt null
						excludes: (relpath) ->
							relpath.match(/^\.git$|^assets|node_modules|^template$|^views$/i) isnt null
					}

					monitor.on 'error', (err) ->
						console.log err.stack ? err

					monitor.on 'change', (changes) ->
						# console.log __arc_engine.vhost[i].DocumentRoot, changes.modifiedFiles
						#

						# console.log changes

						if changes.modifiedFiles.length isnt 0
							Core.log 'Reloading Files: ', "\n\t#{changes.modifiedFiles.join '\n\t'}\n--"

						if changes.removedFiles.length isnt 0
							Core.log 'File Removed: ', "\n\t#{changes.removedFiles.join '\n\t'}\n--"

						if changes.addedFiles.length isnt 0
							Core.log 'Added Files: ', "\n\t#{changes.addedFiles.join '\n\t'}\n--"

						for j in changes.modifiedFiles
							# target_file = "#{__arc_engine.vhost[index].DocumentRoot}/#{j}"

							for k in Core.find_updated_modules __arc_engine.vhost[index].DocumentRoot, j
								changes.modifiedFiles.push k

							# if (global.import_tree[target_file]?.length ? 0) isnt 0
							# 	Core.log global.import_tree[target_file]

						for j in changes.removedFiles
							if global.import_tree and global.import_tree[j] and global.import_tree[j].length isnt 0
								Core.log "Warning for #{j} required: ", "\n\t#{global.import_tree[j].join '\n\t'}\n--"
								delete global.import_tree[j]

						# for j in data.data.addedFiles
						# 	for k in Core.find_updated_modules __arc_engine.vhost[index].DocumentRoot, j
						# 		changes.addedFiles.push k

						# console.log global.import_tree

						# console.log changes

						process.send name: 're-update', data: changes, root: __arc_engine.vhost[index].DocumentRoot

						# process.send 'reset-arce'
				)(i)
				is_watches[__arc_engine.vhost[i].DocumentRoot] = true

		# process.on 'message', (data) ->
		# 	if data is 'reset-arce' then do process.exit

		process.on 'message', (data) ->
			if typeof data is 'object' and data.name? and data.name is 're-update'
				######################################################################################################################################
				###  Files Modified ###

				try

					for j in data.data.modifiedFiles
						if /apps\/[a-zA-Z0-9]+?Controller\/index.coffee/g.test(j) and typeof Core.modules_list['controller']?.__onModified is 'function'
							result = /apps\/([a-zA-Z0-9]+?)Controller\/index.coffee/g.exec(j)
							Core.modules_list['controller'].__onModified data.root, result[1], j
						else if /config\/(.*).coffee/g.test(j) and typeof Core.modules_list['config']?.__onModified is 'function'
							result = /config\/(.*).coffee/g.exec(j)
							Core.modules_list['config'].__onModified data.root, result[1], j
						else if /template\/(.*).coffee/g.test(j) and typeof Core.modules_list['config']?.__onModified is 'function'
							result = /template\/(.*).coffee/g.exec(j)
							Core.modules_list['config'].__onModified data.root, result[1], j
						else if /socketio\/(.*).coffee/g.test(j) and typeof Core.modules_list['config']?.__onModified is 'function'
							result = /socketio\/(.*).coffee/g.exec(j)
							Core.modules_list['config'].__onModified data.root, result[1], j
						else if /apps\/([a-zA-Z0-9]+?)Controller\/models\/(.+?).coffee/g.test(j) and typeof Core.modules_list['model']?.__onModified is 'function'
							result = /apps\/([a-zA-Z0-9]+?)Controller\/models\/(.+?).coffee/g.exec j
							Core.modules_list['model'].__onModified data.root, result[2], j, (Core.loaded_modules['connector'] ? {}), (data.primary ? false)
						else if /models\/(.+?).coffee/g.test(j) and typeof Core.modules_list['model']?.__onModified is 'function'
							result = /models\/(.+?).coffee/g.exec j
							Core.modules_list['model'].__onModified data.root, result[1], j, (Core.loaded_modules['connector'] ? {}), (data.primary ? false)

					######################################################################################################################################
					###  Files Removed ###

					for j in data.data.removedFiles
						if /apps\/[a-zA-Z0-9]+?Controller\/index.coffee/g.test(j) and typeof Core.modules_list['controller']?.__onDeleted is 'function'
							result = /apps\/([a-zA-Z0-9]+?)Controller\/index.coffee/g.exec(j)
							Core.modules_list['controller'].__onDeleted data.root, result[1], j
						else if /config\/(.*).coffee/g.test(j) and typeof Core.modules_list['config']?.__onDeleted is 'function'
							result = /config\/(.*).coffee/g.exec(j)
							Core.modules_list['config'].__onDeleted data.root, result[1], j
						else if /template\/(.*).coffee/g.test(j) and typeof Core.modules_list['config']?.__onDeleted is 'function'
							result = /template\/(.*).coffee/g.exec(j)
							Core.modules_list['config'].__onDeleted data.root, result[1], j
						else if /socketio\/(.*).coffee/g.test(j) and typeof Core.modules_list['config']?.__onDeleted is 'function'
							result = /socketio\/(.*).coffee/g.exec(j)
							Core.modules_list['config'].__onDeleted data.root, result[1], j
						else if /apps\/([a-zA-Z0-9]+?)Controller\/models\/(.+?).coffee/g.test(j) and typeof Core.modules_list['model']?.__onDeleted is 'function'
							result = /apps\/([a-zA-Z0-9]+?)Controller\/models\/(.+?).coffee/g.exec j
							Core.modules_list['model'].__onDeleted data.root, result[2], j, (Core.loaded_modules['connector'] ? {}), (data.primary ? false)
						else if /models\/(.+?).coffee/g.test(j) and typeof Core.modules_list['model']?.__onDeleted is 'function'
							result = /models\/(.+?).coffee/g.exec j
							Core.modules_list['model'].__onDeleted data.root, result[1], j, (Core.loaded_modules['connector'] ? {}), (data.primary ? false)

					######################################################################################################################################
					###  Files Added ###

					for j in data.data.addedFiles
						if /apps\/[a-zA-Z0-9]+?Controller\/index.coffee/g.test(j) and typeof Core.modules_list['controller']?.__onCreated is 'function'
							result = /apps\/([a-zA-Z0-9]+?)Controller\/index.coffee/g.exec(j)
							Core.modules_list['controller'].__onCreated data.root, result[1], j
						else if /config\/(.*).coffee/g.test(j) and typeof Core.modules_list['config']?.__onCreated is 'function'
							result = /config\/(.*).coffee/g.exec(j)
							Core.modules_list['config'].__onCreated data.root, result[1], j
						else if /template\/(.*).coffee/g.test(j) and typeof Core.modules_list['config']?.__onCreated is 'function'
							result = /template\/(.*).coffee/g.exec(j)
							Core.modules_list['config'].__onCreated data.root, result[1], j
						else if /socketio\/(.*).coffee/g.test(j) and typeof Core.modules_list['config']?.__onCreated is 'function'
							result = /socketio\/(.*).coffee/g.exec(j)
							Core.modules_list['config'].__onCreated data.root, result[1], j
						else if /apps\/([a-zA-Z0-9]+?)Controller\/models\/(.+?).coffee/g.test(j) and typeof Core.modules_list['model']?.__onCreated is 'function'
							result = /apps\/([a-zA-Z0-9]+?)Controller\/models\/(.+?).coffee/g.exec j
							Core.modules_list['model'].__onCreated data.root, result[2], j, (Core.loaded_modules['connector'] ? {}), (data.primary ? false)
						else if /models\/(.+?).coffee/g.test(j) and typeof Core.modules_list['model']?.__onCreated is 'function'
							result = /models\/(.+?).coffee/g.exec j
							Core.modules_list['model'].__onCreated data.root, result[1], j, (Core.loaded_modules['connector'] ? {}), (data.primary ? false)

				catch
					console.log _error.stack ? String _error


				do gc

		Object.defineProperty console, 'log', {
			get: ->
				err = new Error()
				Error.captureStackTrace(err, arguments.callee)
				line = err.stack.split('\n')[1]

				match = /^\s+at\s([^\s]*)\s\(([^\)]*)\)$/g.exec line
				if match
					[filename, line, column] = match[2].split ':'
					prop = {
						function: match[1]
						filename: filename
						line: line
						column: column
					}
				else
					match = /^\s+at\s(.*)$/g.exec line
					[filename, line, column] = match[1].split ':'
					prop = {
						function: 'anonymous'
						filename: filename
						line: line
						column: column
					}

				return () ->
					args = Array.prototype.slice.call(arguments)
					args.unshift "<#{prop.function}> [#{prop.filename}]:#{prop.line}:#{prop.column}\n		"
					args.push "\n--"
					Core.log.apply console, args
		}

		for module, c_cart of loader.cartridge
			c_cartridge = Core.modules_list[module]
			unless c_cartridge
				Core.modules[module] = c_cart
				c_cartridge = new c_cart module
				c_cartridge.init module
				Core.modules_list[module] = c_cartridge
			else continue


	@load_modules: (modules, callback) ->
		# Core.synchro ->
		wait.launchFiber ->
			try
				result = []
				for module in modules
					module_name = module.replace ///^\$///g, ''

					if Core.loaded_modules.hasOwnProperty(module_name)
						result.push Core.loaded_modules[module_name]
						continue

					c_cartridge = Core.modules_list[module_name]

					if c_cartridge?.__init?
						parameters = params.get c_cartridge.__init
						param_result = wait.forMethod Core, 'load_modules', parameters

						# Core.synchro.sync null, ->
						Core.nmodules[module_name] = c_cartridge
						Core.loaded_modules[module_name] = c_cartridge.__init.apply c_cartridge, param_result
						result.push Core.loaded_modules[module_name]

					else
						result.push null

				callback null, result
			catch err
				callback err
		# 	return result
		# , (err, result) ->
		# 	if err then throw err
		# 	callback err, result
