###---------------------------------------------------------------------------------------------
  Copyright 2015 - 2015 Arcane Project

###
#!package SocketIOConnect

#!import fs

###---------------------------------------------------------------------------------------------
# This class represents for connection configuration.
#
# @author [author]
# @version [version]
###
class SocketIOConnect

	###
	 # Default routing
	 #
	 # @param modules for socketio
	 ###
	index: ($req, $socket) ->
		# var n2c = fs.createReadStream(arc_system_location + '/logs', {flags : 'r+'});
		# n2c.on('data', function(chunk){

		$socket.stream_trace = fs.createReadStream "/var/arcane/logs", {flags : 'r+'}
		$socket.stream_trace.on 'data', (chuck) ->
			$socket.trigger 'trace', chuck.toString 'utf-8'
