// Generated by IcedCoffeeScript 1.7.1-f
(function() {
  var FSMonitor;

  FSMonitor = require('./monitor');

  exports.watch = function(root, filter, options, listener) {
    var monitor;
    if (typeof options === 'function') {
      listener = options;
      options = {};
    }
    monitor = new FSMonitor(root, filter, options);
    if (listener) {
      monitor.on('change', listener);
    }
    return monitor;
  };

  exports.version = '0.2.4';

}).call(this);
