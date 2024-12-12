/**
 * pay
 */
const express = require('express');
const router = express.Router();
const dbs = require('../common/db/dbs')(config.mysql.dbs.gb_pay);
const TW_linepay = require('../model/pay/tw_linepay');
const Common = require('../model/common');
const Pay = require('../model/pay');
//IP and app token
router.use(async function (req, res, next) {
    await Common.commonMiddleware(req, res, next);
});
/**
 * 创建代收订单
 */
router.post('/createPayOrder', async (req, res) => {
    const appId = req.state.app_id;
    const amount = req.body.amount || 0;
    //支付渠道
    const channel = req.body.channel || '';
    const returnUrl = req.body.returnUrl || '';
    const notifyUrl = req.body.notifyUrl || '';
    const merOrderNo = req.body.merOrderNo || '';
    const environment = req.body.environment || 'production';
    if (amount <= 0) {
        return res.json(errors('param error'));
    }
    let channelInfo;
    const fields = 'c.*,ac.weight,ac.app_id';
    //判断是否传channel
    if (channel) {
        const SQL = `SELECT ${fields} FROM ${Const.TABLES.GB_PAY.CHANNEL} c INNER JOIN ${Const.TABLES.GB_PAY.APP_CHANNEL} ac ON ac.channel_id = c.id 
            WHERE c.type = '${channel}' AND ac.app_id = ${appId} AND ac.status = 0`;
        const channelList = await dbs.querys(SQL, 'SELECT');
        if (channelList.length === 0) {
            return res.json(errors('channel type not bind'));
        }
        channelInfo = channelList[0];
    } else {
        const SQL = `SELECT ${fields} FROM ${Const.TABLES.GB_PAY.CHANNEL} c INNER JOIN ${Const.TABLES.GB_PAY.APP_CHANNEL} ac ON ac.channel_id = c.id 
            WHERE ac.app_id = ${appId} AND ac.status = 0`;
        const channelList = await dbs.querys(SQL, 'SELECT');
        if (channelList.length === 0) {
            return res.json(errors('channel type not bind'));
        }
        if (channelList.length === 1) {
            channelInfo = channelList[0];
        } else {
            //如果不止一个就按权重自动分配
            const weighArr = [];
            const typeArr = [];
            const channelObj = {};
            for (let item of channelList) {
                weighArr.push(item.weight);
                typeArr.push(item.type);
                channelObj[item.type] = item;
            }
            //根据权重选择使用哪个支付渠道
            const weight = funcs.rechargeChannel(weighArr);
            channelInfo = channelObj[typeArr[weight]];
        }
    }
    channelInfo.returnUrl = returnUrl;
    channelInfo.notifyUrl = notifyUrl;
    channelInfo.merOrderNo = merOrderNo;
    const channel_type = channelInfo.type;
    const currency = channelInfo.currency;
    let result = null;
    //line pay
    if (Const.CHANNEL_TYPE.LINE_PAY === channel_type && Const.CURRENCY.TWD === currency) {
        result = await TW_linepay.createPayOrder(channelInfo, amount, environment);
    }
    if (Const.RESULT_STATUS.SUCCESS === result?.code) {
        //订单成功之后添加主动查询机制
        Pay.initiativeQuery(appId, result?.data?.merOrderNo ?? '', Const.PAY_ORDER_TYPE.PAYMENT);
        return res.json(result);
    }
    let error_msg = 'channel type error!';
    if (result?.msg) {
        error_msg = result?.msg;
    }
    return res.json(errors(error_msg));
});
/**
 * 查询代收订单
 */
router.post('/queryPay', async (req, res) => {
    const appId = req.state.app_id;
    const merOrderNo = req.body.merOrderNo || '';
    if (!merOrderNo) {
        return res.json(errors('param error'));
    }
    const result = await Pay.queryPayOrder(appId, merOrderNo);
    return res.json(result);
});

module.exports = router;
