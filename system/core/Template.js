var fs = require('fs'),
    sync = require('../../lib/sync'),
    path = require('path'),
    coffeescript = require('./Coffeescript').parse,
    entities = new(require(__dirname + '/html-entities').AllHtmlEntities)(),
    _PREFIX = '?',
    _REGEX_STRING = '(<\\?\\?|<\\?=|<\\?-|<\\?#|<\\?|\\?>|-\\?>|\\{\\{|\\}\\}|\\{\\%|\\%\\})',
    _REGEX_STRING_CONDITION = '(^if\\s|^while\\s|^for\\s)',
    _REGEX_STRING_CONDITION_DUP = '(^endif|^endwhile|^endfor)';

var cache_template = {};

var Template = function(data, directory, interpolate) {
    this.is_end = false;
    this.data = data;
    this.path = directory;
	 this.interpolate = interpolate
};

var TemplateParseError = function(err, source, raw_source, filename) {
    var err_split = err.split('\n'),
        i,
        source_split = source.split('\n'),
        regex = null,
        row = 0,
        col = 0;

    for (i = 0; i < err_split.length; i++) {
        if (/evalmachine\.\<anonymous\>/g.test(err_split[i])) {
            regex = /evalmachine\.\<anonymous\>\:([0-9]+?)\:([0-9]+?)/g.exec(err_split[i]);
            if (!regex) {
                regex = /evalmachine\.\<anonymous\>\:([0-9]*)/g.exec(err_split[i]);
            }
            row = Number(regex[1]);
            col = Number(regex[2]);
            break;
        }
    }

    var error_msg = 0;
    for (i = 0; i < err_split.length; i++) {
        if (/^(?:\s|)[a-zA-Z]*\:/g.test(err_split[i])) {
            error_msg = i;
            break;
        }
    }


    var k, is_init = false,
        nlcounter = 1,
        deduct_count = 0,
        lock_deduct = false;

    for (k = 0; k < source_split.length; k++) {
        if (!is_init) {
            if (/var\s__output\s\=\s''\;/g.test(source_split[k])) {
                is_init = true;
            }
        } else {
            if (row === k) {
                break;
            } else {
                if (!/__output\s\+\=/g.test(source_split[k]) || source_split[k].length === 0) {
                    if (!lock_deduct) {
                        deduct_count++;
                        lock_deduct = true;
                    }
                    nlcounter++;
                } else {
                    lock_deduct = false;
                    nlcounter += (source_split[k].match(/\\n/g) || []).length;
                }
            }
        }
    }

    if (deduct_count !== 0) {
        nlcounter -= deduct_count;
    }

    /*if (lock_deduct) {
        nlcounter++;
    }*/

    var raw_source_split = raw_source.split('\n'),
        trace = '';

    trace += '<fieldset style="background-color: #fff; color: #000;">';

    trace += '<legend style="font-size: 14px;">' + err_split[error_msg].replace(/^(.+?)\:/g, function(match) {
        return '<span style="color: red; font-weight:bold;">' + match + '</span>';
    }) + '</legend>';
    trace += '<span style="color: blue;font-size: 12px;">&nbsp;&nbsp;&nbsp;&nbsp;at ' + filename + ':' + nlcounter + '</span><br />';
    trace += '<br />';
    /*
    console.log(source_split, i, row, regex, nlcounter);
    console.log(err, err_split);
*/

    if (raw_source_split.hasOwnProperty(nlcounter - 3)) trace += '<span style="background-color: #E2E2E2;padding: 2px 10px;font-size: 10px;">' + (nlcounter - 2) + '</span> ' + entities.encode(raw_source_split[nlcounter - 3]) + '<br />';
    if (raw_source_split.hasOwnProperty(nlcounter - 2)) trace += '<span style="background-color: #E2E2E2;padding: 2px 10px;font-size: 10px;">' + (nlcounter - 1) + '</span> ' + entities.encode(raw_source_split[nlcounter - 2]) + '<br />';
    if (raw_source_split.hasOwnProperty(nlcounter - 1)) trace += '<span style="background-color: #FF8383;padding: 2px 10px;font-size: 10px; color: #fff;">' + (nlcounter) + '</span> ' + '<span style="color: red; font-style: italic;">' + entities.encode(raw_source_split[nlcounter - 1]) + '</span><br />';
    if (raw_source_split.hasOwnProperty(nlcounter)) trace += '<span style="background-color: #E2E2E2;padding: 2px 10px;font-size: 10px;">' + (nlcounter + 1) + '</span> ' + entities.encode(raw_source_split[nlcounter]) + '<br />';
    if (raw_source_split.hasOwnProperty(nlcounter + 1)) trace += '<span style="background-color: #E2E2E2;padding: 2px 10px;font-size: 10px;">' + (nlcounter + 2) + '</span> ' + entities.encode(raw_source_split[nlcounter + 1]) + '<br />';

    trace += '</fieldset>';


    return trace;
}

