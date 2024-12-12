/**
 * 定义常量
 * FileName:const.js
 */
module.exports = {
    //数据库表名
    TABLES: {
        GB_PAY: {
            APP: 'gp_app',
            APP_CHANNEL: 'gp_app_channel',
            CHANNEL: 'gp_channel',
            PAYMENT_ORDER: 'gp_payment_order',
            PAYOUT_ORDER: 'gp_payout_order',
            CURRENCY: 'gp_currency',
            USER: 'gp_user',
            ROLE: 'gp_role',
            MENU: 'gp_menu',
            CONFIG: 'gp_config',
            APP_EVENT: 'gp_app_event',
            POINT_EVENT: 'gp_point_event',
            POINT_LOG: 'gp_point_log',
        }
    },
    //是和否
    WHETHER_STATUS: {
        YES: 1, NO: 0
    },
    //通用状态
    COMMON_STATUS: {
        NORMAL: 0,
        DEL: -1,
    },
    //返回状态值
    RESULT_STATUS: {
        SUCCESS: 0,
        ERROR: -1,
        TIMEOUT: -2,
    },
    //linepay支付接口返回状态
    LINE_PAY_RESULT_CODE: {
        SUCCESS: '0000',            //成功
    },
    //linepay付款状态
    LINE_PAY_CHECK_STATUS: {
        RESERVED: '0000',
        TO_CONFIRM: '0110',
        CANCELED: '0121',
        FAILED: '0122',
        SUCCEED: '0123'
    },
    //letspay代收订单状态
    LETSPAY_ORDER_STATUS: {
        IN_PAY: 1,                  //支付中
        SUCCESS: 2,                 //成功
        FAILED: -1,                 //失败
        EXPIRED: 5,                 //失效
    },
    //letspay代付订单状态
    LETSPAY_PAYOUT_ORDER_STATUS: {
        IN_PROCESS: 1,              //处理中
        SUCCESS: 2,                 //成功
        FAILED: 3,                  //失败
    },
    //pay订单类型
    PAY_ORDER_TYPE: {
        PAYMENT: 0,                 //代收
        PAYOUT: 1,                  //代付
    },
    //统一的代收及代付状态
    COMMON_PAY_STATUS: {
        IN_PAY: 1,                  //支付中
        SUCCESS: 2,                 //交易成功
        FAILED: -1,                 //交易失败
        EXPIRED: -2,                //交易过期
    },
    COMMON_PAY_STATUS_ARR: [
        {status: 1, title: '支付中'},
        {status: 2, title: '交易成功'},
        {status: -1, title: '交易失败'},
        {status: -2, title: '交易过期'},
    ],
    //支付渠道类型 ['linepay']
    CHANNEL_TYPE: {
        LINE_PAY: 'linepay',
    },
    //币种
    CURRENCY: {
        TWD: 'TWD'
    },
    //静态资源后缀
    STATIC_SUFFIX: [
        '.js',
        '.css',
        '.png',
        '.jpg',
        '.gif',
        '.woff',
        '.eot',
        '.svg',
        '.ttf',
    ],
    //埋点状态
    SEND_POINT_STATUS: {
        SUCCESS: 1,
        FAILED: 2
    }
};