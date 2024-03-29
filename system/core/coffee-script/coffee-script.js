// Generated by IcedCoffeeScript 108.0.8
(function() {
  var Lexer, SourceMap, compile, ext, formatSourcePosition, fs, getSourceMap, helpers, iced_runtime, iced_transform, lexer, parser, path, sourceMaps, vm, withPrettyErrors, _base, _i, _len, _ref,
    __hasProp = {}.hasOwnProperty,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  fs = require('fs');

  vm = require('vm');

  path = require('path');

  Lexer = require('./lexer').Lexer;

  parser = require('./parser').parser;

  helpers = require('./helpers');

  SourceMap = require('./sourcemap').SourceMap;

  iced_transform = require('./iced').transform;

  iced_runtime = require('../iced-runtime');

  exports.VERSION = '108.0.8';

  exports.FILE_EXTENSIONS = ['.coffee', '.litcoffee', '.coffee.md', '.iced', '.liticed', '.iced.md'];

  exports.helpers = helpers;

  withPrettyErrors = function(fn) {
    return function(code, options) {
      var err;
      if (options == null) {
        options = {};
      }
      try {
        return fn.call(this, code, options);
      } catch (_error) {
        err = _error;
        throw helpers.updateSyntaxError(err, code, options.filename);
      }
    };
  };

  exports.compile = compile = withPrettyErrors(function(code, options) {
    var answer, currentColumn, currentLine, extend, fragment, fragments, header, js, map, merge, newLines, _i, _len;
    merge = helpers.merge, extend = helpers.extend;
    options = extend({}, options);
    if (options.sourceMap) {
      map = new SourceMap;
    }
    fragments = (iced_transform(parser.parse(lexer.tokenize(code, options)), options)).compileToFragments(options);
    currentLine = 0;
    if (options.header) {
      currentLine += 1;
    }
    if (options.shiftLine) {
      currentLine += 1;
    }
    currentColumn = 0;
    js = "";
    for (_i = 0, _len = fragments.length; _i < _len; _i++) {
      fragment = fragments[_i];
      if (options.sourceMap) {
        if (fragment.locationData) {
          map.add([fragment.locationData.first_line, fragment.locationData.first_column], [currentLine, currentColumn], {
            noReplace: true
          });
        }
        newLines = helpers.count(fragment.code, "\n");
        currentLine += newLines;
        if (newLines) {
          currentColumn = fragment.code.length - (fragment.code.lastIndexOf("\n") + 1);
        } else {
          currentColumn += fragment.code.length;
        }
      }
      js += fragment.code;
    }
    if (options.header) {
      header = "Generated by IcedCoffeeScript " + this.VERSION;
      js = "// " + header + "\n" + js;
    }
    if (options.sourceMap) {
      answer = {
        js: js
      };
      answer.sourceMap = map;
      answer.v3SourceMap = map.generate(options, code);
      return answer;
    } else {
      return js;
    }
  });

  exports.tokens = withPrettyErrors(function(code, options) {
    return lexer.tokenize(code, options);
  });

  exports.nodes = withPrettyErrors(function(source, options) {
    var ast;
    if (typeof source === 'string') {
      ast = parser.parse(lexer.tokenize(source, options));
    } else {
      ast = parser.parse(source);
    }
    if (!options.noIcedTransform) {
      ast = iced_transform(ast, options);
    }
    return ast;
  });

  exports.run = function(code, options) {
    var answer, dir, mainModule, _ref;
    if (options == null) {
      options = {};
    }
    mainModule = require.main;
    mainModule.filename = process.argv[1] = options.filename ? fs.realpathSync(options.filename) : '.';
    mainModule.moduleCache && (mainModule.moduleCache = {});
    dir = options.filename ? path.dirname(fs.realpathSync(options.filename)) : fs.realpathSync('.');
    mainModule.paths = require('module')._nodeModulePaths(dir);
    if (!helpers.isCoffee(mainModule.filename) || require.extensions) {
      options.runtime = "interp";
      answer = compile(code, options);
      code = (_ref = answer.js) != null ? _ref : answer;
    }
    return mainModule._compile(code, mainModule.filename);
  };

  exports["eval"] = function(code, options) {
    var Module, Script, js, k, o, r, sandbox, v, _i, _len, _module, _ref, _ref1, _require;
    if (options == null) {
      options = {};
    }
    if (!(code = code.trim())) {
      return;
    }
    Script = vm.Script;
    if (Script) {
      if (options.sandbox != null) {
        if (options.sandbox instanceof Script.createContext().constructor) {
          sandbox = options.sandbox;
        } else {
          sandbox = Script.createContext();
          _ref = options.sandbox;
          for (k in _ref) {
            if (!__hasProp.call(_ref, k)) continue;
            v = _ref[k];
            sandbox[k] = v;
          }
        }
        sandbox.global = sandbox.root = sandbox.GLOBAL = sandbox;
      } else {
        sandbox = global;
      }
      sandbox.__filename = options.filename || 'eval';
      sandbox.__dirname = path.dirname(sandbox.__filename);
      if (!(sandbox !== global || sandbox.module || sandbox.require)) {
        Module = require('module');
        sandbox.module = _module = new Module(options.modulename || 'eval');
        sandbox.require = _require = function(path) {
          return Module._load(path, _module, true);
        };
        _module.filename = sandbox.__filename;
        _ref1 = Object.getOwnPropertyNames(require);
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          r = _ref1[_i];
          if (r !== 'paths') {
            _require[r] = require[r];
          }
        }
        _require.paths = _module.paths = Module._nodeModulePaths(process.cwd());
        _require.resolve = function(request) {
          return Module._resolveFilename(request, _module);
        };
      }
    }
    o = {};
    for (k in options) {
      if (!__hasProp.call(options, k)) continue;
      v = options[k];
      o[k] = v;
    }
    o.bare = true;
    js = compile(code, o);
    if (sandbox === global) {
      return vm.runInThisContext(js);
    } else {
      return vm.runInContext(js, sandbox);
    }
  };

  exports.register = function() {
    return require('./register');
  };

  if (require.extensions) {
    _ref = this.FILE_EXTENSIONS;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      ext = _ref[_i];
      if ((_base = require.extensions)[ext] == null) {
        _base[ext] = function() {
          throw new Error("Use CoffeeScript.register() or require the coffee-script/register module to require " + ext + " files.");
        };
      }
    }
  }

  exports._compileFile = function(filename, sourceMap, opts_passed) {
    var answer, err, k, opts, raw, stripped, v;
    if (sourceMap == null) {
      sourceMap = false;
    }
    if (opts_passed == null) {
      opts_passed = {};
    }
    raw = fs.readFileSync(filename, 'utf8');
    stripped = raw.charCodeAt(0) === 0xFEFF ? raw.substring(1) : raw;
    opts = {
      filename: filename,
      sourceMap: sourceMap,
      literate: helpers.isLiterate(filename)
    };
    for (k in opts_passed) {
      v = opts_passed[k];
      opts[k] = v;
    }
    try {
      answer = compile(stripped, opts);
    } catch (_error) {
      err = _error;
      throw helpers.updateSyntaxError(err, stripped, filename);
    }
    return answer;
  };

  lexer = new Lexer;

  parser.lexer = {
    lex: function() {
      var tag, token;
      token = this.tokens[this.pos++];
      if (token) {
        tag = token[0], this.yytext = token[1], this.yylloc = token[2];
        this.errorToken = token.origin || token;
        this.yylineno = this.yylloc.first_line;
      } else {
        tag = '';
      }
      return tag;
    },
    setInput: function(tokens) {
      this.tokens = tokens;
      return this.pos = 0;
    },
    upcomingInput: function() {
      return "";
    }
  };

  parser.yy = require('./nodes');

  exports.iced = iced_runtime;

  parser.yy.parseError = function(message, _arg) {
    var errorLoc, errorTag, errorText, errorToken, token, tokens, _ref1;
    token = _arg.token;
    _ref1 = parser.lexer, errorToken = _ref1.errorToken, tokens = _ref1.tokens;
    errorTag = errorToken[0], errorText = errorToken[1], errorLoc = errorToken[2];
    errorText = errorToken === tokens[tokens.length - 1] ? 'end of input' : errorTag === 'INDENT' || errorTag === 'OUTDENT' ? 'indentation' : helpers.nameWhitespaceCharacter(errorText);
    return helpers.throwSyntaxError("unexpected " + errorText, errorLoc);
  };

  formatSourcePosition = function(frame, getSourceMapping) {
    var as, column, fileLocation, fileName, functionName, isConstructor, isMethodCall, line, methodName, source, tp, typeName;
    fileName = void 0;
    fileLocation = '';
    if (frame.isNative()) {
      fileLocation = "native";
    } else {
      if (frame.isEval()) {
        fileName = frame.getScriptNameOrSourceURL();
        if (!fileName) {
          fileLocation = "" + (frame.getEvalOrigin()) + ", ";
        }
      } else {
        fileName = frame.getFileName();
      }
      fileName || (fileName = "<anonymous>");
      line = frame.getLineNumber();
      column = frame.getColumnNumber();
      source = getSourceMapping(fileName, line, column);
      fileLocation = source ? "" + fileName + ":" + source[0] + ":" + source[1] : "" + fileName + ":" + line + ":" + column;
    }
    functionName = frame.getFunctionName();
    isConstructor = frame.isConstructor();
    isMethodCall = !(frame.isToplevel() || isConstructor);
    if (isMethodCall) {
      methodName = frame.getMethodName();
      typeName = frame.getTypeName();
      if (functionName) {
        tp = as = '';
        if (typeName && functionName.indexOf(typeName)) {
          tp = "" + typeName + ".";
        }
        if (methodName && functionName.indexOf("." + methodName) !== functionName.length - methodName.length - 1) {
          as = " [as " + methodName + "]";
        }
        return "" + tp + functionName + as + " (" + fileLocation + ")";
      } else {
        return "" + typeName + "." + (methodName || '<anonymous>') + " (" + fileLocation + ")";
      }
    } else if (isConstructor) {
      return "new " + (functionName || '<anonymous>') + " (" + fileLocation + ")";
    } else if (functionName) {
      return "" + functionName + " (" + fileLocation + ")";
    } else {
      return fileLocation;
    }
  };

  sourceMaps = {};

  getSourceMap = function(filename) {
    var answer, _ref1;
    if (sourceMaps[filename]) {
      return sourceMaps[filename];
    }
    if (_ref1 = path != null ? path.extname(filename) : void 0, __indexOf.call(exports.FILE_EXTENSIONS, _ref1) < 0) {
      return;
    }
    answer = exports._compileFile(filename, true);
    return sourceMaps[filename] = answer.sourceMap;
  };

  Error.prepareStackTrace = function(err, stack) {
    var frame, frames, getSourceMapping;
    getSourceMapping = function(filename, line, column) {
      var answer, sourceMap;
      sourceMap = getSourceMap(filename);
      if (sourceMap) {
        answer = sourceMap.sourceLocation([line - 1, column - 1]);
      }
      if (answer) {
        return [answer[0] + 1, answer[1] + 1];
      } else {
        return null;
      }
    };
    frames = (function() {
      var _j, _len1, _results;
      _results = [];
      for (_j = 0, _len1 = stack.length; _j < _len1; _j++) {
        frame = stack[_j];
        if (frame.getFunction() === exports.run) {
          break;
        }
        _results.push("  at " + (formatSourcePosition(frame, getSourceMapping)));
      }
      return _results;
    })();
    return "" + (err.toString()) + "\n" + (frames.join('\n')) + "\n";
  };

}).call(this);