Template.prototype.parse = function(filename, _template, callback) {
    var self = this;

    if(!cache_template[filename]) {
        cache_template[filename] = {
            stats: fs.lstatSync(filename),
            source: null,
            raw_source: null
        };
    }

    stats = fs.lstatSync(filename);
    if(Number(cache_template[filename].stats.mtime) !== Number(stats.mtime) || !cache_template[filename].source) {
        this.source = 'var __output = \'\'; var echo = function(data) { __output += data; };';
        this.source2 = '';
        this.mode = null;
        this.tab = 0;

        var raw_source = _template.toString('utf-8');

        _template = raw_source;

        var regex = new RegExp(_REGEX_STRING),
            result = regex.exec(_template),
            arr = [],
            firstPos, lastPos;

        while (result) {
            firstPos = result.index;
            lastPos = regex.lastIndex;

            if (firstPos !== 0) {
                this.addToLine(_template.substring(0, firstPos));
                _template = _template.slice(firstPos);
            }

            this.addToLine(result[0]);
            _template = _template.slice(result[0].length);

            result = regex.exec(_template);
        }

        if (_template) {
            this.addToLine(_template);
        }

        //this.source = this.source.replace(/\n+/g, '\n');
        var source = this.source = this.source.replace(/\u0001+/g, '\u0001').replace(/\u0001/g, '\n');
        //console.log(source);

        cache_template[filename].stats = stats
        cache_template[filename].source = this.source
        cache_template[filename].raw_source = raw_source
    }

    this.$compile(cache_template[filename].source, filename, cache_template[filename].raw_source, function(err, result) {
        //err throw compiler
        if (err) {
            //console.log(self.source);
            if (err.stack && result) {
                err = TemplateParseError(err.stack, result, cache_template[filename].raw_source, filename);
            }
            callback(err);
            return;
        }
        callback(null, result);
    });
};

var generateTab = function(count) {
    var ret = '',
        i;
    for (i = 0; i < count; i++) {
        ret += '   ';
    }
    return ret;
};

Template.prototype.addToLine = function(data) {

    switch (data) {
      //   case '<?-':
      //       this.mode = 4;
      //       break;
      //   case '<?=':
      //       this.mode = 1;
      //       break;
      //   case '<?#':
      //       this.mode = 2;
      //       break;
      //   case '<?':
      //       this.mode = 3;
      //       break;
        case this.interpolate.varStart:
            this.mode = 1001;
            break;
        case this.interpolate.varEnd:
            this.mode = 1002;
            break;
        case this.interpolate.scriptStart:
            this.mode = 1003;
            break;
        case this.interpolate.scriptEnd:
            this.mode = 1004;
            break;
      //   case '?>':
      //       this.mode = null;
            // break;
        default:
            if (this.mode === 4) {
                this.source += '\u0001__output += ' + data + ';\u0001';
            } else if (this.mode === 1) {
                this.source += '\u0001__output += __entities.encode(String(' + data + '));\u0001';
            } else if (this.mode === 1001) {

                data = data.replace(/^\s*include\s+(\S+)/g, this.includeCoffee);

                try {
                    if (data.trim().length !== 0) {
                        if (this.tab === 0) {
                            this.source += '\u0001' + coffeescript('__output += ' + data).replace(/\n/g, '').replace('/\t/g', ' ').replace(/\s+/g, ' ') + '\u0001';
                        } else {
                            this.source2 += generateTab(this.tab) + '__output += ' + data + '\n';
                        }
                    }
                } catch (err) {
                    console.log(err.toString().replace(/\n/g, ''), '>>>>>>>>>>>>>>>>>>>>>');
                }

            } else if (this.mode === 1003) {
                try {
                    var regexp_cond = (new RegExp(_REGEX_STRING_CONDITION, 'g')).exec(data.trim());
                    if (regexp_cond) {
                        if (this.tab === 0) {
                            this.source2 = '';
                        }
                        this.source2 += generateTab(this.tab) + data.trim() + '\n';
                        this.tab++;
                    } else if (/^end$/g.test(data.trim())) {
                        this.tab--;
                        if (this.tab === 0) {
                            //console.log(this.source2);
                            //var test;
                            this.source += /*test =*/ '\u0001' + coffeescript(this.source2).replace(/\n/g, '\u0001') + '\u0001';
                            //console.log(test.replace(/\u0001/g, '\n'));
                        }
                    } else if (/^else(\s|$)/g.test(data.trim())) {
                        this.source2 += generateTab(this.tab - 1) + data.trim() + '\n';
                    } else {
                        if (this.tab !== 0) {
                            this.source2 += generateTab(this.tab) + data.trim() + '\n';
                        } else {
                            //var test;
                            this.source += /*test =*/ '\u0001' + coffeescript(data).replace(/\n/g, '\u0001') + '\u0001';
                            //console.log(test.replace(/\u0001/g, '\n'));
                        }
                    }
                } catch (err) {
                    console.log(err.toString().replace(/\n/g, ''), '>>>>>>>>>>>>>>>>>>>>>');
                }
            } else if (this.mode === 1004) {
                if (this.tab !== 0) {
                    this.source2 += generateTab(this.tab) + '__output += ' + JSON.stringify(data) + '\n';
                } else {
                    this.source += '\u0001__output += ' + JSON.stringify(data) + ';\u0001';
                }
            } else if (this.mode === 1002) {
                if (this.tab !== 0) {
                    this.source2 += generateTab(this.tab) + '__output += ' + JSON.stringify(data) + '\n';
                } else {
                    this.source += '\u0001__output += ' + JSON.stringify(data) + ';\u0001';
                }
            } else if (this.mode === 2) {

            } else if (this.mode === 3) {
                data = data.replace(/^\s*include\s+(\S+)/g, this.include);
                this.source += '\u0001' + data + '\u0001';
            } else {
                this.source += '\u0001__output += ' + JSON.stringify(data) + ';\u0001';
            }
    }

};


