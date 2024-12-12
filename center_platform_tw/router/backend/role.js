/**
 * 角色
 * Date: 2023/08/28
 */
const express = require('express');
const router = express.Router();
const common = require('../../model/common');
const dbs = require('../../common/db/dbs')(config.mysql.dbs.gb_pay);
const menuModel = require('../../model/menuModel');
router.use(async function (req, res, next) {
    await common.preExec(req, res, next);
});
/**
 * 首页
 */
router.all('/', async (req, res) => {
    const method = req.method.toUpperCase();
    if ('POST' === method) {
        const status = req.body.status;
        let list;
        const roleList = await dbs.gets(Const.TABLES.GB_PAY.ROLE, [], [], ['id', 'asc']);
        if (Object.keys(req.body).includes('status') && [0, -1, '0', '-1'].includes(status)) {
            list = roleList.filter(item => item.status == status);
        } else {
            list = roleList;
        }
        if (list.length > 0) {
            for(let item of list) {
                item.create_time = funcs.datestamps(item.create_time, true, true, '-');
            }
        }
        return res.json(success({items: list}));
    } else {
        const menuList = await menuModel.getMenuList();
        return res.render('role/index', {menuList});
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
    const result = await dbs.sets(Const.TABLES.GB_PAY.ROLE, {status}, {id});
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
    const info = await dbs.getOne(Const.TABLES.GB_PAY.ROLE, [], {id});
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
    const data = {
        role_name: param.role_name || '',
        description: param.description || '',
        update_time: nowTime,
        auth_id: '',
    }
    const id = param.id || 0;
    let result;
    if (!id) {
        data.create_time = nowTime;
        result = await dbs.insert(Const.TABLES.GB_PAY.ROLE, data);
    } else {
        result = await dbs.sets(Const.TABLES.GB_PAY.ROLE, data, {id});
    }
    if (!result) {
        return res.json(errors('operate failed'));
    }
    return res.json(success());
});
/**
 * 给角色分配权限
 */
router.post('/assignRoleAuth', async (req, res) => {
    const param = req.body;
    const nowTime = Date.now();
    const data = {
        auth_id: param.auth_id || '',
        update_time: nowTime
    }
    const id = param.id || 0;
    const info = await dbs.getOne(Const.TABLES.GB_PAY.ROLE, [], {id});
    if (Object.keys(info).length === 0) {
        return res.json(errors('not found'));
    }
    const result = await dbs.sets(Const.TABLES.GB_PAY.ROLE, data, {id});
    if (!result) {
        return res.json(errors('operate failed'));
    }
    return res.json(success());
});
module.exports = router;
