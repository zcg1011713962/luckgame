/**
 * 中间件
 */
const cache = require('../common/redis/cache');
const dbs = require('../common/db/dbs')(config.mysql.dbs.game);
module.exports = async (req, res, next) => {
    let LocaleLang = req.get('lang') || req.query.lang || req.body.lang || 'vn';
    const uid = req.query.uid || req.body.uid || 0;
    if (!!uid) {
        let langId = 0;
        const userInfo = await cache.hgetall(`d_user:${uid}`);
        if (!userInfo) {
            const info = await dbs.getOne(Const.TABLES.GAME.D_USER, ['lang'], {uid});
            if (Object.keys(info).length > 0) {
                langId = info.lang;
            }
        } else {
            langId = userInfo.lang;
        }
        langId = parseInt(langId);
        if (langId > 0) {
            if (langId === 2) {
                LocaleLang = 'en';
            } else if (langId === 3) {
                LocaleLang = 'vn';
            } else if (langId === 4) {
                LocaleLang = 'zh-tw';
            }
        }
    }
    if (!['vn', 'en', 'zh-tw'].includes(LocaleLang)) {
        LocaleLang = 'vn';
    }
    setLocale(LocaleLang);
    req.state = {};
    const originUri = req.path;
    const openMethod = req.method.toUpperCase();
    req.state.lang = LocaleLang;
    req.state.path = originUri;
    req.state.method = openMethod;
    next();
}