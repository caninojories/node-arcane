#!package export ConnectorConfig

#!import core.Configuration

###---------------------------------------------------------------------------------------------###


# This class represents for connection configuration.
#
# @author	Juvic Martires
# @version	1.0.0
#
# @example MySQL Format
#   myConnectionMysql:
#     adapter: 	'mysql'
#     host:		'localhost'
#     user:		'root'
#     password:	'password'
#     database:	'my_database'
#
# @example SQLite Format
#   myConnectionSQLite:
#     adapter:	'sqlite'
#     file:		'myDatabase.sqlite3'
#
class ConnectorConfig extends Configuration

	# Configuration group settings
	@group: 'connector'

	session: {
		adapter: 'sqlite'
		file: ':memory:'
	}

	globals: {
		adapter: 'sqlite'
		file: "#{__dirname}/../storage/.Globals.sqlite3"
	}
