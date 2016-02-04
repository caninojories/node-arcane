###---------------------------------------------------------------------------------------------
	Copyright 2015 - 2015 Arcane Project
	
###
package export Configuration

###---------------------------------------------------------------------------------------------
# This class represents for connection configuration.
#
# @author [Juvic Martires]
# @version [v1.0.0] 
###
class Configuration

	###
	# configuration name
	###
	@group: 'form'

	Encryption = require('../lib/Encryption.js')
	sizeOf = require('../lib/image-size')

	valid_credit_card = (value) ->
		# accept only digits, dashes or spaces
		if /[^0-9-\s]+/.test(value)
			return false
		# The Luhn Algorithm. It's so pretty.
		nCheck = 0
		nDigit = 0
		bEven = false
		value = value.replace(/\D/g, '')
		n = value.length - 1
		while n >= 0
			cDigit = value.charAt(n)
			nDigit = parseInt(cDigit, 10)
			if bEven
				if (nDigit *= 2) > 9
					nDigit -= 9
			nCheck += nDigit
			bEven = !bEven
			n--
		nCheck % 10 == 0

	md5: (value, label, param, resolve) ->
		resolve null, Encryption.md5(value)
		return

	email: (value, label, param, resolve) ->
		if !value.match(/^(.*)\@(.*)\.[A-Za-z]{2,3}/g)
			resolve 'Invalid Email Address.'
		else
			resolve null, true
		return

	trim: (value, label, param, resolve) ->
		if typeof value != 'object'
			resolve null, String(value).trim()
		else
			resolve null, true
		return

	required: (value, label, param, resolve) ->
		if value.length != 0
			resolve null, true
		else
			resolve label + ' is required.'
		return

	password: (value, label, param, resolve) ->
		if @values.hasOwnProperty(param) and @values[param] == value
			resolve null, true
		else
			resolve 'Password not match.'
		return

	captcha: (value, label, param, resolve) ->
		if typeof @req.session[param] != 'undefined'
			if @req.session[param] == value
				resolve null, true
			else
				resolve 'Invalid security code.'
		else
			resolve 'Invalid security code.'
		return

	number: (value, label, param, resolve) ->
		resolve null, Number(value)
		return

	image: (value, label, param, resolve) ->
		valid_types = []
		if typeof @req.files[@name] != 'undefined'
			if valid_types.length == 0 and value.type.match(/^image\//g)
				resolve null, true
			else
				resolve label + ' is not a valid image.'
		else
			resolve 'Invalid form validation of \'' + label + '\''
		return

	max_img_size: (value, label, param, resolve) ->
		if typeof @req.files[@name] != 'undefined'
			if value.type.match(/^image\//g)
				max_size = param.split('x')
				dimensions = sizeOf(@req.files[@name].path)
				if max_size[0] > dimensions.width and max_size[1] > dimensions.height
					resolve null,
						path: @req.files[@name].path
						type: @req.files[@name].type
				else
					resolve label + ' size is not a valid.'
				resolve null, true
			else
				resolve null,
					path: null
					type: null
		else
			resolve null, true
		return

	phone: (value, label, param, resolve) ->
		if value.length != 0
			phone = /^(?:(?:\(?(?:00|\+)([1-4]\d\d|[1-9]\d?)\)?)?[\-\.\ \\\/]?)?((?:\(?\d{1,}\)?[\-\.\ \\\/]?){0,})(?:[\-\.\ \\\/]?(?:#|ext\.?|extension|x)[\-\.\ \\\/]?(\d+))?$/i
			if phone.exec(value)
				resolve null, true
			else
				resolve label + ' is invalid phone number.'
		else
			resolve label + ' is required.'
		return

	alpha: (value, label, param, resolve) ->
		if !/^[a-zA-Z]$/g.test value
			resolve "Invalid value of #{label}."
		else
			resolve null, true
		return

	alphadashed: (value, label, param, resolve) ->
		if !/^[a-zA-Z\-]$/g.test value
			resolve "Invalid value of #{label}."
		else
			resolve null, true
		return

	alphanumeric: (value, label, param, resolve) ->
		if !/^[a-zA-Z0-9]$/g.test value
			resolve "Invalid value of #{label}."
		else
			resolve null, true
		return

	alphanumericdashed: (value, label, param, resolve) ->
		if !/^[a-zA-Z0-9\-]$/g.test value
			resolve "Invalid value of #{label}."
		else
			resolve null, true
		return

	creditcard: (value, label, param, resolve) ->
		if !valid_credit_card value
			resolve "Invalid creaditcard value of #{label}."
		else
			resolve null, true
		return

	date: (value, label, param, resolve) ->
		if new Date(date) isnt "Invalid Date" and not isNaN(new Date(date))
			resolve null, new Date(date)
		else 
			resolve "#{label} is not a valid date."
		return

	json: (value, label, param, resolve) ->
		try 
			resolve null, JSON.parse value
		catch err
			resolve "#{label} is not a valid JSON."
		return