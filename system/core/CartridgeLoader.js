var sync = require('../../lib/sync'),
    Lister = require(__dirname + '/CartridgeLister.js'),
    libpath = require('path').resolve(__dirname, '..', 'cartridge'),
    fs = require('fs'),
    carlt = fs.readdirSync(libpath),
    cartridge_stats = {};

for (var x in carlt) {
    var cartridge_m = carlt[x].replace(/Cartridge.js$|Cartridge$/g, '').toLowerCase();
    if (!carlt[x].match(/Cartridge(\.js|)$/g)) continue;
    if (fs.lstatSync(libpath + '/' + carlt[x]).isDirectory()) {
        cartridge_stats['$' + cartridge_m] = {
            type: 'directory',
            module: require(libpath + '/' + carlt[x]),
            file: libpath + '/' + carlt[x]
        };
    } else if (fs.lstatSync(libpath + '/' + carlt[x]).isFile()) {
        cartridge_stats['$' + cartridge_m] = {
            type: 'file',
            module: require(libpath + '/' + carlt[x]),
            file: libpath + '/' + carlt[x]
        };
    }
}

var createSync = function() {
    var self = this;
    return function(callback) {
        delete self.sync;
        self.sync = null;
        self.resolve = callback;
    };
};

var imports = function(sub_modules, callback) {
    var self = this;
    sync(function() {
        var cartridge_list = sub_modules || self.store.$server.cartridge,
            ret = [];

        for (var i in cartridge_list) {
            var modlist = cartridge_list[i][1],
                args = [],
                tmp_ret = null;

            for (var j in modlist) {
                if (typeof self.store[modlist[j]] !== 'undefined') {
                    args.push(self.store[modlist[j]]);
                } else {
                    args.push(loadCartridge.sync(self, modlist[j]));
                }
            }

            if(self.store.$res._finished) {
                break;
            }

            if(self.store.$stack) {
                self.store.$stack.push(cartridge_list[i][2]);
            } 

            //console.time( '>>>>>>>>>>>>> ' + cartridge_list[i][2]);
            var start_time = new Date();

            self.sync = createSync.call(self);
            self.name = cartridge_list[i][2];
            sync.sync(null, function() {
                tmp_ret = cartridge_list[i][0].apply(cartridge_list[i][4] || self, args);
            });
            delete self.name;

            if (!self.sync && self.resolve) {
                tmp_ret = sync.sync(null, self.resolve);
                delete self.resolve;
            } else {
                delete self.sync;
                self.sync = null;
            }

            //console.timeEnd( '>>>>>>>>>>>>> ' + cartridge_list[i][2]);
            
            if(self.store.$stime) {
                self.store.$stime[cartridge_list[i][2]] = (new Date()) - start_time;
            }

            ret.push(tmp_ret);

            if(cartridge_list[i][3] && typeof cartridge_list[i][3] === 'function') {
                cartridge_list[i][3].call(null, tmp_ret);
            }
        }

        return ret;
    }, callback);
};

var loadCartridge = function(mod, callback) {
    var self = this;
    if (typeof cartridge_stats[mod] !== 'undefined') {
        if (typeof cartridge_stats[mod].module === 'function') {
            var args = Lister.getParamNames(cartridge_stats[mod].module);
            imports.call(this, [
                [cartridge_stats[mod].module, args, mod.replace(/^\$/g, '')]
            ], function(err, result) {
                //if(err) console.log(err.stack);
                self.store[mod] = result ? result[0] : null;
                callback(err, result ? result[0] : null);
            });
        } else {
            callback(null, cartridge_stats[mod].module);
        }
    } else {
        //log invalid parameter for cartridge
        callback(null, false);
    }
};

var untilExtended = function(callback) {
    var extended = this.extended.slice(),
        self = this;
    this.extended = [];
    imports.call(this, extended, function(err, result) {
        if(err) {
            callback(err);
            return;
        }
        if(self.extended.length !== 0) {
            untilExtended.call(self, callback);
        } else callback(err, result);
    });
};

var Cartridge = module.exports = function(_cartridge, _parent) {
    var self = this;
    this.store = _cartridge || (_parent ? _parent.store : {}) || {};
    this.store.$app = this;
    this.store.$sync = sync;
    this.extended = [];
};

Cartridge.prototype.use = function(callback, finish, _class) {
    var args = Lister.getParamNames(callback);
    this.extended.push([callback, args, null, finish || function() { return undefined; }, _class]);
};

Cartridge.prototype.load = function(callback) {
    var self = this;
    imports.call(this, null, function(err, result) {
        if(err) {
            callback(err, null);
            return;
        } 
        untilExtended.call(self, callback);
    });
};