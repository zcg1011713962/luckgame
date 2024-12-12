/**
 * bank
 */
const express = require('express');
const router = express.Router();
const User = require('../model/user');
const dbs = require('../common/db/dbs')(config.mysql.dbs.game);
//验证token
router.use(async (req, res, next) => {
    await User.checkUserMiddleware(req, res, next);
});
/**
 * 添加
 */
router.all('/add', async (req, res) => {
    const method = req.method.toUpperCase();
    const uid = req.query.uid || req.body.uid || 0;
    const token = req.query.token || req.body.token || '';
    const nowTime = funcs.nowTime();
    if ('POST' === method) {
        const bankId = req.body.bankid || 0;
        const name = req.body.name || '';
        const account = (req.body.account || '').toString().trim();
        const email = req.body.email || '';
        const phone = req.body.phone || '';
        if (!bankId || !account || !name) {
            return res.json(errors('param error'));
        }
        //判断银行卡号不能重复
        const info = await dbs.getOne(Const.TABLES.GAME.D_USER_BANK, ['id'], {account});
        if (Object.keys(info).length > 0) {
            return res.json(errors('The bank account number has been bound'));
        }
        const bankInfo = await dbs.getOne(Const.TABLES.GAME.S_BANK, [], {id: bankId});
        const params = {
            uid,
            username: name,
            account,
            bankid: bankId,
            bankname: bankInfo?.title ?? '',
            email,
            phone,
            create_time: nowTime,
            update_time: nowTime,
            status: 1
        }
        const result = await dbs.insert(Const.TABLES.GAME.D_USER_BANK, params);
        if (result === false) {
            return res.json(errors('operate failed'));
        }
        return res.json(success());
    } else {
        //查询drawtype
        const drawType = await dbs.gets(Const.TABLES.GAME.S_PAY_CFG_DRAW, [], ['status', '=', 1], [['ord', 'asc'], ['id', 'asc']]);
        //三方
        const drawCom = await dbs.gets(Const.TABLES.GAME.S_PAY_CFG_DRAWCOM, [], ['status', '=', 1], [['ord', 'asc'], ['id', 'asc']])
        const drawComId = req.query.draw_com_id || (drawCom[0]?.id ?? 0);
        if (drawCom.length > 0) {
            const sql = `SELECT ub.id,ub.account,ub.bankid,ub.bankname,b.bank_code,b.draw_com_id FROM ${Const.TABLES.GAME.D_USER_BANK} ub 
                    INNER JOIN ${Const.TABLES.GAME.S_BANK} b ON ub.bankid = b.id 
                    WHERE ub.uid = ${uid} AND ub.status = 1 AND b.status = 1 ORDER BY ub.id DESC`;
            const userBankList = await dbs.querys(sql);
            if (userBankList.length > 0) {
                for (let item of userBankList) {
                    item.selected = 0;
                    if (item.account.toString().length > 4) {
                        const lastFourDigits = item.account.slice(-4);
                        item.account = '*'.repeat(item.account.toString().length - 4) + lastFourDigits;
                    }
                }
            }

            for (let item of drawCom) {
                item.selected = 0;
                if (parseInt(drawComId) === parseInt(item.id)) {
                    item.selected = 1;
                }
                item.user_bank = [];
                for (let val of userBankList) {
                    if (parseInt(val.draw_com_id) === parseInt(item.id)) {
                        item.user_bank.push(val);
                    }
                }
            }
        }
        //查询银行
        // const bankList = await dbs.gets(Const.TABLES.GAME.S_BANK, [], ['status', '=', 1], ['id', 'asc']);
        return res.render('bank/index', {uid, token, drawCom, drawComId, drawType, L});
    }
});
/**
 * 银行列表
 */
router.all('/list', async (req, res) => {
    const bankList = await dbs.gets(Const.TABLES.GAME.S_BANK, [], ['status', '=', 1], ['id', 'asc']);
    return res.json(bankList);
});
module.exports = router;
