#!package Disconnect

#!import core.SocketIO

###---------------------------------------------------------------------------------------------###

# This class represents for disconnection socket.
#
# @author Juvic Martires
# @version 1.0.0
#
class Disconnect extends SocketIO

	# Default routing in socket connection.
	#
	# @param [Symbol] $req Request handler.
	# @param [SocketHandler] $socket Socket Handler.
	index: ($req, $socket) ->
