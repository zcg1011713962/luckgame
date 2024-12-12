/**
 * Redis缓存
 */
const redis = require('./redis_util');

class cacheRedis {

    /**
     * 添加
     * @param key
     * @param value
     * @param time
     * @returns {*}
     */
    sets(key, value, time) {
        redis.client.set(key, value, 'EX', time);
    };

    /**
     * 获取
     * @param key
     * @returns {null|*}
     */
    gets(key) {
        return new Promise((resolve) => {
            redis.client.get(key, (err, resp) => {
                resolve(resp);
            });
        });
    };

    /**
     * 删除
     * @param key
     * @returns {boolean}
     */
    del(key) {
        redis.client.del(key);
    }

    hget(key, k) {
        return redis.hget(key, k);
    }

    hmset(key, k, v) {
        return redis.hmset(key, k, v);
    }
}

module.exports = new cacheRedis();