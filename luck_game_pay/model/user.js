/**
 * 用户
 */
const dbs = require('../common/db/dbs')(config.mysql.dbs.game);
const cache = require('../common/redis/cache');
const CfgDrawLimit = require('../model/cfg_draw_limit');
const moment = require('moment');
class User {

    /**
     * 获取余额
     * @param uid
     * @returns {Promise<{uid: *, kyc: *, bonus: number, ispayer: *, dcoin: string, ecoin: string, totalcoin: *, svip: *, coin: string}>}
     */
    async getUserCoin(uid = 0) {
        const fields = 'uid,gamedraw,coin,kyc,cashbonus,svip,ispayer,kycfield,isbindphone,nodislabelid';
        const userInfo = await dbs.getOne(Const.TABLES.GAME.D_USER, fields, {uid});

        let dcoin = parseFloat(userInfo.gamedraw).toFixed(2);
        if (Number(dcoin) < 0) {
            dcoin = 0;
        }
        if (Number(dcoin) > Number(userInfo.coin)) {
            dcoin = userInfo.coin;
        }
        let totalcoin = userInfo.coin;

        return {
            uid: userInfo.uid,
            coin: parseFloat(userInfo.coin).toFixed(2),//现金余额
            dcoin,//可提金额
            ecoin: parseFloat(((userInfo.coin * 100) - (dcoin * 100)) / 100).toFixed(2),//cash balance
            bonus: parseFloat(userInfo.cashbonus),//优惠总余额
            totalcoin,
            kyc: userInfo.kyc,
            svip: userInfo.svip,
            ispayer: userInfo.ispayer
        }
    }

    /**
     * 验证token
     * @param uid
     * @param token
     * @returns {Promise<boolean>}
     */
    async checkUser(uid, token) {
        if (!uid || !token) {
            return false;
        }
        const cache_key = `utoken_${uid}`;
        const cache_token = await cache.gets(cache_key);
        if (!cache_token) {
            return false;
        }
        return (cache_token.toString().trim() === token);
    }
    /**
     * 验证token
     */
    async checkUserMiddleware(req, res, next) {
        const method = req.method.toUpperCase();
        const uid = req.query.uid || req.body.uid || 0;
        const token = req.query.token || req.body.token || '';
        const checkUser = await this.checkUser(uid, token);
        if (!checkUser) {
            if ('POST' === method) {
                return res.json(errors('Disconnect please log in again'));
            }
            return res.render('error', {L, error_message: L('Disconnect please log in again')});
        }
        next();
    }

    /**
     * 获取提现限制
     * @param uid
     * @returns {Promise<string{}>}
     */
    async getLimitInfo(uid) {
        let mincoin = 0;
        let maxcoin = 10000;
        let times = -1;
        let daycoin = -1;
        let totaltimes = -1;
        let totalcoin = -1;
        let interval = 0;
        let userinfo = await dbs.getOne(Const.TABLES.GAME.D_USER, [], {uid});
        let datalist = await CfgDrawLimit.getDataBySvip(uid, userinfo?.svip ?? 0);
        if (datalist.length > 0) {
            for (let row of datalist) {
                if (row.times > times) {
                    times = parseInt(row.times);
                }
                if (row.interval > interval) {
                    interval = parseInt(row.interval);
                }
                if (row.daycoin > daycoin) {
                    daycoin = row.daycoin;
                }
                if (row.totaltimes > totaltimes) {
                    totaltimes = $row.totaltimes;
                }
                if (row.totalcoin > totalcoin) {
                    totalcoin = row.totalcoin;
                }
            }
        }
        return {
            mincoin,
            maxcoin,
            times,
            interval,
            daycoin,
            totaltimes,
            totalcoin
        };
    }

    /**
     * 获取一周前的时间戳
     * @returns {number}
     */
    getWeekDayStartTime() {
        const start = funcs.zeroTimestamps();
        return (start - 7 * 86400);
    }

