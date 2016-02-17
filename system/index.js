/*global
    __userdir, __arc_engine
*/

/*require('trace');
require('clarify');*/

var fs = require('fs'),
    path = require('path'),
    default_conf = require(__dirname + '/../config/default.js').default,
    initiator = require(__dirname + '/../lib/Initiator.js'),

    sync = require(__dirname + '/../lib/sync'),

    // Fiber = require('fibers'),

    //app = require(__dirname + '/core'),
    os = require('os'),
    cluster = require('cluster'),
    process_type_list = {};

global.clusterProcess = [];
global.childList = {};
global.last_function = [];

function hash(ip, seed) {
    var hash = ip.reduce(function(r, num) {
        r += parseInt(num, 10);
        r %= 2147483648;
        r += (r << 10);
        r %= 2147483648;
        r ^= r >> 6;
        return r;
    }, seed);

    hash += hash << 3;
    hash %= 2147483648;
    hash ^= hash >> 11;
    hash += hash << 15;
    hash %= 2147483648;

    return hash >>> 0;
}

var find_module = function(dirname, fname, callback) {
    if (dirname === '/') {
        if (fs.existsSync(dirname + 'node_modules/' + fname)) {
            callback(null, dirname + 'node_modules/' + fname);
        } else {
            callback(true, null);
        }
    } else {
        if (fs.existsSync(dirname + '/node_modules/' + fname)) {
            callback(null, dirname + '/node_modules/' + fname);
        } else {
            find_module(path.dirname(dirname), fname, callback);
        }
    }
};

// var last_access = {};
var recent_loaded_file = {};
// var watch_file_list = {};
global.import_tree = {};

Object.defineProperty(global, '__require', {
    get: function() {
        var current_file = __stack[1].getFileName();
        var current_dir = path.dirname(current_file) + '/';
        return function(fname, options) {

            var path = require('path');
            if (!fs.existsSync(fname) && fs.existsSync(fname + '.coffee')) {
                fname += '.coffee';
            } else if (!fs.existsSync(fname) && fs.existsSync(fname + '.js')) {
                fname += '.js';
            }

            if(/libraries/g.test(fname) && !/\.\.\//g.test(fname)) {
                if(!global.import_tree[fname]) {
                    global.import_tree[fname] = [];
                }
                if(global.import_tree[fname].indexOf(current_file) === -1) {
                    global.import_tree[fname].push(current_file);
                }
            }

            var perfect_url = path.resolve(fname);
            var stats;

            if(fs.existsSync(fname)) {
                stats = fs.lstatSync(fname);
            } else {
                stats = {
                    mode: 33261,
                    nlink: 1,
                    uid: 500,
                    gid: 500,
                    rdev: 0,
                    blksize: 4096,
                    ino: 146605,
                    size: 24084,
                    blocks: 48,
                    atime: new Date(),
                    mtime: new Date(),
                    ctime: new Date(),
                    birthtime: new Date()
                };
            }

            if(fs.existsSync(perfect_url)) {
                if(recent_loaded_file[perfect_url]) {
                    if(Number(recent_loaded_file[perfect_url].mdate) === Number(stats.mtime)) {
                        return recent_loaded_file[perfect_url].fdata;
                    }
                }
                recent_loaded_file[perfect_url] = {};
                if(/\.coffee$/g.test(perfect_url)) {
                    recent_loaded_file[perfect_url].fdata = require(__dirname + '/core/Coffeescript').include(perfect_url);
                    recent_loaded_file[perfect_url].mdate = stats.mtime;
                } else {
                    recent_loaded_file[perfect_url].fdata = require(perfect_url);
                    recent_loaded_file[perfect_url].mdate = stats.mtime;
                }
            } else {
                if(recent_loaded_file[perfect_url]) {
                    return recent_loaded_file[perfect_url].fdata;
                }
                try {
                    require.resolve(fname);
                    recent_loaded_file[fname] = {};
                    recent_loaded_file[fname].mdate = stats.mtime;
                    return recent_loaded_file[fname].fdata = require(fname);
                } catch(err) {
                    var target_required = null;
                    find_module(current_dir + '/', fname, function(error, success) {
                        if (error) {
                            if(options && options.error) {
                                throw new Error(options.error);
                            } else {
                                throw new Error(error);
                            }
                        } else {
                            target_required = require(success);
                        }
                    });
                    recent_loaded_file[fname] = {};
                    recent_loaded_file[fname].mdate = stats.mtime;
                    return recent_loaded_file[fname].fdata = target_required;
                }
            }

            return recent_loaded_file[perfect_url].fdata;
        };
    }
});


Object.defineProperty(global, '__stack', {
    get: function() {
        var orig = Error.prepareStackTrace;
        Error.prepareStackTrace = function(_, stack) {
            return stack;
        };
        var err = new Error();
        Error.captureStackTrace(err, arguments.callee);
        var stack = err.stack;
        Error.prepareStackTrace = orig;
        return stack;
    }
});

Object.defineProperty(global, '__line', {
    get: function() {
        return __stack[1].getLineNumber();
    }
});

Object.defineProperty(global, '__function', {
    get: function() {
        return __stack[1].getFunctionName();
    }
});

