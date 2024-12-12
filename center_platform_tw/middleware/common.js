/**
 * 中间件
 */
module.exports = async (req, res, next) => {
    let LocaleLang = req.get('LocaleLang') || 'en-US';//设置语言包
    setLocale(LocaleLang);
    req.state = {};
    const originUri = req.path;
    const openMethod = req.method.toUpperCase();
    req.state.path = originUri;
    req.state.method = openMethod;
    next();
}