    /**
     * 充值记录
     * @param uid
     * @param startpage
     * @param pagesize
     * @param status
     * @returns {*}
     */
    async getRechargeList(uid, startpage, pagesize, status = -1) {
        let start = (startpage - 1 ) * pagesize;
        if(start < 0) {
            start = 0;
        }
        const startime = this.getWeekDayStartTime();
        const order_status = {
            0: L('In-Process'),
            1: L('In-Process'),
            2: L('Success'),
            3: L('Failed'),
            4: L('Refuse')
        };
        let sql =`SELECT a.id,a.orderid,a.uid,a.count,a.status,a.create_time,b.title,a.memo FROM ${Const.TABLES.GAME.D_USER_RECHARGE} a 
                    LEFT JOIN ${Const.TABLES.GAME.S_PAY_GROUP} b ON a.groupid = b.id 
                    WHERE a.create_time >= ${startime} AND a.uid = ${uid} `
        if (status >= 0) {
            if ([0, 1].includes(parseInt(status))) {
                sql += `AND a.status IN (0,1) `
            } else {
                sql += `AND a.status = ${status} `
            }
        }
        sql += `ORDER BY a.create_time desc LIMIT ${start}, ${pagesize}`;
        const chargeList = await dbs.querys(sql);
        const datalist = [];
        const nowtime = funcs.nowTime();
        if (chargeList.length > 0) {
            for(let row of chargeList) {
                let item = {
                    id: row.id,
                    orderid: row.orderid,
                    coin: parseFloat(row.count),
                    status_str: order_status.hasOwnProperty(row.status) ? order_status[row.status] : 'In-Process',
                    status: row.status,
                    time: moment.unix(row.create_time).format('MM/DD/YYYY hh:mm a'),
                    title: row.title,
                    memo: ''
                };
                if (parseInt(item.status) === 4) {
                    item.memo = row.memo ? row.memo.substring(0, 128) : '';
                }
                if (item.coin > 0) {
                    item.coin = item.coin.toFixed(2);
                }
                if ((nowtime - row.create_time) <= 300 && row.status === 0) {
                    item.status = 1;
                }
                datalist.push(item);
            }
        }
        return datalist;
    }

    /**
     * 获取提现记录
     * @param uid
     * @param startpage
     * @param pagesize
     * @param status
     * @returns {Promise<{}>}
     */
    async getDrawList(uid, startpage, pagesize, status = -1) {
        const start = (startpage - 1) * pagesize >= 0 ? (startpage - 1) * pagesize : 0;
        const starttime = this.getWeekDayStartTime();
        const order_status = {
            0: L('In-Process'),
            1: L('In-Process'),
            2: L('Success'),
            3: L('Refund')
        };
        let sql = `SELECT id, orderid, cat, bankid, userbankid, coin, status, create_time, chanstate, memo 
                 FROM ${Const.TABLES.GAME.D_USER_DRAW} 
                 WHERE uid = ${uid} AND create_time >= ${starttime} `;
        if (status > 0) {
            if ([0, 1].includes(parseInt(status))) {
                sql += `AND status IN (0,1) `
            } else if (parseInt(status) === 2) {
                sql += `AND status = 2 AND chanstate = 2 `
            } else if (parseInt(status) === 3) {
                sql += `AND status = 3 `
            } else if (parseInt(status) === 4) {
                sql += `AND status = 2 AND chanstate = 3 `
            }
        }
        sql += `ORDER BY create_time DESC LIMIT ${start}, ${pagesize}`;
        const chargeList = await dbs.querys(sql);
        const datalist = [];
        const nowtime = funcs.nowTime(); // 当前时间戳，单位秒
        if (chargeList.length > 0) {
            chargeList.forEach(row => {
                let status_str = order_status[row.status] || '';
                let status = row.status;
                let memo = '';
                if (row.status === 2) {
                    if (row.chanstate === 1) {
                        status = 1;
                        status_str = L('In-Payment');
                    } else if (row.chanstate === 0) {
                        status = 1;
                        status_str = L('In-Process');
                    } else if (row.chanstate === 3) {
                        status = 4;
                        status_str = L('Fail');
                    }
                }
                if (row.status === 3) { // 已拒绝
                    memo = row?.memo?.substring(0, 128) ?? '';
                }
                let coin = parseFloat(row.coin);
                if (coin > 0) {
                    coin = coin.toFixed(2);
                }
                if ((nowtime - row.create_time) <= 300 && row.status === 0) { // 5分钟内，未支付成功的订单先不显示need help
                    status = 1;
                }
                const item = {
                    id: row.id,
                    orderid: row.orderid,
                    coin: coin,
                    status_str: status_str,
                    status: status,
                    time: moment(row.create_time * 1000).format('MM/DD/YYYY hh:mm A'),
                    memo: memo
                };
                datalist.push(item);
            });
        }
        return datalist;
    }

