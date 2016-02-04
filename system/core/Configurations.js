var fs = require('fs'),
    is_init = false;

var config = {
    scan: function(dir, target) {
        var file_list = fs.readdirSync(dir);
        for (var i in file_list) {
            try {
                var tmp = __require(dir + '/' + file_list[i]);
                if (typeof tmp === 'object') {
                    for (var v in tmp) {
                        for (var o in tmp[v])
                            config.set(v, o, tmp[v][o], dir, tmp);
                    }
                }
            } catch (err) {
                console.log('ERROR: @config ' + dir + '/' + file_list[i]);
                console.log(err.stack);
            }
        }
    },
    set: function(group, name, value, dir, obj) {
        if (typeof this.config[group] === 'undefined') {
            this.config[group] = {
                '@dir': dir,
                '@obj': obj
            };
        }

        if (group === 'route') {
            name = name.replace(/\s+/g, ' ');
            name = name.replace(/^([a-zA-Z]+?)\s/, function($1) {
                return $1.toUpperCase();
            });
        }

        this.config[group][name] = value;
    },
    get: function(group, name) {
        if (typeof this.config[group] !== 'undefined' &&
            typeof this.config[group][name] !== 'undefined') {
            return this.config[group][name];
        }
        return null;
    },
    all: function(group) {
        if (typeof this.config[group] !== 'undefined') {
            return this.config[group];
        }
        return {};
    },
    clear: function(group) {
        if (typeof this.config[group] !== 'undefined') {
            delete this.config[group];
        }
    }
};

module.exports = function() {
    if (!is_init) {
        config.config = {};
        is_init = true;
    }
    config.scan(__dirname + '/../../config');
    return config;
};