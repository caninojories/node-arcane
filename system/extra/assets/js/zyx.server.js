var clients = [];

var mime = require('mime');
var fs = require('fs');

var crypto = require('crypto');

var ReceiverClass = require( zyx.root + '/core/libs/ws/Receiver' );
var SenderClass = require( zyx.root + '/core/libs/ws/Sender' );

exports.ZYXServer = ZYXServer = function(stream, port) {
	var hrTime = process.hrtime();
	var self = this;
	this.stream = stream;
	this.is_websocket = false;
	this.is_html = false;
	this.port = stream.localPort;
	this._event = new zy.events.EventEmitter();
	this.is_init = false;
	this.id = 0;
	
	this.on_file_changed = function() {};
	
	clients.push(this);
	
	stream.setTimeout(0);
	//stream.setEncoding("utf8");
	
	stream.addListener("connect", function () {
		
	});
	
	stream.addListener("end", function() {
		self._event.emit('disconnected');
		if(self.is_websocket) self.receiver.cleanup();
		self.remove();
		stream.end();
	});
	
	this.initialize();
}

ZYXServer.prototype.remove = function() {
	for (var i = 0; i < clients.length; i++) {
		if (this == clients[i]) { return clients.splice(i, 1); }
	}
};

ZYXServer.prototype.on = function( event, callback ) {
	var self = this;
	this._event.on(event, function( data ) {
		zyx(callback).call(self, data);
	});
};

var pending = { is_running:null };
ZYXServer.prototype.response = function( status, content, mime ) {
	if( !zyx(mime).defined() ) mime = "text/html";
	
	var resp = 'OK';
	switch(status) {
		case 200: resp = 'OK'; break;
		case 404: resp = 'Not Found'; break;
		default:
			status = 200;
	}
	
	try {
		if( pending.is_running ) clearTimeout( pending.is_running );
		this.stream.write("HTTP/1.1 " + status + " " + resp + "\r\n");
		this.stream.write("Cache-Control: public, max-age=60\r\n");
		this.stream.write("Content-Type: " + mime + "; charset=utf-8\r\n");
		this.stream.write("Content-Length: " + content.length + "\r\n\r\n");
		this.stream.write( content );
	} catch( e ) {
		console.log( e );
	}
	
	var self = this;
	pending.is_running = setTimeout(function() {
		self.stream.end();
		pending.is_running = null
	}, 100);
	
};

ZYXServer.prototype.show = function( header ) {
	if( fs.lstatSync(header.dir).isFile() ) {
		var file_list = zy(header.dir).loadStreamList( null, true )
			,request_file = header.request_file.replace(/^\/|\/$/g, '');
		if( file_list[request_file] ) {
			this.response( 200, file_list[request_file], mime.lookup(request_file) );
		} else {
			this.response( 404, 'error' );
		}
	} else {
		var file_location = header.dir + header.request_file;
		if( fs.existsSync(file_location) && fs.lstatSync(file_location).isDirectory() ) {
			if( fs.existsSync(file_location + 'index.html') ) {
				var file_location = file_location + 'index.html';
				var file_data = fs.readFileSync(file_location);
				this.response( 200, file_data, mime.lookup(header.request_file) );
			} else {
				this.response( 404, 'error' );
			}
		} else if( fs.existsSync(file_location) && fs.lstatSync(file_location).isFile() ) {
			var file_data = fs.readFileSync(file_location);
			this.response( 200, file_data, mime.lookup(header.request_file) );
		} else {
			this.response( 404, 'error' );
		}
	}
};

ZYXServer.prototype.write_ws = function( obj ) {
	this.sender.send( JSON.stringify(obj) );
};

ZYXServer.prototype.initialize = function() {
	var self = this;
	this.stream.addListener('data', function (data) {
		
		if( self.is_websocket ) {
			self.receiver.add(data);
			return;
		}
		
		var header = { 
			dir: zyx.root + '/core/.' + self.port,
			request_file: '',
		};
		var data_arr = data.toString().split("\r\n");
		var request_url = /^GET\s(.*)\sHTTP\/1\.1$/g.exec(data_arr[0]);
		if( request_url ) {
			self.is_html = true;
			header.request_file = request_url[1];
			for( var i in data_arr ) {
				if( data_arr[i] !== '' && i !== '0' ) {
					var data_header = /^(.*):\s(.*)$/g.exec(data_arr[i]);
					if( data_header ) {
						header[data_header[1]] = data_header[2];
						if( data_header[1] === 'Upgrade' && data_header[2] === 'websocket' ) {
							self.is_websocket = true;
						}
					}
				}
			}
		}
		
		//self._event.emit('connected');
		
		if( self.is_html && !self.is_websocket ) {
			if( header.request_file.match(/\/js\/.*$/g) || header.request_file.match(/\/modules\/.*$/g) || header.request_file.match(/\/images\/.*$/g) ) {
				var tmp_reqs_file = zyx.root + '/resources' + header.request_file;
				if( fs.existsSync(tmp_reqs_file) && fs.lstatSync(tmp_reqs_file).isFile() ) {
					header.dir = zyx.root + '/resources';
				}
			}
			
			self.show( header );
			//self.pendings(header);
		} else if( self.is_html && self.is_websocket ) {
			
			self.receiver = new ReceiverClass();
			self.receiver.ontext = function(_data) { 
				var arr_data = String(_data.toString('utf8')).replace(/\u0000/g, '').split("\n");
				for( var i in arr_data ) {
					if( arr_data[i].trim().length !== 0 ) self._event.emit('client', arr_data[i].trim());
				}
			};
			
			self.sender = new SenderClass(self.stream);
			
			var key = header['Sec-WebSocket-Key'];
			var shasum = crypto.createHash('sha1');
			shasum.update(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
			key = shasum.digest('base64');
			
			self.stream.write("HTTP/1.1 101 Switching Protocols\r\n");
			self.stream.write("Upgrade: websocket\r\n");
			self.stream.write("Connection: Upgrade\r\n");
			self.stream.write("Sec-WebSocket-Accept: " + key + "\r\n");
			self.stream.write("Sec-WebSocket-Protocol: zyrllex\r\n\r\n");
			
		} else {
			var arr_data = String(data.toString('utf8')).replace(/\u0000/g, '').split("\n");
			for( var i in arr_data ) {
				if( arr_data[i].trim().length !== 0 ) self._event.emit('data', arr_data[i].trim());
			}
		}
		
	});
};