/**
 * 支付
 **/
const dbs = require('../common/db/dbs')(config.mysql.dbs.gb_pay);
const TW_linepay = require('./pay/tw_linepay');
class Pay {
    /**
     * 主动查询
     * @param merOrderNo
     * @param appId
     * @param type 0代收 1代付
     */
    async initiativeQuery(appId, merOrderNo, type) {
        //每隔五分钟查一次，一小时之后就不查了
        let queryCount = 0
        const i = setInterval(async () => {
            queryCount++;
            if (queryCount >= 6) {
                clearInterval(i);
            } else {
                if (Const.PAY_ORDER_TYPE.PAYMENT === type) {
                    const queryRes = await this.queryPayOrder(appId, merOrderNo);
                    if (Const.RESULT_STATUS.SUCCESS === queryRes.code && Const.COMMON_PAY_STATUS.SUCCESS === parseInt(queryRes.data.status)) {
                        clearInterval(i);
                    }
                } else {

                }
            }
        }, 1000 * 60 * 5);
    }

    /**
     * 主动查询代收订单
     * @param appId
     * @param merOrderNo
     * @returns {Promise<{msg: *, code: number, data: {}}|null|*>}
     */
    async queryPayOrder(appId, merOrderNo) {
        //查询订单信息
        const orderInfo = await dbs.getOne(Const.TABLES.GB_PAY.PAYMENT_ORDER, [], {mer_order_no: merOrderNo});
        if (Object.keys(orderInfo).length === 0) {
            return errors(`order info not found, merOrderNo: ${merOrderNo}`);
        }
        //商户订单中的app_id是否等于传过来的appId
        if (orderInfo.app_id !== parseInt(appId)) {
            return errors(`not found the merOrderNo in this app`);
        }
        const status = parseInt(orderInfo.status);
        const backData = {
            merOrderNo,
            orderNo: orderInfo?.order_no ?? '',
            payTime: orderInfo?.pay_time ?? 0,
            status,
            amount: orderInfo?.amount ?? 0,
            channel: orderInfo.channel,
        }
        if (Const.COMMON_PAY_STATUS.IN_PAY !== status) {
            return success(backData);
        }
        //渠道信息
        const channelInfo = await dbs.getOne(Const.TABLES.GB_PAY.CHANNEL, [], {id: orderInfo.channel_id});
        if (Object.keys(channelInfo).length === 0) {
            return errors(`channel info not found, channel id: ${orderInfo.channel_id}`);
        }
        let result = null;
        const channel_type = channelInfo.type;
        const currency = channelInfo.currency;
        const environment = orderInfo.environment;
        //linepay
        if (Const.CHANNEL_TYPE.LINE_PAY === channel_type && Const.CURRENCY.TWD === currency) {
            result = await TW_linepay.queryPayOrder(channelInfo, orderInfo, environment);
        }
        if (!result) {
            return errors('channel type error!');
        }
        if (result.code !== Const.COMMON_STATUS.NORMAL) {
            return result;
        }
        if (Const.COMMON_PAY_STATUS.IN_PAY !== result.data.status) {
            backData.status = result.data.status;
            //更新一下订单表
            dbs.sets(Const.TABLES.GB_PAY.PAYMENT_ORDER, {
                status: result.data.status,
                origin_status: result.data.origin_status
            }, {mer_order_no: merOrderNo});
        }
        return success(backData);
    }
}
module.exports = new Pay();