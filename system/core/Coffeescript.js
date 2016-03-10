var Lexer = require('./coffee-script/lexer').Lexer,
  CSparser = require('./coffee-script/parser').parser,
  helpers = require('./coffee-script/helpers'),
  SourceMap = require('./coffee-script/sourcemap').SourceMap,
  fs = require('fs'),
  path = require('path');

var iced_transform = require('./coffee-script/iced').transform;
var iced_runtime = require('./iced-runtime');

var indexOf = [].indexOf || function(item) {
  for (var i = 0, l = this.length; i < l; i++) {
    if (i in this && this[i] === item) return i;
  }
  return -1;
};

var FILE_EXTENSIONS = ['.coffee', '.litcoffee', '.coffee.md'];

var lexer = new Lexer;

var withPrettyErrors = function(fn) {
  return function(code, options) {
    var err;
    if (options == null) {
      options = {};
    }
    try {
      return fn.call(this, code, options);
    } catch (_error) {
      err = _error;
      if (typeof code !== 'string') {
        throw err;
      }
      throw helpers.updateSyntaxError(err, code, options.filename);
    }
  };
};

//var encrypt = require(__dirname + '/../../lib/Encryption.js');
var code_list = {};

var crypto = require('crypto')
var fs = require('fs')

var encrypt = function(code) {
  var sum = crypto.createHash('md5')
  sum.update(code)
  return sum.digest('hex')
}

var find_project_dir = function(filename) {
  var target_project = '';
  for (var i in __arc_engine.vhost) {
    if ((new RegExp('^' + escapeRegExp(__arc_engine.vhost[i].DocumentRoot), 'g')).test(filename)) {
      target_project = __arc_engine.vhost[i].DocumentRoot;
      break;
    }
  }
  return target_project;
}

var scan_libraries = function(dirname, data, ret) {
  var _ret = '';
/*  if(ret) {
    _ret = ret;
  }*/

  if(data[data.length -1] === '*') {
    data.pop();
    var directory = dirname + '/' + data.join('/');
    var list = null;

    try {
      list = fs.readdirSync(directory);
    } catch(err) {
      list = fs.readdirSync(require('path').resolve(__dirname + '/../libraries/' + data.join('/')));
      directory = __dirname + '/../libraries/' + data.join('/');
    }

    for(var i in list) {
      var f_name = list[i].replace(/.coffee$|.js$/g, '');
      if(fs.lstatSync(directory + '/' + list[i]).isDirectory()) {
        data.push(f_name);
        data.push('*');
        if(ret) {
          _ret += f_name + ' : {';
        } else {
          _ret += f_name + ' = {';
        }
        _ret += scan_libraries(directory, data, _ret);
        _ret += '}, '
        data.pop();
        // data.pop();
      } else if(fs.lstatSync(directory + '/' + list[i]).isFile()) {
        if(ret) {
          _ret += f_name + ' :';
        } else {
          _ret += f_name + ' =';
        }
        _ret += ' __require("' + directory + '/' + list[i] + '", { error: "Unable  to find library \'' + data.join('.') + '/' + list[i] + '\'." }), ';
      }
    }

    return _ret.replace(/\,\s$/g, '');
  } else {
    return data[data.length - 1] + ' = __require "' + library_check(dirname, data.join('.')) + '", { error: "Unable  to find library \'' + data.join('.') + '\'." }';
  }
};

