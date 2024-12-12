local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson   = require "cjson"
local player_tool = require "base.player_tool"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

--订单定时发货处理

--! 发货队列
local ORDERS_QUEUE = {}

--! 接口函数
local CMD    = {}

local function jobs()
    local now = os.time()
    local cointype = PDEFINE.ALTERCOINTAG.SHOP_RECHARGE
    local gameid = PDEFINE.GAME_TYPE.SPECIAL.STORE_BUY
    local sendcoin= 0
    for k, order in pairs(ORDERS_QUEUE) do

        local orderid = tostring(order.orderid)

        local uid     = order.uid
        local coin = order.coin
        --更新订单
        local sql = string.format("update s_shop_order set count=count+%.2f,notify_time=%d,update_time=%d,sendcoin=%.2f where orderid='%s'", sendcoin, now, now, sendcoin, orderid)
        LOG_INFO(" pay.deliverOrder:", uid, orderid, coin, " sql:", sql)
        skynet.call(".mysqlpool", "lua", "execute", sql)

        --给玩家加金币
        local code, before_coin, after_coin = player_tool.funcAddCoin(uid, coin, "商城购买", cointype, gameid, PDEFINE.POOL_TYPE.none, nil, nil)
        if code ~= PDEFINE.RET.SUCCESS then
            LOG_ERROR("发货队列 失败", code, " uid", uid, ' coin', coin, ' orderid:', orderid)
        else
            ORDERS_QUEUE[k] = nil
        end

        --下发协议
        local ok, agent = pcall(skynet.call, '.userCenter', "lua", "getAgent", order.uid)
        -- LOG_INFO("发货队列, 开始发货通知：", order.uid, order.orderid, order.coin, order.shopid, " 获取agent:",ok, agent)
        if ok and agent then
            local ok , result = pcall(cluster.call, agent.server, agent.address, "clusterModuleCall", "pay", "deliverOrder", order.uid, order.orderid, order.coin, order.shopid)
            LOG_INFO(order.orderid, "发货队列, 发货结果：", ok, result)
        end
    end
end
-------- 订单发货(每秒1次) --------
local function deliver()
    while true do
        jobs()
        skynet.sleep(100)
    end
end

--商城中，每满5单，赠送礼盒
function CMD.sendGift(uid, coin)
    local cointype = PDEFINE.ALTERCOINTAG.SHOP_GIFT
    local gameid = PDEFINE.GAME_TYPE.SPECIAL.STORE_SEND
    local code, before_coin, after_coin = player_tool.funcAddCoin(uid, coin, "商城赠送", cointype, gameid, PDEFINE.POOL_TYPE.none, nil, nil)
    if code ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("订单赠送礼盒金币 失败", code, " uid", uid, ' coin', coin)
    end
    return code, before_coin, after_coin
end

-------- 待发货订单加入队列 --------
function CMD.addQueue(uid, orderid, coin, shopid)
    local exists  = false
    for _, row in pairs(ORDERS_QUEUE) do
        if row.orderid == orderid then
            LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), "发货队列, 已存在：", orderid, " vs ", row.orderid)
            exists = true
            break
        end
    end
    if not exists then
        local order = {}
        order["uid"]     = uid
        order["orderid"] = orderid
        order["coin"]    = coin
        order["shopid"]    = shopid

        table.insert(ORDERS_QUEUE, order)
        LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()),  "发货队列, 加入发货队列：", uid, orderid, coin, shopid)
    else
        LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()),  "发货队列, 已存在发货队列中", uid, orderid, coin, shopid)
    end

    return PDEFINE.RET.SUCCESS
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)

    skynet.fork(deliver)

    skynet.register(".orderdeliver")
end)