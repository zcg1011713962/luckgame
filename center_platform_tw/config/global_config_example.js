/**
 * 配置
 * FileName: global_config.js
 */

module.exports = {
    //port
    port: 7000,
    //mysql
    mysql: {
        host: '127.0.0.1',
        port: 3306,
        username: 'root',
        password: 'yx168168'
    },
    //redis
    redis: {
        host: '172.17.0.4',
        port: 6379,
        db: 0,
        password: 'yx168168'
    },
    //支付
    pay: {
        //line pay
        linepay: {
            //sandbox url
            // url: 'https://sandbox-api-pay.line.me',
            //production url
            url: 'https://api-pay.line.me',
        },
        //异步通知域名
        notify_domain: 'https://api.junglespin.net',
    },
};