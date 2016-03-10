#!package export cartridge.validator

#!import system.Middleware
#!import tools.validator
#!import harmony-proxy
#!import util

v = validator

class validator extends Middleware

	@v_map:
		contains: 			['contains', '']
		equals: 			['equals', "Field '{{name}}' not meet the expected value."]
		after: 				['isAfter', '']
		alpha: 				['isAlpha', "Field '{{name}}' is not a valid alpha."]
		alphanumeric: 		['isAlphanumeric', "Field '{{name}}' is not a valid alphanumeric."]
		ascii: 				['isAscii', "Field '{{name}}' is not a valid ascii."]
		base64: 			['isBase64', "Field '{{name}}' is not a valid Base64."]
		before: 			['isBefore', '']
		boolean: 			['isBoolean', "Field '{{name}}' is not a valid Boolean."]
		'byte-length': 		['isByteLength', '']
		'credit-card': 		['isCreditCard', "Field '{{name}}' is not a valid credit card."]
		currency: 			['isCurrency', "Field '{{name}}' is not a valid currency."]
		date: 				['isDate', "Field '{{name}}' is not a valid date."]
		decimal: 			['isDecimal', "Field '{{name}}' is not a valid decimal."]
		'divisible-by': 	['isDivisibleBy', '']
		email: 				['isEmail', "Field '{{name}}' is not a valid email address."]
		fqdn: 				['isFQDN', '']
		float: 				['isFloat', "Field '{{name}}' is not a valid float."]
		'full-width': 		['isFullWidth', '']
		'half-width': 		['isHalfWidth', '']
		'hex-color': 		['isHexColor', "Field '{{name}}' is not a valid HEX Color."]
		hexadecimal: 		['isHexadecimal', "Field '{{name}}' is not a valid Hexadecimal."]
		ip: 				['isIP', "Field '{{name}}' is not a valid IP."]
		isbn: 				['isISBN', "Field '{{name}}' is not a valid ISBN."]
		isin: 				['isISIN', "Field '{{name}}' is not a valid ISIN."]
		iso8601: 			['isISO8601', "Field '{{name}}' is not a valid ISO8601."]
		in: 				['isIn', '']
		int: 				['isInt', "Field '{{name}}' is not a valid Integer."]
		json: 				['isJSON', "Field '{{name}}' is not a valid JSON."]
		length: 			['isLength', '']
		lowercase: 			['isLowercase', "Field '{{name}}' is not a valid date."]
		mac: 				['isMACAddress', "Field '{{name}}' is not a valid MAC Address."]
		mobile: 			['isMobilePhone', "Field '{{name}}' is not a valid mobile."]
		'mongo-id': 		['isMongoId', "Field '{{name}}' is not a valid Mongo BD ID."]
		multibyte: 			['isMultibyte', '']
		null: 				['isNull', "Field '{{name}}' is null."]
		numeric: 			['isNumeric', "Field '{{name}}' is not a valid numeric."]
		'surrogate-pair':	['isSurrogatePair', '']
		url: 				['isURL', "Field '{{name}}' is not a valid URL."]
		uuid: 				['isUUID', "Field '{{name}}' is not a valid UUID."]
		uppercase: 			['isUppercase', '']
		'variable-width': 	['isVariableWidth', '']
		whitelisted: 		['isWhitelisted', '']
		matches: 			['matches', '']

	@s_map:
		blacklist: 			'blacklist'
		escape: 			'escape'
		ltrim: 				'ltrim'
		'normalize-email': 	'normalizeEmail'
		rtrim: 				'rtrim'
		'strip-low': 		'stripLow'
		boolean: 			'toBoolean'
		date: 				'toDate'
		float: 				'toFloat'
		int: 				'toInt'
		string: 			'toString'
		trim: 				'trim'
		whitelist: 			'whitelist'

	__init: ->

		validator.v_map['require'] = ['isRequire', "Field '{{name}}' is required."]
		v.extend 'isRequire', (str) ->
			return str and String(str).length isnt 0

		r_func = ($_STORE, name, value) ->
			$_STORE.value[name] = value
			(pattern, option) ->
				# return null unless value

				for i in pattern.split '|'
					validator_detected = false

					if validator.v_map[i] and v[validator.v_map[i][0]]
						validator_detected = true

						args = option?[i] ? []
						args.unshift $_STORE.value[name]

						if not v[validator.v_map[i][0]].apply v, args
							$_STORE.error[name] = validator.v_map[i][1].replace /\{\{name\}\}/g, name
							break

					if validator.s_map[i] and v[validator.s_map[i]]

						args = option?[i] ? []
						args.unshift $_STORE.value[name]

						$_STORE.value[name] = v[validator.s_map[i]].apply v, args
					else
						if validator_detected
							$_STORE.value[name] = $_STORE.value[name]
						else
							throw new Error("Invalid validation name '#{i}'.")


		validator.object = ($req) ->
			$_STORE = {
				error: {}
				value: {}
			}

			$_DATA = {
				get: harmonyProxy {}, {
					get: (target, name) ->
						r_func($_STORE, name, $req.query?[name] ? null)

				}
				post: harmonyProxy {}, {
					get: (target, name) ->
						r_func($_STORE, name, $req.body?[name] ? null)

				}
			}

			return harmonyProxy (->), {
				get: (target, name) ->

					switch name.toLowerCase()
						when 'get', 'post'
							return $_DATA[name.toLowerCase()]
						when 'error'
							return $_STORE.error
						when 'result'
							return $_STORE.value

				set: (target, name, value) ->

				apply: (target, thisArg, argumentsList) ->
					Object.keys($_STORE.error).length is 0
			}

	__middle: ($req, $res) ->

		return validator.object($req)


		# $validator.get.username.rules('contains[test]|equals[password]|').sanitizer('escape|md5')
		# $validator.post.username.rules('contains[test]|equals[password]|').sanitizer('escape|md5')
