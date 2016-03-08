package export cartridge.FormClass

import system.Middleware
# import system.Sync

import harmony-proxy
# import canvas
import fs
import util

import tools.wait

class FormClass extends Middleware

	@return: null
	@form_list: {}

	__init: ($vhost, $config, $controller) ->
		for vhost in $vhost
			FormClass.rules_list[$vhost] = {} unless FormClass.rules_list[vhost]
			FormClass.template_list[vhost] = {} unless FormClass.template_list[vhost]
			FormClass.form_list[vhost] = {} unless FormClass.form_list[vhost]

			for controller_name of $controller[vhost]
				FormClass.form_list[vhost][controller_name] = $controller[vhost][controller_name]['//form-path~']

			if $config[vhost]['form']?
				FormClass.rules_list[vhost] = $config[vhost]['form']

			if $config[vhost]['template']?
				FormClass.template_list[vhost] = $config[vhost]['template']

		_GET = harmonyProxy (-> ), {
			get: (target, name) ->
				if FormClass.req.query[name]
					FormClass.req.query[name]
				else
					null

			apply: (target, thisArg, argumentsList) ->
				FormClass.method FormClass.req.query, argumentsList
		}

		_POST = harmonyProxy (-> ), {
			get: (target, name) ->
				if FormClass.req.body[name]
					FormClass.req.body[name]
				else
					null

			apply: (target, thisArg, argumentsList) ->
				FormClass.method FormClass.req.body, argumentsList
		}

		_FILES = harmonyProxy (-> ), {
			get: (target, name) ->
				if FormClass.req.files[name]
					FormClass.req.files[name]
				else
					null

			apply: (target, thisArg, argumentsList) ->
				FormClass.method FormClass.req.files, argumentsList
		}

		__return =
			_GET: _GET
			_POST: _POST
			_FILES: _FILES
			validate: (callback) ->
				if (FormClass.req.query and Object.keys(FormClass.req.query).length isnt 0) or (FormClass.req.body and Object.keys(FormClass.req.body).length isnt 0) or (FormClass.req.files and Object.keys(FormClass.req.files).length isnt 0)
					try
						for i of FormClass.FormMethods.sync_list
							wait.for FormClass.FormMethods.sync_list[i]
					catch err
						throw err
						# result err
						# return
					callback null, FormClass.FormMethods.value_list
				else
					callback 'Empty Field Request'


			captcha: (params, resolve) ->
				params = {}	unless params
				params.color = params.color or "rgb(0,100,100)"
				params.background = params.background or "rgb(255,200,150)"
				params.width = params.width or 250
				params.height = params.height or 150
				params.font = params.font or "80px sans"
				params.y = params.y or 100
				params.spacing = params.spacing or 30
				params.x = params.x or 20
				params.name = params.name or "captcha"
				_canvas = new canvas(params.width, params.height)
				ctx = _canvas.getContext("2d")
				ctx.antialias = "gray"
				ctx.fillStyle = params.background
				ctx.fillRect 0, 0, params.width, params.height
				ctx.fillStyle = params.color
				ctx.lineWidth = 8
				ctx.strokeStyle = params.color
				ctx.font = params.font

				text = ("" + Math.random()).substr(3, 5)
				# session = {}
				# # session = FormClass.req.session[params.name] if FormClass.req.session[params.name]
				# if FormClass.req.query.id and session[FormClass.req.query.id]
				# 	text = session[FormClass.req.query.id]
				# else text = session["default"]	if session["default"]
				i = 0
				while i < text.length
					ctx.setTransform Math.random() * 0.5 + 1, Math.random() * 0.4, Math.random() * 0.4, Math.random() * 0.5 + 1, params.spacing * i + params.x, params.y
					ctx.fillText text.charAt(i), 0, 0
					i++
				session_sync = (buf) ->
					->
						if FormClass.req.session?
							# if FormClass.req.query.id
							# 	session[FormClass.req.query.id] = text
							# else
							# 	session["default"] = text
							FormClass.req.session[params.name] = text
						FormClass.res.setHeader "Content-Type", "image/png"
						FormClass.res.send buf

				_canvas.toBuffer (err, buf) ->
					FormClass.synchro session_sync(buf), (_err, _result) ->
						resolve _err, _result

		data_options = {}
		FormClass.return = harmonyProxy (->
		),
			get: (proxy, name) ->
				if __return.hasOwnProperty(name)
					__return[name]
				else if name is "toString"
					->
						FormClass.FormGenerate null, data_options
				else if name is "import"
					FormClass.req.validations = null
					FormClass.RulesGenerator null, __return, data_options
					wait.for __return.validate
					FormClass.FormMethods.value_list
				else
					regex_form = /^import_(.*)$/g.exec(name)
					if regex_form
						FormClass.req.validations = null
						FormClass.RulesGenerator regex_form[1], __return, data_options
						wait.for __return.validate
						FormClass.FormMethods.value_list
					else
						FormClass.throwError name

			set: (proxy, name, value) ->
				if name is 'disable' and typeof value is 'object'
					data_options[name] = value
				if name is 'resetData' and value
					data_options = {}

			apply: (target, thisArg, argumentsList) ->
				FormClass.FormGenerate argumentsList[0], data_options


	__middle: ($req, $res, $config) ->
		FormClass.req = $req
		FormClass.res = $res
		FormClass.config = $config
		$req.validations = null

		FormClass.FormMethods.sync_list = []
		FormClass.FormMethods.value_list = {}

		$req.form_error = FormClass.FormErrorReq
		$res.form_error = FormClass.FormErrorRes

		# we can used this implementation in the future
		FormClass.return.resetData = true

		return FormClass.return

	__socket: ($req, $config) ->
		$res = {}

		FormClass.req = $req
		FormClass.res = $res
		FormClass.config = $config
		$req.validations = null

		FormClass.FormMethods.sync_list = []
		FormClass.FormMethods.value_list = {}

		$req.form_error = FormClass.FormErrorReq
		$res.form_error = FormClass.FormErrorRes

		return FormClass.return

	@req: null
	@res: null
	@config: null

	@escapeRegExp: (str) ->
		str.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"

	@throwError: (name) ->
		throw new Error "Unable to lookup '#{name}' or the the form name is not exist, please check your 'form.js'."

	@findFormTemplate: ($req, field_name) ->
		target_form_file = FormClass.form_list[$req.root][$req.controllerName]

		if fs.existsSync target_form_file
			form_vars = __require target_form_file
			defaults =
				method: "_POST"
				rules: "trim"
				type: "text"
				template: "<div class=\"form-group {{highlight}}\"><label class=\"{{label-col}} control-label\">{{label}} {{required}}</label><div class=\"{{field-col}}\">{{field}}{{error}}</div></div>"
				"label-col": "col-sm-4"
				"field-col": "col-sm-8"
				attributes: ""
				error_template: "form_error"
				error_class: 'has-error'
				caseSensitive: false

			j = undefined
			k = undefined

			if form_vars?.defaults?
				for j of form_vars.defaults
					defaults[j] = form_vars.defaults[j]

			f = ((if field_name and field_name isnt "default" then form_vars[field_name] else form_vars.fields))
			defaults: defaults
			fields: f or {}
		else
			console.log $req.root, $req.controllerName
			throw new Error("Unable to load '#{target_form_file}'.")

	@method: (thisArg, argumentsList) ->
		thisArg[argumentsList[0]] = ""	if thisArg and not thisArg[argumentsList[0]]
		if argumentsList.length isnt 0 and typeof argumentsList[0] is "string" and thisArg and typeof thisArg[argumentsList[0]] isnt "undefined"
			harmonyProxy (->
			),
				get: (target, name) ->
					if name is "path" or name is "type"
						return thisArg[argumentsList[0]][name]	if thisArg[argumentsList[0]][name]
						null
					else if name isnt "toString" and FormClass.FormMethods[name] and typeof FormClass.FormMethods[name] is "function"
						->
							FormClass.FormMethods.value_list[argumentsList[0]] = thisArg[argumentsList[0]]
							FormClass.FormMethods[name].apply
								name: argumentsList[0]
							, arguments
					else if name is "valueOf"
						""
					else if name is "inspect"
						return
					else if name is "toString" and typeof argumentsList[0] isnt "undefined"
						->
							thisArg[argumentsList[0]]
					else

						#console.log('WARNING: Invalid properties of form method \'' + name + '\'.');
						->

				apply: ->

		else
			if not thisArg or not thisArg[argumentsList[0]]
				FormClass.FormMethods.sync_list.push (callback) ->

					#callback('Parameter \'' + argumentsList[0] + '\' is not setted.');
					callback null, ""

			rules: ->

	@FormMethods:
		sync_list: []
		value_list: {}
		rules: (label, rules) ->
			self = this
			rules.split("|").map (value) ->
				value = value.trim()
				value_match = /^([0-9a-zA-Z_-]+?)\[([0-9a-zA-Z_-]+?)\]$/g.exec(value)
				param = null
				tmp_call = (value, param, value_match) ->
					if value_match
						value = value_match[1]
						param = value_match[2]
					if FormClass.rules_list[FormClass.req.root][value]? and typeof FormClass.rules_list[FormClass.req.root][value] is "function"
						FormClass.FormMethods.sync_list.push (callback) ->
							FormClass.rules_list[FormClass.req.root][value].call
								values: FormClass.FormMethods.value_list
								req: FormClass.req
								name: self.name
							, FormClass.FormMethods.value_list[self.name], label, param, (err, result) ->
								if err
									FormClass.req.validations =
										name: self.name
										message: err

									callback err
									return
								FormClass.FormMethods.value_list[self.name] = result if typeof result isnt "boolean"
								callback null, FormClass.FormMethods.value_list[self.name]


					else
						console.log "ERROR: Invalid validation name '" + value + "'"
				tmp_call value, param, value_match
		to: (to, cb) ->
			if typeof FormClass.req.files[@name] isnt "undefined"
				self = this
				readStream = fs.createReadStream(FormClass.req.files[@name].path)
				writeStream = fs.createWriteStream(FormClass.req.root + "/assets/" + to)
				writeStream.on "close", ->
					fs.unlinkSync FormClass.req.files[self.name].path
					cb null, true	if cb

				readStream.pipe writeStream

	@rules_list: {}
	@template_list: {}

	@FormErrorReq: (name, classes, attributes, template) ->
		ret = ""
		return ret	unless FormClass.req.validations
		if FormClass.req.validations.name is name
			if template and FormClass.template_list[FormClass.req.root].hasOwnProperty(template)
				ret = FormClass.template_list[FormClass.req.root][template]
			else if not FormClass.template_list[FormClass.req.root].form_error
				ret = "<div class=\"{{class}}\" {{attributes}}>{{message}}</div>"
			else
				ret = FormClass.template_list[FormClass.req.root].form_error
			ret = ret.replace(/\{\{message\}\}/g, FormClass.req.validations.message)
			ret = ret.replace(/\{\{class\}\}/g, classes or "")
			ret = ret.replace(/\{\{attributes\}\}/g, attributes or "")
		ret

	@FormErrorRes: (name, message) ->
		FormClass.req.validations =
			name: name
			message: message

	@FieldGenerate: (name, helper_value, field) ->
		if helper_value isnt null or helper_value
			if typeof helper_value is "string" or typeof helper_value is "number"
				"<input type=\"{{type}}\" name=\"{{name}}\" value=\"" + helper_value + "\" " + ((if field.hasOwnProperty("readonly") and field.readonly then "readonly=\"readonly\" " else "")) + "class=\"form-control {{class}}\" {{attributes}} />"
			else if typeof helper_value is "object"
				list = ""
				x = undefined
				default_value = (if field.hasOwnProperty("value") then field.value else "")
				if field.hasOwnProperty("method")
					if field.method is "_POST"
						default_value = FormClass.req.body[name] if FormClass.req.body and FormClass.req.body.hasOwnProperty(name)
					else default_value = FormClass.req.query[name] if FormClass.req.query and FormClass.req.query.hasOwnProperty(name)	if field.method is "_GET"
				else
					default_value = FormClass.req.body[name] if FormClass.req.body and FormClass.req.body.hasOwnProperty(name)
				for x of helper_value
					list += "<option value=\"" + x + "\"" + ((if x is default_value then " selected=\"selected\"" else "")) + ">" + helper_value[x] + "</option>"	if helper_value.hasOwnProperty(x)
				"												<select " + ((if field.hasOwnProperty("readonly") and field.readonly then "readonly=\"readonly\" " else "name=\"{{name}}\"")) + " class=\"form-control {{class}}\" {{attributes}}>														 																 " + list + "																										</select>												 "
		else
			if field.hasOwnProperty("type") and field.type is "radio"
				"<input type=\"radio\" name=\"#{name}\" value=\"#{field.value}\" {{selected}} " + ((if field.hasOwnProperty("readonly") and field.readonly then "readonly=\"readonly\" " else "")) + "class=\"form-control {{class}}\" {{attributes}} />"
			else if field.hasOwnProperty("type") and field.type is "textarea"
				"<textarea name=\"{{name}}\" " + ((if field.hasOwnProperty("readonly") and field.readonly then "readonly=\"readonly\" " else "")) + "class=\"form-control {{class}}\" {{attributes}}>{{value}}</textarea>"
			else
				"<input type=\"{{type}}\" name=\"{{name}}\" value=\"{{value}}\" " + ((if field.hasOwnProperty("readonly") and field.readonly then "readonly=\"readonly\" " else "")) + "class=\"form-control {{class}}\" {{attributes}} />"

	@UpdateFormData: (template, name, field, defaults, label) ->
		tmp = template.replace(/\{\{([0-9a-zA-Z_\-\.]+?)\}\}/g, (match) ->
			regex = /\{\{([0-9a-zA-Z_\-\.]+?)\}\}/g.exec(match)
			if regex[1] isnt "value" and field.hasOwnProperty(regex[1])
				return field[regex[1]]
			else if defaults.hasOwnProperty(regex[1])
				return defaults[regex[1]]
			else
				switch regex[1]
					when "name"
						return name
					when "value"
						default_value = (if field.hasOwnProperty("value") then field.value else "")
						if field.hasOwnProperty("method")
							if field.method is "_POST"
								default_value = FormClass.req.body[name] if FormClass.req.body and FormClass.req.body.hasOwnProperty(name)
							else if field.method is "_GET"
								default_value = FormClass.req.query[name] if FormClass.req.query and FormClass.req.query.hasOwnProperty(name)
							else return ""	if field.method is "_FILES"
						else
							default_value = FormClass.req.body[name] if FormClass.req.body and FormClass.req.body.hasOwnProperty(name)
						return default_value
					when "selected"
						if FormClass.req.body
							default_value = FormClass.req.body[name] if FormClass.req.body and FormClass.req.body.hasOwnProperty(name)

							if field.hasOwnProperty('value') and default_value is field.value
								return "checked='checked'"

						return ""
			""
		)
		tmp = tmp.replace(/\{\{([0-9a-zA-Z_\-\.]+?)\}\}/g, (match) ->
			regex = /\{\{([0-9a-zA-Z_\-\.]+?)\}\}/g.exec(match)
			if regex
				switch regex[1]
					when "label"
						return label
			""
		)
		tmp

	@FormGenerate: (target_field, data_options) ->
		form_vars = FormClass.findFormTemplate(FormClass.req, target_field)
		k = undefined
		ret_html = ""
		template = ""
		config_template = FormClass.config.all("template")
		helper_list = FormClass.config.all("helper")
		for k of form_vars.fields
			if form_vars.fields.hasOwnProperty(k)
				template = form_vars.defaults.template
				template = config_template[template] if config_template?.hasOwnProperty(template)
				if form_vars.fields[k].hasOwnProperty("template") and config_template?.hasOwnProperty(form_vars.fields[k].template)
					template = config_template[form_vars.fields[k].template]
				else console.error "WARNING: Unable to find template name '" + form_vars.fields[k].template + "'"	if form_vars.fields[k].hasOwnProperty("template")

				if form_vars.defaults.caseSensitive
					name = k.replace(/\W/g, "_").replace(/^_/g, "").replace(/_$/g, "").replace(/_+/g, "_")
				else
					name = k.replace(/\W/g, "_").replace(/^_/g, "").replace(/_$/g, "").replace(/_+/g, "_").toLowerCase()

				if data_options.disable and data_options.disable.indexOf(name) isnt -1
					continue

				error = null
				m = undefined
				tmp_name = ""
				is_group_of_radio = false

				if form_vars.fields[k].hasOwnProperty("group") and form_vars.fields[k].type and form_vars.fields[k].type is 'radio'
					is_group_of_radio = true

				if form_vars.fields[k].hasOwnProperty("group") and not is_group_of_radio
					for m of form_vars.fields[k].group
						if form_vars.fields[k].group.hasOwnProperty(m)
							if form_vars.defaults.caseSensitive
								tmp_name = m.replace(/\W/g, "_").replace(/^_/g, "").replace(/_$/g, "").replace(/_+/g, "_")
							else
								tmp_name = m.replace(/\W/g, "_").replace(/^_/g, "").replace(/_$/g, "").replace(/_+/g, "_").toLowerCase()
							error = FormClass.req.form_error(tmp_name, "error", null, (if form_vars.fields[k].error_template then form_vars.fields[k].error_template else form_vars.defaults.error_template))
							break	if error.length isnt 0
				else
					error = FormClass.req.form_error(name, "error", null, (if form_vars.fields[k].error_template then form_vars.fields[k].error_template else form_vars.defaults.error_template))

				helper_value = null
				helper_value = wait.for helper_list[form_vars.fields[k].helper], FormClass.req, FormClass.res, FormClass.config if form_vars.fields[k].hasOwnProperty("helper") and helper_list?.hasOwnProperty(form_vars.fields[k].helper)
				template = template.replace(/\{\{([0-9a-zA-Z_\-\.]+?)\}\}/g, (match) ->
					regex = /\{\{([0-9a-zA-Z_\-\.]+?)\}\}/g.exec(match)
					if regex
						if regex[1] isnt "group" and regex[1] isnt "required" and regex[1] isnt "field" and regex[1] isnt "error" and form_vars.fields[k].hasOwnProperty(regex[1]) and regex[1] isnt "error_class"
							return form_vars.fields[k][regex[1]]
						else if form_vars.defaults.hasOwnProperty(regex[1])
							return form_vars.defaults[regex[1]]
						else

							error_class = if form_vars.fields[k].error_class then form_vars.fields[k].error_class else form_vars.defaults.error_class

							switch regex[1]
								when "group"
									if form_vars.fields[k].hasOwnProperty("group")
										v_ret = ""
										l = undefined
										_helper_value = null
										_name = ""
										_length = (12 / Object.keys(form_vars.fields[k].group).length).toFixed 0
										for l of form_vars.fields[k].group
											if form_vars.fields[k].group.hasOwnProperty(l)

												if form_vars.fields[k].type and form_vars.fields[k].type is 'radio'
													form_vars.fields[k].group[l].type = 'radio'
													_name = name
												else
													if form_vars.defaults.caseSensitive
														_name = l.replace(/\W/g, "_").replace(/^_/g, "").replace(/_$/g, "").replace(/_+/g, "_")
													else
														_name = l.replace(/\W/g, "_").replace(/^_/g, "").replace(/_$/g, "").replace(/_+/g, "_").toLowerCase()

												_helper_value = wait.for helper_list[form_vars.fields[k].group[l].helper], FormClass.req, FormClass.res, FormClass.config if form_vars.fields[k].group[l].hasOwnProperty("helper") and helper_list?.hasOwnProperty(form_vars.fields[k].group[l].helper)
												_field = FormClass.UpdateFormData(FormClass.FieldGenerate(_name, _helper_value, form_vars.fields[k].group[l]), _name, form_vars.fields[k].group[l], form_vars.defaults, l)

												if form_vars.fields[k].group[l].group_template? and config_template[form_vars.fields[k].group[l].group_template]?
													v_ret += config_template[form_vars.fields[k].group[l].group_template].replace /\{\{([0-9a-zA-Z_\-\.]+?)\}\}/g, (_match) ->
														_regex = /\{\{([0-9a-zA-Z_\-\.]+?)\}\}/g.exec(_match)
														if _regex
															switch _regex[1]
																when "field" then return _field
																when "highlight"
																	return ' ' + error_class if error.length isnt 0
																	return ''
																when "label"
																	return l
																when "col"
																	if form_vars.fields[k].group[l].hasOwnProperty _regex[1]
																		return form_vars.fields[k].group[l][_regex[1]]
																	else
																		return _length
																else
																	if form_vars.fields[k].group[l].hasOwnProperty _regex[1]
																		return form_vars.fields[k].group[l][_regex[1]]
																	else return ""
														else return ""
										return v_ret
									return ""
								when "field"
									if form_vars.fields[k].hasOwnProperty("group")
										v_ret = "<div class=\"row\">"
										l = undefined
										_helper_value = null
										_name = ""
										for l of form_vars.fields[k].group
											if form_vars.fields[k].group.hasOwnProperty(l)
												if form_vars.defaults.caseSensitive
													_name = l.replace(/\W/g, "_").replace(/^_/g, "").replace(/_$/g, "").replace(/_+/g, "_")
												else
													_name = l.replace(/\W/g, "_").replace(/^_/g, "").replace(/_$/g, "").replace(/_+/g, "_").toLowerCase()
												_helper_value = wait.for helper_list[form_vars.fields[k].group[l].helper], FormClass.req, FormClass.res, FormClass.config	if form_vars.fields[k].group[l].hasOwnProperty("helper") and helper_list?.hasOwnProperty(form_vars.fields[k].group[l].helper)
												if form_vars.fields[k].group[l].hasOwnProperty("col")
													v_ret += "<div class=\"" + form_vars.fields[k].group[l].col + "\">"
												else
													v_ret += "<div class=\"col-md-6\">"
												v_ret += FormClass.UpdateFormData(FormClass.FieldGenerate(_name, _helper_value, form_vars.fields[k].group[l]), _name, form_vars.fields[k].group[l], form_vars.defaults, l)
												v_ret += "</div>"
										v_ret += "</div>"
										return v_ret
									else
										return FormClass.UpdateFormData(FormClass.FieldGenerate(name, helper_value, form_vars.fields[k]), name, form_vars.fields[k], form_vars.defaults, k)
								when "error"
									return error
								when "required"
									return "<span class=\"required\">*</span>"	if form_vars.fields[k].hasOwnProperty("rules") and /required/g.test(form_vars.fields[k].rules)
								when "label"
									return k
								when "highlight"
									return ' ' + error_class if error.length isnt 0
					""
				)
				ret_html += template + "\n"
		ret_html

	@FieldRuleGenerator: (caseSensitive, field, is_readonly, defaults, label, __return) ->
		return	if is_readonly
		if caseSensitive
			name = label.replace(/\W/g, "_").replace(/^_/g, "").replace(/_$/g, "").replace(/_+/g, "_")
		else
			name = label.replace(/\W/g, "_").replace(/^_/g, "").replace(/_$/g, "").replace(/_+/g, "_").toLowerCase()
		form_method = defaults.method
		if field.hasOwnProperty("method")
			form_method = field.method
		else
			form_method = defaults.method
		__return[form_method](name).rules label, field.rules or defaults.rules

	@RulesGenerator: (target_form, __return, data_options) ->
		form_vars = FormClass.findFormTemplate(FormClass.req, target_form)
		k = undefined
		l = undefined
		for k of form_vars.fields
			if data_options.disable and data_options.disable.indexOf(k) isnt -1
				continue

			if form_vars.fields.hasOwnProperty(k)
				if form_vars.fields[k].hasOwnProperty("group") and (not form_vars.fields[k].type and form_vars.fields[k].type isnt 'radio')
					for l of form_vars.fields[k].group
						FormClass.FieldRuleGenerator form_vars.defaults.caseSensitive, form_vars.fields[k].group[l], (if form_vars.fields[k].group[l].hasOwnProperty("readonly") and form_vars.fields[k].group[l].readonly then true else false), form_vars.defaults, (l if form_vars.fields[k].group.hasOwnProperty(l)), __return
				else
					FormClass.FieldRuleGenerator form_vars.defaults.caseSensitive, form_vars.fields[k], (if form_vars.fields[k].hasOwnProperty("readonly") and form_vars.fields[k].readonly then true else false), form_vars.defaults, k, __return
