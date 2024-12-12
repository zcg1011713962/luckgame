/**
 * linepay回调
 */
const express = require('express');
const router = express.Router();
const dbs = require('../../common/db/dbs')(config.mysql.dbs.gb_pay);
const TW_linepay = require('../../model/pay/tw_linepay');
const Common = require('../../model/common');
//ip白名单
router.use(async (req, res, next) => {
    let reqAddress = req.headers['x-forwarded-for'] || req.connection.remoteAddress || req.socket.remoteAddress || req.connection.socket.remoteAddress;
    console.log(`request ip address: ${reqAddress}`);
    if (!reqAddress) {
        return res.json(errors('request failed: can not get IP address'));
    }
    if (typeof reqAddress !== 'string') {
        return res.json(errors('request failed: IP address error!'));
    }
    const checkIp = await Common.checkIpWhitelist(reqAddress, 'linepay_callback_ip_whitelist');
    if (!checkIp) {
        return res.json(errors('request failed: IP not allowed!'));
    }
    next();
});
/**
 * 代收同步回调
 */
router.all('/paySync', async (req, res) => {
    Common.writeLog(`Linepay paySync body param : ${JSON.stringify(req.body)}, query param: ${JSON.stringify(req.query)}`);
    return res.send('ok');
});
/**
 *  取消代收回调
 */
router.all('/payCancelSync', async (req, res) => {
    Common.writeLog(`Linepay payCancelSync body param : ${JSON.stringify(req.body)}, query param: ${JSON.stringify(req.query)}`);
    return res.send('ok');
});
/**
 * 支付confirm url回调
 */
router.all('/payAsync', async (req, res) => {
    const nowTime = Date.now();
    Common.writeLog(`Linepay payAsync param : ${JSON.stringify(req.body)}`);
    const merOrderNo = req.query.orderId || req.body.orderId || '';
    const transactionId = req.query.transactionId || req.body.transactionId || '';
    //查询订单信息
    const orderInfo = await dbs.getOne(Const.TABLES.GB_PAY.PAYMENT_ORDER, [], {mer_order_no: merOrderNo});
    if (Object.keys(orderInfo).length === 0) {
        console.error(`payAsync, order info not found, merOrderNo: ${merOrderNo}`);
        return res.send('ok');
    }
    //查询渠道信息
    const channelInfo = await dbs.getOne(Const.TABLES.GB_PAY.CHANNEL, [], {id: orderInfo.channel_id});
    if (Object.keys(channelInfo).length === 0) {
        const cb_msg = `channel info not found, channel id: ${orderInfo.channel_id}`;
        dbs.sets(Const.TABLES.GB_PAY.PAYMENT_ORDER, {cb_msg: cb_msg.toString().replace(/'/g, '')}, {id: orderInfo.id});
        return res.send('ok');
    }
    //判断当前订单状态
    if (Const.COMMON_PAY_STATUS.IN_PAY !== orderInfo.status) {
        //订单如果不是支付中说明已经回调过，处理过订单状态了，更新一下回调次数
        const data = {
            async_nums: ['func_phrase', `async_nums + 1`], update_time: nowTime
        };
        dbs.sets(Const.TABLES.GB_PAY.PAYMENT_ORDER, data, {id: orderInfo.id});
        return res.send('ok');
    }
    setTimeout(function () {
        TW_linepay.callConfirmApiToFinishTrade(transactionId, channelInfo, orderInfo);
    }, 2000);
    return res.send('ok');
});

/**
 * 代付同步回调
 */
router.all('/payoutSync', async (req, res) => {
    Common.writeLog(`Linepay payoutSync body param : ${JSON.stringify(req.body)}, query param: ${JSON.stringify(req.query)}`);
    return res.send('ok');
});
/**
 * 代付异步回调
 */
router.post('/payoutAsync', async (req, res) => {

});
module.exports = router;
