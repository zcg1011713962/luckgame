/**
 * withdraw
 */
const express = require('express');
const router = express.Router();
const User = require('../model/user');
const dbs = require('../common/db/dbs')(config.mysql.dbs.game);
const UserBank = require('../model/user_bank');
const httpRequest = require('../common/request/http');
//验证token
router.use(async (req, res, next) => {
    await User.checkUserMiddleware(req, res, next);
});
/**
 * 首页
 */
router.get('/', async (req, res) => {
    const uid = req.query.uid || 0;
    const token = req.query.token || '';
    //查询drawtype
    const drawType = await dbs.gets(Const.TABLES.GAME.S_PAY_CFG_DRAW, [], ['status', '=', 1], [['ord', 'asc'], ['id', 'asc']]);
    //三方
    const drawCom = await dbs.gets(Const.TABLES.GAME.S_PAY_CFG_DRAWCOM, [], ['status', '=', 1], [['ord', 'asc'], ['id', 'asc']])
    const userInfo = await User.getUserCoin(uid);
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
    // //查询银行卡
    // const where = [
    //     ['uid', '=', uid],
    //     ['status', '=', 1]
    // ]
    // const userBankList = await dbs.gets(Const.TABLES.GAME.D_USER_BANK, [], where, ['id', 'desc']);
    // let selectedBankId = 0;
    // if (userBankList.length > 0) {
    //     for (let item of userBankList) {
    //         item.selected = 0;
    //         if (item.account.toString().length > 4) {
    //             const lastFourDigits = item.account.slice(-4);
    //             item.account = '*'.repeat(item.account.toString().length - 4) + lastFourDigits;
    //         }
    //     }
    //     userBankList[0].selected = 1;
    //     selectedBankId = userBankList[0].id;
    // }
    //查询银行
    // const bankList = await dbs.gets(Const.TABLES.GAME.S_BANK, [], ['status', '=', 1], ['id', 'asc']);
    return res.render('withdraw/index', {
        userInfo, token, drawComId, uid, drawType, drawCom, L
        // bankList，
    });
});
/**
 * 提现订单
 */
