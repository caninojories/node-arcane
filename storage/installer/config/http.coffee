#!package export HttpConfig

#!import core.Configuration

###---------------------------------------------------------------------------------------------###

# This class represents for http configuration.
#
# @author Juvic Martires
# @version 1.0.0
#
# @method #routeMiddleWare($req, $res)
#   Routing Middleware.
#   @param [Object] $req describe $req param
#   @param [Object] $res describe $res param
#
# @method #sessionMiddleWare($req, $res)
#   Session Middleware you can organize the session storage.
#   @param [Object] $req describe $req param
#   @param [Object] $res describe $res param
#   @example Session Middleware
#     sessionMiddleWare: ($req, $res, $model) ->
#       try
#         ses = __model.session_token_yqc.objects.get(session_key: $req.sessionID)
#       catch
#         ses = null
#       {
#         data: JSON.parse(ses?.session_value ? '{}')
#         save: (data) ->
#           [updated_data, iscreated] = __model.session_token_yqc.objects.update_or_create(session_value: data, defaults: { session_key: $req.sessionID })
#       }
#
class HttpConfig extends Configuration

	# Configuration group settings
	@group: 'http'

	# @method #set(var1, var2)
	#   Testing
	#   @param [Symbol] key describe key param
	#   @param [Object] value describe value param
	#
