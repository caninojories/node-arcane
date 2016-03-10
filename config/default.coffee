#!package export DefaultConfig

#!import core.Configuration

###---------------------------------------------------------------------------------------------###

# This class represents for default configuration.
#
# @author	Juvic Martires
# @version	1.0.0
#
class DefaultConfig extends Configuration

	# Configuration group settings
	@group: 'default'

	port: 80
	https: false
