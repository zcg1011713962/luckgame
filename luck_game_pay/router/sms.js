/**
 * sms
 */
const express = require('express');
const router = express.Router();

/**
 * 测试发短信
 */
router.all('/dosend', async (req, res) => {
    console.log(req.query);
    console.log(req.body);
    return res.json(success());
});

module.exports = router;
