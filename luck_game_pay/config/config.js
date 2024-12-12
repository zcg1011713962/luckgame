/**
 * 公共配置文件
 */
//配置文件路径
const configPath = `${APP_ROOT}/config`;
//基本配置
const basic = require(configPath + '/basic');
//时间日期相关配置
const time = require(configPath + '/time');
//artTemplate相关配置
const template = require(configPath + '/template');
//配置
const globalConfig = require('./global_config');
//項目配置
const config = {
    //端口
    port: globalConfig.port,
    //MySQL配置
    mysql: {
        host: globalConfig.mysql.host,
        port: globalConfig.mysql.port,
        username: globalConfig.mysql.username,
        password: globalConfig.mysql.password,
        dbs: {
            adm: 'indiarummy_adm',
            game: 'indiarummy_game',
        }
    },
    //redis配置
    redis: {
        host: globalConfig.redis.host,
        port: globalConfig.redis.port,
        db: globalConfig.redis.db,
        password: globalConfig.redis.password
    },
    //支付及埋点的app token
    app_token: globalConfig?.opt?.app_token || '420783b940c346c1b0b8d76933a87fbc',
    //运营平台url
    opt_url: {
        //代收
        create_pay_order_url: `${globalConfig.opt.url}/pay/createPayOrder`,
        query_pay_order_url: `${globalConfig.opt.url}/pay/queryPay`,
        //代付
        create_payout_order_url: `${globalConfig.opt.url}/pay/createPayoutOrder`,
        query_payout_order_url: `${globalConfig.opt.url}/pay/queryPayout`,
        //打点
        point_url: `${globalConfig.opt.url}/point/sendEvent`,
    },
    //游戏服务端URL
    game_server_url: globalConfig.game_server_url,
    //deposit配置
    deposit: {
        min_amount: 20000,
        max_amount: 100000000
    },
    //withdraw配置
    withdraw: {
        min_amount: 50000,
        max_amount: 500000000
    },
    //头像地址
    img_url: globalConfig.avatar_url
};
const configString = JSON.stringify(Object.assign({}, config, basic, time, template));
module.exports = JSON.parse(configString);