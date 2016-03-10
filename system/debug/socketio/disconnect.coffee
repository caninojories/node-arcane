###---------------------------------------------------------------------------------------------
  Copyright 2015 - 2015 Arcane Project

###
#!package SocketIODisconnect

###---------------------------------------------------------------------------------------------
# This class represents for connection configuration.
#
# @author [author]
# @version [version]
###
class SocketIODisconnect

	###
	 # Default routing
	 #
	 # @param modules for socketio
	 ###
	index: ($req, $socket) ->
		do $socket.stream_trace.close
