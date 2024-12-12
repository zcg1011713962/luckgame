/**
 * line Pay支付
 **/
const httpRequest = require('../../common/request/http');
const globalConfig = require('../../config/global_config');
const common = require('../common');
const uuid = require('uuid');
const crypto = require('crypto');
class Linepay {
    constructor(channelId, channelSecret, environment) {
        this.channel_type = 'linepay';
        this.environment = environment;
        //channel id
        this.channel_id = channelId;
        //channel secret key
        this.channel_secret = channelSecret;
        //url地址
        this.url = globalConfig.pay.linepay.url;
        //默认货币
        this.currency = 'TWD';

        //代收创建订单地址
        this.payOrderCreateUrl = `/v3/payments/request`;
        //代收查询订单地址
        this.payOrderQueryUrl = `/qpayorder`;
        //代收同步回调地址
        this.payReturnUrl = `${globalConfig.pay.notify_domain}/callback/linepay/paySync`;
        //代收取消回调地址
        this.payCancelUrl = `${globalConfig.pay.notify_domain}/callback/linepay/payCancelSync`;
        //代收异步回调地址
        this.payNotifyUrl = `${globalConfig.pay.notify_domain}/callback/linepay/payAsync`;
    }

    /**
     * 代收创建订单
     * @param data
     * @returns {Promise<{}>}
     */
    async createPayOrder(data = {}) {
        const nonce = uuid.v4();
        const headers = {
            "Content-Type": "application/json",
            "X-LINE-ChannelId": this.channel_id,
            "X-LINE-Authorization-Nonce": nonce,
        };
        const params = {
            amount: data.amount,
            currency: data.currency || this.currency,
            orderId: data.merOrderNo,
            packages: [
                {
                    id: 1,
                    amount: data.amount,
                    name: 'goods',
                    products: [
                        {
                            name: 'goods1',
                            quantity: 1,
                            price: data.amount,
                        }
                    ],
                }
            ],
            redirectUrls: {
                confirmUrl: this.payNotifyUrl,
                confirmUrlType: 'SERVER',
                cancelUrl: this.payCancelUrl,//使用者通過LINE付款頁，取消付款後跳轉到該URL
            },
            options: {
                payment: {
                    //是否自動請款
                    // true(預設)：呼叫Confirm API，統一進行授權/請款處理
                    // false：呼叫Confirm API只能完成授權，需要呼叫Capture API完成請款
                    capture: true,
                    payType: 'NORMAL',//一般付款
                },
                display: {
                    // checkConfirmUrlBrowser: true,
                    locale: 'zh-TW'
                }
            }
        };
        headers['X-LINE-Authorization'] = (this.paySign(this.payOrderCreateUrl, {...params}, this.channel_secret, nonce)).sign;
        common.writeLog(`channel: ${this.channel_type}, environment: ${this.environment} createPaymentOrder headers: ${JSON.stringify(headers)}, param: ${JSON.stringify(params)}`);
        const result = await httpRequest.post(`${this.url}${this.payOrderCreateUrl}`, params, headers);
        common.writeLog(`channel: ${this.channel_type}, environment: ${this.environment} createPaymentOrder response: ${JSON.stringify(result)}`);
        return result;
    }

    /**
     * 调用confirm api
     * @param data
     * @returns {Promise<*>}
     */
    async callConfirmApi(data = {}) {
        const nonce = uuid.v4();
        const headers = {
            "Content-Type": "application/json",
            "X-LINE-ChannelId": this.channel_id,
            "X-LINE-Authorization-Nonce": nonce,
        };
        const params = {
            amount: data.amount,
            currency: data.currency || this.currency,
        }
        const confirmApiUrl = `/v3/payments/${data.transactionId}/confirm`;
        headers['X-LINE-Authorization'] = (this.paySign(confirmApiUrl, {...params}, this.channel_secret, nonce)).sign;
        common.writeLog(`channel: ${this.channel_type}, environment: ${this.environment} callConfirmApi headers: ${JSON.stringify(headers)}, param: ${JSON.stringify(params)}`);
        const result = await httpRequest.post(`${this.url}${confirmApiUrl}`, params, headers);
        // const result = {
        //     "status":0,
        //     "statusCode":200,
        //     "msg":"ok",
        //     "data":{
        //         "returnCode":"0000",
        //         "returnMessage":"Success.",
        //         "info":{
        //             "transactionId":2024071902161907000,
        //             "orderId":"11721382939652869477",
        //             "payInfo":[
        //                 {"method":"CREDIT_CARD","amount":10,"maskedCreditCardNumber":"************1111"}
        //             ],
        //             "packages":[
        //                 {
        //                     "id":"1",
        //                     "amount":10,
        //                     "userFeeAmount":0,
        //                     "products":[
        //                         {"name":"goods1","quantity":1,"price":10}
        //                     ]
        //                 }
        //             ]
        //         }
        //     }
        // }
        common.writeLog(`channel: ${this.channel_type}, environment: ${this.environment} callConfirmApi response: ${JSON.stringify(result)}`);
        return result;
    }

    /**
     * 确认支付订单状态
     * @param data
     * @returns {Promise<{}>}
     */
    async checkPaymentStatus(data = {}) {
        const nonce = uuid.v4();
        const headers = {
            "Content-Type": "application/json",
            "X-LINE-ChannelId": this.channel_id,
            "X-LINE-Authorization-Nonce": nonce,
        };
        const checkPaymentStatusApiUrl = `/v3/payments/requests/${data.transactionId}/check`;
        headers['X-LINE-Authorization'] = (this.paySign(checkPaymentStatusApiUrl, {}, this.channel_secret, nonce)).sign;
        const requestUrl = `${this.url}${checkPaymentStatusApiUrl}`;
        console.log(`channel: ${this.channel_type}, environment: ${this.environment} checkPaymentStatus url: ${requestUrl} headers: ${JSON.stringify(headers)}`);
        const result = await httpRequest.get(requestUrl, {}, headers);
        console.log(`channel: ${this.channel_type}, environment: ${this.environment} checkPaymentStatus response: ${JSON.stringify(result)}`);
        return result;
    }

    /**
     * 签名
     * @param requestUri
     * @param data
     * @param channelSecret
     * @param nonce
     * @returns {{sign: string, signStr: string}}
     */
    paySign(requestUri, data, channelSecret, nonce) {
        const paramsString = Object.keys(data).length === 0 ? `${channelSecret}${requestUri}${nonce}` : `${channelSecret}${requestUri}${JSON.stringify(data)}${nonce}`;
        const signature = this.encrypt(channelSecret, paramsString);
        console.log(`Sign params string: ${paramsString}`);
        console.log(`Encrypted signature: ${signature}`);
        return {
            signStr: paramsString,
            sign: signature
        }
    }

    /**
     * 加密
     * @param key
     * @param data
     * @returns {string}
     */
    encrypt(key, data) {
        const hmac = crypto.createHmac('sha256', key);
        hmac.update(data);
        return hmac.digest('base64');
    }
}

module.exports = Linepay;