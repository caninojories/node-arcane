#!package export Configuration

#!import core.Configuration

###---------------------------------------------------------------------------------------------###

# This class represents for http configuration.
#
# @author Juvic Martires
# @version 1.0.0
#
class ViewConfig extends Configuration

	# Configuration group settings
	@group: 'view'

	# Enable to change the interpolate symbols in html files under views.
	# @property [Object] interpolate
	interpolate: {
		scriptStart: '{%'
		scriptEnd: '%}'
		varStart: '{{'
		varEnd: '}}'
	}
