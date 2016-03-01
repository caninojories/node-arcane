package export cartridge.session

import system.Middleware

import path
import crypto
import util

import tools.wait

import harmony-proxy

class session extends Middleware

	@redis: require path.resolve "#{__dirname}/../../../../core/pool-redis"
	@poolRedis: @redis 'host': 'localhost', 'password': '', 'maxConnections': 10
	@redisClient: null

	__init: ($vhost, $config, $connector) ->
		session.redisClient = wait.for (func) ->
			session.poolRedis.getClient (client, done) ->
				func null, client

	__middle: ($cookies, $req, $res, $app, $config, $connector) ->
		http = $config.all 'http'
		$req.sessionID = $cookies.get $req, 'ArcEngine'

		unless $req.sessionID?
			shasum = crypto.createHash('sha1', 'd8aae46eba9976b0cbb399444e710f4b')
			shasum.update session.guid()
			$req.sessionID = shasum.digest('hex')

			$res.cookie 'ArcEngine', $req.sessionID, $cookies.options

		if typeof http?.sessionMiddleWare is 'function'
			self = this
			$req.session = wait.for (callback) ->
				$app.use http.sessionMiddleWare, (err, result) ->
					console.log err.stack ? err if err
					# callback null, self.initSessionData($req, $res, $connector, $config)
					tmp_data = util._extend {}, (result?.data ? {})
					if result?.data? and result?.save?
						d = new harmonyProxy tmp_data,  #Proxy.create {
							get: (target, name) ->
								if name is 'toJSON'
									return ->
										JSON.stringify target
								else if name is 'valueOf'
									return ->
										target
								else
									target?[name] ? null

							set: (target, name, value) ->
								target[name] = value

						if typeof result?.save is 'function'
							$req.events.on 'request-complete', ->
								result.save d.toJSON()

						callback null, d
						#}
					else
						callback null, session.default_session($req, $config, $connector)
		else
			$req.session = session.default_session($req, $config, $connector)

	__socket: ($req, $config, $app, $params) ->
		http = $config['http']

		cookies_value = null
		for cookies in $req.cookies
			if cookies.name is 'ArcEngine'
				cookies_value = cookies.value

		if cookies_value
			$req.sessionID = cookies_value

		self = this

		if typeof http?.sessionMiddleWare is 'function'
			self = this
			return wait.for (callback) ->
				result = $app http.sessionMiddleWare, http, $params

				tmp_data = util._extend {}, (result?.data ? {})
				if result?.data? and result?.save?
					d = new harmonyProxy tmp_data,  #Proxy.create {
						get: (target, name) ->
							if name is 'toJSON'
								return ->
									JSON.stringify target
							else if name is 'valueOf'
								return ->
									target
							else
								target?[name] ? null

						set: (target, name, value) ->
							target[name] = value

					if typeof result?.save is 'function'
						$req.events.on 'request-complete', ->
							result.save d.toJSON()

					callback null, d
				else
					callback null, session.default_session($req, $config, null)

		else
			return session.default_session($req, $config, null)

	@default_session: ($req, $config, $connector) ->
		config = $config.all?('session') ? $config['session']
		connection_type = if config?.connection? then config.connection else 'redis'
		if $connector and connection_type is 'memory'
			is_new = true
			if $connector.session.$?
				wait.for $connector.session.$
				wait.forMethod $connector.session, 'table', 'session', {
					'session_id': String
					'value': String
					'expiration': Number
				}

			result = wait.forMethod $connector.session, 'query', "SELECT * FROM `tbl_session` WHERE `session_id` LIKE ?", [$req.sessionID]
			if result.length is 0
				tmp_session = {}
			else if result.length isnt 0
				is_new = false
				tmp_session = JSON.parse result[0].value

			$req.events.on 'request-complete', ->
				if is_new
					wait.forMethod $connector.session, 'query', "INSERT INTO `tbl_session` (`session_id`, `value`) VALUES (?, ?)", [$req.sessionID, JSON.stringify tmp_session]
				else
					wait.forMethod $connector.session, 'query', "UPDATE `tbl_session` SET `value`=? WHERE `session_id` LIKE ?", [JSON.stringify(tmp_session), $req.sessionID]
		else
			value = wait.forMethod session.redisClient, 'get', $req.sessionID
			if not value?
				tmp_session = {}
			else
				tmp_session = JSON.parse value

			$req.events.on 'request-complete', ->
				wait.forMethod session.redisClient, 'set', $req.sessionID, JSON.stringify(tmp_session)

		return new harmonyProxy {},
			get: (target, name) ->
				tmp_session[name]

			set: (target, name, value) ->
				tmp_session[name] = value

	@guid: ->
		s4 = ->
			Math.floor((1 + Math.random()) * 0x10000).toString(16).substring 1
		s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4()
