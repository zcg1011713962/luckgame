/**
 * 控制台页面
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
    const appCount = await dbs.count(Const.TABLES.GB_PAY.APP);
    const channelCount = await dbs.count(Const.TABLES.GB_PAY.CHANNEL);
    const where = [
        ['status', '=', Const.COMMON_PAY_STATUS.SUCCESS],
        ['pay_time', '>=', funcs.zeroTimestamps()],
        ['environment', '!=', 'sandbox']
    ];
    const todayPayCount = await dbs.count(Const.TABLES.GB_PAY.PAYMENT_ORDER, [], where);
    const todayPayoutCount = await dbs.count(Const.TABLES.GB_PAY.PAYOUT_ORDER, [], where);
    const todayPay = await dbs.gets(Const.TABLES.GB_PAY.PAYMENT_ORDER, ['SUM(amount) as total_amount'], where);
    const todayPayout = await dbs.gets(Const.TABLES.GB_PAY.PAYOUT_ORDER, ['SUM(amount) as total_amount'], where);
    const todayPayAmount = todayPay[0]?.total_amount ?? 0;
    const todayPayoutAmount = todayPayout[0]?.total_amount ?? 0;
    return res.render('console/index', {
        appCount, channelCount, todayPayCount,
        todayPayoutCount,
        todayPayoutAmount: parseFloat(todayPayoutAmount).toFixed(2),
        todayPayAmount: parseFloat(todayPayAmount).toFixed(2)
    });
});
module.exports = router;
