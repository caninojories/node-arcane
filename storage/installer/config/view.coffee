###---------------------------------------------------------------------------------------------
  Copyright 2015 - 2015 Arcane Project

###
package export Configuration

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
	@group: 'view'

	interpolate: {
		scriptStart: '{%'
		scriptEnd: '%}'
		varStart: '{{'
		varEnd: '}}'
	}