    /**
     * 下注记录
     * @param uid
     * @param startpage
     * @param pagesize
     * @param status
     * @returns {Promise<{}>}
     */
    async getBetList(uid, startpage, pagesize, status = -1) {
        const start = (startpage - 1) * pagesize >= 0 ? (startpage - 1) * pagesize : 0;
        const starttime = this.getWeekDayStartTime();
        let sql = `SELECT id, gameid, bet, wincoin, create_time, issue 
                 FROM ${Const.TABLES.GAME.D_DESK_USER} 
                 WHERE uid = ${uid} AND create_time >= ${starttime} `;
        if (status >= 0) {
            sql += `AND win = ${status} `;
        }
        sql += `ORDER BY create_time DESC LIMIT ${start}, ${pagesize}`;
        const betList = await dbs.querys(sql);
        const datalist = [];
        const gameList = await dbs.gets(Const.TABLES.GAME.S_GAME, ['id', 'title'], ['status', '=', 1]);
        const gameDict = {};
        if (gameList.length > 0) {
            for (let item of gameList) {
                gameDict[item.id] = item.title;
            }
        }
        if (betList.length > 0) {
            betList.forEach(row => {
                // let wincoin = parseFloat(row.wincoin - row.bet);
                let wincoin = Number(row.wincoin);
                const status = wincoin > 0 ? 2 : 3; // 2 win 3 lose
                if (wincoin > 0) {
                    wincoin = wincoin.toFixed(2);
                } else {
                    wincoin = 0;
                }
                const item = {
                    id: row.id,
                    orderid: row.issue,
                    bet: parseFloat(row.bet),
                    wincoin: parseFloat(wincoin),
                    status: status,
                    gameid: row.gameid,
                    title: gameDict[row.gameid] || '',
                    time: moment(row.create_time * 1000).format('MM/DD/YYYY hh:mm A')
                };
                datalist.push(item);
            });
        }
        return datalist;
    }

    /**
     * bonus
     * @param uid
     * @param startpage
     * @param pagesize
     * @param status
     * @returns {Promise<{}>}
     */
    async getBonusList(uid, startpage, pagesize, status = -1) {
        const start = (startpage - 1) * pagesize >= 0 ? (startpage - 1) * pagesize : 0;
        const starttime = this.getWeekDayStartTime();
        let sql = `SELECT id, title, coin, category, create_time, orderid, useruid 
                 FROM ${Const.TABLES.GAME.D_LOG_CASHBONUS} 
                 WHERE uid = ${uid} AND create_time >= ${starttime} `;
        if (parseInt(status) === 0) {
            sql += `AND coin <= 0 `;
        } else if (parseInt(status) === 1) {
            sql += `AND coin > 0 `;
        }
        sql += `ORDER BY create_time DESC LIMIT ${start}, ${pagesize}`;
        const chargeList = await dbs.querys(sql);
        const datalist = [];
        if (chargeList.length > 0) {
            chargeList.forEach(row => {
                let status_str = '';
                switch (row.category) {
                    case 1:
                        status_str = row.useruid ? L('Refer & earn bonus referral register') : L('Register bonus');
                        break;
                    case 2:
                        status_str = row.useruid ? L('Refer & earn bonus referral deposit') : L('Deposit bonus');
                        break;
                    case 3:
                        status_str = row.useruid ? L('Refer & earn bonus referral bet') : L('User Bet');
                        break;
                    case 4:
                        status_str = L('Quest');
                        break;
                    case 5:
                        status_str = L('VIP level up bonus');
                        break;
                    case 6:
                        status_str = L('Transfer Out');
                        break;
                    case 9:
                        status_str = L('VIP weekly bonus');
                        break;
                    case 10:
                        status_str = L('VIP monthly bonus');
                        break;
                    case 11:
                        status_str = L('Task bonus deposit task');
                        break;
                    case 12:
                        status_str = L('Deposit and receive bonus');
                        break;
                    case 22:
                        status_str = L('Task bonus game task');
                        break;
                    case 23:
                        status_str = L('Task bonus profit task');
                        break;
                    case 33:
                        status_str = L('Task bonus betting task');
                        break;
                    case 34:
                        status_str = L('Transfer to Cash Balance');
                        break;
                    case 35:
                        status_str = L('Login bonus');
                        break;
                    case 36:
                        status_str = L('Share & spin bonus');
                        break;
                    case 37:
                        status_str = L('Rebate bonus');
                        break;
                    case 38:
                        status_str = L('Salon room tax bonus');
                        break;
                    case 39:
                        status_str = L('Free Winnings transfer in');
                        break;
                    case 40:
                        status_str = L('First withdraw of bonus transfer out');
                        break;
                    default:
                        status_str = L('Lucky bonus');
                }
                let coin = parseFloat(row.coin);
                coin = coin > 0 ? coin.toFixed(2) : 0;
                const item = {
                    id: row.id,
                    orderid: row.orderid,
                    coin: coin,
                    title: row.title,
                    status: row.category,
                    status_str: status_str,
                    time: moment(row.create_time * 1000).format('MM/DD/YYYY hh:mm A')
                };
                datalist.push(item);
            });
        }
        return datalist;
    }
}

module.exports = new User();