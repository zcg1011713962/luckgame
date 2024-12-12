/**
 * index
 */
const express = require('express');
const router = express.Router();
/**
 * 首页
 */
router.get('/', async (req, res) => {
    return res.send('Hello!');
});
module.exports = router;
