#!package export RouteConfig

#!import core.Configuration

###---------------------------------------------------------------------------------------------###

# This class represents for http configuration.
#
# @author Juvic Martires
# @version 1.0.0
#
# <h2>RESTFul API</h2>
#
# <dt><b><u>GET</u></b></dt>
# <dd>The GET method requests a representation of the specified resource.
# equests using GET should only retrieve data and should have no other effect.
# (This is also true of some other HTTP methods.) The W3C has published guidance principles on this distinction,
# saying, "Web application design should be informed by the above principles,
# but also by the relevant limitations.".</dd>
#
# <dt><b><u>HEAD</u></b></dt>
# <dd>The HEAD method asks for a response identical to that of a GET request,
# but without the response body. This is useful for retrieving meta-information written in response headers,
# without having to transport the entire content.</dd>
#
# <dt><b><u>POST</u></b></dt>
# <dd>The POST method requests that the server accept the entity enclosed in the request as a new subordinate of the web
# resource identified by the URI. The data POSTed might be, for example, an annotation for existing resources;
# a message for a bulletin board, newsgroup, mailing list, or comment thread; a block of data that is the result
# of submitting a web form to a data-handling process; or an item to add to a database.</dd>
#
# <dt><b><u>PUT</u></b></dt>
# <dd>The PUT method requests that the enclosed entity be stored under the supplied URI. If the URI refers to an already existing resource,
# it is modified; if the URI does not point to an existing resource, then the server can create the resource with that URI.</dd>
#
# <dt><b><u>DELETE</u></b></dt>
# <dd>The DELETE method deletes the specified resource.</dd>
#
# <dt><b><u>TRACE</u></b></dt>
# <dd>The TRACE method echoes the received request so that a client can see what (if any) changes or additions
# have been made by intermediate servers.</dd>
#
# <dt><b><u>OPTIONS</u></b></dt>
# <dd>The OPTIONS method returns the HTTP methods that the server supports for the specified URL. This can be used to check the
# functionality of a web server by requesting '*' instead of a specific resource.</dd>
#
# <dt><b><u>CONNECT</u></b></dt>
# <dd>The CONNECT method converts the request connection to a transparent TCP/IP tunnel, usually to facilitate SSL-encrypted communication
# (HTTPS) through an unencrypted HTTP proxy. See HTTP CONNECT tunneling.</dd>
#
# <dt><b><u>PATCH</u></b></dt>
# <dd>The PATCH method applies partial modifications to a resource.</dd>
#
# <hr />
#
# @example Route Settings
#   'GET /my-url': {
#     controller: 'mycontroller'
#     action: 'index'
#   }
class RouteConfig extends Configuration

	# Configuration group settings
	@group: 'route'

	# Load the default page file that located in view/default.html
	# in arcane project.
	'/': {
		view: 'default'
	}
