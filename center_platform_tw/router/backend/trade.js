/**
 * 交易管理
 */
const express = require('express');
const router = express.Router();
const common = require('../../model/common');
const dbs = require('../../common/db/dbs')(config.mysql.dbs.gb_pay);
const Pay = require('../../model/pay');
router.use(async function (req, res, next) {
    await common.preExec(req, res, next);
});
/**
 * 代收订单
 */
router.all('/payOrder', async (req, res) => {
    const method = req.method.toUpperCase();
    if ('POST' === method) {
        const data = {code: 0, count: 0, data: [], msg: 'success'};
        const appId = req.body.app_id || '';
        const channelId = req.body.channel_id || '';
        const merOrderNo = req.body.mer_order_no || '';
        const startTime = req.body.start_time || '';
        const endTime = req.body.end_time || '';
        const environment = req.body.environment || '';
        const status = req.body.status;
        const page = req.body.page || 1;
        const pageSize = req.body.limit || 10;
        const where = [];
        if (appId) {
            where.push(['app_id', '=', appId]);
        }
        if (channelId) {
            where.push(['channel_id', '=', channelId]);
        }
        if (merOrderNo) {
            where.push(['mer_order_no', '=', merOrderNo]);
        }
        if (Object.keys(req.body).includes('status') && status !== '') {
            where.push(['status', '=', status]);
        }
        if (startTime) {
            where.push(['create_time', '>=', funcs.timestamps(startTime)]);
        }
        if (endTime) {
            where.push(['create_time', '<=', funcs.timestamps(endTime)]);
        }
        if (environment) {
            where.push(['environment', '=', environment]);
        }
        const start = (page - 1) * pageSize;
        const limit = [start, pageSize];
        const count = await dbs.count(Const.TABLES.GB_PAY.PAYMENT_ORDER, [], where);
        if (count > 0) {
            data.data = await dbs.gets(Const.TABLES.GB_PAY.PAYMENT_ORDER, [], where, ['id', 'desc'], limit);
            if (data.data.length > 0) {
                const appObj = {};
                const appList = await dbs.gets(Const.TABLES.GB_PAY.APP, ['id', 'name']);
                if (appList.length > 0) {
                    for (let item of appList) {
                        appObj[item.id] = item.name;
                    }
                }
                const channelObj = {};
                const channelList = await dbs.gets(Const.TABLES.GB_PAY.CHANNEL, ['id', 'name']);
                if (channelList.length > 0) {
                    for (let item of channelList) {
                        channelObj[item.id] = item.name;
                    }
                }
                for(let item of data.data) {
                    item.create_time = funcs.datestamps(item.create_time, true, true, '-');
                    item.pay_time = item.pay_time ? funcs.datestamps(item.pay_time, true, true, '-') : '';
                    item.app_name = appObj[item.app_id] ?? '';
                    item.channel_name = channelObj[item.channel_id] ?? '';
                }
            }
            data.count = count;
        }
        return res.json(data);
    } else {
        const appList = await dbs.gets(Const.TABLES.GB_PAY.APP);
        const channelList = await dbs.gets(Const.TABLES.GB_PAY.CHANNEL);
        const orderStatus = Const.COMMON_PAY_STATUS_ARR;
        return res.render('trade/pay_order', {appList, channelList, orderStatus});
    }
});
/**
 * 查询代收订单
 */
router.post('/queryPay', async(req, res) => {
    const appId = req.body.app_id || '';
    const merOrderNo = req.body.merOrderNo || '';
    if (!appId || !merOrderNo) {
        return res.json(errors('param error'));
    }
    const result = await Pay.queryPayOrder(appId, merOrderNo);
    return res.json(result);
});
/**
 * 已支付订单再次回调
 */
router.post('/callbackPayAgain', async(req, res) => {

});
/**
 * 代收订单测试回调
 */
router.post('/callbackPayTest', async(req, res) => {

});

/**
 * 代付订单
 */
