/**
 * 渠道
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
        const count = await dbs.count(Const.TABLES.GB_PAY.CHANNEL, [], where);
        if (count > 0) {
            data.data = await dbs.gets(Const.TABLES.GB_PAY.CHANNEL, [], where, ['id', 'desc'], limit);
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
        const channelTypeList = Object.values(Const.CHANNEL_TYPE);
        return res.render('channel/index', {currencyList, channelTypeList});
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
    const result = await dbs.sets(Const.TABLES.GB_PAY.CHANNEL, {status}, {id});
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
    const info = await dbs.getOne(Const.TABLES.GB_PAY.CHANNEL, [], {id});
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
        type: param.type || '',
        currency: param.currency || '',
        mch_id: param.mch_id || '',
        md5_key: param.md5_key || '',
        pay_app_id: param.pay_app_id || '',
        pay_app_secret: param.pay_app_secret || '',
        payout_app_id: param.payout_app_id || '',
        payout_app_secret: param.payout_app_secret || '',
        remark: param.remark || '',
        update_time: nowTime
    }
    let result;
    if (!id) {
        data.create_time = nowTime;
        result = await dbs.insert(Const.TABLES.GB_PAY.CHANNEL, data);
    } else {
        result = await dbs.sets(Const.TABLES.GB_PAY.CHANNEL, data, {id});
    }
    if (!result) {
        return res.json(errors('operate failed'));
    }
    return res.json(success());
});
module.exports = router;
