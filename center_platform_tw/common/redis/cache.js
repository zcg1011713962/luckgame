/**
 * 缓存
 */
const redis = require('./cache_redis');

class cache {
    /**
     * 全局缓存
     */
    constructor() {
        this._cache = new Map();
        // 缓存类型
        this._type = 'redis';
    }

    /**
     * 添加
     * @param key
     * @param value
     * @param time 秒
     * @returns {*}
     */
    sets(key, value, time) {
        if (typeof time !== 'undefined' && (typeof time !== 'number' || isNaN(time) || time <= 0)) {
            return false;
        }
        switch (this._type) {
            case 'memory':
                const record = {
                    value: value,
                    expire: time + Date.now()
                };
                if (!isNaN(record.expire)) {
                    setTimeout(() => {
                        this._cache.delete(key);
                    }, time);
                }
                this._cache.set(key, record);
                break;
            case 'redis':
                const val = typeof value === 'object' ? JSON.stringify(value) : value;
                redis.sets(key, val, time);
                break;
        }
        return true;
    };

    /**
     * 获取
     * @param key
     * @returns {null|*}
     */
    async gets(key) {
        if (this._type === 'memory') {
            if (this._cache.has(key)) {
                const data = this._cache.get(key);
                if (typeof data != "undefined") {
                    if (isNaN(data.expire) || data.expire >= Date.now()) {
                        return data.value;
                    } else {
                        this._cache.delete(key);
                    }
                }
            }
        } else if (this._type === 'redis') {
            const val = await redis.gets(key);
            return this.isJson(val) ? JSON.parse(val) : val;
        }
        return null;
    };

    /**
     * 删除
     * @param key
     * @returns {boolean}
     */
    del(key) {
        switch (this._type) {
            case 'memory':
                if (this._cache.has(key)) {
                    return this._cache.delete(key);
                }
                break;
            case 'redis':
                redis.del(key);
        }
        return true;
    }

    hget(key, k) {
        return redis.hget(key, k);
    }

    hmset(key, k, v) {
        return redis.hmset(key, k, v);
    }

    /**
     * JSON判断
     * @param str
     * @returns {boolean}
     */
    isJson(str) {
        try {
            JSON.parse(str);
            return true;
        } catch (error) {
            console.log(`Not JSON: ${str}`);
            return false;
        }
    }
}

module.exports = new cache();