global.p_args_raw = function(arg, arr, def) {
    var ret = [].slice.call(arr),
        args = [].slice.call(arg),
        cntr = args.length - 1;

    for (var i = arr.length - 1; i >= 0; i--) {
        if (typeof ret[i] === 'string') {
            if (args[cntr] && typeof args[cntr] === ret[i]) {
                ret[i] = args[cntr];
                cntr--;
            } else ret[i] = def[i];
        } else {
            if (args[cntr] && args[cntr] instanceof ret[i]) {
                ret[i] = args[cntr];
                cntr--;
            } else ret[i] = def[i];
        }
    }
    return ret;
};

global.p_args = function(args, obj) {
    var ret = {},
        types = [],
        defs = [];
    for (var i in obj) {
        types.push(obj[i][0]);
        defs.push(obj[i][1]);
    }
    var result = p_args_raw(args, types, defs),
        counts = 0;
    for (var x in obj) {
        ret[x] = result[counts++];
    }
    return ret;
};

process.stdin.resume();

process.on('uncaughtException', function(err) {
    if(err && typeof err !== 'string') {
        console.log(err.stack || err);
    }
    //process.exit(0);
});

var net = require('net');
var crypto = require('crypto');

var modules = ['$console', '$http', '$vhost', '$config', '$connector', '$model', '$cookies', '$url', '$session', '$bodyparser', '$controller', '$view', '$route', '$form', '$validator'];

var arc_system_location = '/var/arcane';

var cert_pem = __dirname + '/../storage/https/cert.pem',
    key_pem = __dirname + '/../storage/https/key.pem';

if (fs.existsSync(arc_system_location + '/cert.pem')) {
    cert_pem = arc_system_location + '/cert.pem';
}

if (fs.existsSync(arc_system_location + '/key.pem')) {
    key_pem = arc_system_location + '/key.pem';
}

var connectionListener = function(seed, workers) {
    return function(c) {
        var ipHash = hash((c.remoteAddress || '').split(/\./g), seed);
         random = crypto.randomBytes(4).readUInt32BE(0, true);
        //console.log(random % workers.length);
        worker = workers[random % workers.length];
        worker.send('arcane-session:connection', c);
    }
}

var ClusterServer = {
    name: 'ClusterServer',
    cpus: os.cpus().length,
    autoRestart: true, // Restart threads on death?
    start: function() {
        var me = this,
            i,
            //cpu_count = /*((me.cpus * 2) >= 4) ?*/ (me.cpus * 1) /*: 4*/,
            cpu_count = ((me.cpus * 1) >= 2) ? (me.cpus * 1) : 2,
            child;

        if (cluster.isMaster) { // fork worker threads


            var workers = [];

            var spawn = function(i) {
                if(i === 0) {
                    workers[i] = cluster.fork({worker_leader: true});
                    workers[i].primary = true
                } else {
                    workers[i] = cluster.fork();
                }

                // Optional: Restart worker on exit
                workers[i].on('exit', function(worker, code, signal) {
                    console.log('respawning worker', i);
                    spawn(i);
                });

                workers[i].on('message', function(data, handler) {
                    if(typeof data === 'object' && data.command) {
                        if(data.command === 'add-socket') {

                        } else if(data.command === 'delete-socket') {

                        } else if(data.command === 'broadcast' ||
                                  data.command === 'globalTimer-call' ||
                                  data.command === 'socket-connect' ||
                                  data.command === 'socket-disconnect'
                        ) {
                            for(var j in workers) {
                                workers[j].send(data);
                            }
                        }
                    } else if(data === 'reset-arce') {
                        for(var j in workers) {
                            workers[j].send(data);
                        }
                    } else if(typeof data === 'object' && data.name && (data.name === 're-update' || data.name === 'emitter')) {
                        // var primary_setted = false;
                        for(var j in workers) {
                            if(workers[j].primary) {
                                data.primary = true;
                                // primary_setted = true;
                            } else {
                                data.primary = false;
                            }
                            workers[j].send(data);
                        }
                    }
                })
            };

            for (var i = 0; i < cpu_count; i++) {
                spawn(i);
            }

            fs.writeFile(arc_system_location + '/arc.pid', process.pid, function(err) {
                if (err) {
                    return console.log(err);
                }
            });
        } else {
            var fibby = require(__dirname + '/libraries/tools/fibby.js');
            var _log = console.log
            /*sync*/
            // fibby.run(function(fib) {
                try {
                    var app = __require(__dirname + '/core/index.coffee');

                    app.server(modules, function() {
                        app.initialize(null).listen(default_conf.port);

                        __arc_engine.ports.forEach(function(value) {
                            if (typeof value === 'string') {
                                var port_settings = value.split(':');

                                if (port_settings.length === 2 && port_settings[0] === 'https') {
                                    app.initialize({
                                        key: fs.readFileSync(key_pem, 'utf8'),
                                        cert: fs.readFileSync(cert_pem, 'utf8')
                                    }).listen(port_settings[1]);
                                }
                            } else if (typeof value === 'number') {
                                app.initialize(null).listen(value);
                            }
                        });

                        if (default_conf.https) {
                            app.initialize({
                                key: fs.readFileSync(key_pem),
                                cert: fs.readFileSync(cert_pem)
                            }).listen(443);
                        }

                        _log('Server Worker Loaded...');
                    });


                } catch(err) {
                    _log(err.stack || err);
                }
            // }, function(err) {
            //     if (err) {
            //         _log(err.stack || err);
            //     } else _log('Server Worker Loaded...');
            // });
        }
    }
};

ClusterServer.start();
