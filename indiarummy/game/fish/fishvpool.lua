local stgy = require "stgy"
local GAME_ID = require "fish.fishgameid"


local VPOOL_AMOUNT_REDIS_KEY = "fishvpool:amount:"
local VPOOL_TAX_REDIS_KEY = "fishvpool:total_tax:"

local fishvpool = {}

-- 启动游戏服时调用
function fishvpool.init()
    stgy.vp_set_tax_rate(0.02)  --抽水率

    for id = GAME_ID.MIN_ID, GAME_ID.MAX_ID do
        -- 设置波动周期范围
        stgy.vp_set_wave_period(id, 1000, 2000)
        -- 设置波动调整百分比范围
        stgy.vp_set_wave_scope(id, 10)
        -- 设置随机调整百分比范围
        stgy.vp_set_rand_scope(id, 8)
        -- 设置水池切换频率范围
        stgy.vp_set_switch_freq(id, 2000, 4000)
        -- 设置增加概率的起始阈值
        stgy.vp_set_raise_threshold(id, 100000, 500000)
        -- 设置降低概率的起始阈值
        stgy.vp_set_reduce_threshold(id, -10000, -50000)
        -- 设置池子数量
        stgy.vp_set_pool_count(id, 1)
    end
end

-- 水池数据从redis加载
function fishvpool.load_all_data()
    for id = GAME_ID.MIN_ID, GAME_ID.MAX_ID do
        local amount = do_redis({"get", VPOOL_AMOUNT_REDIS_KEY..id})
        if amount == nil then
            amount = 0
            do_redis({"set", VPOOL_AMOUNT_REDIS_KEY..id, amount})
        end
        stgy.vp_set_amount(id, tonumber(amount))
        LOG_INFO("load fishvpool data, gameid:", id, "amount:", amount)
    end
end

-- 水池数据保存到redis
function fishvpool.save_data(gameid)
    local amount = stgy.vp_query_amount(gameid)
    do_redis({"set", VPOOL_AMOUNT_REDIS_KEY..gameid, amount})
    local total_tax = stgy.vp_query_total_tax(gameid)
    LOG_INFO("save fishvpool data, gameid:", gameid, "amount:", amount, "total_tax:", total_tax)
end

-- 水池数据保存到redis
function fishvpool.save_all_data(close_server)
    for id = GAME_ID.MIN_ID, GAME_ID.MAX_ID do
        fishvpool.save_data(id)
    end
end


return fishvpool
