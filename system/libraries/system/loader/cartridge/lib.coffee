#!package export cartridge.lib

#!import system.Middleware
#!import fs

class lib extends Middleware

	__init: () ->

	__middle: ($req, $res) ->
		lib = (lib) ->
			filename = "#{$req.root}/libraries/#{lib}.js"
			if fs.existsSync filename
				return __require filename
			else
				throw new Error "ERROR: Library not found \'#{filename}\'"
			return

		return lib
