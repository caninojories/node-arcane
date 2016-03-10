#!package export RouteConfig

#!import core.Configuration

###---------------------------------------------------------------------------------------------###

# This class represents for http configuration.
#
# @author Juvic Martires
# @version 1.0.0
#
class RouteConfig extends Configuration

	# Configuration group settings
	@group: 'route'

	500: "#{__dirname}/../system/extra/views/500.html"
	404: "#{__dirname}/../system/extra/views/404.html"
