/**
 * request.js
 */

const request = require('request');
const querystring = require('querystring');

module.exports = {
    post: (url, params = {}, headers = {}) => {
        return new Promise((resolve, reject) => {
            request.post({url: url, headers: headers, form: params}, (error, response, body) => {
                let result = {code: response?.statusCode ?? 500, data: body ?? {}};
                if (!error) {
                    if (typeof body == "object") {
                        resolve([true, result]);
                    } else {
                        try {
                            resolve([true, {code: response.statusCode, data: JSON.parse(body)}]);
                        } catch (e) {
                            resolve([true, {code: response.statusCode, data: body}]);
                        }
                    }
                } else {
                    console.error(url, 'request error!', JSON.stringify(error));
                    resolve([false, error]);
                }
            });
        });
    },
    jsonPost: (url, jsonData = {}, headers = {}) => {
        return new Promise((resolve, reject) => {
            request.post({url: url, headers: headers, json: jsonData}, (error, response, body) => {
                let result = {code: response?.statusCode ?? 500, data: body ?? {}};
                if (!error) {
                    if (typeof body == "object") {
                        resolve([true, result]);
                    } else {
                        try {
                            resolve([true, {code: response.statusCode, data: JSON.parse(body)}]);
                        } catch (e) {
                            resolve([true, {code: response.statusCode, data: body}]);
                        }
                    }
                } else {
                    console.error(url, 'request error!', JSON.stringify(error));
                    resolve([false, error]);
                }
            });
        });
    },
    get: (url, params = {}, headers = {}) => {
        return new Promise((resolve, reject) => {
            request.get({url: url + '?' + querystring.stringify(params), headers}, (error, response, body) => {
                let result = {code: response?.statusCode ?? 500, data: body ?? {}};
                if (!error) {
                    if (typeof body == "object") {
                        resolve([true, result]);
                    } else {
                        try {
                            resolve([true, {code: response.statusCode, data: JSON.parse(body)}]);
                        } catch (e) {
                            resolve([true, {code: response.statusCode, data: body}]);
                        }
                    }
                } else {
                    console.error(url, 'request error!', JSON.stringify(error));
                    resolve([false, error]);
                }
            })
        });
    },
    put: (url, params = {}) => {
        return new Promise((resolve, reject) => {
            request.put({url: url, form: params}, (error, response, body) => {
                let result = {code: response?.statusCode ?? 500, data: body ?? {}};
                if (!error) {
                    if (typeof body == "object") {
                        resolve([true, result]);
                    } else {
                        try {
                            resolve([true, {code: response.statusCode, data: JSON.parse(body)}]);
                        } catch (e) {
                            resolve([true, {code: response.statusCode, data: body}]);
                        }
                    }
                } else {
                    console.error(url, 'request error!', JSON.stringify(error));
                    resolve([false, error]);
                }
            });
        });
    },
    delete: (url, params = {}) => {
        return new Promise((resolve, reject) => {
            request.delete(url + '?' + querystring.stringify(params), params, (error, response, body) => {
                let result = {code: response?.statusCode ?? 500, data: body ?? {}};
                if (!error) {
                    if (typeof body == "object") {
                        resolve([true, result]);
                    } else {
                        try {
                            resolve([true, {code: response.statusCode, data: JSON.parse(body)}]);
                        } catch (e) {
                            resolve([true, {code: response.statusCode, data: body}]);
                        }
                    }
                } else {
                    console.error(url, 'request error!', JSON.stringify(error));
                    resolve([false, error]);
                }
            })
        });
    },
    head: (url, params = {}) => {
        return new Promise((resolve, reject) => {
            request.head(url + '?' + querystring.stringify(params), (error, response, body) => {
                let result = {code: response?.statusCode ?? 500, data: body ?? {}};
                if (!error) {
                    if (typeof body == "object") {
                        resolve([true, result]);
                    } else {
                        try {
                            resolve([true, {code: response.statusCode, data: JSON.parse(body)}]);
                        } catch (e) {
                            resolve([true, {code: response.statusCode, data: body}]);
                        }
                    }
                } else {
                    console.error(url, 'request error!', JSON.stringify(error));
                    resolve([false, error]);
                }
            })
        });
    },
    options: (url, params = {}) => {
        return new Promise((resolve, reject) => {
            request({url: url + '?' + querystring.stringify(params), method: 'OPTIONS'}, (error, response, body) => {
                let result = {code: response?.statusCode ?? 500, data: body ?? {}};
                if (!error) {
                    if (typeof body == "object") {
                        resolve([true, result]);
                    } else {
                        try {
                            resolve([true, {code: response.statusCode, data: JSON.parse(body)}]);
                        } catch (e) {
                            resolve([true, {code: response.statusCode, data: body}]);
                        }
                    }
                } else {
                    console.error(url, 'request error!', JSON.stringify(error));
                    resolve([false, error]);
                }
            })
        });
    }
};
