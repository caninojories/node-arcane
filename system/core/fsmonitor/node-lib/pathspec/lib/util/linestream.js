// Generated by CoffeeScript 1.3.3
(function() {

  module.exports = function(stream) {
    var leftover, result;
    result = new EventEmitter();
    leftover = '';
    stream.setEncoding('utf-8');
    stream.on('data', function(chunk) {
      var line, lines, _i, _len;
      lines = (leftover + chunk).split("\n");
      leftover = lines.pop();
      for (_i = 0, _len = lines.length; _i < _len; _i++) {
        line = lines[_i];
        result.emit('line', line);
      }
    });
    stream.on('end', function() {
      if (leftover) {
        result.emit('line', leftover);
      }
      return result.emit('end');
    });
    return result;
  };

}).call(this);