router.post('/order', async (req, res) => {
    const uid = req.body.uid || 0;
    const bankId = req.body.bankid || 0;
    const dcoin = req.body.dcoin || 0;
    const chanid = req.body.chanid || 0;
    if (dcoin <= 0) {
        return res.json(errors('Withdrawal amount must be greater than zero'));
    }
    if (bankId <= 0) {
        return res.json(errors('Please select a withdrawal bankcount'));
    }
    const userBank = await UserBank.getUserBankinfoById(bankId, uid);
    if (Object.keys(userBank).length === 0) {
        return res.json(errors('Please select the correct withdrawal method'));
    }
    const bank = await UserBank.getBankinfoById(userBank.bankid);
    if (Object.keys(bank).length === 0) {
        return res.json(errors('Please select the correct withdrawal method'));
    }

    const minWithdraw = bank?.mincoin ?? config.withdraw.min_amount;
    const maxWithdraw = bank?.maxcoin ?? config.withdraw.max_amount;
    if (dcoin < minWithdraw) {
        return res.json(errors(`Minimum withdrawal amount of ${minWithdraw}`));
    }
    if (dcoin > maxWithdraw) {
        return res.json(errors(`The maximum withdrawal amount is ${maxWithdraw}`));
    }
    const fields = ["uid", "playername", "svip", "coin", "ispayer", "gamedraw"];
    const userInfo = await dbs.getOne(Const.TABLES.GAME.D_USER, fields, {uid});
    if (Object.keys(userInfo).length === 0) {
        return res.json(errors('user not found'));
    }
    if (parseInt(userInfo.ispayer) === 0) {//未充值用户不能超过系统最高金额
        //判断是否充过值
        const where = [
            ['uid', '=', uid], ['status', 'in', [2, 3]]
        ];
        const rechargeList = await dbs.gets(Const.TABLES.GAME.D_USER_RECHARGE, ['id'], where, [], 1);
        if (rechargeList.length === 0) {
            const cfg = await dbs.getOne(Const.TABLES.GAME.S_CONFIG, [], {k: 'newuser_no_pay_drawlimit'});
            const maxcoin = parseInt(cfg?.v ?? 0);
            const haWhere = [
                ['uid', '=', uid], ['status', '=', 2]
            ];
            const haddrawcoinInfo = await dbs.gets(Const.TABLES.GAME.D_USER_DRAW, ['sum(coin) as sum_coin'], haWhere);
            const haddrawcoin = haddrawcoinInfo?.sum_coin ?? 0;
            if (maxcoin > 0 && (parseInt(dcoin) + parseInt(haddrawcoin)) > maxcoin) {
                return res.json(errors('Withdrawal amount must be less than the maximum'));
            }
            const doWhere = [
                ['uid', '=', uid], ['status', '=', 0]
            ];
            const doingcnt = await dbs.count(Const.TABLES.GAME.D_USER_DRAW, ['count(id) as count'], doWhere);
            if (doingcnt >= 1) {
                return res.json(errors('You have a withdrawal order under review please wait patiently'));
            }
            const donecnt = await dbs.count(Const.TABLES.GAME.D_USER_DRAW, ['count(id) as count'], haWhere);
            if (donecnt >= 1) {
                return res.json(errors('You already have a withdrawal order please recharge vip'));
            }
        }
    }
    const usercoins = await User.getUserCoin(uid);
    if (Number(usercoins.dcoin) < parseInt(dcoin)) {
        return res.json(errors('Insufficient withdrawal amount'));
    }
    const limit = await User.getLimitInfo(uid);
    const cnd = [
        ['uid', '=', uid], ['status', '=', 2]
    ];
    const todaytime = funcs.zeroTimestamps();
    const cndtoday = [
        ['uid', '=', uid], ['status', '=', 2], ['create_time', '>=', todaytime]
    ];
    const todaytimes = await dbs.count(Const.TABLES.GAME.D_USER_DRAW, ['count(1) as count'], cndtoday); //today max times
    if (limit.times > 0 && todaytimes > limit.times) {
        return res.json(errors('Today withdrawal times has reached the limit'));
    }
    const todaycoinInfo = await dbs.gets(Const.TABLES.GAME.D_USER_DRAW, ['sum(coin) as sum_coin'], cndtoday);//today max coin
    const todaycoin = todaycoinInfo?.sum_coin ?? 0;
    if (Number(limit.daycoin) > 0 && Number(todaycoin) >= Number(limit.daycoin)) {
        return res.json(errors('Today withdrawal amount has reached the limit'));
    }
    const alltimes = await dbs.count(Const.TABLES.GAME.D_USER_DRAW, ['count(1) as count'], cnd); //total max times
    if (limit.totaltimes > 0 && alltimes > $limit.totaltimes) {
        return res.json(errors('Withdrawal times has reached the limit times'));
    }
    const allcoinInfo = await dbs.gets(Const.TABLES.GAME.D_USER_DRAW, ['sum(coin) as sum_coin'], cnd);
    const allcoin = allcoinInfo?.sum_coin ?? 0;
    if (Number(limit.totalcoin) > 0 && Number(allcoin) >= Number(limit.totalcoin)) {
        return res.json(errors('Withdrawal Amount has reached the limit coin'));
    }

    const lastItemList = await dbs.gets(Const.TABLES.GAME.D_USER_DRAW, [], ['uid', '=', uid], ['id', 'desc'], 1);
    const lastItem = lastItemList.length > 0 ? lastItemList[0] : {};
    const now = funcs.nowTime();
    if (Object.keys(lastItem).length > 0 && limit.interval && lastItem.create_time > (now - limit.interval * 60)) {
        return res.json(errors('Withdrawals too frequently'));
    }

    const params = {
        mod: 'user',
        act: 'draw',
        uid: uid,
        coin: dcoin,
        bankid: bankId,
        chanid: 0,
    }
    const result = await httpRequest.get(config.game_server_url, params, {});
    if (Const.RESULT_STATUS.SUCCESS === result.status && 'succ' === result.data) {
        return res.json(success({}, 'withdraw success'));
    }
    funcs.log(`${uid} submit draw order failed: ${JSON.stringify(result)}, param: ${JSON.stringify(params)}`);
    return res.json(errors('submit draw order failed'));
});
module.exports = router;
