/**
 * 回调
 */
const express = require('express');
const router = express.Router();
const dbs = require('../common/db/dbs')(config.mysql.dbs.game);
const Common = require('../model/common');
const httpRequest = require('../common/request/http');
const Pay = require('../model/pay');
//ip白名单
router.use(async (req, res, next) => {
    await Common.checkIpWhitelist(req, res, next, Const.IP_WHITELIST_KEY.PAY_CALLBACK);
});
/**
 * 代收同步回调
 */
router.all('/paySync', async (req, res) => {
    Common.writeLog(`paySync body param : ${JSON.stringify(req.body)}, query param: ${JSON.stringify(req.query)}`);
    return res.send('ok');
});
/**
 * 代收异步回调
 */
router.post('/payAsync', async (req, res) => {
    // channel	letspay	支付渠道
    // currency	INR	币种
    // merOrderNo	21716109879899425888	商户号
    // orderNo	P1UPE4V4RJ	交易号
    // status	1	1支付中 2交易成功 -1交易失败 -2交易过期
    // amount	20000	金额
    // payTime	1716191425685	交易时间
    funcs.log(`payAsync param : ${JSON.stringify(req.body)}`);
    const nowTime = funcs.nowTime();
    const orderStatus = parseInt(funcs.removeQuotes(req.body.status));
    const merOrderNo = req.body.merOrderNo || '';
    const sign = req.body.sign || '';
    const localSign = funcs.callbackSign(merOrderNo);
    if (sign !== localSign) {
        funcs.log(`[payAsync]merOrderNO: ${merOrderNo}, sign error! sign: ${sign}, local_sign: ${localSign}`);
        return res.send('failed');
    }

    //查询订单状态
    const orderInfo = await dbs.getOne(Const.TABLES.GAME.D_USER_RECHARGE, [], {orderid: merOrderNo});
    if (Object.keys(orderInfo).length === 0) {
        funcs.log(`merOrderNO: ${merOrderNo}, order not found`);
        return res.send('failed');
    }
    if (orderInfo.status >= 2) {
        funcs.log(`merOrderNO: ${merOrderNo}, no need callback`);
        return res.send('ok');
    }
    if (Const.COMMON_PAY_STATUS.SUCCESS !== orderStatus) {
        //订单回调状态不是支付成功
        funcs.log(`merOrderNO: ${merOrderNo}, order unpaid`);
        return res.send('ok');
    }
    //回调的支付状态是成功的，回调6920端口 3次
    const params = {
        mod: 'pay',
        act: 'callback',
        orderid: merOrderNo
    };
    const timeout = 60000;
    const result1 = await httpRequest.get(config.game_server_url, params, {}, timeout);
    if (Const.RESULT_STATUS.SUCCESS === result1.status && 'succ' === result1.data) {
        funcs.log(`merOrderNO: ${merOrderNo}, params: ${JSON.stringify(params)}, Request success(1)`);
        Pay.addDrawOrPayLog(merOrderNo, orderInfo['uid'], nowTime, '充值订单异步通知处理成功1');
        return res.send('ok');
    }
    const result2 = await httpRequest.get(config.game_server_url, params, {}, timeout);
    if (Const.RESULT_STATUS.SUCCESS === result2.status && 'succ' === result2.data) {
        funcs.log(`merOrderNO: ${merOrderNo}, params: ${JSON.stringify(params)}, Request success(2)`);
        Pay.addDrawOrPayLog(merOrderNo, orderInfo['uid'], nowTime, '充值订单异步通知处理成功2');
        return res.send('ok');
    }
    const result3 = await httpRequest.get(config.game_server_url, params, {}, timeout);
    if (Const.RESULT_STATUS.SUCCESS === result3.status && 'succ' === result3.data) {
        Pay.addDrawOrPayLog(merOrderNo, orderInfo['uid'], nowTime, '充值订单异步通知处理成功3');
        funcs.log(`merOrderNO: ${merOrderNo}, params: ${JSON.stringify(params)}, Request success(3)`);
        return res.send('ok');
    }
    funcs.log(`merOrderNO: ${merOrderNo}, Request Failed 3 times, result1: ${JSON.stringify(result1)}, result2: ${JSON.stringify(result2)}, result3: ${JSON.stringify(result3)}`);
    Pay.addDrawOrPayLog(merOrderNo, orderInfo['uid'], nowTime, '充值订单异步通知处理失败');
    return res.send('failed');
});

