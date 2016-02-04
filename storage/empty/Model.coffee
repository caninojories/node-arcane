###---------------------------------------------------------------------------------------------
  Copyright 2015 - 2015 Arcane Project
  
###
package export Model

###---------------------------------------------------------------------------------------------
# This class represents for model design. 
#
# @author [author]
# @version [version] 
###
class Model

	@connection: '{{connection-name}}'

	###
	# 'alter' for database fields update and creating database and fields.
	# 'safe' to protect the table fields.
	#
	# @migrate Can be 'safe' or 'alter'
	###
	@migrate: 'safe'

	###
	# Can set the size and fields arrangements.
	#
	# @attributes set the fields of the database.
	###
	@attributes: {

	}