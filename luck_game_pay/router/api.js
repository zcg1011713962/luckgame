/**
 * api
 */
const express = require('express');
const router = express.Router();
const dbs = require('../common/db/dbs')(config.mysql.dbs.game);
const Pay = require('../model/pay');
const Common = require('../model/common');
const UserBank = require('../model/user_bank');
//ip白名单
router.use(async (req, res, next) => {
    await Common.checkIpWhitelist(req, res, next, Const.IP_WHITELIST_KEY.CALL_API);
});
/**
 * 提交提现
 */
router.post('/withdraw', async (req, res) => {
    const merOrderNo = req.body.merOrderNo || '';
    const amount = req.body.amount || 0;
    const userBankId = req.body.userBankId || 0;
    if (!merOrderNo || !userBankId || isNaN(amount) || amount <= 0) {
        return res.json(errors('param error'));
    }
    const userBankInfo = await dbs.getOne(Const.TABLES.GAME.D_USER_BANK, [], {id: userBankId});
    if (Object.keys(userBankInfo).length === 0) {
        return res.json(errors('user bank not bind'));
    }
    const bankInfo = await UserBank.getBankinfoById(userBankInfo.bankid);
    if (Object.keys(bankInfo).length === 0) {
        return res.json(errors('bank not found'));
    }
    const params = {
        amount,
        merOrderNo,
        accountNo: userBankInfo.account,
        accountName: userBankInfo.username,
        email: userBankInfo.email,
        phone: userBankInfo.phone,
        bankCode: bankInfo.bank_code,
        channel: bankInfo.title,
    }
    const result = await Pay.createPayoutOrder(params);
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
    //订单发起成功之后添加主动查询机制
    Pay.initiativeQuery(merOrderNo, Const.PAY_ORDER_TYPE.PAYOUT);
    return res.json(success({transaction_id: resultData.data.orderNo}));
});
module.exports = router;
