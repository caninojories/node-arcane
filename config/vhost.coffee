###---------------------------------------------------------------------------------------------
	Copyright 2015 - 2015 Arcane Project

###
#!package export Configuration

###---------------------------------------------------------------------------------------------
# This class represents for connection configuration.
#
# @author [Juvic Martires]
# @version [v1.0.0]
###
class Configuration

	###
	# configuration name
	###
	@group: 'vhost'

	localhost: {
		DocumentRoot: "#{__dirname}/../system/extra"
	}
