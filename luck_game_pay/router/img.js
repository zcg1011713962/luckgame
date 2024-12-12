/**
 * img
 */
const express = require('express');
const router = express.Router();
const Img = require('../model/img');
const User = require('../model/user');
//验证token
router.use(async (req, res, next) => {
    await User.checkUserMiddleware(req, res, next);
});
/**
 * 上传头像
 */
router.post('/uploadByJson', async (req, res) => {
    const base64_image_content = req.body.img || '';
    const uid = req.body.uid || '';
    const token = req.body.token || '';
    const ret = {code: 200};
    try {
        const imgMatch = base64_image_content.match(/^data:image\/(\w+);base64,/);
        if (!imgMatch) {
            ret.code = 502;
            ret.msg = 'file ext error!';
            return res.json(ret);
        }
        const objName = `${uid}_${Img.getRandStr(8)}.png`;
        const url = await Img.base64imgsave(base64_image_content, objName);
        if (url === 500) {
            ret.code = 500;
            ret.msg = `file error1! ${uid} yellow`;
            return res.json(ret);
        }
        ret.url = url;
        ret.uid = uid;
    } catch (error) {
        ret.code = 500;
        ret.msg = 'upload failed';
    }
    return res.json(ret);
});
/**
 * 上传头像
 */
router.all('/upload', async (req, res) => {
    const postData = req.rawData;
    console.log('postData: ', postData);
    const uid = postData.uid || '';
    const token = postData.token || '';
    const ret = {code: 200};
    try {
        const base64_image_content = postData.img;
        const imgMatch = base64_image_content.match(/^data:image\/(\w+);base64,/);
        if (!imgMatch) {
            ret.code = 502;
            ret.msg = 'file ext error!';
            return res.json(ret);
        }
        const objName = `${uid}_${Img.getRandStr(8)}.png`;
        const url = await Img.base64imgsave(base64_image_content, objName);
        if (url === 500) {
            ret.code = 500;
            ret.msg = `file error1! ${uid} yellow`;
            return res.json(ret);
        }
        ret.url = url;
        ret.uid = uid;
    } catch (error) {
        ret.code = 500;
        ret.msg = 'upload failed';
    }
    return res.json(ret);
});
module.exports = router;
