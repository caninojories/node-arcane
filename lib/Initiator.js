var shell = require('shelljs'),
    fs = require('fs'),
    vh_values = {},
    htaccess = {

    },
    multiports = [];

// var arc_system_location = '/var/arcane';
var arc_system_location = (process.env[(process.platform == 'win32') ? 'USERPROFILE' : 'HOME']) + '/.arcane';

Object.defineProperty(global, '__userdir', {
    get: function() {
        return process.env[(process.platform == 'win32') ? 'USERPROFILE' : 'HOME'];
    }
});

var last_access = {
    vhost: {
        mtime: null,
        value: {}
    },
    hta: {
        mtime: null,
        value: {}
    },
    ports: {
        mtime: null,
        value: {}
    }
};
Object.defineProperty(global, '__arc_engine', {
    get: function() {
        if (shell.ls('-A', __userdir).indexOf('.arcane') == -1) {
            shell.mkdir(arc_system_location);
            fs.writeFileSync(arc_system_location + '/vhost.json', JSON.stringify(vh_values));
            fs.writeFileSync(arc_system_location + '/htaccess.json', JSON.stringify(htaccess));
            fs.writeFileSync(arc_system_location + '/multiports.json', JSON.stringify(multiports));
        }

        var vhost_time = (fs.lstatSync(arc_system_location + '/vhost.json').mtime / 1000);
        var htacc_time = (fs.lstatSync(arc_system_location + '/htaccess.json').mtime / 1000);
        var ports_time = (fs.lstatSync(arc_system_location + '/multiports.json').mtime / 1000);

        if (last_access.vhost.mtime !== vhost_time) {
            last_access.vhost.value = JSON.parse(shell.cat(arc_system_location + '/vhost.json'));
            last_access.vhost.mtime = vhost_time;
        }

        if (last_access.hta.mtime !== vhost_time) {
            last_access.hta.value = JSON.parse(shell.cat(arc_system_location + '/htaccess.json'));
            last_access.hta.mtime = vhost_time;
        }

        if (last_access.ports.mtime !== ports_time) {
            last_access.ports.value = JSON.parse(shell.cat(arc_system_location + '/multiports.json'));
            last_access.ports.mtime = ports_time;
        }

        return {
            vhost: last_access.vhost.value,
            htaccess: last_access.hta.value,
            ports: last_access.ports.value
        };
    }
});

module.exports = {};
