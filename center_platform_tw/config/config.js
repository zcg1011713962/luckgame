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
            gb_pay: 'cp_tw'
        }
    },
    //redis配置
    redis: {
        host: globalConfig.redis.host,
        port: globalConfig.redis.port,
        db: globalConfig.redis.db,
        password: globalConfig.redis.password
    }
};
const configString = JSON.stringify(Object.assign({}, config, basic, time, template));
module.exports = JSON.parse(configString);