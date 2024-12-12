/**
 * transaction
 */
const express = require('express');
const router = express.Router();
const User = require('../model/user');
//验证token
router.use(async (req, res, next) => {
    await User.checkUserMiddleware(req, res, next);
});
/**
 * transaction records
 */
router.all('/:type?', async (req, res) => {
    const method = req.method.toUpperCase();
    const type = req.params.type || 'deposit';
    const uid = req.query.uid || req.body.uid || 0;
    const token = req.query.token || req.body.token || '';
    if ('POST' === method) {
        const num = req.body.num || 0;
        const size = req.body.size || 10;
        const status = req.body.status || -1;
        let data = [];
        switch (type) {
            case "deposit":
                data = await User.getRechargeList(uid, num, size, status);
                break;
            case "withdraw":
                data = await User.getDrawList(uid, num, size, status);
                break;
            case "bet":
                data = await User.getBetList(uid, num, size, status);
                break;
            case "bonus":
                data = await User.getBonusList(uid, num, size, status);
                break;
        }
        return res.json(success(data));
    } else {
        let tmp = 'transaction/deposit';
        switch (type) {
            case "deposit":
                tmp = 'transaction/deposit';
                break;
            case "withdraw":
                tmp = 'transaction/withdraw';
                break;
            case "bet":
                tmp = 'transaction/bet';
                break;
            case "bonus":
                tmp = 'transaction/bonus';
                break;
        }
        return res.render(tmp, {uid, token, L});
    }
});

module.exports = router;
