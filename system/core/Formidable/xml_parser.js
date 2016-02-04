if (global.GENTLY) require = GENTLY.hijack(require);

var Buffer = require('buffer').Buffer;
var xml_arr = require(__dirname + '/../xml2js').parseString;

function XMLParser() {
    this.data = new Buffer('');
    this.bytesWritten = 0;
}
exports.XMLParser = XMLParser;

XMLParser.prototype.initWithLength = function(length) {
    this.data = new Buffer(length);
};

XMLParser.prototype.write = function(buffer) {
    if (this.data.length >= this.bytesWritten + buffer.length) {
        buffer.copy(this.data, this.bytesWritten);
    } else {
        this.data = Buffer.concat([this.data, buffer]);
    }
    this.bytesWritten += buffer.length;
    return buffer.length;
};

XMLParser.prototype.end = function() {
    try {
        var self = this;
        xml_arr(this.data.toString('utf8'), function(err, fields) {
            if (err) {
                console.log(err.stack || err);
                self.data = null;
                self.onEnd();
                return;
            }
            for (var field in fields) {
                self.onField(field, fields[field]);
            }
            self.data = null;
            self.onEnd();
        });
    } catch (e) {
        console.log(e.stack);
        this.data = null;
        this.onEnd();
    }
};