Template.prototype.$compile = function(content, filename, raw_source, callback) {
    var data_id = this.makeid(),
        source = '';
    exit = function(err, success) {
        delete global['data_' + data_id];
        if (err) {
            callback(err, source);
            return;
        }
        callback(null, success);
    };
    global['data_' + data_id] = {
        __sync: sync,
        __exit: exit,
        __render: render,
        __data: this.data,
        __path: this.path,
        __this: this,
        __tpte: includeTemplate,
        __entities: entities,
        __coffeescript: coffeescript
    };
    try {
        //add try catch here then trow error
        //console.dir(this.genLocalVars(data_id) + '__sync(function() {\n' + content + '\nreturn __output;\n}, __exit);');
        source = this.genLocalVars(data_id) + ' var include = function(content) { return __tpte.sync(__this, __path + \'/\' + content.trim() + \'\'); }; __sync(function() {\n' + content + '\nreturn __output;\n}, __exit);';
        module._compile(source);
    } catch (err) {
        console.log('------------------------------------------------------------------');
        console.log(err.stack);
        err = TemplateParseError(err.stack, source, raw_source, filename);
        if (callback && typeof callback === 'function') {
            callback(err);
        } else if (content && typeof content === 'function') {
            content(err);
        }
    }
};

Template.prototype.makeid = function() {
    var text = "";
    var possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    for (var i = 0; i < 5; i++)
        text += possible.charAt(Math.floor(Math.random() * possible.length));

    return text;
};

Template.prototype.genLocalVars = function(data_id) {
    var ret = '';
    for (var x in global['data_' + data_id])
        ret += 'var ' + x + ' = global.data_' + data_id + '.' + x + ';\n';
    for (var y in global['data_' + data_id].__data)
        ret += 'var ' + y + ' = global.data_' + data_id + '.__data.' + y + ';\n';
    return ret;
};

Template.prototype.include = function(match, contents, offset, s) {
    return '\u0001__output += __tpte.sync(__this, __path + \'/' + contents.trim() + '\');\u0001';
};

Template.prototype.includeCoffee = function(match, contents, offset, s) {
    return '__tpte.sync __this, __path + \'/' + contents.trim() + '\'';
};

var includeTemplate = function(file, callback) {
    var _template = renderFile(file);
    if (!Array.isArray(_template)) {
        console.log(_template);
        callback(_template);
        return;
    }
    this.path = path.dirname(_template[0]);
    this.parse(_template[0], _template[1], function(err, result) {
        if (err) {
            if (err.stack) {
                console.log(err.stack);
                callback(null, 'ERROR:' + file + '[' + err.code + ']');
            } else {
                //console.log(err);
                callback(null, [err]);
            }
            return;
        }
        callback(null, result);
    });
};

var renderFile = function(file) {
    var ext = path.extname(file).toString().length,
        target_file = path.resolve(file + (ext === 0 ? '.html' : ''));

    if (!fs.existsSync(target_file)) {
        return 'Unable to load file "' + target_file + '", file not exists.';
    }

    var _template = fs.readFileSync(target_file);
    return [target_file, _template];
};

var render = function(template, data, interpolate, callback) {
    var _template = renderFile(template);
    //file check exists
    var t = new Template(data || {}, path.dirname(_template[0]), interpolate);
    t.parse(_template[0], _template[1], callback);
};

module.exports = render;