var code_replacer = function(code, options) {
  //code = code.replace(/(import|package)\s([a-zA-Z0-9\.\-\_]*)?\n/g, '\n');

  var splited_code = code.split('\n');
  var codes = [];
  for(var line in splited_code) {
    codes.push(splited_code[line].replace(/^\#\!import\s.*/g, function(match) {

      var regex = /^\#\!import\s(.+?)\sin\s([^\s]*|[^#]*|[^$]*)|\#\!import\s([^\s]*|[^#]*|[^$]*)/g.exec(match), ret = '';

      if(regex) {

        if(regex[1] && regex[2]) {
			  var vname = regex[2].trim().split('.');
			  var var_list = regex[1].split(',');
			  var var_name_list = [];
			  for(var i in var_list) {
				   var_name_list.push("'" + var_list[i] + "'");
			  }

			  if(vname[vname.length - 1] === '*') {
				//  ret =  vname[vname.length - 2] + ' = { ' + scan_libraries(find_project_dir(options.filename) + '/libraries', vname, true) + '}';
			  } else {
				 ___require = '__require("' + library_check(options.filename, regex[2].trim()) + '", { error: "Unable  to find library \'' + regex[2].trim() + '\'." })';
				 ret = '[' + regex[1] + ']' + ' = (___obj[___v.trim()] for ___v in [' + var_name_list.join(', ') + '] when ___obj[___v.trim()]? if ___obj = ' + ___require + ')';
				// console.log(ret);
			  }


         //  console.log(regex[1], regex[2]);

        } else if(regex[3]) {
          var vname = regex[3].trim().split('.');

          if(vname[0] === 'model' && vname[1] !== 'ModelComparators') {
            ret = vname[vname.length - 1] + ' = __model.' + vname[vname.length - 1];
          } else {
            if(vname[vname.length - 1] === '*') {
              ret =  vname[vname.length - 2] + ' = { ' + scan_libraries(find_project_dir(options.filename) + '/libraries', vname, true) + '}';
            } else {
              ret = vname[vname.length - 1].replace(/\-([a-zA-Z])/g, function(match) {  return match.replace(/^\-/g, '').toUpperCase(); }) + ' = __require "' + library_check(options.filename, regex[3].trim()) + '", { error: "Unable  to find library \'' + regex[3].trim() + '\'." }';
            }
          }
        }

      }

      // var regex = /import\s([^#]*)#/g.exec(match),
      //     ret = '';

      // if(!regex) {
      //   regex = /import\s([^$]*)$/g.exec(match);
      // }

      // if(regex) {
      //   var vname = regex[1].trim().split('.');
      //   if(vname[vname.length - 1] === '*') {
      //     ret =  vname[vname.length - 2] + ' = { ' + scan_libraries(find_project_dir(options.filename) + '/libraries', vname, true) + '}';
      //   } else {
      //     ret = vname[vname.length - 1].replace(/\-([a-zA-Z])/g, function(match) {  return match.replace(/^\-/g, '').toUpperCase(); }) + ' = __require "' + library_check(options.filename, regex[1].trim()) + '", { error: "Unable  to find library \'' + regex[1].trim() + '\'." }';
      //   }
      // }

      return ret;
    }));
  }
  code = codes.join('\n');



  var last_to_code = '';
  codes = [];
  splited_code = code.split('\n');
  for(var line in splited_code) {
    codes.push(splited_code[line].replace(/^\#\!package(\sexport|)\s([a-zA-Z0-9\.\-\_]+)?(\s(.*)|)$/g, function(match) {
      var regex = /\#\!package(\sexport|)\s([a-zA-Z0-9\.\-\_]+)?(\s(.*)|)$/g.exec(match),
        ret = '';
      if (regex) {
        var vname = regex[2].split('.');
        /*last_to_code = '\n\nmodule.export ' + vname[vname.length - 1];*/
        last_to_code = '\n\nreturn [' + vname[vname.length - 1] + ', ' + (regex[1].length ? true : false) + ']';
      }
      return '# package';
    }));
  }
  code = codes.join('\n');

  code += last_to_code;
  return code;
}

