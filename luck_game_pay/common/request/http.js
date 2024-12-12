/**
 * http.js
 */
const http = require('http');
const https = require('https');
const querystring = require('querystring');

module.exports = {
    /**
     * 发起 HTTP GET 请求
     * @param {string} url 请求的URL
     * @param {object} params 请求参数对象
     * @param {object} headers 请求头对象
     * @param {object} timeout 超时时间
     * @returns {Promise} 返回一个 Promise 对象
     */
    get(url, params = {}, headers = {}, timeout = 0) {
        const result = {
            status: Const.RESULT_STATUS.SUCCESS,
            msg: 'ok',
            data: {}
        }
        const isHttps = funcs.isHttps(url);
        const reqMethod = isHttps ? https : http;
        // 将参数拼接到 URL 中
        const queryString = querystring.stringify(params);
        const fullUrl = url + (queryString ? '?' + queryString : '');
        // 请求的选项对象，包括请求头
        const options = {
            headers: headers
        };
        return new Promise((resolve) => {
            // 发起 GET 请求
            const req = reqMethod.get(fullUrl, options, (res) => {
                let data = '';
                // 接收到数据时触发
                res.on('data', (chunk) => {
                    data += chunk;
                });
                // 接收完全部数据时触发
                res.on('end', () => {
                    result.data = funcs.isJson(data) ? JSON.parse(data) : data;
                    resolve(result);
                });
            }).on('error', (error) => {
                console.error(`Http request error: ${url}, param: ${JSON.stringify(params)}`, error);
                result.status = Const.RESULT_STATUS.ERROR;
                result.msg = `Http request error: ${error.toString()}`;
                resolve(result);
            });
            if (timeout > 0) {
                // 设置超时时间
                req.setTimeout(timeout, () => {
                    console.error(`Http request timeout: ${url}, param: ${JSON.stringify(params)}`);
                    result.status = Const.RESULT_STATUS.TIMEOUT;
                    result.msg = 'request timeout';
                    resolve(result);
                });
            }
        });
    },
    /**
     * 发起 HTTP POST 请求
     * @param {string} url 请求的URL
     * @param {object} data POST 请求的数据
     * @param {object} options 其他请求选项，例如请求头等
     * @returns {Promise} 返回一个 Promise 对象
     */
    post(url, data, options = {}) {
        const result = {
            status: Const.RESULT_STATUS.SUCCESS,
            msg: 'ok',
            data: {}
        }
        return new Promise((resolve) => {
            const postData = JSON.stringify(data);
            // 设置 POST 请求选项
            const requestOptions = Object.assign({}, options, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData),
                }
            });
            // 发起 POST 请求
            const isHttps = funcs.isHttps(url);
            const reqMethod = isHttps ? https : http;
            const req = reqMethod.request(url, requestOptions, (response) => {
                let responseData = '';
                // 将接收到的数据拼接起来
                response.on('data', (chunk) => {
                    responseData += chunk;
                });
                // 请求完成后 resolve 接收到的数据
                response.on('end', () => {
                    result.data = funcs.isJson(responseData) ? JSON.parse(responseData) : responseData;
                    resolve(result);
                });
            });
            // 请求错误处理
            req.on('error', (error) => {
                console.error(`Http request error: ${url}, param: ${JSON.stringify(data)}`, error);
                result.status = Const.RESULT_STATUS.ERROR;
                result.msg = error.toString();
                resolve(result);
            });
            // 写入 POST 数据
            req.write(postData);
            req.end();
        });
    },
    /**
     * post form
     * @param url
     * @param params
     * @returns {Promise<>}
     */
    postForm(url, params) {
        const result = {
            status: Const.RESULT_STATUS.SUCCESS,
            msg: 'ok',
            data: {}
        }
        const postData = querystring.stringify(params);
        const options = {
            hostname: url.replace(/^https?:\/\//, '').split('/')[0],
            port: url.startsWith('https') ? 443 : 80,
            path: url.replace(/^https?:\/\/[^/]+/, ''),
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Content-Length': postData.length
            }
        };
        const isHttps = funcs.isHttps(url);
        const reqMethod = isHttps ? https : http;
        return new Promise((resolve, reject) => {
            const req = reqMethod.request(options, (res) => {
                let responseData = '';
                res.on('data', (chunk) => {
                    responseData += chunk;
                });
                res.on('end', () => {
                    result.data = funcs.isJson(responseData) ? JSON.parse(responseData) : responseData;
                    resolve(result);
                });
            });

            req.on('error', (error) => {
                console.error(`Http request error: ${url}, param: ${JSON.stringify(params)}`, error);
                result.status = Const.RESULT_STATUS.ERROR;
                result.msg = error.toString();
                resolve(result);
            });
            req.write(postData);
            req.end();
        });
    },
    /**
     * post form
     * @param url
     * @param params
     * @param timeout 超时时间 单位：毫秒
     * @returns {Promise<{status: number, msg: string, data: any}>}
     */
    posts(url, params, timeout = 0) {
        const result = {
            status: Const.RESULT_STATUS.SUCCESS,
            msg: 'ok',
            data: {}
        }
        const postData = querystring.stringify(params);
        const options = {
            hostname: url.replace(/^https?:\/\//, '').split('/')[0],
            port: url.startsWith('https') ? 443 : 80,
            path: url.replace(/^https?:\/\/[^/]+/, ''),
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Content-Length': postData.length
            }
        };
        const isHttps = funcs.isHttps(url);
        const reqMethod = isHttps ? https : http;
        return new Promise((resolve, reject) => {
            const req = reqMethod.request(options, (res) => {
                let responseData = '';
                res.on('data', (chunk) => {
                    responseData += chunk;
                });
                res.on('end', () => {
                    result.data = funcs.isJson(responseData) ? JSON.parse(responseData) : responseData;
                    resolve(result);
                });
            });

            req.on('error', (error) => {
                console.error(`Http request error: ${url}, param: ${JSON.stringify(params)}`, error);
                result.status = Const.RESULT_STATUS.ERROR;
                result.msg = error.toString();
                resolve(result);
            });
            if (timeout > 0) {
                // 设置超时时间
                req.setTimeout(timeout, () => {
                    console.error(`Http request timeout: ${url}, param: ${JSON.stringify(params)}`);
                    result.status = Const.RESULT_STATUS.TIMEOUT;
                    result.msg = 'request timeout';
                    resolve(result);
                });
            }
            req.write(postData);
            req.end();
        });
    },
    /**
     * post json
     * @param url
     * @param params
     * @param headers
     * @returns {Promise<>}
     */
    postJson(url, params, headers = {}) {
        const result = {
            status: Const.RESULT_STATUS.SUCCESS,
            msg: 'ok',
            data: {}
        }
        const postData = JSON.stringify(params);
        const options = {
            hostname: url.replace(/^https?:\/\//, '').split('/')[0],
            port: url.startsWith('https') ? 443 : 80,
            path: url.replace(/^https?:\/\/[^/]+/, ''),
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': postData.length
            }
        };
        if (Object.keys(headers).length > 0) {
            Object.assign(options.headers, headers);
        }
        const isHttps = funcs.isHttps(url);
        const reqMethod = isHttps ? https : http;
        return new Promise((resolve, reject) => {
            const req = reqMethod.request(options, (res) => {
                let responseData = '';
                res.on('data', (chunk) => {
                    responseData += chunk;
                });
                res.on('end', () => {
                    result.data = funcs.isJson(responseData) ? JSON.parse(responseData) : responseData;
                    resolve(result);
                });
            });

            req.on('error', (error) => {
                console.error(`Http request error: ${url}, param: ${JSON.stringify(params)}`, error);
                result.status = Const.RESULT_STATUS.ERROR;
                result.msg = error.toString();
                resolve(result);
            });
            req.write(postData);
            req.end();
        });
    },
}
