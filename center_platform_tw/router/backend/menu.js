/**
 * 菜单
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
        const pid = req.body.pid;
        let list;
        const menuList = await menuModel.menuList();
        if (Object.keys(req.body).includes('pid') && pid !== '') {
            list = menuList.filter(item => item.pid == pid);
        } else {
            list = menuList;
        }
        if (list.length > 0) {
            for(let item of list) {
                item.create_time = funcs.datestamps(item.create_time, true, true, '-');
            }
        }
        return res.json(success({items: list}));
    } else {
        const menuList = await menuModel.menuList();
        const pmList = menuList.filter(item => item.level < 2);
        return res.render('menu/index', {pmList});
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
    const result = await dbs.sets(Const.TABLES.GB_PAY.MENU, {status}, {id});
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
    const info = await dbs.getOne(Const.TABLES.GB_PAY.MENU, [], {id});
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
    const pid = param.pid || 0;
    const data = {
        title: param.title || '',
        url: param.url || '',
        method: param.method || '',
        icon: param.icon || '',
        is_menu: param.is_menu || 0,
        pid,
        remark: param.remark || '',
        update_time: nowTime
    }
    if (pid > 0) {
        const info = await dbs.getOne(Const.TABLES.GB_PAY.MENU, [], {id: pid});
        if (Object.keys(info).length === 0) {
            return res.json(errors('上级菜单不存在'));
        }
        data.level = parseInt(info.level) + 1;
    } else {
        data.level = 0;
    }
    const id = param.id || 0;
    let result;
    if (!id) {
        data.create_time = nowTime;
        result = await dbs.insert(Const.TABLES.GB_PAY.MENU, data);
    } else {
        result = await dbs.sets(Const.TABLES.GB_PAY.MENU, data, {id});
    }
    if (!result) {
        return res.json(errors('operate failed'));
    }
    return res.json(success());
});
module.exports = router;
