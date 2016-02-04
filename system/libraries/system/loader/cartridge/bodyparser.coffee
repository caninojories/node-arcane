package export cartridge.bodyparser

import system.Middleware

import querystring
import fs
import path

class bodyparser extends Middleware

	@form: null

	@formidable: require(path.resolve "#{__dirname}/../../../../core/Formidable").IncomingForm

	__init: () ->
		bodyparser.form = new bodyparser.formidable

	__middle: ($req, $wait) ->
		if $req.method.toLowerCase() == 'post'
			
			# form_parse = bodyparser.form.parse.sync bodyparser.form, $req
			form_parse = $wait.forMethod bodyparser.form, 'parse', $req
			$req.files = form_parse[1]
			$req.body = form_parse[0]

			return form_parse[0]
		else
			return {}