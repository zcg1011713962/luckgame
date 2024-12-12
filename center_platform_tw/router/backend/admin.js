/**
 * admin.js 后台管理
 */
const express = require('express');
const router = express.Router();
const dbs = require('../../common/db/dbs')(config.mysql.dbs.gb_pay);
const menuModel = require('../../model/menuModel');

/**
 * 登录
 */
router.all('/login', async function (req, res) {
    const method = req.method.toUpperCase();
    if ('POST' === method) {
        const username = req.body.username || '';
        const password = req.body.password || '';
        const ip = req.body.ip || '';
        if (!username || !password) {
            return res.json(errors('Wrong username or password'));
        }
        const userInfo = await dbs.getOne(Const.TABLES.GB_PAY.USER, [], {username, password: funcs.encryptMd5(password)});
        if (Object.keys(userInfo).length === 0) {
            return res.json(errors('user not found'));
        }
        if (Const.COMMON_STATUS.DEL === userInfo.status) {
            return res.json(errors('user disabled'));
        }
        req.session.userInfo = userInfo;
        return res.json(success());
    } else {
        if (req.session?.userInfo) {
            return res.redirect(`/backend/admin`);
        }
        return res.render('admin/login', {meta_title: 'Login'});
    }
});
/**
 * 登录session验证
 */
router.use(function (req, res, next) {
    if (req.session?.userInfo) {
        next()
    } else {
        return res.redirect(`/backend/admin/login`);
    }
});
/**
 * 后台首页
 */
router.get('/', async (req, res) => {
    let menuList = [];
    if (parseInt(req.session?.userInfo?.id) === 1) {
        menuList = await menuModel.getLeftMenu();
    } else {
        //根据权限查找菜单
        const authId = req.session?.userInfo?.authId ?? '';
        const list = await menuModel.getAuthMenu(authId);
        if (list.length > 0) {
            const pidSet = new Set();
            for (let item of list) {
                if (item.pid > 0) {
                    pidSet.add(item.pid);
                }
            }
            //查找一级菜单
            const mainList = await menuModel.getAuthFirstLevelMenu([...pidSet]);
            if (mainList.length > 0) {
                for (let item of mainList) {
                    item.children = [];
                    for (let val of list) {
                        if (parseInt(item.id) === parseInt(val.pid)) {
                            item.children.push(val);
                        }
                    }
                }
                menuList = mainList;
            }
        }
    }
    return res.render('admin/index', {
        meta_title: 'Integrate Payment', userInfo: req.session?.userInfo, menuList
    });
});
/**
 * 修改当前登录用户密码
 */
router.post('/editPwd', async function (req, res) {
    const id = req.session?.userInfo?.id ?? 0;
    const password = req.session?.userInfo?.password ?? 0;
    if (!id) {
        return res.json(errors('用户未登录'));
    }
    const originPwd = req.body.originPwd || '';
    const newPwd = req.body.newPwd || 'abc123456';
    if (password !== funcs.encryptMd5(originPwd)) {
        return res.json(errors('原密码不正确'));
    }
    const result = await dbs.sets(Const.TABLES.GB_PAY.USER, {password: funcs.encryptMd5(newPwd)}, {id});
    if (!result) {
        return res.json(errors('failed'));
    }
    return res.json(success());
});
/**
 * 登出
 */
router.get('/logout', async function (req, res, next) {
    req.session.userInfo = null
    req.session.save(function (err) {
        if (err) next(err)
        // regenerate the session, which is good practice to help
        // guard against forms of session fixation
        req.session.regenerate(function (err) {
            if (err) next(err);
            res.redirect(`/backend/admin/login`);
        })
    })
});
module.exports = router;
