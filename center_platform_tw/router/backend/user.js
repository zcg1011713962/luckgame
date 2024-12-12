/**
 * 用户
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
 * 首页
 */
router.all('/', async (req, res) => {
    const method = req.method.toUpperCase();
    if ('POST' === method) {
        const status = req.body.status;
        const where = [
            ['id', '!=', 1]
        ];
        if (Object.keys(req.body).includes('status') && [0, -1, '0', '-1'].includes(status)) {
            where.push(['status', '=', status]);
        }
        const list = await dbs.gets(Const.TABLES.GB_PAY.USER, [], where, ["id", "desc"]);
        if (list.length > 0) {
            const roleObj = {};
            const roleList = await dbs.gets(Const.TABLES.GB_PAY.ROLE, ['id', 'role_name'], ['status', '==', 0]);
            if (roleList.length > 0) {
                for (let item of roleList) {
                    roleObj[item.id] = item.role_name;
                }
            }
            for(let item of list) {
                item.role_name = roleObj[item.role_id] || '';
                item.create_time = funcs.datestamps(item.create_time, true, true, '-');
            }
        }
        return res.json(success({items: list}));
    } else {
        //获取角色
        const roleList = await dbs.gets(Const.TABLES.GB_PAY.ROLE, [], [], ['id', 'asc']);
        return res.render('user/index', {roleList});
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
    const result = await dbs.sets(Const.TABLES.GB_PAY.USER, {status}, {id});
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
    const info = await dbs.getOne(Const.TABLES.GB_PAY.USER, [], {id});
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
    const password = param.password || '';
    const username = param.username || '';
    if (!username) {
        return res.json(errors('username can not be empty'));
    }
    //判断账号是否存在
    const userInfo = await dbs.getOne(Const.TABLES.GB_PAY.USER, [], {username});
    if (Object.keys(userInfo).length > 0) {
        if (parseInt(id) !== parseInt(userInfo.id)) {
            return res.json(errors('username already exists'));
        }
    }
    const data = {
        username,
        role_id: param.role_id || 0,
        remark: param.remark || '',
        update_time: nowTime
    }
    if (!!password) {
        data.password = funcs.encryptMd5(password);
    }
    let result;
    if (!id) {
        data.create_time = nowTime;
        result = await dbs.insert(Const.TABLES.GB_PAY.USER, data);
    } else {
        result = await dbs.sets(Const.TABLES.GB_PAY.USER, data, {id});
    }
    if (!result) {
        return res.json(errors('operate failed'));
    }
    return res.json(success());
});
/**
 * 重置密码
 */
router.post('/resetPwd', async (req, res) => {
    const param = req.body;
    const nowTime = Date.now();
    const id = param.id || 0;
    const password = param.password || '';
    if (!id) {
        return res.json(errors('user not found'));
    }
    const data = {
        password: !password ? funcs.encryptMd5('abc123456') : funcs.encryptMd5(password),
        update_time: nowTime
    }
    const result = await dbs.sets(Const.TABLES.GB_PAY.USER, data, {id});
    if (!result) {
        return res.json(errors('operate failed'));
    }
    return res.json(success());
});
module.exports = router;
