#!package Connect

#!import core.SocketIO

###---------------------------------------------------------------------------------------------###

# This class represents for socket connection.
#
# @author Juvic Martires
# @version 1.0.0
#
class Connect extends SocketIO

	# Default routing in socket connection.
	#
	# @param [Symbol] $req Request handler.
	# @param [SocketHandler] $socket Socket Handler.
	index: ($req, $socket) ->
