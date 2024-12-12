/**
 * 公共函数
 */
const fs = require('fs');
const cache = require('../common/redis/cache');
class common {

    /**
     * @name 写入日志
     * @param text
     * @param type info正常 warning橘色 error红色 receive蓝色 response绿色
     * @return json
     */
    async writeLog(text = '', type = 'info') {
        const nowTime = Date.now();
        const timeStr = '[' + funcs.datestamps(nowTime, true, true, '-') + '] ';
        console.log(timeStr + text);
        try {
            switch (type) {
                case "info":
                    break;
                case "warning":
                    text = `<span style="color: orange">${text}</span>`;
                    break;
                case "error":
                    text = `<span style="color: red">${text}</span>`;
                    break;
                case "receive":
                    text = `<span style="color: blue">${text}</span>`;
                    break;
                case "response":
                    text = `<span style="color: green">${text}</span>`;
                    break;
            }
            text = timeStr + text + '<br />\n';
            let dateStr = funcs.timeWithoutLink(nowTime, false);
            //文件日志
            fs.appendFileSync(APP_ROOT + "/runtime/log/" + dateStr + ".txt", text, error => {
                if (error) return console.log("error: " + error.message);
                console.log("写入成功");
            });
            return true;
        } catch (e) {
            console.log(e.toString());
            return false;
        }
    }
    /**
     * @name 读取日志
     * @param docId
     * @return json
     */
    async readLog (docId) {
        try {
            if (!docId) {
                let nowTime = Date.now();
                docId = funcs.timeWithoutLink(nowTime, false);
            }
            const docu = fs.readFileSync(APP_ROOT + "/runtime/log/" + docId + ".txt");
            return docu.toString();
        } catch (e) {
            return 'no such file or directory';
        }
    }
    /**
     * @name 清除日志
     * @param docId
     * @return json
     */
    async clearLog (docId = '') {
        try {
            if (!docId) {
                let nowTime = Date.now();
                docId = funcs.timeWithoutLink(nowTime, false);
            }
            fs.writeFileSync(APP_ROOT + "/runtime/log/" + docId + ".txt", '');
            return true;
        } catch (e) {
            return false;
        }
    }

    /**
     * ip白名单校验
     * @param req
     * @param res
     * @param next
     * @param ipWhitelistKey
     * @returns {Promise<boolean>}
     */
    async checkIpWhitelist(req, res, next, ipWhitelistKey) {
        let reqAddress = req.headers['x-forwarded-for'] || req.connection.remoteAddress || req.socket.remoteAddress || req.connection.socket.remoteAddress;
        console.log(`[${ipWhitelistKey}] request ip address: ${reqAddress}`);
        if (!reqAddress) {
            return res.json(errors('request failed: can not get IP address'));
        }
        if (typeof reqAddress !== 'string') {
            return res.json(errors('request failed: IP address error!'));
        }
        let serverWhitelist = await cache.gets(ipWhitelistKey);
        console.log('serverWhitelist: ', serverWhitelist);
        if (serverWhitelist) {
            let allowConfig = false;
            const whitelistArr = serverWhitelist.split(',').map(s => s.trim());
            for (let item of whitelistArr) {
                if (reqAddress.includes(item)) {
                    allowConfig = true;
                    break;
                }
            }
            if (!allowConfig) {
                return res.json(errors('request failed: IP not allowed!'));
            }
        }
        next();
    }
}

module.exports = new common();