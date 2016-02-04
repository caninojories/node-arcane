module.exports.connector = {

	'session': {
		adapter: 'sqlite',
		file: __dirname + '/../storage/.Session.sqlite3'
	},

	'globals': {
		adapter: 'sqlite',
		file: __dirname + '/../storage/.Globals.sqlite3'
	}

};