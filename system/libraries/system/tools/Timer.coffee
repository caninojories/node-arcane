package export Timer

class Timer

	@interval: (time, func) ->
		setInterval func, time

	@timeout: (time, func) ->
		setTimeout func, time