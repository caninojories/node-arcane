var wait = require(__dirname + '/../wait.js');

(function() {
  var Stream;

  module.exports = function(root, opts) {
    var stream;
    stream = new Stream(root, opts);
    return function(req, res, next) {
      res.stream = function(src, opt/*, cb*/) {
        if (opt == null) {
          opt = {};
        }
        // if (cb == null) {
        //   cb = function() {};
        // }
        // if (typeof opt === 'function') {
        //   cb = opt;
        // }
        wait.for(function(cb) {
          stream.serve(src, opt, cb, req, res, next);
        });
        // var ret = stream.serve(src, opt, cb, req, res, next);
        throw('server:streaming');
        // return ret;
      };
      return next();
    };
  };

  Stream = (function() {
    var Negotiator, asyncCache, fs, http, mime, path, url, zlib;

    fs = require('fs');

    url = require('url');

    path = require('path');

    http = require('http');

    zlib = require('zlib');

    mime = require(__dirname + '/mime');

    Negotiator = require(__dirname + '/negotiator');

    asyncCache = require(__dirname + '/async-cache.js');

    Stream.prototype.opts = {
      root: process.cwd(),
      trim: true,
      concatenate: 'join',
      passthrough: false,
      cache: {
        fd: {
          max: 1000,
          maxAge: 1000 * 60 * 60
        },
        stat: {
          max: 5000,
          maxAge: 1000 * 60
        },
        content: {
          max: 1024 * 1024 * 64,
          maxAge: 1000 * 60 * 10
        }
      }
    };

    Stream.prototype.fdman = (require(__dirname + '/../file/fd.js'))();

    Stream.prototype.store = {
      fd: null,
      stat: null,
      content: null
    };

    function Stream(root, opts) {
      var _ref, _ref1, _ref10, _ref11, _ref12, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
      if (root == null) {
        root = '/';
      }
      if (opts == null) {
        opts = {};
      }
      if (root) {
        this.opts.root = root;
      }
      if ((opts.concatenate != null) && ((_ref = opts.concatenate) === 'join' || _ref === 'resolve')) {
        this.opts.concatenate = opts.concatenate;
      }
      if (opts.passthrough != null) {
        this.opts.passthrough = opts.passthrough;
      }
      if (opts.debug != null) {
        this.opts.debug = opts.debug;
      }
      if (((_ref1 = opts.cache) != null ? (_ref2 = _ref1.fd) != null ? _ref2.max : void 0 : void 0) != null) {
        this.opts.cache.fd.max = opts.cache.fd.max;
      }
      if (((_ref3 = opts.cache) != null ? (_ref4 = _ref3.fd) != null ? _ref4.maxAge : void 0 : void 0) != null) {
        this.opts.cache.fd.maxAge = opts.cache.fd.maxAge;
      }
      if (((_ref5 = opts.cache) != null ? (_ref6 = _ref5.stat) != null ? _ref6.max : void 0 : void 0) != null) {
        this.opts.cache.stat.max = opts.cache.stat.max;
      }
      if (((_ref7 = opts.cache) != null ? (_ref8 = _ref7.stat) != null ? _ref8.maxAge : void 0 : void 0) != null) {
        this.opts.cache.stat.maxAge = opts.cache.stat.maxAge;
      }
      if (((_ref9 = opts.cache) != null ? (_ref10 = _ref9.content) != null ? _ref10.max : void 0 : void 0) != null) {
        this.opts.cache.content.max = opts.cache.content.max;
      }
      if (((_ref11 = opts.cache) != null ? (_ref12 = _ref11.content) != null ? _ref12.maxAge : void 0 : void 0) != null) {
        this.opts.cache.content.maxAge = opts.cache.content.maxAge;
      }
      if (opts.cache === false) {
        this.opts.cache.fd.max = 1;
        this.opts.cache.fd.maxAge = 0;
        this.opts.cache.fd.length = function() {
          return Infinity;
        };
        this.opts.cache.stat.max = 1;
        this.opts.cache.stat.maxAge = 0;
        this.opts.cache.stat.length = function() {
          return Infinity;
        };
        this.opts.cache.content.max = 1;
        this.opts.cache.content.maxAge = 0;
        this.opts.cache.content.length = function() {
          return Infinity;
        };
      } else {
        this.opts.cache.fd.length = function(n) {
          return n.length;
        };
        this.opts.cache.stat.length = function(n) {
          return n.length;
        };
        this.opts.cache.content.length = function(n) {
          return n.length;
        };
      }
      this.store.fd = asyncCache({
        max: this.opts.cache.fd.max,
        maxAge: this.opts.cache.fd.maxAge,
        length: this.opts.cache.fd.length,
        load: this.fdman.open.bind(this.fdman),
        dispose: this.fdman.close.bind(this.fdman)
      });
      this.store.stat = asyncCache({
        max: this.opts.cache.stat.max,
        maxAge: this.opts.cache.stat.maxAge,
        length: this.opts.cache.stat.length,
        load: (function(_this) {
          return function(key, cb) {
            var fd, fdp, p, _ref13;
            if (!(fdp = key.match(/^(\d+):(.*)/))) {
              return fs.stat(key, cb);
            }
            _ref13 = [+fdp[1], fdp[2]], fd = _ref13[0], p = _ref13[1];
            return fs.fstat(fd, function(err, stat) {
              if (err) {
                return cb(err);
              }
              _this.store.stat.set(p, stat);
              return cb(null, stat);
            });
          };
        })(this)
      });
      this.store.content = asyncCache({
        max: this.opts.cache.content.max,
        maxAge: this.opts.cache.content.maxAge,
        length: this.opts.cache.content.length,
        load: function() {
          throw new Error('This should not ever happen');
        }
      });
    }

    Stream.prototype.parseRange = function(stat, req) {
      var end, ini, range, ranges, _i, _len, _ref, _ref1, _ref2, _ref3;
      if (((_ref = req.headers) != null ? _ref.range : void 0) != null) {
        ranges = [];
        _ref1 = req.headers.range.replace('bytes=', '').split(',');
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          range = _ref1[_i];
          _ref2 = range.split('-'), ini = _ref2[0], end = _ref2[1];
          if (ini.length === 0) {
            ini = stat.size - end;
            if (ini < 0) {
              ini = 0;
            }
            end = stat.size - 1;
          }
          if (end.length === 0) {
            end = stat.size - 1;
          }
          _ref3 = [+ini, +end], ini = _ref3[0], end = _ref3[1];
          ranges.push({
            ini: ini,
            end: end
          });
        }
        return ranges;
      }
      return null;
    };

    Stream.prototype.isAcceptGzip = function(src, req) {
      var gz, neg;
      gz = false;
      if (!/\.t?gz$/.exec(src)) {
        neg = req.negotiator || new Negotiator(req);
        gz = neg.preferredEncoding(['gzip', 'identity']) === 'gzip';
      }
      return gz;
    };

    Stream.prototype.isValidRange = function(ini, end) {
      if (ini > end) {
        return false;
      }
      return true;
    };

    Stream.prototype.error = function(err, res, next, fdend) {
      if (fdend) {
        fdend();
      }
      if (typeof err === 'number') {
        res.statusCode = err;
      } else {
        res.statusCode = (function() {
          switch (err.code) {
            case 'ENOENT':
            case 'EISDIR':
              return 404;
            case 'EPERM':
            case 'EACCES':
              return 403;
            default:
              return 500;
          }
        })();
      }
      if (this.opts.passthrough && res.statusCode === 404) {
        return next();
      }
      return next(err);
    };

    Stream.prototype.cache = function(res, fdend) {
      fdend();
      res.statusCode = 304;
      return res.end();
    };

    Stream.prototype.serve = function(src, opt, cb, req, res, next) {
      if (!src) {
        throw new Error('`src` should not be blank, res.stream(src, callback).');
      }
      if (typeof cb !== 'function') {
        console.error('`callback` should be function, res.stream(src, callback).');
        cb = function() {};
      }
      src = path[this.opts.concatenate](this.opts.root, src);
      if (this.opts.trim) {
        src = decodeURIComponent(url.parse(src).pathname);
      }
      if (!src) {
        return next();
      }
      return this.store.fd.get(src, (function(_this) {
        return function(err, fd) {
          var fdend;
          if (err) {
            cb(err, null);
            return _this.error(err, res, next);
          }
          _this.fdman.checkout(src, fd);
          fdend = _this.fdman.checkinfn(src, fd);
          return _this.store.stat.get("" + fd + ":" + src, function(err, stat) {
            var buf, cache, ctype, end, etag, gzbuf, gzstream, ini, isFirstStream, match, partial, range, ranges, since, storekey, stream, _ref, _ref1, _ref2, _ref3;
            if (err) {
              cb(err, null);
              return _this.error(err, res, next, fdend);
            }
            ranges = _this.parseRange(stat, req);
            if (ranges === null) {
              partial = false;
              _ref = [0, stat.size - 1], ini = _ref[0], end = _ref[1];
              isFirstStream = true;
            } else {
              if (ranges.length !== 1) {
                console.error('not supported multi range-spec');
              }
              range = ranges[0];
              partial = true;
              _ref1 = [range.ini, range.end], ini = _ref1[0], end = _ref1[1];
              isFirstStream = ini === 0 && (end === 0 || end === 1);
            }
            if (!_this.isValidRange(ini, end)) {
              res.statusCode = 416;
              res.set('content-length', 0);
              cb(new Error('out of range'), [ini, end], isFirstStream);
              return res.end();
            }
            if ((since = req.headers['if-modified-since'])) {
              since = (new Date(since)).getTime();
              if (since && since >= stat.mtime.getTime()) {
                cb(null, [ini, end], isFirstStream);
                return _this.cache(res, fdend);
              }
            }
            etag = "\"" + stat.dev + "-" + stat.ino + "-" + (stat.mtime.getTime()) + "\"";
            // if ((match = req.headers['if-none-match'])) {
            //   if (match === etag) {
            //     cb(null, [ini, end], isFirstStream);
            //     return _this.cache(res, fdend);
            //   }
            // }
            // if ((match = req.headers['if-range'])) {
            //   if (match === etag) {
            //     cb(null, [ini, end], isFirstStream);
            //     return _this.cache(res, fdend);
            //   }
            // }
            if (stat.isDirectory()) {
              err = new Error;
              err.code = 'EISDIR';
              cb(err, [ini, end], isFirstStream);
              return _this.error(err, res, next, fdend);
            }
            cache = ((_ref2 = opt.headers) != null ? _ref2['cache-control'] : void 0) || 'public';
            ctype = ((_ref3 = opt.headers) != null ? _ref3['content-type'] : void 0) || mime.lookup(path.extname(src));
            res.set('cache-control', cache);
            res.set('last-modified', stat.mtime.toUTCString());
            res.set('etag', etag);
            res.set('content-type', ctype);
            if (!partial) {
              res.statusCode = 200;
            } else {
              res.statusCode = 206;
              if (stat.size < end - ini + 1) {
                end = stat.size - 1;
              }
              res.set('content-range', "bytes " + ini + "-" + end + "/" + stat.size);
            }
            storekey = "" + fd + ":" + stat.size + ":" + etag;
            if (!partial && _this.store.content.has(storekey)) {
              return _this.store.content.get(storekey, function(err, content) {
                fdend();
                if (err) {
                  cb(err, [ini, end], isFirstStream);
                  return _this.error(err, res, next);
                }
                if (_this.isAcceptGzip(src, req) && content.gz) {
                  res.set('content-encoding', 'gzip');
                  res.set('content-length', content.gz.length);
                  cb(null, [ini, end], isFirstStream);
                  return res.end(content.gz);
                } else {
                  res.set('content-length', content.length);
                  cb(null, [ini, end], isFirstStream);
                  return res.end(content);
                }
              });
            } else {
              stream = fs.createReadStream(src, {
                fd: fd,
                start: ini,
                end: end
              });
              stream.destroy = function() {};
              stream.on('error', function(err) {
                err = err.stack || err.message;
                console.error('Error serving %s fd=%d\n%s', src, fd, err);
                res.socket.destroy();
                return fdend();
              });
              gzstream = zlib.createGzip();
              if (!partial && _this.isAcceptGzip(src, req)) {
                res.set('content-encoding', 'gzip');
                stream.pipe(gzstream);
                gzstream.pipe(res);
                if (_this.store.content._cache.max > stat.size) {
                  buf = [];
                  gzbuf = [];
                  stream.on('data', function(chunk) {
                    return buf.push(chunk);
                  });
                  gzstream.on('data', function(chunk) {
                    return gzbuf.push(chunk);
                  });
                  gzstream.on('end', function() {
                    var content;
                    content = Buffer.concat(buf);
                    content.gz = Buffer.concat(gzbuf);
                    return _this.store.content.set(storekey, content);
                  });
                }
              } else {
                res.set('content-length', end - ini + 1);
                stream.pipe(res);
              }
              return stream.on('end', function() {
                cb(null, [ini, end], isFirstStream);
                return process.nextTick(fdend);
              });
            }
          });
        };
      })(this));
    };

    return Stream;

  })();

}).call(this);
