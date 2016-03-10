#!package export pathToRegexp

parse = (str) ->
	tokens = []
	key = 0
	index = 0
	path = ""
	res = undefined
	while (res = PATH_REGEXP.exec(str))?
		m = res[0]
		escaped = res[1]
		offset = res.index
		path += str.slice(index, offset)
		index = offset + m.length

		# Ignore already escaped sequences.
		if escaped
			path += escaped[1]
			continue

		# Push the current path onto the tokens.
		if path
			tokens.push path
			path = ""
		prefix = res[2]
		name = res[3]
		capture = res[4]
		group = res[5]
		suffix = res[6]
		asterisk = res[7]
		repeat = suffix is "+" or suffix is "*"
		optional = suffix is "?" or suffix is "*"
		delimiter = prefix or "/"
		pattern = capture or group or ((if asterisk then ".*" else "[^" + delimiter + "]+?"))
		tokens.push
			name: name or key++
			prefix: prefix or ""
			delimiter: delimiter
			optional: optional
			repeat: repeat
			pattern: escapeGroup(pattern)


	# Match any characters still remaining.
	path += str.substr(index)	if index < str.length

	# If the path exists, push it onto the end.
	tokens.push path	if path
	tokens


compile = (str) ->
	tokensToFunction parse(str)


tokensToFunction = (tokens) ->

	# Compile all the tokens into regexps.
	matches = new Array(tokens.length)

	# Compile all the patterns before compilation.
	i = 0

	while i < tokens.length
		matches[i] = new RegExp("^" + tokens[i].pattern + "$")	if typeof tokens[i] is "object"
		i++
	(obj) ->
		path = ""
		data = obj or {}
		i = 0

		while i < tokens.length
			token = tokens[i]
			if typeof token is "string"
				path += token
				continue
			value = data[token.name]
			segment = undefined
			unless value?
				if token.optional
					continue
				else
					throw new TypeError("Expected \"" + token.name + "\" to be defined")
			if isarray(value)
				throw new TypeError("Expected \"" + token.name + "\" to not repeat, but received \"" + value + "\"")	unless token.repeat
				if value.length is 0
					if token.optional
						continue
					else
						throw new TypeError("Expected \"" + token.name + "\" to not be empty")
				j = 0

				while j < value.length
					segment = encodeURIComponent(value[j])
					throw new TypeError("Expected all \"" + token.name + "\" to match \"" + token.pattern + "\", but received \"" + segment + "\"")	unless matches[i].test(segment)
					path += ((if j is 0 then token.prefix else token.delimiter)) + segment
					j++
				continue
			segment = encodeURIComponent(value)
			throw new TypeError("Expected \"" + token.name + "\" to match \"" + token.pattern + "\", but received \"" + segment + "\"")	unless matches[i].test(segment)
			path += token.prefix + segment
			i++
		path


escapeString = (str) ->
	str.replace /([.+*?=^!:${}()[\]|\/])/g, "\\$1"


escapeGroup = (group) ->
	group.replace /([=!:$\/()])/g, "\\$1"


attachKeys = (re, keys) ->
	re.keys = keys
	re


flags = (options) ->
	(if options.sensitive then "" else "i")


regexpToRegexp = (path, keys) ->

	# Use a negative lookahead to match only capturing groups.
	groups = path.source.match(/\((?!\?)/g)
	if groups
		i = 0

		while i < groups.length
			keys.push
				name: i
				prefix: null
				delimiter: null
				optional: false
				repeat: false
				pattern: null

			i++
	attachKeys path, keys


arrayToRegexp = (path, keys, options) ->
	parts = []
	i = 0

	while i < path.length
		parts.push pathToRegexp(path[i], keys, options).source
		i++
	regexp = new RegExp("(?:" + parts.join("|") + ")", flags(options))
	attachKeys regexp, keys


stringToRegexp = (path, keys, options) ->
	tokens = parse(path)
	re = tokensToRegExp(tokens, options)

	# Attach keys back to the regexp.
	i = 0

	while i < tokens.length
		keys.push tokens[i]	if typeof tokens[i] isnt "string"
		i++
	attachKeys re, keys


tokensToRegExp = (tokens, options) ->
	options = options or {}
	strict = options.strict
	end = options.end isnt false
	route = ""
	lastToken = tokens[tokens.length - 1]
	endsWithSlash = typeof lastToken is "string" and /\/$/.test(lastToken)

	# Iterate over the tokens and create our regexp string.
	i = 0

	while i < tokens.length
		token = tokens[i]
		if typeof token is "string"
			route += escapeString(token)
		else
			prefix = escapeString(token.prefix)
			capture = token.pattern
			capture += "(?:" + prefix + capture + ")*"	if token.repeat
			if token.optional
				if prefix
					capture = "(?:" + prefix + "(" + capture + "))?"
				else
					capture = "(" + capture + ")?"
			else
				capture = prefix + "(" + capture + ")"
			route += capture
		i++

	# In non-strict mode we allow a slash at the end of match. If the path to
	# match already ends with a slash, we remove it for consistency. The slash
	# is valid at the end of a path match, not in the middle. This is important
	# in non-ending mode, where "/test/" shouldn't match "/test//route".
	route = ((if endsWithSlash then route.slice(0, -2) else route)) + "(?:\\/(?=$))?"	unless strict
	if end
		route += "$"
	else

		# In non-ending mode, we need the capturing groups to match as much as
		# possible by using a positive lookahead to the end or next path segment.
		route += (if strict and endsWithSlash then "" else "(?=\\/|$)")
	new RegExp("^" + route, flags(options))


pathToRegexp = (path, keys, options) ->
	keys = keys or []
	unless isarray(keys)
		options = keys
		keys = []
	else options = {}	unless options
	return regexpToRegexp(path, keys, options)	if path instanceof RegExp
	return arrayToRegexp(path, keys, options)	if isarray(path)
	stringToRegexp path, keys, options
isarray = module.exports = Array.isArray or (arr) ->
	Object::toString.call(arr) is "[object Array]"

###module.exports = pathToRegexp
module.exports.parse = parse
module.exports.compile = compile
module.exports.tokensToFunction = tokensToFunction
module.exports.tokensToRegExp = tokensToRegExp###
PATH_REGEXP = new RegExp([ "(\\\\.)", "([\\/.])?(?:(?:\\:(\\w+)(?:\\(((?:\\\\.|[^()])+)\\))?|\\(((?:\\\\.|[^()])+)\\))([+*?])?|(\\*))" ].join("|"), "g")
