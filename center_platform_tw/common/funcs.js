/**
 * 公共函数
 * FileName:funcs.js
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
module.exports = {
    /**
     * 获取时间戳
     * @param date 日期：2023/02/11 13：49：55
     * @param num 当前日期的前或后推几天/小时/分钟/秒
     * @param type d天/h小时/m分钟/s秒
     * @returns {string}
     */
    timestamps: (date = '', num = 0, type = 'd') => {
        let today;
        if (!date) {
            today = (new Date()).getTime();
        } else {
            today = (new Date(date)).getTime();
        }
        let result;
        if (!num) {
            num = parseInt(num);
            if (type === 'h') {
                result = today + 3600 * num * 1000;
            } else if (type === 'm') {
                result = today + 60 * num * 1000;
            } else if (type === 's') {
                result = today + num * 1000;
            } else {
                result = today + 3600 * 24 * num * 1000;
            }
        } else {
            result = today;
        }
        return result;
    },
    /**
     * 根据时间戳获取日期
     * @param stamps 毫秒级时间戳
     * @param date 返回日期
     * @param time 返回时间
     * @param link 日期链接符
     * @param has_minutes 是否保留分
     * @param has_second 是否保留秒
     * @param time_link 时间链接符
     * @returns {string}
     */
    datestamps: (stamps = 0, date = true, time = true, link = "/", has_minutes = true, has_second = true, time_link = ":") => {
        if (!stamps) {
            stamps = Date.now();
        }
        let now = new Date(stamps);
        let result = '';
        if (date) {
            result += now.getFullYear() + link
                + (((now.getMonth() + 1).toString().length === 1) ? ('0' + (now.getMonth() + 1)) : (now.getMonth() + 1)) + link
                + ((now.getDate().toString().length === 1) ? ('0' + now.getDate()) : now.getDate());
        }
        if (time) {
            if (date && time_link) result += ' ';
            let hours = now.getHours();
            if (hours.toString().length === 1) {
                hours = '0' + hours;
            }
            if (has_minutes) {
                let minutes = now.getMinutes();
                if (minutes.toString().length === 1) {
                    minutes = '0' + minutes;
                }
                if (has_second) {
                    let seconds = now.getSeconds();
                    if (seconds.toString().length === 1) {
                        seconds = '0' + seconds;
                    }
                    result += hours + time_link + minutes + time_link + seconds;
                } else {
                    result += hours + ':' + minutes + time_link + '00';
                }
            } else {
                result += hours + time_link + '00' + time_link + '00';
            }
        }
        return result;
    },
    /**
     * @name 返回一个没有连接符的日期字符串 eg:20220728120117
     * @param timeStamps
     * @param hasTime
     * @date 2023/02/11 12:01:32
     * @return string
     */
    timeWithoutLink(timeStamps = 0, hasTime = true) {
        if (hasTime) {
            return this.datestamps(timeStamps, true, true, '', true, true, '');
        } else {
            return this.datestamps(timeStamps, true, false, '');
        }
    },
    /**
     * md5加密
     * @param {*} value
     * @returns
     */
    encryptMd5: (value) => {
        return crypto.createHash('md5').update(value).digest('hex');
    },
    /**
     * base64编码
     * @param str
     * @returns {string}
     */
    base64Encode(str) {
        return Buffer.from(str).toString('base64');
    },
    /**
     * base64解码
     * @param str
     * @returns {string}
     */
    base64Decode(str) {
        return Buffer.from(str, 'base64').toString();
    },
    /**
     * 是否是对象
     * @param obj
     * @returns {boolean}
     */
    isObject(obj = {}) {
        return (obj?.constructor ?? '') === Object;
    },
    /**
     * 生成随机字符串函数
     */
    randomString(length) {
        const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        return Array.from({length}, () => chars.charAt(Math.floor(Math.random() * chars.length))).join('');
    },

    /**
     * 生成随机数的函数
     * @param m
     * @param n
     * @returns {null|*}
     */
    randomNumber(m, n) {
        // 检查参数合法性
        if (m >= n) {
            console.error(`Error: Invalid range. The second parameter (n = ${n}) must be greater than the first parameter (m = ${m}).`);
            return 0;
        }
        // 生成随机数
        return Math.floor(Math.random() * (n - m + 1)) + m;
    },

    /**
     * 小写字母
     * @param length
     * @returns {string}
     */
    randomLowerString(length = 7) {
        const chars = 'abcdefghijklmnopqrstuvwxyz';
        return Array.from({length}, () => chars.charAt(Math.floor(Math.random() * chars.length))).join('');
    },

    /**
     * 清空文件夹
     * @param folderPath
     */
    clearFolder(folderPath) {
        // 获取文件夹内的所有文件和子文件夹
        const files = fs.readdirSync(folderPath);
        // 遍历并删除所有文件和子文件夹
        files.forEach(file => {
            const filePath = path.join(folderPath, file);
            if (fs.lstatSync(filePath).isDirectory()) {
                // 如果是子文件夹，递归清空
                this.clearFolder(filePath);
            } else {
                // 如果是文件，直接删除
                fs.unlinkSync(filePath);
            }
        });
        // 删除空文件夹
        fs.rmdirSync(folderPath);
    },

    /**
     * 首字母大写
     * @param str
     * @returns {string}
     */
    upFirstLetter(str) {
        return str.charAt(0).toUpperCase() + str.slice(1);
    },
    /**
     * 生成n个不重复的随机数
     * @param n
     * @param min
     * @param max
     * @returns {any[]|*[]}
     */
    genUniqueRandomNumbers(n, min, max) {
        if (n > (max - min + 1) || max < min) {
            return [];
        }
        const uniqueNumbers = new Set();
        while (uniqueNumbers.size < n) {
            const randomNumber = Math.floor(Math.random() * (max - min + 1)) + min;
            uniqueNumbers.add(randomNumber);
        }
        return Array.from(uniqueNumbers);
    },
    /**
     * 删除文件夹
     * @param folderPath
     */
    deleteFolderRecursive(folderPath) {
        if (fs.existsSync(folderPath)) {
            fs.readdirSync(folderPath).forEach((file, index) => {
                const curPath = path.join(folderPath, file);
                if (fs.lstatSync(curPath).isDirectory()) { // 是文件夹
                    this.deleteFolderRecursive(curPath); // 递归删除文件夹
                } else { // 是文件
                    fs.unlinkSync(curPath); // 删除文件
                }
            });
            fs.rmdirSync(folderPath); // 删除文件夹本身
            console.log(`Deleted folder: ${folderPath}`);
        }
    },
    /**
     * 生成商户订单号
     * @returns {*}
     */
    generateMerOrderNo(appId = '') {
        let orderNo = `${appId.toString()}${Date.now().toString()}`;
        const num = 20 - orderNo.length;
        if (num > 0) {
            orderNo += this.generateRandomNumber(num);
        }
        return orderNo;
    },
    /**
     * 生成随机数
     * @param num
     * @returns {number}
     */
    generateRandomNumber(num) {
        // 生成随机数的最小值和最大值
        const min = Math.pow(10, num - 1); // 位数为 num 的最小值
        const max = Math.pow(10, num) - 1; // 位数为 num 的最大值

        // 生成随机数
        return Math.floor(Math.random() * (max - min + 1)) + min;
    },


    /**
     * 生成随机字符串函数
     */
    randomStringLower(length) {
        const chars = 'abcdefghijklmnopqrstuvwxyz';
        return Array.from({length}, () => chars.charAt(Math.floor(Math.random() * chars.length))).join('');
    },
    /**
     *
     * @param probabilities
     * @returns {number}
     */
    rechargeChannel(probabilities = []) {
        const randomNumber = Math.random();
        if (probabilities.length > 0) probabilities = probabilities.map(parseFloat);
        console.log(`probabilities: ${JSON.stringify(probabilities)}, rechargeChannel: ${randomNumber}`);
        let sum = 0;
        let rand = 0;
        if (probabilities.length > 0) {
            for (let i = 0; i < probabilities.length; i++) {
                sum += probabilities[i];
                if (randomNumber < sum) {
                    rand = i;
                    break;
                }
            }
        }
        return rand;
    },
    /**
     * url地址是否是https
     * @param urlString
     * @returns {boolean}
     */
    isHttps(urlString) {
        // 解析 URL
        const parsedUrl = new URL(urlString);
        // 判断协议是否为 HTTPS
        return parsedUrl.protocol === 'https:';
    },
    /**
     * 除以100
     * @param val
     * @returns {number|string}
     */
    divideHundred(val) {
        return val % 100 === 0 ? val / 100 : parseFloat(val / 100).toFixed(2);
    },
    /**
     * 是否是json字符串
     * @param str
     * @returns {boolean}
     */
    isJson(str) {
        try {
            JSON.parse(str);
            return true;
        } catch (error) {
            return false;
        }
    },
    /**
     * 今日零点时间戳
     */
    zeroTimestamps() {
        // 创建一个表示当前日期的 Date 对象
        const today = new Date();
        // 将时间设置为零点
        today.setHours(0, 0, 0, 0);
        // 获取零点时间戳
        return today.getTime();
    },
    /**
     * 回调签名
     * @param merOrderNo
     * @param salt
     * @returns {string}
     */
    callbackSign(merOrderNo = '', salt = 'dgfj364#$%^&hhyy%%') {
        return this.encryptMd5(`${merOrderNo}${salt}`);
    },
    /**
     * 当前秒级时间戳
     * @returns {number}
     */
    nowTime() {
        return parseInt(Date.now() / 1000);
    },
    /**
     * 16位以上的数字处理成字符串
     * @param text
     * @returns {string|*}
     */
    handleBigInteger(text) {
        if (typeof text == 'string') {
            const largeNumberRegex = /:\s*(\d{16,})\b/g;
            return text.replace(largeNumberRegex, ': "$1"');
        }
        return text;
    }
};