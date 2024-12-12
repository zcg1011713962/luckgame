/**
 * 应用
 * Date: 2023/08/28
 */
const express = require('express');
const router = express.Router();
const common = require('../../model/common');
const dbs = require('../../common/db/dbs')(config.mysql.dbs.gb_pay);
router.use(async function (req, res, next) {
    await common.preExec(req, res, next);
});
/**
 * 列表
 */
router.all('/', async (req, res) => {
    const method = req.method.toUpperCase();
    if ('POST' === method) {
        const data = {code: 0, count: 0, data: [], msg: 'success'};
        const name = req.body.name || '';
        const page = req.body.page || 1;
        const pageSize = req.body.limit || 10;
        const where = [];
        if (name) {
            where.push(['name', '==', name]);
        }
        const start = (page - 1) * pageSize;
        const limit = [start, pageSize];
        const count = await dbs.count(Const.TABLES.GB_PAY.APP, [], where);
        if (count > 0) {
            data.data = await dbs.gets(Const.TABLES.GB_PAY.APP, [], where, ['id', 'desc'], limit);
            if (data.data.length > 0) {
                for(let item of data.data) {
                    item.create_time = funcs.datestamps(item.create_time, true, true, '-');
                }
            }
            data.count = count;
        }
        return res.json(data);
    } else {
        const currencyList = await dbs.gets(Const.TABLES.GB_PAY.CURRENCY);
        const channelList = await dbs.gets(Const.TABLES.GB_PAY.CHANNEL);
        const eventList = await dbs.gets(Const.TABLES.GB_PAY.POINT_EVENT);
        const percentList = [];
        for (let i = 0; i <= 100; i++) {
            percentList.push(parseFloat(i / 100).toFixed(2));
        }
        return res.render('app/index', {currencyList, channelList, percentList, eventList});
    }
});
/**
 * @name 更新状态
 * @param status 0正常 -1被封
 * @date 2023/07/11 17:50:28
 * @return json
 */
router.post('/editStatus', async (req, res) => {
    const {id = 0, status = 0} = req.body;
    if (!id) {
        return res.json(errors('param error'));
    }
    if (![0, -1].includes(parseInt(status))) {
        return res.json(errors('param error'));
    }
    const result = await dbs.sets(Const.TABLES.GB_PAY.APP, {status}, {id});
    if (!result) {
        return res.json(errors('operate failed'));
    }
    return res.json(success());
});
/**
 * 查看详情
 */
router.post('/info', async (req, res) => {
    const id = req.body.id || 0;
    const info = await dbs.getOne(Const.TABLES.GB_PAY.APP, [], {id});
    if (Object.keys(info).length === 0) {
        return res.json(errors('not found'));
    }
    return res.json(success(info));
});
/**
 * 新增或编辑
 */
router.post('/addEdit', async (req, res) => {
    const param = req.body;
    const nowTime = Date.now();
    const id = param.id || 0;
    const name = param.name || '';
    if (!name) {
        return res.json(errors('param error'));
    }
    const data = {
        name: param.name || '',
        currency: param.currency || '',
        ad_app_token: param.ad_app_token || '',
        ad_identity_token: param.ad_identity_token || '',
        remark: param.remark || '',
        update_time: nowTime
    }
    let result;
    if (!id) {
        data.app_token = funcs.encryptMd5(`${name}_${nowTime}`);
        data.create_time = nowTime;
        result = await dbs.insert(Const.TABLES.GB_PAY.APP, data);
    } else {
        result = await dbs.sets(Const.TABLES.GB_PAY.APP, data, {id});
    }
    if (!result) {
        return res.json(errors('operate failed'));
    }
    return res.json(success());
});
/**
 * 应用绑定的支付渠道
 */
router.post('/appChannel', async (req, res) => {
    const id = req.body.id || 0;
    const list = await dbs.gets(Const.TABLES.GB_PAY.APP_CHANNEL, [], [['app_id', '=', id], ['status', '=', Const.COMMON_STATUS.NORMAL]]);
    return res.json(success(list));
});
/**
 * 应用绑定支付渠道
 */