router.all('/payoutOrder', async (req, res) => {
    const method = req.method.toUpperCase();
    if ('POST' === method) {
        const data = {code: 0, count: 0, data: [], msg: 'success'};
        const appId = req.body.app_id || '';
        const channelId = req.body.channel_id || '';
        const merOrderNo = req.body.mer_order_no || '';
        const startTime = req.body.start_time || '';
        const endTime = req.body.end_time || '';
        const status = req.body.status;
        const page = req.body.page || 1;
        const pageSize = req.body.limit || 10;
        const environment = req.body.environment || '';
        const where = [];
        if (appId) {
            where.push(['app_id', '=', appId]);
        }
        if (channelId) {
            where.push(['channel_id', '=', channelId]);
        }
        if (merOrderNo) {
            where.push(['mer_order_no', '=', merOrderNo]);
        }
        if (Object.keys(req.body).includes('status') && status !== '') {
            where.push(['status', '=', status]);
        }
        if (startTime) {
            where.push(['create_time', '>=', funcs.timestamps(startTime)]);
        }
        if (endTime) {
            where.push(['create_time', '<=', funcs.timestamps(endTime)]);
        }
        if (environment) {
            where.push(['environment', '=', environment]);
        }
        const start = (page - 1) * pageSize;
        const limit = [start, pageSize];
        const count = await dbs.count(Const.TABLES.GB_PAY.PAYOUT_ORDER, [], where);
        if (count > 0) {
            data.data = await dbs.gets(Const.TABLES.GB_PAY.PAYOUT_ORDER, [], where, ['id', 'desc'], limit);
            if (data.data.length > 0) {
                const appObj = {};
                const appList = await dbs.gets(Const.TABLES.GB_PAY.APP, ['id', 'name']);
                if (appList.length > 0) {
                    for (let item of appList) {
                        appObj[item.id] = item.name;
                    }
                }
                const channelObj = {};
                const channelList = await dbs.gets(Const.TABLES.GB_PAY.CHANNEL, ['id', 'name']);
                if (channelList.length > 0) {
                    for (let item of channelList) {
                        channelObj[item.id] = item.name;
                    }
                }
                for(let item of data.data) {
                    item.create_time = funcs.datestamps(item.create_time, true, true, '-');
                    item.pay_time = item.pay_time ? funcs.datestamps(item.pay_time, true, true, '-') : '';
                    item.app_name = appObj[item.app_id] ?? '';
                    item.channel_name = channelObj[item.channel_id] ?? '';
                }
            }
            data.count = count;
        }
        return res.json(data);
    } else {
        const appList = await dbs.gets(Const.TABLES.GB_PAY.APP);
        const channelList = await dbs.gets(Const.TABLES.GB_PAY.CHANNEL);
        const orderStatus = Const.COMMON_PAY_STATUS_ARR;
        return res.render('trade/payout_order', {appList, channelList, orderStatus});
    }
});
/**
 * 查询代付订单
 */
router.post('/queryPayout', async(req, res) => {
    const appId = req.body.app_id || '';
    const merOrderNo = req.body.merOrderNo || '';
    if (!appId || !merOrderNo) {
        return res.json(errors('param error'));
    }
    const result = await Pay.queryPayoutOrder(appId, merOrderNo);
    return res.json(result);
});
/**
 * 代付已支付订单再次回调
 */
router.post('/callbackPayoutAgain', async(req, res) => {

});
/**
 * 代付订单测试回调
 */
router.post('/callbackPayoutTest', async(req, res) => {

});
/**
 * 代收统计
 */
router.all('/payStat', async (req, res) => {
    const method = req.method.toUpperCase();
    if ('POST' === method) {
        const data = {code: 0, count: 0, data: [], msg: 'success'};
        const appId = req.body.app_id || '';
        const channel = req.body.channel || '';
        const startTime = req.body.start_time || '';
        const endTime = req.body.end_time || '';
        const where = [
            ['environment', '=', 'production']
        ];
        if (appId) {
            where.push(['app_id', '=', appId]);
        }
        if (startTime) {
            where.push(['create_time', '>=', funcs.timestamps(startTime)]);
        }
        if (endTime) {
            where.push(['create_time', '<=', funcs.timestamps(endTime)]);
        }
        let fields;
        if (channel) {
            where.push(['channel', '=', channel]);
            fields = [
                'channel', 'method',
                'SUM(1) AS total',
                'SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) AS in_pay',
                'SUM(CASE WHEN status = -1 THEN 1 ELSE 0 END) AS failed',
                'SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) AS success'
            ];
            data.data = await dbs.gets(Const.TABLES.GB_PAY.PAYMENT_ORDER, fields, where, [], 0, 'method');
        } else {
            fields = [
                'channel','"all" as method',
                'SUM(1) AS total',
                'SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) AS in_pay',
                'SUM(CASE WHEN status = -1 THEN 1 ELSE 0 END) AS failed',
                'SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) AS success'
            ];
            data.data = await dbs.gets(Const.TABLES.GB_PAY.PAYMENT_ORDER, fields, where, [], 0, 'channel');
        }

        if (data.data.length > 0) {
            for (let item of data.data) {
                item.success_rate = parseFloat(item.success / item.total * 100).toFixed() + '%';
                item.failed_rate = parseFloat(item.failed / item.total * 100).toFixed() + '%';
                item.in_pay_rate = parseFloat(item.in_pay / item.total * 100).toFixed() + '%';
            }
        }
        data.count = data.data.length;
        return res.json(data);
    } else {
        const appList = await dbs.gets(Const.TABLES.GB_PAY.APP);
        const channelList = await dbs.gets(Const.TABLES.GB_PAY.CHANNEL, ['type'], [], [], 0, 'type');
        return res.render('trade/pay_stat', {appList, channelList});
    }
});
module.exports = router;
