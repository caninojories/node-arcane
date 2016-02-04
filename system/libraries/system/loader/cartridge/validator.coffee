package export cartridge.validator

import system.Middleware
import tools.validator
import harmony-proxy
import util

class validator extends Middleware

	__init: ->

		validator.object = ($req) ->
			$_CHAIN = {
				rules: (patern) ->
					return this unless @value



					return this

				sanitizer: (patern) ->
					return this unless @value

					


					return this

			}

			$_DATA = {
				get: harmonyProxy {}, {
					get: (target, name) ->
						chain = util._extend {}, $_CHAIN
						chain.value = $req.query?[name] ? null
						return chain
				}
				post: harmonyProxy {}, {
					get: (target, name) ->					
						chain = util._extend {}, $_CHAIN
						chain.value = $req.body?[name] ? null
						return chain
				}
			}

			return harmonyProxy {}, {
				get: (target, name) ->
					
					switch name.toLowerCase()
						when 'get', 'post'
							return $_DATA[name]

				set: (target, name, value) ->
			}

	__middle: ($req, $res) ->
		
		return validator.object($req)


		# $validator.get.username.rules('contains[test]|equals[password]|').sanitizer('escape|md5')
		# $validator.post.username.rules('contains[test]|equals[password]|').sanitizer('escape|md5')