router.post('/bindChannel', async (req, res) => {
    const app_id = req.body.id || 0;
    const id_weight = req.body.id_weight || '';
    if (!app_id || !id_weight) {
        return res.json(errors('param error'));
    }
    const idWeightArr = JSON.parse(id_weight);
    const appChannelList = await dbs.gets(Const.TABLES.GB_PAY.APP_CHANNEL, [], ['app_id', '=', app_id]);
    if (appChannelList.length > 0) {
        if (idWeightArr.length > 0) {
            const origin = appChannelList.map(s => s.channel_id);
            const curr = [], currObj = {};
            for (let val of idWeightArr) {
                curr.push(parseInt(val.channel_id));
                currObj[val.channel_id] = val.weight;
                if (!origin.includes(parseInt(val.channel_id))) {
                    appChannelList.push({id: 0, app_id, channel_id: val.channel_id, weight: val.weight});
                }
            }
            for (let item of appChannelList) {
                if (item.id === 0) {
                    dbs.insert(Const.TABLES.GB_PAY.APP_CHANNEL, {app_id, channel_id: item.channel_id, weight: item.weight});
                } else {
                    if (curr.includes(parseInt(item.channel_id))) {
                        dbs.sets(Const.TABLES.GB_PAY.APP_CHANNEL, {weight: currObj[item.channel_id], status: Const.COMMON_STATUS.NORMAL}, {app_id, channel_id: item.channel_id});
                    } else {
                        dbs.sets(Const.TABLES.GB_PAY.APP_CHANNEL, {status: Const.COMMON_STATUS.DEL}, {app_id, channel_id: item.channel_id});
                    }
                }
            }
        } else {
            dbs.sets(Const.TABLES.GB_PAY.APP_CHANNEL, {status: Const.COMMON_STATUS.DEL}, {app_id});
        }
    } else {
        if (idWeightArr.length > 0) {
            for (let item of idWeightArr) {
                dbs.insert(Const.TABLES.GB_PAY.APP_CHANNEL, {app_id, channel_id: item.channel_id, weight: item.weight});
            }
        }
    }
    return res.json(success());
});
/**
 * 应用绑定的埋点事件
 */
router.post('/appEvent', async (req, res) => {
    const id = req.body.id || 0;
    const list = await dbs.gets(Const.TABLES.GB_PAY.APP_EVENT, [], ['app_id', '=', id]);
    return res.json(success(list));
});
/**
 * 应用绑定埋点事件
 */
router.post('/bindEvent', async (req, res) => {
    const app_id = req.body.id || 0;
    const id_token = req.body.id_token || '';
    if (!app_id || !id_token) {
        return res.json(errors('param error'));
    }
    const idTokenArr = JSON.parse(id_token);
    const appEventList = await dbs.gets(Const.TABLES.GB_PAY.APP_EVENT, [], ['app_id', '=', app_id]);
    if (appEventList.length > 0) {
        if (idTokenArr.length > 0) {
            const origin = appEventList.map(s => s.event_id);
            const curr = [], currObj = {};
            for (let val of idTokenArr) {
                curr.push(parseInt(val.event_id));
                currObj[val.event_id] = val.event_token;
                if (!origin.includes(parseInt(val.event_id))) {
                    appEventList.push({id: 0, app_id, event_id: val.event_id, event_token: val.event_token});
                }
            }
            for (let item of appEventList) {
                if (item.id === 0) {
                    dbs.insert(Const.TABLES.GB_PAY.APP_EVENT, {app_id, event_id: item.event_id, event_token: item.event_token});
                } else {
                    if (curr.includes(parseInt(item.event_id))) {
                        dbs.sets(Const.TABLES.GB_PAY.APP_EVENT, {event_token: currObj[item.event_id], status: Const.COMMON_STATUS.NORMAL}, {app_id, event_id: item.event_id});
                    } else {
                        dbs.sets(Const.TABLES.GB_PAY.APP_EVENT, {status: Const.COMMON_STATUS.DEL}, {app_id, event_id: item.event_id});
                    }
                }
            }
        } else {
            dbs.sets(Const.TABLES.GB_PAY.APP_EVENT, {status: Const.COMMON_STATUS.DEL}, {app_id});
        }
    } else {
        if (idTokenArr.length > 0) {
            for (let item of idTokenArr) {
                dbs.insert(Const.TABLES.GB_PAY.APP_EVENT, {app_id, event_id: item.event_id, event_token: item.event_token});
            }
        }
    }
    return res.json(success());
});
module.exports = router;
