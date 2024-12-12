/**
 * 日志记录中间件
 */
const common = require('../model/common');
module.exports = async (req, res, next) => {
    const originUri = req.originalUrl;
    const openMethod = req.method.toUpperCase();
    let reqAddress = req.headers['x-forwarded-for'] || req.connection.remoteAddress || req.socket.remoteAddress || req.connection.socket.remoteAddress;
    //添加请求log
    const logData = {
        ip: reqAddress,
        url: originUri,
        method: openMethod,
        create_time: Date.now()
    };
    if (openMethod === 'POST') {
        logData.req_param = JSON.stringify(req.body);
    } else if (openMethod === 'GET') {
        logData.req_param = JSON.stringify(req.query);
    }
    let recordFlag = true;
    for (let item of Const.STATIC_SUFFIX) {
        if (originUri.includes(item)) {
            recordFlag = false;
            break;
        }
    }
    const noRecordArr = ['/pay/queryPay', '/pay/queryPayout'];
    if (noRecordArr.includes(originUri)) {
        recordFlag = false;
    }
    if (recordFlag) {
        common.writeLog(JSON.stringify(logData));
    }
    next();
}