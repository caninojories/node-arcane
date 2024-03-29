// Generated by CoffeeScript 1.3.3
(function() {
  var RelPathList, assert, o, tests;

  assert = require('assert');

  RelPathList = require('../index').RelPathList;

  tests = [];

  o = function(spec, examples) {
    return tests.push([spec, examples]);
  };

  o('foo.txt', ['foo.txt', '!bar.txt', 'some/dir/foo.txt', 'foo.txt/another.js']);

  o('*.txt', ['foo.txt', 'some/dir/foo.txt', '!foo.js']);

  o('*', ['qwerty.txt', 'some/dir/qwerty.txt']);

  o('some/dir/*', ['some/dir/qwerty.txt', '!some/dir', 'some/dir/subdir/qwerty.txt', '!elsewhere/qwerty.txt']);

  o('/some', ['some', 'some/qwerty.txt', 'some/subdir/qwerty.txt', '!another', '!another/qwerty.txt']);

  o('*.txt !some/dir', ['qwerty.txt', 'another/qwerty.txt', 'some/qwerty.txt', '!some/dir/qwerty.txt', '!some/dir/subdir/qwerty.txt', '!another.js', 'dir.txt/qwerty.js', '!some/dir/subdir.txt/qwerty.js', 'some/directly/notexcluded.txt', 'some/directly.txt']);

  describe("RelPathList", function() {
    var examples, specStr, _i, _len, _ref, _results;
    _results = [];
    for (_i = 0, _len = tests.length; _i < _len; _i++) {
      _ref = tests[_i], specStr = _ref[0], examples = _ref[1];
      _results.push((function(specStr, examples) {
        return describe("like '" + specStr + "'", function() {
          var example, spec, _j, _len1, _results1;
          spec = RelPathList.parse(specStr.split(' '));
          _results1 = [];
          for (_j = 0, _len1 = examples.length; _j < _len1; _j++) {
            example = examples[_j];
            _results1.push((function(example) {
              if (example[0] === '!') {
                example = example.substr(1);
                return it("should not match '" + example + "'", function() {
                  return assert.ok(!spec.matches(example));
                });
              } else {
                return it("should match '" + example + "'", function() {
                  return assert.ok(spec.matches(example));
                });
              }
            })(example));
          }
          return _results1;
        });
      })(specStr, examples));
    }
    return _results;
  });

}).call(this);