/**
 * 代付同步回调
 */
router.all('/payoutSync', async (req, res) => {
    Common.writeLog(`payoutSync body param : ${JSON.stringify(req.body)}, query param: ${JSON.stringify(req.query)}`);
    return res.send('ok');
});
/**
 * 代付异步回调
 */
router.post('/payoutAsync', async (req, res) => {
    // channel	letspay	支付渠道
    // currency	INR	币种
    // merOrderNo	21716109879899425888	商户号
    // orderNo	P1UPE4V4RJ	交易号
    // status	1	1支付中 2交易成功 -1交易失败 -2交易过期
    // amount	50000	金额
    // payTime	1716191425685	交易时间
    funcs.log(`payoutAsync param : ${JSON.stringify(req.body)}`);
    const nowTime = funcs.nowTime();
    const orderStatus = parseInt(funcs.removeQuotes(req.body.status));
    const merOrderNo = req.body.merOrderNo || '';
    const amount = req.body.amount || '';
    const sign = req.body.sign || '';
    const localSign = funcs.callbackSign(merOrderNo);
    if (sign !== localSign) {
        funcs.log(`[payoutAsync]merOrderNO: ${merOrderNo}, sign error! sign: ${sign}, local_sign: ${localSign}`);
        return res.send('failed');
    }

    const orderInfo = await dbs.getOne(Const.TABLES.GAME.D_USER_DRAW, [], {orderid: merOrderNo});
    if (Object.keys(orderInfo).length === 0) {
        funcs.log(`merOrderNO: ${merOrderNo}, order not found`);
        return res.send('failed');
    }
    if (parseInt(orderInfo.status) === 2 && [Const.PAYMENT_DICT.DONE, Const.PAYMENT_DICT.FAIL].includes(orderInfo.chanstate)) {
        //已出款成功或失败
        funcs.log(`merOrderNO: ${merOrderNo}, no need callback`);
        return res.send('ok');
    }
    const param = {
        chanstate: Const.PAYMENT_DICT.DONE,
        notify_time: nowTime,
    };
    let actStatus = Const.PAYMENT_DICT.FAIL;
    if(Const.COMMON_PAY_STATUS.SUCCESS === orderStatus) {
        param.backcoin = amount;
        actStatus = Const.PAYMENT_DICT.DONE;
    }
    const ret = await dbs.sets(Const.TABLES.GAME.D_USER_DRAW, param, {orderid: merOrderNo});
    if (ret !== false) {
        const params = {
            mod: 'user',
            act: 'drawverify',
            uid: orderInfo['uid'],
            coin: orderInfo['coin'],
            id: orderInfo['id'],
            status: actStatus,
        };
        const timeout = 60000;
        const result = await httpRequest.get(config.game_server_url, params, {}, timeout);
        Pay.addDrawOrPayLog(merOrderNo, orderInfo['uid'], nowTime, '提现订单异步通知处理成功');
        funcs.log(`提现订单处理成功！订单号：${merOrderNo}, 参数：${JSON.stringify(params)} 游戏服务器返回值：${JSON.stringify(result)}`);
        return res.send('ok');
    }
    funcs.log(`提现订单处理失败！订单号：${merOrderNo}`);
    Pay.addDrawOrPayLog(merOrderNo, orderInfo['uid'], nowTime, '提现订单异步通知处理失败');
    return res.send('ok');
});
module.exports = router;
