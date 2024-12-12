/**
 * 用户银行卡
 */
const dbs = require('../common/db/dbs')(config.mysql.dbs.game);
class User_bank {

    /**
     * 获取用户银行卡
     * @param uid
     * @param id
     * @returns {*}
     */
    async getUserBankinfoById(id, uid) {
        return await dbs.getOne(Const.TABLES.GAME.D_USER_BANK, [], {uid, id});
    }

    /**
     * 获取银行信息
     * @param id
     * @returns {Promise<{}|*>}
     */
    async getBankinfoById(id) {
        const bankSQL = `SELECT b.id,b.draw_com_id,b.bank_code,d.title,d.mincoin,d.maxcoin FROM ${Const.TABLES.GAME.S_BANK} b 
              INNER JOIN ${Const.TABLES.GAME.S_PAY_CFG_DRAWCOM} d ON b.draw_com_id = d.id where b.id = ${id}`;
        const bankList = await dbs.querys(bankSQL);
        if (bankList.length > 0) {
            return bankList[0];
        }
        return {};
    }
}

module.exports = new User_bank();