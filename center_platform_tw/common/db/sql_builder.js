/**
 * 构建SQL语句
 */
module.exports = {
    /**
     * 查询语句构建
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
     * @returns {string}
     */
    select(table, field = [], where = [], order = [], limit = 0, group = '', having = '') {
        try {
            let sqlStr = 'select ';
            if (!field) field = '*';
            if (Array.isArray(field)) {
                if (field.length === 0) {
                    field = '*';
                } else {
                    field = field.join(',');
                }
            }
            //如果field不是字符串的话，置为*
            if (typeof field != 'string') field = '*';
            sqlStr += field + ' from ' + table + ' ';
            //where语句构建
            if (where.length > 0) {
                if (typeof where[0] == 'object') {
                    //多条件查询语句
                    let a = [];
                    for (let item of where) {
                        let itemFormat = '`' + item[0] + '` ';
                        if (item[1] === '==') {
                            itemFormat += '=';
                        } else {
                            itemFormat += item[1];
                        }
                        if (typeof item[2] == 'number') {
                            itemFormat += ' ' + item[2];
                        } else if (Array.isArray(item[2])) {
                            itemFormat += ' (' + item[2].map(s => {
                                if (typeof s == 'string') s = "'" + s + "'";
                                return s;
                            }).join(',') + ')';
                        } else {
                            itemFormat += " '" + item[2] + "'";
                        }
                        a.push(itemFormat);
                    }
                    sqlStr += 'where (' + a.join(' and ') + ')';
                } else {
                    //单条件查询语句
                    sqlStr += 'where (`' + where[0] + '` ';
                    if (where[1] === '==') {
                        sqlStr += '=';
                    } else {
                        sqlStr += where[1];
                    }
                    if (typeof where[2] == 'number') {
                        sqlStr += ' ' + where[2];
                    } else if (Array.isArray(where[2])) {
                        sqlStr += ' (' + where[2].map(s => {
                            if (typeof s == 'string') s = "'" + s + "'";
                            return s;
                        }).join(',') + ')';
                    } else {
                        sqlStr += " '" + where[2] + "'";
                    }
                    sqlStr += ')';
                }
            }
            //group by
            if (typeof group === 'string') {
                if (group) sqlStr += ' group by ' + group;
            } else if (Array.isArray(group)) {
                if (group.length > 0) sqlStr += ' group by ' + group.map(s => s.toString()).join(',');
            }
            //having
            if (typeof having === 'string') {
                if (having) sqlStr += ' having (' + having + ')';
            } else if (Array.isArray(having)) {
                if (having.length > 0) sqlStr += ' having (' + having.join(' and ') + ')';
            }
            //order
            if (order.length > 0) {
                if (typeof order[0] == 'object') {
                    let b = [];
                    for (let item of order) {
                        b.push('`' + item[0] + '` '+ item[1]);
                    }
                    sqlStr += ' order by ' + b.join(',');
                } else {
                    sqlStr += ' order by `' + order[0] + '` '+ order[1] +'';
                }
            }
            //limit
            if (limit) {
                sqlStr += ' limit ' + (Array.isArray(limit) ? limit.join(',') : limit);
            }
            return sqlStr;
        } catch (e) {
            console.error("sql builder select errors: ", e.toString());
            return '';
        }
    },
    /**
     * 获取单条记录sql构建
     * @param table 表名 hs_user
     * @param maps 查询条件，如果是对象的话可以加多个{id: 1, name: 'abc'}，
     *      如果是字符串的话，默认转换成{id: maps}这种格式
     * @param field 字段名 可以使字符串: id,name,abc as time，也可以是数组['id', 'name', 'abc as time']
     * @returns {string}
     */
    selectOne(table, field = [], maps) {
        try {
            let sqlStr = 'select ';
            if (!field) field = '*';
            if (Array.isArray(field)) {
                if (field.length === 0) {
                    field = '*';
                } else {
                    field = field.join(',');
                }
            }
            //如果field不是字符串的话，置为*
            if (typeof field != 'string') field = '*';
            sqlStr += field + ' from ' + table + ' ';
            //maps参数如果是字符串或数值类型的话，默认一个id字段
            if (typeof maps == 'string' || typeof maps == 'number') {
                maps = {id: maps};
            }
            //maps如果不是对象或字符串，数值的话，提示一个错误，返回空
            if (maps?.constructor !== Object) {
                console.error("sql builder selectOne errors: incorrect parameter format(maps)");
                return '';
            }
            if (Object.keys(maps).length > 0) {
                let a = [];
                for (let [k, v] of Object.entries(maps)) {
                    let itemFormat = '`' + k + '` = ';
                    if (typeof v == 'string') v = "'" + v + "'";
                    itemFormat += v;
                    a.push(itemFormat);
                }
                sqlStr += 'where (' + a.join(' and ') + ')';
            }
            sqlStr += ' limit 1';
            return sqlStr;
        } catch (e) {
            console.error("sql builder selectOne errors: ", e.toString());
            return '';
        }
    },
    /**
     * 插入数据sql构建
     * @param table 表名 hs_user
     * @param data 单个插入用对象，多个插入用数组
     * @returns {string}
     */
    insertInto(table, data = {}) {
        try {
            let sqlStr = 'replace into ' + table;
            if (data?.constructor === Object) {
                //如果data是一个对象的话，是单个插入
                if (Object.keys(data).length === 0) {
                    console.error("sql builder insertInto errors: object data is empty");
                    return '';
                }
                //field
                let field = Object.keys(data).map(val => '`' + val + '`').join(',');
                //values
                let valList = '(' + Object.values(data).map(val => {
                    if (typeof val == 'number') {
                        return val;
                    } else if (typeof val == 'object') {
                        return "'" + JSON.stringify(val) + "'";
                    } else {
                        return "'" + val + "'";
                    }
                }).join(',') + ')';
                sqlStr += ' (' + field + ') values ' + valList;
            } else if (Array.isArray(data)) {
                //data是数组的话，是多条插入
                if (data.length === 0) {
                    console.error("sql builder insertInto errors: array data is empty");
                    return '';
                }
                //field
                let field = Object.keys(data[0]).map(val => '`' + val + '`').join(',');
                //values
                let valList = data.map(vals => {
                    return '(' + Object.values(vals).map(val => {
                        if (typeof val == 'number') {
                            return val;
                        } else if (typeof val == 'object') {
                            return "'" + JSON.stringify(val) + "'";
                        } else {
                            return "'" + val + "'";
                        }
                    }).join(',') + ')';
                }).join(',');
                sqlStr += ' (' + field + ') values ' + valList;
            } else {
                //不支持其他格式的data
                console.error("sql builder insertInto errors: incorrect parameter format(data)");
                return '';
            }
            return sqlStr;
        } catch (e) {
            console.error("sql builder insertInto errors: ", e.toString());
            return '';
        }
    },
    /**
     * 更新数据sql构建
     * @param table 表名 hs_user
     * @param data 对象 如果更新的对象中含有函数表达式，可以这么写：{bonus: ['func_phrase', `GREATEST(bonus - ${item.bonus}, 0)`]}
     * @param where 对象
     * @returns {string}
     */
    update(table, data = {}, where = {}) {
        try {
            let sqlStr = 'update ' + table;
            if (Object.keys(data).length === 0) {
                console.error("sql builder update errors: object data is empty");
                return '';
            }
            if (Object.keys(where).length === 0) {
                console.error("sql builder update errors: object where is empty");
                return '';
            }
            //set data
            let setData = [];
            for (let item of Object.keys(data)) {
                data[item] = typeof data[item] == 'undefined' ? '' : data[item];
                if (Array.isArray(data[item])) {
                    if (data[item].length > 1 && data[item][0] === 'func_phrase') {
                        //如果是函数语句
                        data[item] = data[item][1];
                    } else {
                        data[item] = "'" + JSON.stringify(data[item]) + "'";
                    }
                } else if (data[item] === Object) {
                    data[item] = "'" + JSON.stringify(data[item]) + "'";
                } else {
                    data[item] = "'" + data[item] + "'";
                }
                setData.push('`' + item + '` = ' + data[item]);
            }
            sqlStr += ' set ' + setData.join(',') + '';
            //where data
            let whereData = [];
            for (let [k, v] of Object.entries(where)) {
                let whereStr = '`' + k + '` ', operator = '=', valStr = v;
                if (typeof v != 'number') {
                    if (Array.isArray(v)) {
                        operator = v[0];
                        if (Array.isArray(v[1])) {
                            valStr = '(' + v[1].join(',') + ')';
                        } else if (v[1]?.constructor === Object) {
                            valStr = '(' + Object.values(v[1]).join(',') + ')';
                        } else {
                            valStr = v[1];
                        }
                    } else {
                        valStr = "'" + v + "'";
                    }
                }
                whereStr += operator + ' ' + valStr;
                whereData.push(whereStr);
            }
            sqlStr += ' where (' + whereData.join(' and ') + ')';
            return sqlStr;
        } catch (e) {
            console.error("sql builder update errors: ", e.toString());
            return '';
        }
    },
    /**
     * 删除数据SQL构建
     * @param table 表名 hs_user
     * @param where 对象
     * @returns {string}
     */
    delete(table, where) {
        try {
            if (Object.keys(where).length === 0) {
                console.error("sql builder delete errors: object where is empty");
                return '';
            }
            let sqlStr = 'delete from ' + table;
            //where data
            let whereData = [];
            for (let [k, v] of Object.entries(where)) {
                let whereStr = '`' + k + '`', operator = '=', valStr = v;
                if (typeof v != 'number') {
                    if (Array.isArray(v)) {
                        operator = v[0];
                        if (Array.isArray(v[1])) {
                            valStr = '(' + v[1].join(',') + ')';
                        } else if (v[1]?.constructor === Object) {
                            valStr = '(' + Object.values(v[1]).join(',') + ')';
                        } else {
                            valStr = v[1];
                        }
                    } else {
                        valStr = "'" + v + "'";
                    }
                }
                whereStr += operator + ' ' + valStr;
                whereData.push(whereStr);
            }
            sqlStr += ' where (' + whereData.join(' and ') + ')';
            return sqlStr;
        } catch (e) {
            console.error("sql builder delete errors: ", e.toString());
            return '';
        }
    },
    /**
     * count语句构建
     * @returns {string}
     */
    count(table, field = [], where = [], order = [], limit = 0, group = '', having = '') {
        try {
            let sql = this.select(table, field, where, order, limit, group, having);
            if (!sql) {
                console.error("sql builder count errors: sql - ", sql);
                return '';
            }
            let flag = false;
            if (sql.includes('group by')) {
                flag = true;
            } else {
                if (!sql.includes('count(1) as count')) {
                    let sql2 = sql;
                    sql2 = sql2.substring(0, sql2.indexOf('from'));
                    sql2 = sql2.substring(sql2.indexOf('select') + 6, sql2.length).trim();
                    sql = sql.replace(sql2, 'count(1) as count');
                }
            }
            if (sql.includes('order by')) {
                sql = sql.substring(0, sql.indexOf('order by'))
            }
            return sql;
        } catch (e) {
            console.error("sql builder count errors: ", e.toString());
            return '';
        }
    }
};