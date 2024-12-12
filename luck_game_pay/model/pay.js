/**
 * 支付
 */
const httpRequest = require('../common/request/http');
const dbs = require('../common/db/dbs')(config.mysql.dbs.game);
const globalConfig = require('../config/global_config');
class Pay {

    constructor() {
        //代收发起订单地址
        this.payOrderCreateUrl = config.opt_url.create_pay_order_url;
        //代收订单查询
        this.payOrderQueryUrl = config.opt_url.query_pay_order_url;
        //代收异步回调地址
        this.payNotifyUrl = `${globalConfig.pay.notify_domain}/callback/payAsync`;
        //代付发起订单地址
        this.payoutOrderCreateUrl = config.opt_url.create_payout_order_url;
        //代付订单查询
        this.payoutOrderQueryUrl = config.opt_url.query_payout_order_url;
        //代付异步回调地址
        this.payoutNotifyUrl = `${globalConfig.pay.notify_domain}/callback/payoutAsync`;
    }

    /**
     * 代收创建订单
     * @param data
     * @returns {Promise<*>}
     */
    async createPayOrder(data) {
        const environment = globalConfig?.pay?.environment ?? 'production';
        const params = {
            app_token: config.app_token,
            channel: data?.channelType || '',
            method: data?.channelCode || '',
            amount: data.amount,
            merOrderNo: funcs.genOrderNo(),
            notifyUrl: this.payNotifyUrl,
            environment
        };
        funcs.log(`environment: ${environment} createPayOrder param: ${JSON.stringify(params)}`);
        const result = await httpRequest.post(this.payOrderCreateUrl, params);
        funcs.log(`environment: ${environment} createPayOrder response: ${JSON.stringify(result)}`);
        return result;
    }

    /**
     * 代收查询订单
     * @param data
     * @returns {Promise<*>}
     */
    async queryPayOrder(data) {
        const params = {
            app_token: config.app_token,
            merOrderNo: data.merOrderNo,
        };
        funcs.log(`queryPayOrder param: ${JSON.stringify(params)}`);
        const result = await httpRequest.post(this.payOrderQueryUrl, params);
        funcs.log(`queryPayOrder response: ${JSON.stringify(result)}`);
        return result;
    }
    /**
     * 代付创建订单
     * @param data
     * @returns {Promise<*>}
     */
    async createPayoutOrder(data) {
        const environment = globalConfig?.pay?.environment ?? 'production';
        const params = {
            app_token: config.app_token,
            amount: data.amount,
            merOrderNo: data.merOrderNo || funcs.genOrderNo(),
            notifyUrl: this.payoutNotifyUrl,
            environment,
            accountNo: data.accountNo,
            accountName: data.accountName,
            bankCode: data.bankCode,
            channel: data?.channel || '',
        };
        if (Object.keys(data).includes('email') && !!data.email) {
            params.email = data.email;
        }
        if (Object.keys(data).includes('phone') && !!data.phone) {
            params.phone = data.phone;
        }
        funcs.log(`environment: ${environment} createPayoutOrder param: ${JSON.stringify(params)}`);
        const result = await httpRequest.post(this.payoutOrderCreateUrl, params);
        funcs.log(`environment: ${environment} createPayoutOrder response: ${JSON.stringify(result)}`);
        return result;
    }

    /**
     * 代付查询订单
     * @param data
     * @returns {Promise<*>}
     */
    async queryPayoutOrder(data) {
        const params = {
            app_token: config.app_token,
            merOrderNo: data.merOrderNo,
        };
        funcs.log(`queryPayoutOrder param: ${JSON.stringify(params)}`);
        const result = await httpRequest.post(this.payoutOrderQueryUrl, params);
        funcs.log(`queryPayoutOrder response: ${JSON.stringify(result)}`);
        return result;
    }

