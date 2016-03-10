###---------------------------------------------------------------------------------------------
  Copyright 2015 - 2015 Arcane Project

###
#!package export Configuration

###---------------------------------------------------------------------------------------------
# This class represents for http configuration.
#
# @author [author]
# @version [version]
###
class Configuration

	###
	# configuration name
	###
	@group: 'http'

	###
	# middleWare function

		middleWare: function($app, $req, $res) ->

			#set for next arcane module
	 		do $app.next

	###
