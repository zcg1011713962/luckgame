/**
 * tw line pay
 */
const dbs = require('../../common/db/dbs')(config.mysql.dbs.gb_pay);
const Linepay = require('../channel/linepay');
const httpRequest = require('../../common/request/http');
const Common = require('../common');
class Tw_linepay {

    constructor() {
        //币种
        this.currency = 'TWD';
    }

    /**
     * 创建代收订单
     * @param channelInfo
     * @param environment 环境
     * @param amount
     */
    async createPayOrder(channelInfo = {}, amount = 0, environment) {
        const isTest = environment === 'sandbox';
        const nowTime = Date.now();
        const merOrderNo = channelInfo.merOrderNo ? channelInfo.merOrderNo : funcs.generateMerOrderNo(channelInfo.app_id);
        const params = {
            merOrderNo,
            amount: amount,
            currency: this.currency
        }
        const apiPay = new Linepay(channelInfo.mch_id, channelInfo.md5_key, environment);
        let result;
        if (!isTest) {
            result = await apiPay.createPayOrder(params);
        } else {
            const orderNo = funcs.encryptMd5(merOrderNo);
            result = {
                "status":0,
                "msg":"ok",
                "data":{
                    "returnCode":"0000",
                    "returnMessage":"Success.",
                    "info":{
                        "paymentUrl":{
                            "web":"https://sandbox-web-pay.line.me/web/payment/wait?transactionReserveId=Vk1DNnc2QUMxaDFnSjRxL1FHTGZkZUlHL0YvbndCYWYvQ0xkN1c5U2JTYlNvR0ZkTWkwbzdsSkxkeWlmakVyWQ&locale=zh-TW_LP",
                            "app":"line://pay/payment/Vk1DNnc2QUMxaDFnSjRxL1FHTGZkZUlHL0YvbndCYWYvQ0xkN1c5U2JTYlNvR0ZkTWkwbzdsSkxkeWlmakVyWQ"
                        },
                        "transactionId": orderNo,
                        "paymentAccessToken":"261817178799"
                    }
                },
                "statusCode":200
            };
            //测试环境10秒自动回调
            setTimeout(() => {
                const backParam = {
                    "orderId": merOrderNo,
                    "transactionId": orderNo,
                }
                httpRequest.get(apiPay.payNotifyUrl, backParam);
            }, 10000);
        }
        let failedMsg = '';
        //请求失败
        if (Const.RESULT_STATUS.ERROR === result.status) {
            failedMsg = `create payment order error! error msg: ${result.msg}`;
        } else {
            //返回的数据是否为空
            const resultData = result.data || {};
            if (Object.keys(resultData).length === 0) {
                failedMsg = `Response data error! detail: ${JSON.stringify(result.data)}`;
            } else if (Const.LINE_PAY_RESULT_CODE.SUCCESS !== resultData.returnCode) {
                failedMsg = `Response code error! detail: ${JSON.stringify(result.data)}`;
            }
        }
        const data = {
            app_id: channelInfo.app_id,
            channel_id: channelInfo.id,
            channel: channelInfo.type,
            currency: channelInfo.currency,
            mer_order_no: merOrderNo,
            create_time: nowTime,
            update_time: nowTime,
            amount: amount,
            return_url: channelInfo.returnUrl,
            notify_url: channelInfo.notifyUrl,
            status: Const.COMMON_PAY_STATUS.IN_PAY,
            origin_status: Const.LINE_PAY_CHECK_STATUS.RESERVED,
            environment
        };
        if (failedMsg) {
            data.status = Const.COMMON_PAY_STATUS.FAILED;
            data.origin_status = result?.data?.returnCode ?? Const.LINE_PAY_CHECK_STATUS.FAILED;
            data.msg = failedMsg.toString().replace(/'/g, '');
            dbs.insert(Const.TABLES.GB_PAY.PAYMENT_ORDER, data);
            return errors(failedMsg);
        }
        const resultData = result.data || {};
        //交易流水号
        const orderNo = resultData?.info?.transactionId || '';
        //用來跳轉到付款頁的Web URL，在網頁請求付款時使用，在跳轉到LINE Pay等待付款頁時使用，不經參數，直接跳轉到傳來的URL
        // 在Desktop版，彈窗大小為Width：700px，Height：546px
        const webUrl = resultData?.info?.paymentUrl?.web || '';
        //用來跳轉到付款頁的App URL 在應用程式發起付款請求時使用 在從商家應用跳轉到LINE Pay時使用
        const appUrl = resultData?.info?.paymentUrl?.app || '';
        //該代碼在LINE Pay可以代替掃描器使用
        const paymentAccessToken = resultData?.info?.paymentAccessToken || '';
        data.order_no = orderNo;
        data.pay_url = webUrl;
        data.app_url = appUrl;
        data.qrcode = paymentAccessToken;
        const orderRes = await dbs.insert(Const.TABLES.GB_PAY.PAYMENT_ORDER, data);
        if (orderRes === false) {
            const failedMsg = `create order failed!`;
            return errors(failedMsg);
        }
        //返回值
        const backData = {
            create_time: nowTime,
            amount,
            merOrderNo,
            orderNo,
            web_url: webUrl,
            app_url: appUrl,
            qrcode: paymentAccessToken,
            channel: channelInfo.type
        };
        return success(backData);
    }

    /**
     * 查询代收订单
     * @param channelInfo
     * @param orderInfo
     * @param environment
     */
    async queryPayOrder(channelInfo = {}, orderInfo = {}, environment) {
        const isTest = environment === 'sandbox';
        const merOrderNo = orderInfo.mer_order_no;
        const transactionId = orderInfo.order_no;
        const params = {
            transactionId,
        }
        const apiPay = new Linepay(channelInfo.mch_id, channelInfo.md5_key, environment);
        let result;
        if (!isTest) {
            result = await apiPay.checkPaymentStatus(params);
        } else {
            const orderInfo = await dbs.getOne(Const.TABLES.GB_PAY.PAYMENT_ORDER, [], {mer_order_no: merOrderNo});
            if (Object.keys(orderInfo).length === 0) {
                result = {
                    status: Const.RESULT_STATUS.ERROR,
                    msg: 'order not found',
                    data: {}
                }
            } else {
                result = {
                    "statusCode":200,
                    "status":0,
                    "msg":"ok",
                    "data":{
                        "returnCode":orderInfo.origin_status,
                        "returnMessage":"completed transaction"
                    }
                }
            }
        }
        let failedMsg = '';
        //请求失败
        if (Const.RESULT_STATUS.ERROR === result.status) {
            failedMsg = `Request error! error msg: ${result.msg}`;
        } else {
            //返回的数据是否为空
            const resultData = result.data || {};
            if (Object.keys(resultData).length === 0) {
                failedMsg = `Response data error! detail: ${JSON.stringify(result.data)}`;
            }
        }
        if (failedMsg) {
            return errors(failedMsg);
        }
        const resultData = result.data || {};
        //订单状态
        const queryOrderStatus = resultData.returnCode;
        //返回值
        const backData = {
            status: Const.COMMON_PAY_STATUS.IN_PAY,
            origin_status: queryOrderStatus
        };
        if (Const.LINE_PAY_CHECK_STATUS.SUCCEED === queryOrderStatus) {
            backData.status = Const.COMMON_PAY_STATUS.SUCCESS;
        } else if (Const.LINE_PAY_CHECK_STATUS.FAILED === queryOrderStatus) {
            backData.status = Const.COMMON_PAY_STATUS.FAILED;
        } else if (Const.LINE_PAY_CHECK_STATUS.TO_CONFIRM === queryOrderStatus) {
            this.callConfirmApiToFinishTrade(transactionId, channelInfo, orderInfo);
        }
        return success(backData);
    }

    /**
     * 调用confirm api完成交易
     * @param transactionId
     * @param channelInfo
     * @param orderInfo
     * @returns {Promise<boolean>}
     */
    async callConfirmApiToFinishTrade(transactionId, channelInfo, orderInfo) {
        const environment = orderInfo.environment;
        const nowTime = Date.now();
        const data = {
            update_time: nowTime,
            async_nums: ['func_phrase', `async_nums + 1`]
        };
        if (environment === 'sandbox') {
            data.origin_status = Const.LINE_PAY_CHECK_STATUS.SUCCEED;
            data.pay_time = nowTime;
            data.status = Const.COMMON_PAY_STATUS.SUCCESS;
        } else {
            //生产环境去调用confirm API
            const params = {
                amount: orderInfo.amount,
                currency: orderInfo.currency,
                transactionId
            };
            const apiPay = new Linepay(channelInfo.mch_id, channelInfo.md5_key, environment);
            const result = await apiPay.callConfirmApi(params);
            //请求失败
            if (Const.RESULT_STATUS.ERROR === result.status) {
                const cb_msg = `call confirm api error! param: ${JSON.stringify(params)}； error msg: ${result.msg}`;
                dbs.sets(Const.TABLES.GB_PAY.PAYMENT_ORDER, {status: Const.COMMON_PAY_STATUS.FAILED, cb_msg: cb_msg.toString().replace(/'/g, '')}, {id: orderInfo.id});
                return false;
            }
            //返回的数据是否为空
            const resultData = result.data || {};
            if (Object.keys(resultData).length === 0) {
                const cb_msg = `Response data error! detail: ${JSON.stringify(result.data)}`;
                dbs.sets(Const.TABLES.GB_PAY.PAYMENT_ORDER, {status: Const.COMMON_PAY_STATUS.FAILED, cb_msg: cb_msg.toString().replace(/'/g, '')}, {id: orderInfo.id});
                return false;
            }
            //请求成功，判断result.data.returnCode
            if (Const.LINE_PAY_RESULT_CODE.SUCCESS !== resultData.returnCode) {
                const cb_msg = `Response code error! detail: ${JSON.stringify(result.data)}`;
                dbs.sets(Const.TABLES.GB_PAY.PAYMENT_ORDER, {status: Const.COMMON_PAY_STATUS.FAILED, origin_status: resultData.returnCode, cb_msg: cb_msg.toString().replace(/'/g, '')}, {id: orderInfo.id});
                return false;
            }
            data.origin_status = Const.LINE_PAY_CHECK_STATUS.SUCCEED;
            data.pay_time = nowTime;
            data.status = Const.COMMON_PAY_STATUS.SUCCESS;
        }
        const back_status = data?.status ?? 0;
        const back_pay_time = data?.pay_time ?? nowTime;
        //更新订单信息
        await dbs.sets(Const.TABLES.GB_PAY.PAYMENT_ORDER, data, {id: orderInfo.id});
        //支付成功之后回调客户端
        const url = orderInfo.notify_url;
        if (url) {
            const cbData = {
                channel: channelInfo.type,
                currency: channelInfo.currency,
                orderNo: orderInfo.order_no,
                merOrderNo: orderInfo.mer_order_no,
                payTime: back_pay_time,
                status: back_status,
                amount: orderInfo.amount
            };
            Common.payAsyncCallback(url, cbData);
        }
        return true;
    }
}

module.exports = new Tw_linepay();