    /**
     * 主动查询
     * @param merOrderNo
     * @param type 0代收 1代付
     */
    async initiativeQuery(merOrderNo, type) {
        //每隔五分钟查一次，一小时之后就不查了
        let queryCount = 0
        const i = setInterval(async () => {
            queryCount++;
            if (queryCount >= 6) {
                clearInterval(i);
            } else {
                if (Const.PAY_ORDER_TYPE.PAYMENT === type) {//代收
                    //查当前订单是否已支付成功
                    const payOrder = await dbs.getOne(Const.TABLES.GAME.D_USER_RECHARGE, [], {orderid: merOrderNo});
                    if (Object.keys(payOrder).length === 0) {
                        clearInterval(i);
                    } else {
                        if (payOrder.status < 2) {
                            //查询
                            const payResult = await this.queryPayOrder({merOrderNo});
                            if (Const.RESULT_STATUS.SUCCESS === payResult.status &&
                                Const.RESULT_STATUS.SUCCESS === payResult?.data?.code &&
                                Const.COMMON_PAY_STATUS.SUCCESS === payResult?.data?.data?.status) {
                                const params = {
                                    mod: 'pay',
                                    act: 'callback',
                                    orderid: merOrderNo
                                };
                                httpRequest.get(config.game_server_url, params);
                            }
                        } else {
                            clearInterval(i);
                        }
                    }
                } else if (Const.PAY_ORDER_TYPE.PAYOUT === type) {//代付
                    //查当前订单是否已出款成功
                    const nowTime = funcs.nowTime();
                    const payoutOrder = await dbs.getOne(Const.TABLES.GAME.D_USER_DRAW, [], {orderid: merOrderNo});
                    if (Object.keys(payoutOrder).length === 0) {
                        clearInterval(i);
                    } else {
                        if (Const.PAYMENT_DICT.DOING === parseInt(payoutOrder.chanstate)) {
                            //查询
                            const payoutResult = await this.queryPayoutOrder({merOrderNo});
                            if (Const.RESULT_STATUS.SUCCESS === payoutResult.status &&
                                Const.RESULT_STATUS.SUCCESS === payoutResult?.data?.code &&
                                Const.COMMON_PAY_STATUS.SUCCESS === payoutResult?.data?.data?.status) {
                                const param = {
                                    chanstate: Const.PAYMENT_DICT.DONE,
                                    notify_time: nowTime,
                                    backcoin: payoutResult?.data?.data?.amount ?? 0
                                };
                                const actStatus = Const.PAYMENT_DICT.DONE;
                                const ret = await dbs.sets(Const.TABLES.GAME.D_USER_DRAW, param, {orderid: merOrderNo});
                                if (ret !== false) {
                                    const params = {
                                        mod: 'user',
                                        act: 'drawverify',
                                        uid: payoutOrder['uid'],
                                        coin: payoutOrder['coin'],
                                        id: payoutOrder['id'],
                                        status: actStatus,
                                    };
                                    const timeout = 60000;
                                    const result = await httpRequest.get(config.game_server_url, params, {}, timeout);
                                    this.addDrawOrPayLog(merOrderNo, payoutOrder['uid'], nowTime, '提现订单异步通知处理成功');
                                    funcs.log(`提现订单处理成功！订单号：${merOrderNo}, 游戏服务器返回值：${JSON.stringify(result)}`);
                                } else {
                                    funcs.log(`提现订单处理失败！订单号：${merOrderNo}`);
                                    this.addDrawOrPayLog(merOrderNo, payoutOrder['uid'], nowTime, '提现订单异步通知处理失败');
                                }
                            }
                        } else {
                            clearInterval(i);
                        }
                    }
                }
            }
        }, 1000 * 60 * 5);
    }

    /**
     * 日志
     * @param orderid
     * @param uid
     * @param now_time
     * @param memo
     * @param cat
     */
    addDrawOrPayLog(orderid, uid = 0, now_time, memo, cat = 2) {
        const log = {
            orderid: orderid,
            cat: cat,
            create_time: now_time,
            uid: uid,
            memo: memo
        };
        dbs.insert(Const.TABLES.GAME.D_LOG_ORDER, log);
    }

    /**
     * 获取快捷金额列表 1:充值 2:提现
     * @param type
     * @returns {Promise<*[]>}
     */
    async getBetCoinList(type= 1) {
        const where = [
            ['type', '=', type], ['status', '=', 1]
        ];
        const order = ['amount', 'asc'];
        return await dbs.gets(Const.TABLES.GAME.S_CONFIG_AMOUNT, ['id', 'amount'], where, order);
    }
    /**
     * 获取充值活动金额列表
     * @returns {Promise<*[]>}
     */
    async getRechargeBonusList() {
        const rechargeBonusKey = 'recharge_bonus_list';
        const result = await dbs.getOne(Const.TABLES.GAME.S_CONFIG, ['v'], {k: rechargeBonusKey});
        if (Object.keys(result).length === 0 || !result.v) {
            return [];
        }
        try {
            const list = JSON.parse(result.v);
            return list.filter(item => parseInt(item.status) === 1).sort((a, b) => parseInt(a.ord) - parseInt(b.ord));
        } catch (e) {
            return [];
        }
    }
    /**
     * 获取普通充值金额列表
     * @returns {Promise<*[]>}
     */
    async getRechargeNormalList() {
        const rechargeBonusKey = 'recharge_normal_list';
        const result = await dbs.getOne(Const.TABLES.GAME.S_CONFIG, ['v'], {k: rechargeBonusKey});
        if (Object.keys(result).length === 0 || !result.v) {
            return [];
        }
        try {
            const list = JSON.parse(result.v);
            return list.filter(item => parseInt(item.status) === 1).sort((a, b) => parseInt(a.ord) - parseInt(b.ord));
        } catch (e) {
            return [];
        }
    }
}

module.exports = new Pay();