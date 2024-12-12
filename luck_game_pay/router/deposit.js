/**
 * deposit
 */
const express = require('express');
const router = express.Router();
const User = require('../model/user');
const Pay = require('../model/pay');
const dbs = require('../common/db/dbs')(config.mysql.dbs.game);
//验证token
router.use(async (req, res, next) => {
    await User.checkUserMiddleware(req, res, next);
});
/**
 * deposit channel page
 */
router.get('/', async (req, res) => {
    const uid = req.query.uid || 0;
    const token = req.query.token || '';
    const rbid = req.query.rbid || 0;
    //查询三方支付和通道
    const order = [
        ['ord', 'asc'], ['id', 'asc']
    ];
    const thirdPay = await dbs.gets(Const.TABLES.GAME.S_PAY_CFG_OTHER, ['id', 'title'], ['status', '=', 1], order);
    if (thirdPay.length > 0) {
        const channelList = await dbs.gets(Const.TABLES.GAME.S_PAY_CFG_CHANNEL, [], ['status', '=', 1], order);
        for (let item of thirdPay) {
            item.channel = [];
            if (channelList.length > 0) {
                for (let val of channelList) {
                    if (parseInt(item.id) === parseInt(val.otherid)) {
                        item.channel.push(val);
                    }
                }
            }
        }
    }
    return res.render('deposit/channel', {
        uid, token, thirdPay, L, rbid
    });
});
/**
 * deposit amount page
 */
router.get('/amount', async (req, res) => {
    const uid = req.query.uid || 0;
    const token = req.query.token || '';
    const id = req.query.id || '';
    const rbid = parseInt(req.query.rbid || 0);
    if (!id) {
        return res.json(errors('param error'));
    }
    const userInfo = await User.getUserCoin(uid);

    //通道优惠
    const channelInfo = await dbs.getOne(Const.TABLES.GAME.S_PAY_CFG_CHANNEL, ['title', 'discoin', 'disrate', 'mincoin', 'maxcoin'], {id});
    if (Object.keys(channelInfo).length === 0) {
        return res.json(errors('channel err'));
    }
    const discoin = channelInfo.discoin;
    const disrate = channelInfo.disrate;
    const channelTitle = channelInfo.title;
    const minDeposit = channelInfo?.mincoin ?? config.deposit.min_amount;
    const maxDeposit = channelInfo?.maxcoin ?? config.deposit.max_amount;
    let filterBetCoinList = [], tempPage = 'deposit/index';
    //如果参数rbid存在，说明是从充值活动进来的
    if (rbid > 0) {
        //充值活动金额
        const rechargeBonusList = await Pay.getRechargeBonusList();
        if (rechargeBonusList.length > 0) {
            for (let item of rechargeBonusList) {
                if (Number(item.cash_balance) >= Number(minDeposit) && Number(item.cash_balance) <= Number(maxDeposit)) {
                    let obj = {
                        id: item.id, amount: parseInt(item.cash_balance), bonus: parseInt(item.cash_bonus), selected: 0
                    };
                    if (rbid === parseInt(item.id)) {
                        obj.selected = 1;
                    }
                    filterBetCoinList.push(obj);
                }
            }
        }
        if (filterBetCoinList.length > 0) {
            let hasSelected = false;
            for (let item of filterBetCoinList) {
                if (item.selected === 1) {
                    hasSelected = true;
                    break;
                }
            }
            if (!hasSelected) {
                filterBetCoinList[0].selected = 1;
            }
        }
    } else {
        //没传rbid参数的话说明是普通充值
        const rechargeNormalList = await Pay.getRechargeNormalList();
        if (rechargeNormalList.length > 0) {
            for (let item of rechargeNormalList) {
                // if (Number(item.pay) >= Number(minDeposit) && Number(item.pay) <= Number(maxDeposit)) {
                //     item.selected = 0;
                //     filterBetCoinList.push(item);
                // }
                item.selected = 0;
                filterBetCoinList.push(item);
            }
            if (filterBetCoinList.length > 0) filterBetCoinList[0].selected = 1;
        }
        tempPage = 'deposit/index_normal';
    }
    return res.render(tempPage, {
        userInfo, uid, token, minDeposit, maxDeposit,
        betCoinList: filterBetCoinList,
        discoin, disrate, id, channelTitle, rbid,
        encrypt_uid: funcs.encryptUid(userInfo.uid), L
    });
});
/**
 * post deposit
 */
