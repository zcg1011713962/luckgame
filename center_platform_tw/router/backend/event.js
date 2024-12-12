/**
 * 埋点事件
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
        const name = req.body.event_name || '';
        const page = req.body.page || 1;
        const pageSize = req.body.limit || 10;
        const where = [];
        if (name) {
            where.push(['event_name', '=', name]);
        }
        const start = (page - 1) * pageSize;
        const limit = [start, pageSize];
        const count = await dbs.count(Const.TABLES.GB_PAY.POINT_EVENT, [], where);
        if (count > 0) {
            data.data = await dbs.gets(Const.TABLES.GB_PAY.POINT_EVENT, [], where, ['id', 'asc'], limit);
            data.count = count;
        }
        return res.json(data);
    } else {
        return res.render('event/index', {});
    }
});
/**
 * 查看详情
 */
router.post('/info', async (req, res) => {
    const id = req.body.id || 0;
    const info = await dbs.getOne(Const.TABLES.GB_PAY.POINT_EVENT, [], {id});
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
    const eventName = param.event_name || '';
    if (!eventName) {
        return res.json(errors('param error'));
    }
    const data = {
        event_name: eventName,
        description: param.description || '',
    }
    let result;
    if (!id) {
        data.create_time = nowTime;
        result = await dbs.insert(Const.TABLES.GB_PAY.POINT_EVENT, data);
    } else {
        result = await dbs.sets(Const.TABLES.GB_PAY.POINT_EVENT, data, {id});
    }
    if (!result) {
        return res.json(errors('operate failed'));
    }
    return res.json(success());
});
module.exports = router;
