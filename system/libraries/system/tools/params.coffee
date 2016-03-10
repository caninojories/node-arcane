#!package export tools.params

#!import system.core.*

class params extends core.WObject

	@STRIP_COMMENTS: ///((\/\/.*$)|(\/\*[\s\S]*?\*\/))///mg
	@ARGUMENT_NAMES: ///([^\s,]+)///g

	@get: (func) ->
		fnStr = func.toString().replace params.STRIP_COMMENTS, ''
		result = fnStr.slice(fnStr.indexOf('(') + 1, fnStr.indexOf(')')).match params.ARGUMENT_NAMES
		result = [] unless result
		return result;
