#!package export model.ModelComparators


class ModelComparators


	createSpecialObject = (obj, tag) ->
		Object.defineProperty obj, 'sql_comparator',
			configurable: false
			enumerable: false
			value: ->
				tag
		obj

	@between: (a, b) ->
		createSpecialObject {
			from: a
			to: b
		}, 'between'

	@not_between: (a, b) ->
		createSpecialObject {
			from: a
			to: b
		}, 'not_between'

	@like: (expr) ->
		createSpecialObject { expr: expr }, 'like'

	@not_like: (expr) ->
		createSpecialObject { expr: expr }, 'not_like'

	@eq: (v) ->
		createSpecialObject { val: v }, 'eq'

	@ne: (v) ->
		createSpecialObject { val: v }, 'ne'

	@gt: (v) ->
		createSpecialObject { val: v }, 'gt'

	@gte: (v) ->
		createSpecialObject { val: v }, 'gte'

	@lt: (v) ->
		createSpecialObject { val: v }, 'lt'

	@lte: (v) ->
		createSpecialObject { val: v }, 'lte'

	@not_in: (v) ->
		createSpecialObject { val: v }, 'not_in'
