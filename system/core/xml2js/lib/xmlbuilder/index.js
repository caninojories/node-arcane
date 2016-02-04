// Generated by CoffeeScript 1.9.1
(function() {
  var XMLBuilder, assign;

  assign = require(__dirname + '/../lodash/object/assign');

  XMLBuilder = require('./XMLBuilder');

  module.exports.create = function(name, xmldec, doctype, options) {
    options = assign({}, xmldec, doctype, options);
    return new XMLBuilder(name, options).root();
  };

}).call(this);
