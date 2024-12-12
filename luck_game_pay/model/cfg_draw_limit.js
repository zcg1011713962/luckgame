/**
 * 提现限制
 */
const dbs = require('../common/db/dbs')(config.mysql.dbs.game);
class Cfg_draw_limit {

    /**
     * 获取支付等级对方的支付分组方法
     * @param uid
     * @param svip
     * @param superArr
     * @returns {*}
     */
    async getDataBySvip(uid, svip, superArr = []) {
        let where = '';
        if (uid && superArr.length === 0) {
            where += `useruid = ${uid}`
        } else if (!uid && superArr.length > 0) {
            where += `superuid in (${superArr.join(',')})`;
        } else if (uid && superArr.length > 0) {
            where += `(useruid = ${uid} or superuid in (${superArr.join(',')}))`;
        }
        if (svip) {
            if (where) where += ` and `;
            where += `FIND_IN_SET(${svip}, svip)`;
        }
        let sql = `select * from ${Const.TABLES.GAME.S_PAY_CFG_DRAWLIMIT}`;
        if (where) {
            sql += ` where ${where}`;
        }
        sql += ' order by id desc'
        return await dbs.querys(sql, 'SELECT');
    }
}

module.exports = new Cfg_draw_limit();