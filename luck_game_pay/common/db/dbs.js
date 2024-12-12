/**
 * 数据库查询方法
 */
const mysql = require('mysql2');
const sqlBuilder = require('./sql_builder');

class Dbs {
    constructor(db_name) {
        this.pool = mysql.createPool({
            connectionLimit: 10000,
            host: config.mysql.host,
            user: config.mysql.username,
            password: config.mysql.password,
            port: config.mysql.port,
            database: db_name,
            charset: "utf8mb4",
        });
    }

    /**
     * 执行sql方法
     * @param sql
     * @param type
     * @returns {Promise<>}
     */
    querys(sql, type = 'SELECT') {
        return new Promise((resolve, reject) => {
            this.pool.getConnection((error, connection) => {
                if (error) {
                    console.error('Error connecting to database:', error);
                    let result = false;
                    if ('SELECT' === type) result = [];
                    return resolve(result);
                }
                connection.query(sql, (err, rows) => {
                    connection.release();
                    err ? console.error(sql, err) : console.log(sql);
                    switch (type) {
                        case 'SELECT':
                            //返回数组，报错的话返回空数组
                            resolve(err ? [] : Array.from(rows));
                            break;
                        case 'UPDATE':
                            //返回的是受影响的行
                            resolve(err ? false : (typeof rows.affectedRows != "undefined" ? rows.affectedRows : 1));
                            break;
                        case 'INSERT':
                            //返回的是主键id
                            resolve(err ? false : (typeof rows.insertId != "undefined" ? rows.insertId : 1));
                            break;
                        case 'DELETE':
                            //返回的是受影响的行
                            resolve(err ? false : (typeof rows.affectedRows != "undefined" ? rows.affectedRows : 1));
                            break;
                    }
                });
            });
        });
    }

    /**
     * 获取列表
     * @param table 表名 hs_user
     * @param field 字段名
     *  可以是字符串: id,name,abc as time，
     *  也可以是数组 ['id', 'name', 'abc as time']
     *  也可以是函数: id, name, SUM(coinIn), MAX(sort), COUNT(1), GROUP_CONCAT(name)...
     * @param where 单条件["id", "==", 1]
     * 多条件[
     *  ["id", "==", 1], ["id", "!=", 1], ["id", "in", [1,2,3,4]],
     *  ["create_time", ">=",16535252525221], ["create_time", "<=",16535252525221]
     *  ["name", "like", "%abc%"]
     * ]
     * @param order(单排序["id", "asc"], 多排序[["id", "asc"], ["name", "desc"]])
     * @param limit 数字或数组 10或[1, 10]
     * @param group 可以是字符串：id, name；可以是数组：['id', 'name']，不支持其他格式
     * @param having 可以是字符串：id > 1 and name < 100；可以是数组：['id > 1', 'num < 100']， 不支持其他格式
     * @returns {Promise<[]>}
     */
    async gets(table, field = [], where = [], order = [], limit = 0, group = '', having = '') {
        try {
            const sqlStr = sqlBuilder.select(table, field, where, order, limit, group, having);
            return await this.querys(sqlStr, 'SELECT');
        } catch (e) {
            console.error(`gets ${table} errors: `, e.toString());
            return [];
        }
    }

    /**
     * 获取单条记录
     * @param table 表名 hs_user
     * @param maps 查询条件，如果是对象的话可以加多个{id: 1, name: 'abc'}，
     *      如果是字符串的话，默认转换成{id: maps}这种格式
     * @param field 字段名 可以使字符串: id,name,abc as time，也可以是数组['id', 'name', 'abc as time']
     * @returns {Promise<{}|*>}
     */
    async getOne(table, field = [], maps) {
        try {
            const info = await this.querys(sqlBuilder.selectOne(table, field, maps), 'SELECT');
            return info.length > 0 ? info[0] : {};
        } catch (e) {
            console.error('getOne ' + table + " errors: ", e.toString());
            return {};
        }
    }

    /**
     * 插入数据
     * @param table 表名 hs_user
     * @param data 单个插入用对象，多个插入用数组
     * @returns {Promise<boolean|*>}
     */
    async insert(table, data = {}) {
        try {
            //返回值为主键id
            return await this.querys(sqlBuilder.insertInto(table, data), 'INSERT');
        } catch (e) {
            console.log('insert ' + table, " errors: ", e.toString());
            return false;
        }
    }

    /**
     * 更新数据
     * @param table 表名 hs_user
     * @param data 对象
     * @param where 对象
     * @returns {Promise<boolean|*>}
     */
    async sets(table, data = {}, where = {}) {
        try {
            return await this.querys(sqlBuilder.update(table, data, where), 'UPDATE');
        } catch (e) {
            console.error('sets ' + table, " errors: ", e.toString());
            return false;
        }
    }

    /**
     * 删除数据
     * @param table 表名 hs_user
     * @param where 对象
     * @returns {Promise<boolean>}
     */
    async delete(table, where) {
        try {
            return await this.querys(sqlBuilder.delete(table, where), 'DELETE');
        } catch (e) {
            console.error('delete ' + table, " errors: ", e.toString());
            return false;
        }
    }

    /**
     * count方法
     * @param table
     * @param field
     * @param where
     * @param order
     * @param limit
     * @param group
     * @param having
     * @returns {Promise<*|number>}
     */
    async count(table, field = [], where = [], order = [], limit = 0, group = '', having = '') {
        try {
            const sql = sqlBuilder.count(table, field, where, order, limit, group, having);
            const result = await this.querys(sql, 'SELECT');
            return !!group ? result.length : (typeof result[0] != 'undefined' ? result[0].count : 0);
        } catch (e) {
            console.error('count ' + table, " errors: ", e.toString());
            return 0;
        }
    };
}

module.exports = (dbName = 'gb_pay') => new Dbs(dbName);