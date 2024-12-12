/**
 * 定义常量
 * FileName:const.js
 */
module.exports = {
    //数据库表名
    TABLES: {
        GAME: {
            D_USER: 'd_user',
            D_USER_RECHARGE: 'd_user_recharge',
            D_USER_BANK: 'd_user_bank',
            D_USER_DRAW: 'd_user_draw',
            D_LOG_ORDER: 'd_log_order',
            D_DESK_USER: 'd_desk_user',
            D_LOG_CASHBONUS: 'd_log_cashbonus',
            S_BANK: 's_bank',
            S_PAY_CFG_CHANNEL: 's_pay_cfg_channel',
            S_PAY_GROUP: 's_pay_group',
            S_PAY_CFG_OTHER: 's_pay_cfg_other',
            S_PAY_DISCOUNT: 's_pay_discount',
            S_PAY_CFG_DRAW: 's_pay_cfg_draw',
            S_PAY_CFG_DRAWCHAN: 's_pay_cfg_drawchan',
            S_PAY_CFG_DRAWCOM: 's_pay_cfg_drawcom',
            S_CONFIG: 's_config',
            S_PAY_CFG_DRAWLIMIT: 's_pay_cfg_drawlimit',
            S_GAME: 's_game',
            S_CONFIG_AMOUNT: 's_config_amount',
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
    //币种
    CURRENCY: {
        VND: 'VND'
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
    //出款状态值
    PAYMENT_DICT: {
        'INIT': 0,
        'DOING': 1,
        'DONE': 2,
        'FAIL': 3,
        'REJECT': 4,
    },
    //ip白名单键
    IP_WHITELIST_KEY: {
        PAY_CALLBACK: 'ip_whitelist_pay_callback',  //支付回调白名单
        CALL_API: 'ip_whitelist_call_api',          //api调用白名单
    }
};