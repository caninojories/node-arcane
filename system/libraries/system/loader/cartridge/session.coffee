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

		# for DocumentRoot in $vhost
		# 	config = $config[DocumentRoot]['session']
		# 	session.list[DocumentRoot] = {} unless session.list[DocumentRoot]

		# 	connection_type = if config?.connection? then config.connection else 'sqlite'

			# switch connection_type
			# 	when 'redis'
			# 		result = @redis_connection $connector[DocumentRoot]
			# 	else
			# 		result = @sqlite_connection $connector[DocumentRoot]

	__middle: ($cookies, $req, $res, $app, $config, $connector) ->
		http = $config.all 'http'

		$req.sessionID = $cookies.get $req, 'ArcEngine'

		unless $req.sessionID?
			shasum = crypto.createHash('sha1', 'd8aae46eba9976b0cbb399444e710f4b')
			shasum.update session.guid()
			$req.sessionID = shasum.digest('hex')

			$res.cookie 'ArcEngine', $req.sessionID, $cookies.options

			# $res.setHeader 'Set-Cookie', 'ArcEngine=' + $req.sessionID



		# if Object.keys($cookies.list).length == 0 or typeof $cookies.list['ArcEngine'] is 'undefined'
		# 	shasum = crypto.createHash('sha1', 'd8aae46eba9976b0cbb399444e710f4b')
		# 	shasum.update session.guid()
		# 	$req.sessionID = shasum.digest('hex')
		# 	$res.setHeader 'Set-Cookie', 'ArcEngine=' + $req.sessionID
		# else
		# 	$req.sessionID = $cookies.list['ArcEngine']


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
						callback null, self.initSessionData($req, $res, $connector, $config)
		else
			$req.session = @initSessionData $req, $res, $connector, $config



	__socket: ($req, $config, $app, $params) ->
		http = $config['http']

		cookies_value = null
		for cookies in $req.cookies
			if cookies.name is 'ArcEngine'
				cookies_value = cookies.value
				# break

		if cookies_value
			$req.sessionID = cookies_value

		self = this
		default_exec = ->
			redis = self.redis_connection session.redisClient, null, $req.sessionID
			return Proxy.create {
				get: (proxy, name) ->
					data = JSON.parse redis.get $req.sessionID
					if data and data.hasOwnProperty(name)
						return data[name]
					else
						return null

				set: (proxy, name, value) ->
					redis.set name, value, $req.sessionID
			}

		if typeof http?.sessionMiddleWare is 'function'
			self = this
			return wait.for (callback) ->
				result = $app http.sessionMiddleWare, http, $params
				# if result?.set? and result?.get?
				# 	callback null, Proxy.create {
				# 		get: result.get
				# 		set: result.set
				# 	}
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
					callback null, do default_exec
		else
			return do default_exec




	###
	# Private function and variables
	###

	@list: {}

	proxy_session: null

	raw_connection: {
		get: (SessionID) ->
		set: (SessionID, name, value) ->
		sessionID: null
	}

	initSessionData: ($req, $res, $connector, $config) ->
		config = $config.all 'session'
		connection_type = if config?.connection? then config.connection else 'redis'

		switch connection_type
			when 'redis'
				# $res.redis_client = do session.redis.createClient
				# $res.onEnd () ->
				# 	do $res.redis_client.quit

				result = @redis_connection session.redisClient, $connector, $req.sessionID
			else
				result = @sqlite_connection $connector, $req.sessionID

		# result = @redis_connection $connector, $req.sessionID
		return Proxy.create {
			get: (proxy, name) ->
				data = JSON.parse do result.get
				if data and data.hasOwnProperty(name)
					return data[name]
				else
					return null

			set: (proxy, name, value) ->
				result.set name, value
		}

	redis_connection: (client, $connector, sessionID) ->
		return {
			get: ->
				value = wait.forMethod client, 'get', sessionID
				if not value?
					wait.forMethod client, 'set', sessionID, '{}'
					value = '{}'
				return value
			set: (name, value) ->
				data = JSON.parse do @get
				data[name] = value
				wait.forMethod client, 'set', sessionID, JSON.stringify(data)
		}


	sqlite_connection: ($connector, sessionID) ->
		if $connector.session.$?
			wait.for $connector.session.$

		wait.forMethod $connector.session, 'table', 'session', {
			'session_id': String
			'value': String
			'expiration': Number
		}

		return {
			get: ->
				result = wait.forMethod $connector.session, 'query', "SELECT * FROM `tbl_session` WHERE `session_id` LIKE ?", [sessionID]
				if result.length is 0
					wait.forMethod $connector.session, 'query', "INSERT INTO `tbl_session` (`session_id`, `value`) VALUES (?, ?)", [sessionID, '{}']
					result.push { value: '{}' }
				return result[0].value

			set: (name, value) ->
				data = JSON.parse @get()
				data[name] = value
				wait.forMethod $connector.session, 'query', "UPDATE `tbl_session` SET `value`=? WHERE `session_id` LIKE ?", [JSON.stringify(data), sessionID]
		}

		# callback null, true # @raw_connection

	@guid: ->
		s4 = ->
			Math.floor((1 + Math.random()) * 0x10000).toString(16).substring 1
		s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4()
