###---------------------------------------------------------------------------------------------
  Copyright 2015 - 2015 Arcane Project
  
###
package export Configuration

###---------------------------------------------------------------------------------------------
# This class represents for connection configuration.
#
# @author [author]
# @version [version] 
###
class Configuration

	###
	# configuration name
	###
	@group: 'connector'

	###
	# Create connection properties.
	# 
	# MySQL Format -
	#
	#  myDatabase: {
	#     adapter: 'mysql'
	#	  host: 'localhost'
	#	  user: 'root'
	#	  password: 'password'
	#	  database: 'sails'
	#  }
	#
	# SQLite Format -
	# 
	#  mySQLite: {
	#     adapter: 'sqlite'
	#	  file: 'myDatabase.sqlite3'
	#  }
	#
	###

	default: {
		adapter: 'sqlite'
		file: 'Database.sqlite3'
	}
