#!package export Model

class Model

	@fieldOneToOne: (table) ->
		createSpecialObject {
			model: table
		}, 'one_to_one'

	@fieldOneToMany: (table, field) ->
		createSpecialObject {
			collection: table
			via: field
		}, 'one_to_many'


	@fieldManyToMany: (table) ->
		createSpecialObject {
			collection: table
			via: 'id'
		}, 'many_to_many'

	@fieldEnumerate: ->


	@Abs:			-> createSpecialObject { val: arguments }, 'abs'
	@Ceil:		-> createSpecialObject { val: arguments }, 'ceil'
	@Floor:		-> createSpecialObject { val: arguments }, 'floor'
	@Round:		-> createSpecialObject { val: arguments }, 'round'
	@Avg:			-> createSpecialObject { val: arguments }, 'avg'
	@Min:			-> createSpecialObject { val: arguments }, 'min'
	@Max:			-> createSpecialObject { val: arguments }, 'max'
	@Exp:			-> createSpecialObject { val: arguments }, 'exp'
	@Power:		-> createSpecialObject { val: arguments }, 'power'
	@Acos:		-> createSpecialObject { val: arguments }, 'acos'
	@Asin:		-> createSpecialObject { val: arguments }, 'asin'
	@Atan:		-> createSpecialObject { val: arguments }, 'atan'
	@Cos:			-> createSpecialObject { val: arguments }, 'cos'
	@Sin:			-> createSpecialObject { val: arguments }, 'sin'
	@tan:			-> createSpecialObject { val: arguments }, 'tan'
	@Conv:		-> createSpecialObject { val: arguments }, 'conv'
	@Random:		-> createSpecialObject { val: arguments }, 'random'
	@Rand:		-> createSpecialObject { val: arguments }, 'rand'
	@Radians:	-> createSpecialObject { val: arguments }, 'radians'
	@Degrees:	-> createSpecialObject { val: arguments }, 'degrees'
	@Sum:			-> createSpecialObject { val: arguments }, 'sum'


createSpecialObject = (obj, tag) ->
	Object.defineProperty obj, "sql_function", {
		configurable : false,
		enumerable   : false,
		value        : tag
	}
	obj
