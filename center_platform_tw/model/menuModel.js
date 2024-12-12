/**
 * 菜单
 * Date: 2024/03/20
 */
const dbs = require('../common/db/dbs')(config.mysql.dbs.gb_pay);
class menuModel {

    /**
     * 所有未删除的菜单
     * @returns {Promise<*>}
     */
    async menuList() {
        return await dbs.gets(Const.TABLES.GB_PAY.MENU, [], ['status', '=', 0], [['sort', 'asc'], ['id', 'asc']]);
    }
    /**
     * 获取格式化后的所有权限子项
     * @returns {Promise<*>}
     */
    async getMenuList() {
        const list = await this.menuList();
        if (list.length === 0) {
            return [];
        }
        const allMenuList = list.filter(item => item.level < 3);
        const menuList = allMenuList.filter(item => parseInt(item.level) === 0);
        const subMenuList = allMenuList.filter(item => parseInt(item.level) === 1);
        const sub2MenuList = allMenuList.filter(item => parseInt(item.level) === 2);
        for (let item of subMenuList) {
            item.children = [];
            for (let val of sub2MenuList) {
                if (parseInt(item.id) === parseInt(val.pid)) {
                    item.children.push(val);
                }
            }
        }
        for (let item of menuList) {
            item.children = [];
            for (let val of subMenuList) {
                if (parseInt(item.id) === parseInt(val.pid)) {
                    item.children.push(val);
                }
            }
        }
        return menuList
    }

    /**
     * 获取左侧菜单
     * @returns {Promise<*[]|*>}
     */
    async getLeftMenu() {
        const list = await this.menuList();
        if (list.length === 0) {
            return [];
        }
        const allMenuList = list.filter(item => item.level < 2);
        const menuList = allMenuList.filter(item => parseInt(item.level) === 0 && item.is_menu === 1);
        const subMenuList = allMenuList.filter(item => parseInt(item.level) === 1 && item.is_menu === 1);
        for (let item of menuList) {
            item.children = [];
            for (let val of subMenuList) {
                if (parseInt(item.id) === parseInt(val.pid)) {
                    item.children.push(val);
                }
            }
        }
        return menuList
    }

    /**
     * 获取菜单
     * @param id
     * @returns {Promise<*[]>}
     */
    async getAuthMenu(id) {
        const list = await this.menuList();
        if (list.length === 0) {
            return [];
        }
        return list.filter(item => id.split(',').map(s => parseInt(s)).includes(item.id) && item.level < 2 && item.is_menu === 1);
    }
    /**
     * 获取一级菜单
     * @param idArr
     * @returns {Promise<*[]>}
     */
    async getAuthFirstLevelMenu(idArr) {
        const list = await this.menuList();
        if (list.length === 0) {
            return [];
        }
        return list.filter(item => idArr.map(s => parseInt(s)).includes(item.id) && item.level == 0 && item.is_menu === 1);
    }

    /**
     * 根据url查菜单
     * @param originUri
     * @param openMethod
     * @returns {Promise<boolean|*[]|*>}
     */
    async menuByUrl(originUri, openMethod) {
        const where = [
            ['url', '==', originUri],
            ['method', '==', openMethod],
            ['status', '==', 0]
        ];
        return await dbs.gets(Const.TABLES.GB_PAY.MENU, [], where, [], 1);
    }
}

module.exports = new menuModel();