/**
 * index
 */
const express = require('express');
const router = express.Router();
const httpRequest = require('../common/request/http');
/**
 * 首页
 */
router.all('/', async (req, res) => {
    console.log('query ================> ', req.query);
    console.log('body ================> ', req.body);
    console.log('params ================> ', req.params);
    return res.send('Hello !');
});
router.all('/testLine', async (req, res) => {
    const method = req.method.toUpperCase();
    if ('POST' === method) {
        const params = {
            app_token: req.body.app_token,
            amount: req.body.amount,
        };
        const url = "https://twpay.junglespin.net/pay/createPayOrder";
        const result = await httpRequest.post(url, params);
        console.log(result);
        const data = {
            web_url: result?.data?.data?.web_url ?? '',
            app_url: result?.data?.data?.app_url ?? '',
        };
        return res.json(data);
    } else {
        return res.render('index/test_line');
    }
});
module.exports = router;
