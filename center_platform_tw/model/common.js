/**
 * 公共函数
 */
const fs = require('fs');
const dbs = require('../common/db/dbs')(config.mysql.dbs.gb_pay);
const httpRequest = require('../common/request/http');
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
     * 查询验证app token
     * @param appToken
     * @returns {Promise<{msg: *, code: number, data: {}}>}
     */
    async checkToken(appToken = '') {
        //根据app token查询app状态
        const appInfo = await dbs.getOne(Const.TABLES.GB_PAY.APP, [], {app_token: appToken});
        if (Object.keys(appInfo).length === 0) {
            return errors('app not found');
        }
        if (Const.COMMON_STATUS.NORMAL !== appInfo.status) {
            return errors(('app is disabled'));
        }
        return success(appInfo);
    }

    /**
     * 支付异步回调
     * @param url
     * @param data
     * @returns {Promise<void>}
     */
    async payAsyncCallback(url = '', data = {}) {
        const header = {};
        data.sign = funcs.callbackSign(data.merOrderNo);
        const timeout = 30000;
        const result = await httpRequest.post(url, data, header, timeout);
        if (Const.RESULT_STATUS.TIMEOUT === result.status || Const.RESULT_STATUS.ERROR === result.status) {
            //如果请求超时或报错，重新请求一次
            httpRequest.post(url, data, header, timeout);
        } else {
            if (!(typeof result.data === 'string' && result.data.toLowerCase() === 'ok')) {
                //如果返回值不是字符串ok，重新请求一次
                httpRequest.post(url, data, header, timeout);
            }
        }
    }
    /**
     * 前置执行的方法
     * @param req
     * @param res
     * @param next
     * @returns {Promise<*>}
     */
    async preExec(req, res, next) {
        if (req.session?.userInfo) {
            const roleId = req.session?.userInfo?.role_id ?? 0;
            if (roleId > 0) {
                //查找角色对应的权限id
                const authId = req.session?.userInfo?.authId ?? '';
                const authIdArr = authId.split(',');
                if (authIdArr.length === 0) {
                    return res.json(errors('permission denied'));
                }
                //查找url对应的权限id
                const originUri = req.originalUrl;
                const openMethod = req.method.toUpperCase();
                console.log(originUri, openMethod);
                const where = [
                    ['url', '==', originUri],
                    ['method', '==', openMethod],
                    ['status', '==', 0]
                ];
                const authInfo = await dbs.gets(Const.TABLES.GB_PAY.MENU, [], where, [], 1);
                if (authInfo.length === 0) {
                    return res.json(errors('request url not found'));
                }
                const reqAuthId = authInfo[0]?.id ?? 0;
                //判断url对应的权限id在角色中是否存在
                if (!authIdArr.map(item => parseInt(item)).includes(parseInt(reqAuthId))) {
                    return res.json(errors('permission denied!'));
                }
            }
            next()
        } else {
            return res.redirect(`/backend/admin/login`);
        }
    }

    /**
     * 接口中间件(IP白名单，app_token处理等等)
     * @param req
     * @param res
     * @param next
     * @returns {Promise<*>}
     */
    async commonMiddleware (req, res, next) {
        let reqAddress = req.headers['x-forwarded-for'] || req.connection.remoteAddress || req.socket.remoteAddress || req.connection.socket.remoteAddress;
        console.log(`request ip address: ${reqAddress}`);
        if (!reqAddress) {
            return res.json(errors('request failed: can not get IP address'));
        }
        if (typeof reqAddress !== 'string') {
            return res.json(errors('request failed: IP address error!'));
        }
        const checkIp = await this.checkIpWhitelist(reqAddress, 'server_ip_whitelist');
        if (!checkIp) {
            return res.json(errors('request failed: IP not allowed!'));
        }
        //app token
        let appToken = req.get('app_token') || req.body.app_token || '';
        if (!appToken) {
            return res.json(errors('unauthorized access'));
        }
        //验证Token
        let result = await this.checkToken(appToken);
        if (result.code !== Const.COMMON_STATUS.NORMAL) {
            return res.json(result);
        }
        req.state.app_id = result.data.id;
        req.state.app_info = result.data;
        next();
    }

    /**
     * ip白名单校验
     * @param ip
     * @param ipWhitelistKey
     * @returns {Promise<boolean>}
     */
    async checkIpWhitelist(ip = '', ipWhitelistKey = '') {
        let serverWhitelist = await cache.gets(ipWhitelistKey);
        if (!serverWhitelist) {
            const ipInfo = await dbs.getOne(Const.TABLES.GB_PAY.CONFIG, ['value_txt'], {unique_key: ipWhitelistKey});
            if (Object.keys(ipInfo).length > 0) {
                serverWhitelist = ipInfo.value_txt;
                console.log(serverWhitelist);
                console.log(typeof serverWhitelist);
                cache.sets(ipWhitelistKey, serverWhitelist, 60 * 60 * 1000);
            }
        }
        if (serverWhitelist) {
            let allowConfig = false;
            const whitelistArr = serverWhitelist.split(',').map(s => s.trim());
            for (let item of whitelistArr) {
                if (ip.includes(item)) {
                    allowConfig = true;
                    break;
                }
            }
            if (!allowConfig) {
                return false;
            }
        }
        return true;
    }
}

module.exports = new common();