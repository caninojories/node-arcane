var fibby = require(__dirname + '/fibby.js');
var wait = require(__dirname + '/wait.js');

module.exports = function(opt) {
	var p_func = [];
	var p_count = -1;
	var p_seq = 0;
	var i;

	var errorHandler = opt && opt.done && typeof opt.done === 'function' ? opt.done : function(err) {
		if(err) {
			console.log(err.stack || err);
		}
	};

	// BUG: opt.handler not calling sometimes

	var d = function() {
		var c = p_count++;
		// console.log('Instance Created');
		while(true) {
			var result = wait.for(function(callback) {
				p_func[c] = callback;
			});

			p_func[c] = null;

			// console.log('Request for: ', result[0].url);

			if(opt && opt.handler && typeof opt.handler === 'function') {
				opt.handler(result[0], result[1], result[2]);
			}
		}
	};

	for(i = 0; i < 30; i++) {
		wait.launchFiber(d); // Fiber Engine
	}

	var ret = function(req, res) {
		if(typeof p_func[p_seq] === 'function') {
			p_func[p_seq](null, req, res, opt.app);
		} else {
			// console.log('Invalid Function', req.url);
			var st = function() {
				if(typeof p_func[p_seq] === 'function') {
					p_func[p_seq](null, req, res, opt.app);
				} else {
					if(p_seq === p_count) {
						p_seq = 0;
					} else {
						p_seq++;
					}
					// console.log('Invalid Function', req.url);
					setTimeout(st, 0);
				}
			};
			setTimeout(st, 0);
		}
	};

	if(opt && opt.app && typeof opt.app === 'function') {
		ret.__proto__ = opt.app;
	}

	return ret;
};