module.exports.parse = compile = withPrettyErrors(function(code, options) {
  var answer, currentColumn, currentLine, extend, fragment, fragments, header, i, js, len, map, merge, newLines, token, tokens;
  merge = helpers.merge, extend = helpers.extend;
  options = extend({}, options);

  code = code_replacer(code, options);

  //if(options.filename && /WObject/g.test(options.filename) ) console.log(code);

  // var encrypt_md5 = (options.hasOwnProperty('filename') ? options.filename + ':' : '') + encrypt((options.hasOwnProperty('filename') ? options.filename + ':' : '') + code);

  // if (typeof code_list[encrypt_md5] !== 'undefined' && code_list[encrypt_md5] !== null) {
  //   return code_list[encrypt_md5];
  // } else if (options.sourceMap && typeof code_list[encrypt_md5 + ':source_map'] !== 'undefined' && code_list[encrypt_md5 + ':source_map'] !== null) {
  //   return code_list[encrypt_md5 + ':source_map'];
  // }

  if (options.sourceMap) {
    map = new SourceMap;
  }
  tokens = lexer.tokenize(code, options);
  options.referencedVars = (function() {
    var i, len, results;
    results = [];
    for (i = 0, len = tokens.length; i < len; i++) {
      token = tokens[i];
      if (token.variable) {
        results.push(token[1]);
      }
    }
    return results;
  })();
  //fragments = CSparser.parse(tokens).compileToFragments(options);
  fragments = (iced_transform(CSparser.parse(lexer.tokenize(code, options)), options)).compileToFragments(options);
  currentLine = 0;
  if (options.header) {
    currentLine += 1;
  }
  if (options.shiftLine) {
    currentLine += 1;
  }
  currentColumn = 0;
  js = "";

  for (i = 0, len = fragments.length; i < len; i++) {
    fragment = fragments[i];
    if (options.sourceMap) {
      if (fragment.locationData && !/^[;\s]*$/.test(fragment.code)) {
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
  /*if (options.header) {
    header = "Generated by CoffeeScript " + this.VERSION;
    js = "// " + header + "\n" + js;
  }*/

  if (options.sourceMap) {
    //code_list[encrypt_md5 + ':source_map'] = answer;
    answer = {
      js: js
    };
    answer.sourceMap = map;
    answer.v3SourceMap = map.generate(options, code);
    return answer;
  } else {
    //code_list[encrypt_md5] = js;
    return js;
  }
});


var escapeRegExp = function(str) {
  return str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&");
};

var library_check = function(filename, data) {
  var target_project = find_project_dir(filename),
    target_file = data.replace(/^\.+/g, '').replace(/\.+$/g, '').replace(/\./g, '/');
  return library_check_file(target_project, target_file);
};

var library_check_file = function(target_project, target_file) {
  var ret = target_file;
  try {
      require.resolve('./' + target_file);
      ret = './' + target_file;
  } catch(e) {
      try {
        require.resolve(target_file);
        ret = target_file;
      } catch(e2) {
        if (fs.existsSync(target_project + '/libraries/' + target_file + '.coffee')) {
          ret = target_project + '/libraries/' + target_file + '.coffee';
        } else if (fs.existsSync(target_project + '/libraries/' + target_file + '.js')) {
          ret = target_project + '/libraries/' + target_file + '.js';
        } else if (fs.existsSync(target_project + '/libraries/' + target_file + '/index.coffee')) {
          ret = target_project + '/libraries/' + target_file + '/index.coffee';
        } else if (fs.existsSync(target_project + '/libraries/' + target_file + '/index.js')) {
          ret = target_project + '/libraries/' + target_file + '/index.js';
        } else if (fs.existsSync(__dirname + '/../libraries/' + target_file + '.coffee')) {
          ret = __dirname + '/../libraries/' + target_file + '.coffee';
        } else if (fs.existsSync(__dirname + '/../libraries/' + target_file + '.js')) {
          ret = __dirname + '/../libraries/' + target_file + '.js';
        } else if (fs.existsSync(__dirname + '/../libraries/' + target_file + '/index.coffee')) {
          ret = __dirname + '/../libraries/' + target_file + '/index.coffee';
        } else if (fs.existsSync(__dirname + '/../libraries/' + target_file + '/index.js')) {
          ret = __dirname + '/../libraries/' + target_file + '/index.js';
        } else {
          ret = target_file;
        }
      }
  }
  return ret;
}

module.exports.run = runScript = function(code, options) {
  var answer, dir, mainModule, ref, _exports = {};
  if (options == null) {
    options = {};
  }
  mainModule = require.main;
  mainModule.filename = process.argv[1] = options.filename ? fs.realpathSync(options.filename) : '.';
  mainModule.moduleCache && (mainModule.moduleCache = {});
  dir = options.filename ? path.dirname(fs.realpathSync(options.filename)) : fs.realpathSync('.');
  mainModule.paths = require('module')._nodeModulePaths(dir);
  if (!helpers.isCoffee(mainModule.filename) || require.extensions) {
    //code = code_replacer(code, options);
    answer = compile(code, options);
    code = (ref = answer.js) != null ? ref : answer;
  }
  var _exports = mainModule._compile(code, mainModule.filename);
  if(_exports) {
    return _exports[1] ? _exports[0] : new _exports[0];
  } else {
    return {};
  }
};

/*module.exports._compileFile = function(filename, sourceMap) {
  var answer, err, raw, stripped;
  if (sourceMap == null) {
    sourceMap = false;
  }
  raw = fs.readFileSync(filename, 'utf8');
  stripped = raw.charCodeAt(0) === 0xFEFF ? raw.substring(1) : raw;
  stripped = code_replacer(stripped, {filename: filename});
  try {
    answer = compile(stripped, {
      filename: filename,
      sourceMap: sourceMap,
      literate: helpers.isLiterate(filename)
    });
  } catch (_error) {
    err = _error;
    throw helpers.updateSyntaxError(err, stripped, filename);
  }
  return answer;
};*/

module.exports._compileFile = function(filename, sourceMap, opts_passed) {
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

module.exports.include = function(filename, options) {
  var raw = fs.readFileSync(filename, 'utf8');
  var stripped = raw.charCodeAt(0) === 0xFEFF ? raw.substring(1) : raw;
  var result;
  try {
    result = runScript(stripped, {
      filename: filename,
      literate: helpers.isLiterate(filename),
      opt: options || {}
    })
  } catch (err) {
    throw helpers.updateSyntaxError(err, stripped, filename);
  }
  return result;
};

CSparser.lexer = {
  lex: function() {
    var tag, token;
    token = CSparser.tokens[this.pos++];
    if (token) {
      tag = token[0], this.yytext = token[1], this.yylloc = token[2];
      CSparser.errorToken = token.origin || token;
      this.yylineno = this.yylloc.first_line;
    } else {
      tag = '';
    }
    return tag;
  },
  setInput: function(tokens) {
    CSparser.tokens = tokens;
    return this.pos = 0;
  },
  upcomingInput: function() {
    return "";
  }
};

CSparser.yy = require('./coffee-script/nodes');

CSparser.yy.parseError = function(message, arg) {
  var errorLoc, errorTag, errorText, errorToken, token, tokens;
  token = arg.token;
  errorToken = CSparser.errorToken, tokens = CSparser.tokens;
  errorTag = errorToken[0], errorText = errorToken[1], errorLoc = errorToken[2];
  errorText = (function() {
    switch (false) {
      case errorToken !== tokens[tokens.length - 1]:
        return 'end of input';
      case errorTag !== 'INDENT' && errorTag !== 'OUTDENT':
        return 'indentation';
      case errorTag !== 'IDENTIFIER' && errorTag !== 'NUMBER' && errorTag !== 'STRING' && errorTag !== 'STRING_START' && errorTag !== 'REGEX' && errorTag !== 'REGEX_START':
        return errorTag.replace(/_START$/, '').toLowerCase();
      default:
        return helpers.nameWhitespaceCharacter(errorText);
    }
  })();
  return helpers.throwSyntaxError("unexpected " + errorText, errorLoc);
};

sourceMaps = {};

getSourceMap = function(filename) {
  var answer, ref1;
  if (sourceMaps[filename]) {
    return sourceMaps[filename];
  }
  if (ref1 = path != null ? path.extname(filename) : void 0, indexOf.call(FILE_EXTENSIONS, ref1) < 0) {
    return;
  }
  answer = exports._compileFile(filename, true);
  return sourceMaps[filename] = answer.sourceMap;
};

var formatSourcePosition = function(frame, getSourceMapping) {
  var as, column, fileLocation, fileName, functionName, isConstructor, isMethodCall, line, methodName, source, tp, typeName;
  fileName = void 0;
  fileLocation = '';
  if (frame.isNative()) {
    fileLocation = "native";
  } else {
    if (frame.isEval()) {
      fileName = frame.getScriptNameOrSourceURL();
      if (!fileName) {
        fileLocation = (frame.getEvalOrigin()) + ", ";
      }
    } else {
      fileName = frame.getFileName();
    }
    fileName || (fileName = "<anonymous>");
    line = frame.getLineNumber();
    column = frame.getColumnNumber();
    source = getSourceMapping(fileName, line, column);
    fileLocation = source ? fileName + ":" + source[0] + ":" + source[1] : fileName + ":" + line + ":" + column;
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
        tp = typeName + ".";
      }
      if (methodName && functionName.indexOf("." + methodName) !== functionName.length - methodName.length - 1) {
        as = " [as " + methodName + "]";
      }
      return "" + tp + functionName + as + " (" + fileLocation + ")";
    } else {
      return typeName + "." + (methodName || '<anonymous>') + " (" + fileLocation + ")";
    }
  } else if (isConstructor) {
    return "new " + (functionName || '<anonymous>') + " (" + fileLocation + ")";
  } else if (functionName) {
    return functionName + " (" + fileLocation + ")";
  } else {
    return fileLocation;
  }
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
    var j, len1, results;
    results = [];
    for (j = 0, len1 = stack.length; j < len1; j++) {
      frame = stack[j];
      if (frame.getFunction() === exports.run) {
        break;
      }
      results.push("  at " + (formatSourcePosition(frame, getSourceMapping)));
    }
    return results;
  })();
  return (err.toString()) + "\n" + (frames.join('\n')) + "\n";
};