router.post('/post', async (req, res) => {
    const uid = req.body.uid || 0;
    let amount = parseInt(req.body.amount || 0);
    const encryptUid = req.body.encrypt_uid || '';
    const goodsType = req.body.goodsType || 1;
    const id = req.body.id || 1;//通道id
    const pic = req.body.pic || '';
    //充值活动的id
    const rbid = parseInt(req.body.rbid || 0);
    if (!uid || amount < 0) {
        return res.json(errors('param error'));
    }
    if (funcs.encryptUid(uid) !== encryptUid) {
        return res.json(errors('request denied'));
    }
    const userInfo = await dbs.getOne(Const.TABLES.GAME.D_USER, 'uid,svip,coin,playername', {uid});
    if (Object.keys(userInfo).length === 0) {
        return res.json(errors('user not found'));
    }
    //支付通道
    const chan = await dbs.getOne(Const.TABLES.GAME.S_PAY_CFG_CHANNEL, [], {id});
    if (Object.keys(chan).length === 0) {
        return res.json(errors('channel err'));
    }
    const minDeposit = chan?.mincoin ?? config.deposit.min_amount;
    const maxDeposit = chan?.maxcoin ?? config.deposit.max_amount;
    if (amount < minDeposit) {
        return res.json(errors(`Minimum deposit amount of ${minDeposit}`));
    }
    if (amount > maxDeposit) {
        return res.json(errors(`The maximum deposit amount is ${maxDeposit}`));
    }
    let cash = 0, cash_rate = '0:1', give = 0, give_rate = '1:0';
    //根据rbid查询赠送的bonus
    let rbObj = {};
    const rechargeBonusList = await Pay.getRechargeBonusList();
    if (rechargeBonusList.length > 0) {
        for (let item of rechargeBonusList) {
            if (parseInt(item.id) === rbid) {
                rbObj = item;
                break;
            }
        }
    }
    if (Object.keys(rbObj).length > 0) {
        //根据rbid查找充值活动，找到的话按充值活动来
        if (amount !== parseInt(rbObj.cash_balance)) {
            //rbid对应的recharge_bonus_list中设置的cash_balance要跟amount金额对得上
            return res.json(errors('Abnormal recharge amount'));
        }
        cash = amount;
        give = rbObj.cash_bonus;
    } else {
        //根据rbid没找到充值活动或者没有传rbid，都按普通充值来
        const rechargeNormalList = await Pay.getRechargeNormalList();
        if (rechargeNormalList.length > 0) {
            for (let item of rechargeNormalList) {
                if (amount >= item.pay_min && amount <= item.pay_max) {
                    cash = Math.round(amount * Number(item.cash));
                    cash_rate = `${item.cash_coin}:${item.cash_cash}`;
                    give = Math.round(amount * Number(item.give));
                    give_rate = `${item.give_coin}:${item.give_cash}`;
                    // cash = Math.round(amount * Number(item.cash) * Number(item.cash_cash)) + Math.round(amount * Number(item.give) * Number(item.give_cash));
                    // give = Math.round(amount * Number(item.cash) * Number(item.cash_coin)) + Math.round(amount * Number(item.give) * Number(item.give_coin));
                    break;
                }
            }
        }
    }
    if (!cash) {
        cash = amount;
        give = 0;
    }
    const channelCode = chan.code;
    const thirdPay = await dbs.getOne(Const.TABLES.GAME.S_PAY_CFG_OTHER, ['title'], {id: chan.otherid});
    if (Object.keys(thirdPay).length === 0) {
        return res.json(errors('channel err'));
    }
    const channelType = thirdPay.title;
    const group = await dbs.getOne(Const.TABLES.GAME.S_PAY_GROUP, [], {id: chan.groupid});
    const discounts = await dbs.gets(Const.TABLES.GAME.S_PAY_DISCOUNT, [], {id: chan.groupid});
    let disrate = 0;
    let rate1 = ''; //比例分成
    let discoin = 0;
    let rate2 = ''; //固定金额的分成金额
    let rate = ''; //固定金额分成
    if(Object.keys(discounts).length > 0) { //先将交易科目的最大优惠项挑选出来
        for(let dis of discounts) {
            dis['disrate'] = Number(dis['disrate']);
            dis['discoin'] = Number(dis['discoin']);
            if(dis['disrate'] > disrate) {
                disrate = dis['disrate'];
                rate1 = dis['rate'];
            }
            if(dis['discoin'] > 0) {
                discoin = dis['discoin'];
                rate2 = dis['rate'];
            }
        }
    }
    console.log('discounts: ====>', JSON.stringify(discounts));
    if(discoin > 0 && disrate > 0) { //从优惠比例 或 固定优惠金额中挑选出最大值
        let disCount = parseFloat(amount * disrate).toFixed(2);
        if(disCount > discoin) { //比例大优惠金额大，就先采用比例
            discoin = 0;
            rate2 = '';
            rate = rate1;
        } else {
            disrate = 0;
            rate1 = '';
            rate = rate2;
        }
    }

    //从交易科目的优惠 和 通道的优惠中 选择出最大优惠项
    if(disrate > 0) {
        if(chan['disrate'] > disrate) {
            disrate = chan['disrate'];
            rate = chan['rate'];
        }
    } else {
        let disCount = parseFloat(amount * chan['disrate']).toFixed(2);
        if (disCount > discoin) { //固定优惠金额大，就先采用固定优惠金额
            discoin = 0;
            rate2 = '';
            disrate = chan['disrate'];
            rate = chan['rate'];
        }
    }
    const params = {
        amount: amount,
        channelCode,
        channelType
    }
    const result = await Pay.createPayOrder(params);
    //请求失败
    if (Const.RESULT_STATUS.ERROR === result.status) {
        const failedMsg = `Request error! error msg: ${result.msg}`;
        return res.json(errors(failedMsg));
    }
    const resultData = result.data || {};
    //创建订单状态
    if (Const.RESULT_STATUS.SUCCESS !== resultData.code) {
        const failedMsg = `Response code error! detail: ${JSON.stringify(result.data)}`;
        return res.json(errors(failedMsg));
    }
    //返回的数据是否为空
    if (Object.keys(resultData.data).length === 0) {
        const failedMsg = `Response data error! detail: ${JSON.stringify(result.data)}`;
        return res.json(errors(failedMsg));
    }
    //插入订单表
    const data = {
        orderid: resultData.data.merOrderNo,
        uid: uid,
        playername: userInfo.playername,
        count: amount,
        // goodstype: parseInt(goodsType),
        before_coin: userInfo.coin,
        svip: userInfo.svip,
        channelid: id,
        groupid: chan.groupid,
        pic,
        subjectid: group?.subject ?? 0,
        create_time: funcs.nowTime(),
        status: 0,
        type: group?.category ?? 0,
        disrate,
        discoin,
        rate,
        category: 1,
        cash,
        cash_rate,
        give,
        give_rate
    }
    const ret = await dbs.insert(Const.TABLES.GAME.D_USER_RECHARGE, data);
    if(ret === false) {
        return res.json(errors('order failed'));
    }
    //订单发起成功之后添加主动查询机制
    Pay.initiativeQuery(data.orderid, Const.PAY_ORDER_TYPE.PAYMENT);
    return res.json(success({url: resultData.data.url}));
});
module.exports = router;
