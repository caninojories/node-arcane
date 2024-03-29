// Generated by IcedCoffeeScript 1.7.1-f
(function() {
  var FSMonitorTool, RelPathList, RelPathSpec, USAGE, displayStringForShellArgs, escapeShellArgForDisplay, fsmonitor, iced, spawn, __iced_k, __iced_k_noop, _ref,
    __slice = [].slice;

  iced = {
    Deferrals: (function() {
      function _Class(_arg) {
        this.continuation = _arg;
        this.count = 1;
        this.ret = null;
      }

      _Class.prototype._fulfill = function() {
        if (!--this.count) {
          return this.continuation(this.ret);
        }
      };

      _Class.prototype.defer = function(defer_params) {
        ++this.count;
        return (function(_this) {
          return function() {
            var inner_params, _ref;
            inner_params = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
            if (defer_params != null) {
              if ((_ref = defer_params.assign_fn) != null) {
                _ref.apply(null, inner_params);
              }
            }
            return _this._fulfill();
          };
        })(this);
      };

      return _Class;

    })(),
    findDeferral: function() {
      return null;
    },
    trampoline: function(_fn) {
      return _fn();
    }
  };
  __iced_k = __iced_k_noop = function() {};

  _ref = require('../node-lib/pathspec'), RelPathList = _ref.RelPathList, RelPathSpec = _ref.RelPathSpec;

  fsmonitor = require('./index');

  spawn = require('child_process').spawn;

  USAGE = "Usage: fsmonitor [-d <folder>] [-p] [-s] [-q] [<mask>]... [<command> <arg>...]\n\nOptions:\n  -d <folder>        Specify the folder to monitor (defaults to the current folder)\n  -p                 Print changes to console (default if no command specified)\n  -s                 Run the provided command once on start up\n  -l                 Display a full list of matched (monitored) files and folders\n  -q                 Quiet mode (don't print the initial banner)\n  -J <subst>         Replace <subst> in the executed command with the name of the modified file\n                     (this also changes how multiple changes are handled; normally, the command\n                     is only invoked once per a batch of changes; when -J is specified, the command\n                     is invoked once per every modified file)\n\nMasks:\n  +<mask>            Include only the files matching the given mask\n  !<mask>            Exclude files matching the given mask\n\n  If no inclusion masks are provided, all files not explicitly excluded will be included.\n\nGeneral options:\n  --help             Display this message\n  --version          Display fsmonitor version number";

  escapeShellArgForDisplay = function(arg) {
    if (arg.match(/[ ]/)) {
      if (arg.match(/[']/)) {
        return '"' + arg.replace(/[\\]/g, '\\\\').replace(/["]/g, '\\"') + '"';
      } else {
        return "'" + arg + "'";
      }
    } else {
      return arg;
    }
  };

  displayStringForShellArgs = function(args) {
    var arg;
    return ((function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = args.length; _i < _len; _i++) {
        arg = args[_i];
        _results.push(escapeShellArgForDisplay(arg));
      }
      return _results;
    })()).join(' ');
  };

  FSMonitorTool = (function() {
    function FSMonitorTool() {
      this.list = new RelPathList();
      this.list.include(RelPathSpec.parse('**'));
      this.list2 = new RelPathList();
      this.folder = process.cwd();
      this.command = [];
      this.print = false;
      this.quiet = false;
      this.prerun = false;
      this.subst = null;
      this.listFiles = false;
      this._latestChangeForExternalCommand = null;
      this._externalCommandRunning = false;
    }

    FSMonitorTool.prototype.parseCommandLine = function(argv) {
      var arg, requiredValue, spec, _ref1;
      requiredValue = function(arg) {
        if (argv.length === 0) {
          process.stderr.write(" *** Missing required value for " + arg + ".\n");
          process.exit(13);
        }
        return argv.shift();
      };
      while ((arg = argv.shift()) != null) {
        if (arg === '--') {
          break;
        }
        if (arg.match(/^--/)) {
          switch (arg) {
            case '--help':
              process.stdout.write(USAGE.trim() + "\n");
              process.exit(0);
              break;
            case '--version':
              process.stdout.write("" + fsmonitor.version + "\n");
              process.exit(0);
              break;
            default:
              process.stderr.write(" *** Unknown option: " + arg + ".\n");
              process.exit(13);
          }
        } else if (arg.match(/^-./)) {
          if (arg.match(/^-[dJ]./)) {
            argv.unshift(arg.substr(2));
            arg = arg.substr(0, 2);
          }
          switch (arg) {
            case '-d':
              this.folder = requiredValue();
              break;
            case '-J':
              this.subst = requiredValue();
              break;
            case '-p':
              this.print = true;
              break;
            case '-s':
              this.prerun = true;
              break;
            case '-q':
              this.quiet = true;
              break;
            case '-l':
              this.listFiles = true;
              break;
            default:
              process.stderr.write(" *** Unknown option: " + arg + ".\n");
              process.exit(13);
          }
        } else {
          if (arg.match(/^!/)) {
            spec = RelPathSpec.parseGitStyleSpec(arg.slice(1));
            this.list.exclude(spec);
            if ((_ref1 = this.list2) != null) {
              _ref1.exclude(spec);
            }
          } else if (arg.match(/^[+]/)) {
            spec = RelPathSpec.parseGitStyleSpec(arg.slice(1));
            if (this.list2) {
              this.list = this.list2;
              this.list2 = null;
            }
            this.list.include(spec);
          } else {
            argv.unshift(arg);
            break;
          }
        }
      }
      this.command = argv;
      if (this.command.length === 0) {
        return this.print = true;
      }
    };

    FSMonitorTool.prototype.printOptions = function() {
      var action, folderStr;
      if (this.command.length > 0) {
        action = displayStringForShellArgs(this.command);
      } else {
        action = '<print to console>';
      }
      folderStr = this.folder.replace(process.env.HOME, '~');
      process.stderr.write("\n");
      process.stderr.write("Monitoring:  " + folderStr + "\n");
      process.stderr.write("    filter:  " + this.list + "\n");
      process.stderr.write("    action:  " + action + "\n");
      if (this.subst) {
        process.stderr.write("     subst:  " + this.subst + "\n");
      }
      return process.stderr.write("\n");
    };

    FSMonitorTool.prototype.startMonitoring = function() {
      var watcher;
      watcher = fsmonitor.watch(this.folder, this.list, this.handleChange.bind(this));
      return watcher.on('complete', (function(_this) {
        return function() {
          var file, folder, _i, _j, _len, _len1, _ref1, _ref2;
          if (_this.listFiles) {
            _ref1 = watcher.tree.allFiles;
            for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
              file = _ref1[_i];
              process.stdout.write("" + file + "\n");
            }
            _ref2 = watcher.tree.allFolders;
            for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
              folder = _ref2[_j];
              process.stdout.write("" + folder + "/\n");
            }
            process.exit();
          }
          if (!_this.quiet) {
            return process.stderr.write("...");
          }
        };
      })(this));
    };

    FSMonitorTool.prototype.handleChange = function(change) {
      if (this.print) {
        this.printChange(change);
      }
      if (this.command.length > 0) {
        return this.executeCommandForChange(change);
      }
    };

    FSMonitorTool.prototype.printChange = function(change) {
      var prefix, str;
      str = change.toString();
      prefix = "" + (Date.now()) + " ";
      if (str) {
        return process.stderr.write("\n" + str.trim().split("\n").map(function(x) {
          return "" + prefix + x + "\n";
        }).join(''));
      } else {
        return process.stderr.write("\n" + prefix + " <empty change>\n");
      }
    };

    FSMonitorTool.prototype.executeCommandForChange = function(change) {
      if (this._latestChangeForExternalCommand) {
        this._latestChangeForExternalCommand.append(change);
      } else {
        this._latestChangeForExternalCommand = change;
      }
      return this._scheduleExternalCommandExecution();
    };

    FSMonitorTool.prototype._scheduleExternalCommandExecution = function() {
      if (this._latestChangeForExternalCommand && !this._externalCommandRunning) {
        return process.nextTick((function(_this) {
          return function() {
            var arg, change, command, file, files, ___iced_passed_deferral, __iced_deferrals, __iced_k;
            __iced_k = __iced_k_noop;
            ___iced_passed_deferral = iced.findDeferral(arguments);
            change = _this._latestChangeForExternalCommand;
            _this._latestChangeForExternalCommand = null;
            _this._externalCommandRunning = true;
            (function(__iced_k) {
              if (_this.subst) {
                files = change.addedFiles.concat(change.modifiedFiles);
                (function(__iced_k) {
                  var _i, _len, _ref1, _results, _while;
                  _ref1 = files;
                  _len = _ref1.length;
                  _i = 0;
                  _results = [];
                  _while = function(__iced_k) {
                    var _break, _continue, _next;
                    _break = function() {
                      return __iced_k(_results);
                    };
                    _continue = function() {
                      return iced.trampoline(function() {
                        ++_i;
                        return _while(__iced_k);
                      });
                    };
                    _next = function(__iced_next_arg) {
                      _results.push(__iced_next_arg);
                      return _continue();
                    };
                    if (!(_i < _len)) {
                      return _break();
                    } else {
                      file = _ref1[_i];
                      command = (function() {
                        var _j, _len1, _ref2, _results1;
                        _ref2 = this.command;
                        _results1 = [];
                        for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
                          arg = _ref2[_j];
                          _results1.push(arg.replace(this.subst, file));
                        }
                        return _results1;
                      }).call(_this);
                      (function(__iced_k) {
                        __iced_deferrals = new iced.Deferrals(__iced_k, {
                          parent: ___iced_passed_deferral,
                          filename: "c:\\Users\\saita\\Documents\\program\\fsmonitor.js\\lib\\cli.iced"
                        });
                        _this._invokeExternalCommand(command, __iced_deferrals.defer({
                          lineno: 185
                        }));
                        __iced_deferrals._fulfill();
                      })(_next);
                    }
                  };
                  _while(__iced_k);
                })(__iced_k);
              } else {
                (function(__iced_k) {
                  __iced_deferrals = new iced.Deferrals(__iced_k, {
                    parent: ___iced_passed_deferral,
                    filename: "c:\\Users\\saita\\Documents\\program\\fsmonitor.js\\lib\\cli.iced"
                  });
                  _this._invokeExternalCommand(_this.command, __iced_deferrals.defer({
                    lineno: 187
                  }));
                  __iced_deferrals._fulfill();
                })(__iced_k);
              }
            })(function() {
              if (!_this.quiet) {
                process.stderr.write("\n...");
              }
              _this._externalCommandRunning = false;
              return _this._scheduleExternalCommandExecution();
            });
          };
        })(this));
      }
    };

    FSMonitorTool.prototype._invokeExternalCommand = function(command, callback) {
      var child;
      if (!this.quiet) {
        process.stderr.write("\r" + (displayStringForShellArgs(command)) + "\n");
      }
      child = spawn(command[0], command.slice(1), {
        stdio: 'inherit'
      });
      return child.on('exit', callback);
    };

    return FSMonitorTool;

  })();

  exports.run = function(argv) {
    var app;
    app = new FSMonitorTool();
    app.parseCommandLine(argv);
    app.startMonitoring();
    if (app.prerun) {
      app.executeCommandForChange({});
    }
    if (!app.quiet) {
      return app.printOptions();
    }
  };

}).call(this);
