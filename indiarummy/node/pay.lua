local pay = {}
local handle
local skynet = require "skynet"
local queue = require "skynet.queue"
local cjson = require "cjson"
local cluster = require "cluster"
local player_tool = require "base.player_tool"
local jsondecode = cjson.decode
local cs = queue()
local DEBUG = skynet.getenv("DEBUG") or nil  -- 是否是调试阶段
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local UID
local UNIT_STRING = '$'

local FREE_TIME_PREFIX = 'shop_free:'

-- 获取免费领取标记的倒计时
local function getFreeTime(uid, rtype)
    local cacheKey = FREE_TIME_PREFIX .. uid .. rtype
    local leftTime = do_redis( {"ttl", cacheKey})
    leftTime = tonumber(leftTime or 0)
    if leftTime < 0 then
        leftTime = 0
    end
    return leftTime
end

-- 记录免费获取的时间
local function cacheFreeGetTime(uid, rtype)
    local cacheKey = FREE_TIME_PREFIX .. uid .. rtype
    do_redis( {"set", cacheKey, 1})
    local leftTime = getThisPeriodTimeStamp()
    if DEBUG then
        leftTime = 30
    end
    do_redis( {"expire", cacheKey, leftTime}) 
end

local function getShopList(stype, isReview)
    local ok, tmplist = pcall(cluster.call, "master", ".shopmgr", "getShopList", nil, isReview)
    if ok then
        return tmplist[stype]
    end
    return {}
end

--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

function pay.initUid(uid)
    UID = uid
end

function pay.init(uid)
    UID = uid
end

function pay.bind(agent_handle)
    handle = agent_handle
end

function pay.getFreeTime(uid, rtype)
    return getFreeTime(uid, rtype)
end

--添加首次购买记录
local function addFirstBuyLog(uid, productid, stype, shopid)
    local sql = string.format( "select * from d_user_firstbuy where uid=%d and shopid=%d", uid, shopid)
    local hadbuy = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #hadbuy == 0 then
        sql = string.format( "insert into d_user_firstbuy(uid,shopid, product_id,create_time,stype) values(%d,%d,'%s',%d,%d)", uid, shopid, productid, os.time(), stype)
        LOG_DEBUG("addFirstBuyLog:", sql)
        skynet.call(".mysqlpool", "lua", "execute", sql)
    end
    -- 商城订单，首次购买的标记 记录到用户身上
    if stype == PDEFINE.SHOPSTYPE.DIAMOND then
        local first_list = handle.dcCall("user_dc", "getvalue", uid, "firstbuylist") --已首次购买的shopid列表
        if nil == first_list or "" == first_list then
            first_list = {}
        else
            local ok
            ok, first_list = pcall(jsondecode, first_list)
        end
        if type(first_list) == 'table' then
            if #first_list > 0 then
                if not table.contain(first_list, shopid) then
                    table.insert(first_list, shopid)
                end
            else
                table.insert(first_list, shopid)
            end
        else
            first_list = {}
        end
        handle.dcCall("user_dc", "setvalue", uid, "firstbuylist", cjson.encode(first_list))
    end
end

-- 修改订单状态为已支付
local function changeOrderStatus(orderid, now, agentno, token, uid, amount)
    local sql = string.format("update s_shop_order set status=%d,pay_time=%d,update_time=%d where orderid='%s'", PDEFINE.ORDER_STATUS.PAID, now, now, orderid)
    if agentno ~= nil then
        local paytoken = token or '' --记录谷歌支付验证的token
        sql = string.format( "update s_shop_order set status=%d,pay_time=%d,update_time=%d, agentno='%s',token='%s' where orderid='%s'",PDEFINE.ORDER_STATUS.PAID,now, now, agentno, paytoken,orderid)
    end
    LOG_INFO(
        os.date("%Y-%m-%d %H:%M:%S", os.time()),
        " pay.ipayVerify updateOrder:",
        UID,
        orderid,
        agentno,
        " sql:",
        sql
    )
    local ret = skynet.call(".mysqlpool", "lua", "execute", sql)
    local totalSql = string.format("update d_user set totalpay = totalpay + %f where uid=%d", amount, uid)
    do_mysql_queue(totalSql)
    return ret
end

local function getShopInfo(id)
    local shopInfo
    local sql = string.format("select * from s_shop where id='%s' limit 1", id)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        shopInfo = rs[1]
    end
    return shopInfo
end

-- 赠送权益
local function sendBenefit(shopid, compress)
    local shopInfo = getShopInfo(shopid)
    local ok, prizetbl = pcall(jsondecode, shopInfo.prize)
    local rewards = {}
    if ok then
        for _, item in pairs(prizetbl) do --奖励
            if item.s == PDEFINE.PROP_ID.DIAMOND then
                handle.addProp(item.s, item.n, 'shop', nil, 'shop_send_benefit', shopid)
            else
                handle.addProp(item.s, item.n, 'shop')
            end
            
            table.insert(rewards, {
                ['type'] = item.s,
                ['count']= item.n
            })
        end
    end
    return rewards
end

local function orderShipping(orderid, time, istest)
    local sql = string.format("update s_shop_order set status=%d, update_time=%d where orderid='%s'", PDEFINE.ORDER_STATUS.SHIPPING, time, orderid)
    if istest then
        sql = string.format("update s_shop_order set status=%d, update_time=%d, istest=1 where orderid='%s'", PDEFINE.ORDER_STATUS.SHIPPING, time, orderid)
    end
    skynet.call(".mysqlpool", "lua", "execute", sql)
end



--更新订单 加金币
local function updateOrder(uid, orderid, coin, agentno, amount, shopid, level, token, istest)
    return cs(
        function()
            handle.moduleCall("quest", 'updateQuest', uid, PDEFINE.QUEST_TYPE.REPEAT, PDEFINE.QUESTID.DAILY.PAYMENT, 1)
            handle.moduleCall("quest", 'updateQuest', uid, PDEFINE.QUEST_TYPE.NEWER, PDEFINE.QUESTID.NEW.PAYMENT, 1)
            local now = os.time()
            local sql = string.format("select * from s_shop_order where orderid='%s' limit 1", orderid)
            local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
            local rewards = {}
            if #rs == 1 then
                setSendRate(uid, rs[1].shopid)
                amount = rs[1].amount --钱
                if rs[1].status == PDEFINE.ORDER_STATUS.PAID or rs[1].status == PDEFINE.ORDER_STATUS.SHIPPING then
                    LOG_ERROR(string.format("The same orderid %s  verify again.", orderid))
                    local json = {price = rs[1].amount, times = 2}
                    json['orderid'] = orderid
                    return PDEFINE.RET.SUCCESS, cjson.encode(json) --已经支付成功的订单
                end

                orderShipping(orderid, now, istest) --更改订单发货中
                
                if rs[1].stype == PDEFINE.SHOPSTYPE.STORE then --商城订单

                     -- 更新bonus 任务
                    local updateMainObjs = {
                        {kind=PDEFINE.MAIN_TASK.KIND.Pay, count=rs[1].amount},
                    }
                    handle.moduleCall("maintask", "updateTask", uid, updateMainObjs)

                    handle.moduleCall("upgrade","useVipDiamond", rs[1].count) --积累vip经验值

                    pcall(cluster.send, "master", ".userCenter", "AddSuperiorRewards", uid, PDEFINE.TYPE.SOURCE.BUY, rs[1].count)

                elseif rs[1].stype == PDEFINE.SHOPSTYPE.SKINS then
                    LOG_DEBUG("玩家购买皮肤道具: uid:", uid, "count:", rs[1].count)
                    local sql = string.format("select * from s_shop_skin where shopid=%d", rs[1].shopid)
                    local skin = skynet.call(".mysqlpool", "lua", "execute", sql)

                    local leftTime = getTodayLeftTimeStamp()
                    local endtime = 86400 * skin[1].days + leftTime
                    send_timeout_skin(skin[1].img, endtime, uid)

                    local category = PDEFINE.PROP_ID.SKIN_FRAME --头像框
                    if skin[1].category == 2 then
                        category = PDEFINE.PROP_ID.SKIN_CHAT
                    elseif skin[1].category == 3 then
                        category = PDEFINE.PROP_ID.SKIN_TABLE
                    elseif skin[1].category == 4 then
                        category = PDEFINE.PROP_ID.SKIN_POKER
                    end
                    local retobj = {}
                    retobj.c = PDEFINE.NOTIFY.BUY_OK
                    retobj.code = PDEFINE.RET.SUCCESS
                    retobj.uid = uid
                    retobj.diamond = 0
                    retobj.type = 1
                    retobj.shopid = skin[1].shopid
                    retobj.stype = category
                    retobj.rewards = {{type=category, count=1, days=skin[1].days, img=skin[1].img}}
                    handle.sendToClient(cjson.encode(retobj))

                    changeOrderStatus(orderid, now, agentno, token, uid, amount)
                    local json = {price = skin[1].amount,}
                    json['orderid'] = orderid

                    return PDEFINE.RET.SUCCESS, cjson.encode(json)
                elseif rs[1].stype == PDEFINE.SHOPSTYPE.DIAMOND then
                    LOG_DEBUG("玩家购买钻石: uid:", uid, "count:", rs[1].count)
                    addFirstBuyLog(uid, rs[1].productid, rs[1].stype, rs[1].shopid)
                    handle.dcCall("user_dc", "user_addvalue", UID, "diamond", rs[1].count)
                    handle.moduleCall("player", "addDiamondLog", uid, rs[1].count, 0, "shop", "shop_buy_diamond")
                    handle.addDiamondInGame(rs[1].count)
                    rewards = sendBenefit(rs[1].shopid) --根据权益配置进行赠送
                    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)

                    local notifyobj = {}
                    notifyobj.c = PDEFINE.NOTIFY.coin
                    notifyobj.code = PDEFINE.RET.SUCCESS
                    notifyobj.uid = UID
                    notifyobj.deskid = 0
                    notifyobj.count = 0
                    notifyobj.coin = playerInfo.coin
                    notifyobj.diamond = playerInfo.diamond
                    notifyobj.addDiamond = rs[1].count
                    notifyobj.type = 1
                    notifyobj.rewards = rewards
                    handle.sendToClient(cjson.encode(notifyobj))

                    local retobj = {}
                    retobj.c = PDEFINE.NOTIFY.BUY_OK
                    retobj.code = PDEFINE.RET.SUCCESS
                    retobj.uid = uid
                    retobj.diamond = rs[1].count
                    retobj.type = 1
                    retobj.shopid = rs[1].shopid
                    retobj.stype = PDEFINE.SHOPSTYPE.DIAMOND
                    retobj.rewards = {{type=PDEFINE.PROP_ID.DIAMOND, count=rs[1].count}}
                    table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.VIP_POINT, count= rs[1].count})
                    handle.sendToClient(cjson.encode(retobj))

                    handle.moduleCall("upgrade","useVipDiamond", rs[1].count) --积累vip经验值

                    changeOrderStatus(orderid, now, agentno, token, uid, amount)
                    local json = {price = rs[1].amount,}
                    json['orderid'] = orderid

                    -- 更新主线任务
                    -- local updateMainObjs = {
                    --     {kind=PDEFINE.MAIN_TASK.KIND.Pay, count=rs[1].count},
                    -- }
                    -- handle.moduleCall("maintask", "updateTask", uid, updateMainObjs)

                    local msgObj = {
                        title_al = "إشعار شراء",
                        title = 'Purchased Notice',
                        msg_al = "لقد قمت بشراء الماس بنجاح ويمكنك استخدامه في المتجر.",
                        msg = 'You have successfully purchased diamonds and can use them in the store.',
                        attach = {{type=PDEFINE.PROP_ID.DIAMOND, count= rs[1].count}}
                    }
                    handle.sendBuyOrUpGradeEmail(msgObj, PDEFINE.MAIL_TYPE.SHOP)


                    return PDEFINE.RET.SUCCESS, cjson.encode(json)
                elseif rs[1].stype == PDEFINE.SHOPSTYPE.ONETIME then --新人礼包
                    handle.dcCall("user_dc", "setvalue", uid, "isonetime", 1)
                elseif rs[1].stype == PDEFINE.SHOPSTYPE.TIMELIMITED then
                    -- handle.addProp(PDEFINE.PROP_ID.VIP_POINT, rs[1].vipExp) --送经验值

                elseif rs[1].stype == PDEFINE.SHOPSTYPE.MONEYBAG then --金猪
                    addFirstBuyLog(uid, rs[1].productid, rs[1].stype, rs[1].shopid)
                    handle.dcCall("user_dc", "setvalue", uid, "moneybag", 0) --存的金猪里的金币设置为0
                    handle.dcCall("user_dc", "setvalue", uid, "moneybag_time", 0) --存的金猪里的金币设置为0
                    local nextbag = handle.moduleCall("player", "getNextMoneyBag", 0)
                    handle.syncUserInfo({uid=uid, moneybag=0, nextbag=nextbag})
                end
            end

           

            local ret = changeOrderStatus(orderid, now, agentno, token, uid, amount)
            if ret then
                local ok, result = pcall(cluster.call, "master", ".orderdeliver", "addQueue", uid, orderid, coin, shopid)
                LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), uid, " 加入发货队列 返回:", ok, result, orderid)
                if ok and result == 200 then
                    local json = {price = amount, times = 1}
                    json['orderid'] = orderid
                    return PDEFINE.RET.SUCCESS, cjson.encode(json)
                end
            end

            LOG_INFO(
                os.date("%Y-%m-%d %H:%M:%S", os.time()),
                " pay.ipayVerify updateOrder 返回失败:",
                PDEFINE.RET.ERROR.ORDER_PAID_UPDATE_FAILED
            )
            return PDEFINE.RET.ERROR.ORDER_PAID_UPDATE_FAILED
        end
    )
end

-------- 支付发货(由发货队列发送) --------
function pay.deliverOrder(uid, orderid, coin, shopid)
    LOG_DEBUG(" pay.deliverOrder, getdata", uid, orderid, coin, shopid)
    local shopInfo = getShopInfo(shopid)
    local stype = shopInfo.stype
    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    if playerInfo then
        LOG_INFO(" pay.deliverOrder, playerInfo.ispayer", uid, playerInfo.ispayer)
        local addDiamond = 0
        if shopInfo.stype == PDEFINE.SHOPSTYPE.ONETIME or
            shopInfo.stype == PDEFINE.SHOPSTYPE.SUPERPACK or
            shopInfo.stype == PDEFINE.SHOPSTYPE.PROPACK then
            addDiamond = shopInfo.ocount
        end

        local retobj = {}
        retobj.c = PDEFINE.NOTIFY.coin
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.uid = uid
        retobj.deskid = 0
        retobj.count = coin
        retobj.coin = playerInfo.coin
        retobj.diamond = playerInfo.diamond + addDiamond
        retobj.addDiamond = addDiamond
        retobj.type = 1
        local compress = false
        if stype == PDEFINE.SHOPSTYPE.COIN or type == PDEFINE.SHOPSTYPE.DIAMOND then
            compress = true
        end
        retobj.rewards = sendBenefit(shopid, compress) --根据权益配置进行赠送
        handle.sendToClient(cjson.encode(retobj))

        retobj = {}
        retobj.c = PDEFINE.NOTIFY.BUY_OK
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.uid = uid
        retobj.coin = coin
        retobj.type = 1
        retobj.shopid = shopid
        retobj.stype = stype
        retobj.rewards = {}
        if stype == PDEFINE.SHOPSTYPE.TIMELIMITED  then
            if coin > 0 then
                table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN, count=coin})
            end
            if shopInfo.vipExp > 0 then
                table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.VIP_POINT, count = shopInfo.vipExp}) --加vip经验值
                handle.moduleCall("upgrade","useVipDiamond", shopInfo.vipExp)
            end
        else
            if coin > 0 then
                table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN, count=coin})
            end
            if addDiamond > 0 then
                table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.DIAMOND, count=addDiamond})
            end
        end
        if stype == PDEFINE.SHOPSTYPE.ONETIME then
            table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.SKIN_FRAME, count=1, img='avatarframe_newer', days=3})
        end
        handle.sendToClient(cjson.encode(retobj)) --1035

        if coin > 0 then --金币类型通知游戏服
            handle.addCoinInGame(coin)
        end

        --更新订单成功
        LOG_INFO(" pay.deliverOrder: 发货完毕", uid, orderid, coin)
    end
    return PDEFINE.RET.SUCCESS
end

--IAP回调
--! 服务器验证发货
function pay.ipayVerify(msg)
    LOG_INFO("---------------ipayVerify get_msg--------------------:", msg)
    local recvobj = cjson.decode(msg)
    assert(recvobj.data)

    local uid = math.floor(recvobj.uid)
    local platform = math.floor(recvobj.platform) -- 1安卓 2ios
    local data = recvobj.data or ""
    local orderid = recvobj.orderid or ""
    local appId = recvobj.appId or 0 --渠道包id
    if #data == 0 then
        return PDEFINE.RET.ERROR.ORDER_PAID_EMPTY_PARAMS
    end
    --ios 会传orderid, android 在data里
    if platform == 2 then
        if #orderid == 0 then
            return PDEFINE.RET.ERROR.ORDER_PAID_EMPTY_PARAMS
        end
    end

    local purchaseTokenDataHuawei = nil
    local orderIsTest = false
    --谷歌支付orderid会在developerPayload, 实例: inapp:wydlm_gp_02:2fb54a3e-e726-49f2-afbd-97bd5dba442b:OrderId:201806212245533962383484
    if platform == 1 then
        --google play paid
        data = cjson.decode(data)
        if handle.isHuaWei() then
            orderid = data.developerPayload --游戏服订单id
            local purchaseType = data.purchaseType --区分华为渠道正式单子或测试单子, 为0表示沙盒环境测试单子
            --华为支付 需要验证有效性
            if purchaseType ~= nil and math.floor(purchaseType) == 0 then
                orderIsTest = true
            end
            local ok, retCode
            ok, retCode, purchaseTokenDataHuawei = pcall(skynet.call, ".huawei", "lua", "verify", data.purchaseToken, data.productId)
            if not ok or retCode ~= PDEFINE.RET.SUCCESS then
                LOG_ERROR("huawei verify retCode: ", retCode, ' ok:', ok)
                return PDEFINE.RET.ERROR.ORDER_PAID_VERIFY_RECEIPT_FAILED
            end
        end
    end

    --获取订单信息
    local sql = string.format("select * from s_shop_order where orderid='%s' limit 1", orderid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs == 0 then
        LOG_ERROR(" pay.ipayVerify 订单号找不到记录:", orderid)
        return PDEFINE.RET.ERROR.ORDER_PAID_ORDER_NOT_FOUND
    end

    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    local price  = 0 --订单价格
    local productid, orderCoin, shopid, stype
    if #rs == 1 then
        price = rs[1].amount
        productid = rs[1].productid
        if rs[1].uid ~= uid then
            LOG_ERROR(" pay.ipayVerify 订单号所属uid不一致:", rs[1].uid, " vs ", uid)
            return PDEFINE.RET.ERROR.ORDER_PAID_USER_ERROR
        end

        if rs[1].status == 2 then
            LOG_ERROR(string.format("The same orderid %s  verify again.", orderid))
            return PDEFINE.RET.SUCCESS, cjson.encode({price = price, times = 2}) --已经支付成功的订单
        end
        orderCoin = rs[1].count
        shopid    = rs[1].shopid
        stype     = rs[1].stype --订单类型
    end
    if platform == 1 then
        --google play paid
        if data.productId ~= productid then
            LOG_ERROR(string.format("The data.productId: %s  vs %s.", data.productId, orderid, productid))
            return PDEFINE.RET.ERROR.ORDER_PAID_VERIFY_PRODUCT_FAILED
        end

        --华为支付渠道无需验证google
        local token = ''
        if not handle.isHuaWei() then 
            local ok, ret, body = pcall(skynet.call, ".google", "lua", "verify", data, recvobj.sign, handle.getBundleid())
            if not ok or ret ~= 200 then
                LOG_ERROR("Verify body from google failed.", ok, body)
                return PDEFINE.RET.ERROR.ORDER_PAID_VERIFY_RECEIPT_FAILED
            end
            --验证rsa
            if body ~= 200 then
                LOG_ERROR(" pay.ipayVerify google验证rsa失败, 非200:", orderid, body)
                return PDEFINE.RET.ERROR.ORDER_PAID_VERIFY_PRODUCT_FAILED
            end
            token = data.purchaseToken
        end

        if data.purchaseState ~= 0 then
            LOG_ERROR(" pay.ipayVerify google订单并未支付成功:", orderid, data.purchaseState)
            return PDEFINE.RET.ERROR.ORDER_PAID_VERIFY_STATUS_FAILED
        end
        if stype == PDEFINE.SHOPSTYPE.TURNTABLE then
            --轮盘购买权限
            do_redis({ "set", "turntable_buytimes:" .. uid, 1})
            local json = {}
            json["orderid"] = orderid
            return PDEFINE.RET.SUCCESS, cjson.encode(json)
        end
        local result, retdata = updateOrder(uid, orderid, orderCoin, data.orderId, price, shopid, playerInfo.level, token, orderIsTest)
        if retdata ~= nil then
            local json = cjson.decode(retdata)
            json["purchaseTokenData"] = purchaseTokenDataHuawei
            json["orderid"] = orderid
            retdata = cjson.encode(json)
        else
            local json = {["purchaseTokenData"] = purchaseTokenDataHuawei}
            json["orderid"] = orderid
            retdata = cjson.encode(json)
        end
        LOG_DEBUG("result:", result)
        LOG_DEBUG("retdata:", retdata)
        return result, retdata
    end
    if platform == 2 then
        --ios paid
        LOG_DEBUG("post Verify body from apple ", data)
        local ok, ret, body = pcall(skynet.call, ".apple", "lua", "verify", data, orderid)
        if not ok or ret ~= 200 then
            LOG_ERROR("Verify body from apple failed.", ok, body)
            return PDEFINE.RET.ERROR.ORDER_PAID_VERIFY_RECEIPT_FAILED
        end
        local resp = cjson.decode(body)
        local err = PDEFINE.RET.ERROR.ORDER_PAID_VERIFY_PRODUCT_FAILED
        if nil ~= resp.receipt then
            for _, item in pairs(resp.receipt.in_app) do
                if item.product_id == productid then
                    err = 0
                    break
                end
            end
        end
        if err > 0 then
            return err
        end
        if resp.status ~= 0 then
            return PDEFINE.RET.ERROR.ORDER_PAID_VERIFY_STATUS_FAILED
        end
        if stype == PDEFINE.SHOPSTYPE.TURNTABLE then
            --轮盘购买权限
            do_redis({ "set", "turntable_buytimes:" .. uid, 1})
            local json = {}
            json["orderid"] = orderid
            return PDEFINE.RET.SUCCESS, cjson.encode(json)
        end
        return updateOrder(uid, orderid, orderCoin, 0, price, shopid, playerInfo.level)
    end
end

-- 是否首次购买该类型下该商品
local function isFirstBuy(uid, shopid)
    return 1
    -- local sqlFirst = string.format( "select count(1) as t from d_user_firstbuy where uid=%d and shopid=%d", uid, shopid)
    -- local rs = skynet.call(".mysqlpool", "lua", "execute", sqlFirst)
    -- if #rs > 0 and rs[1].t > 0 then
    --     return 0
    -- end
    -- return 1
end

local function isSkinItem(shopid)
    if shopid >= 200 and shopid<=240 then
        return true
    end
    return false
end

--! IAP 下单
function pay.ipayOrder(msg)
    -- TODO:如果是折扣，需要删掉redis中的数据 do_redis({"hdel", "discountShop:uid:"..uid, "stype:"..stype..":time"})
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local shopid = math.floor(recvobj.id) --产品id
    local platform = recvobj.platform or 2 --默认ios 1android  2apple 3h5 paymol
    local version = recvobj.version or ""
    local posid = recvobj.posid or 0
    local pay_channel = recvobj.channel or 0 --支付渠道
    local appId = recvobj.appId or 0 --渠道包id
    platform = math.floor(platform)
    pay_channel = math.floor(pay_channel)
    appId = math.floor(appId)

    local rs
    local shop
    local stype
    local cat
    if isSkinItem(shopid) then
        local sql = string.format("select * from s_shop_skin where shopid=%d", shopid)
        rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        shop = rs[1]
        stype = rs[1].stype
        cat = 0
    else
        local sql = string.format("select * from s_shop where id=%d", shopid)
        rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        shop = rs[1]
        stype = rs[1].stype
        cat = rs[1].cat
    end
    if #rs ~= 1 then
        return PDEFINE.RET.ERROR.PRODUCT_NOT_FOUND
    end

    -- if tonumber(stype) == PDEFINE.SHOPSTYPE.TIMELIMITED then
    --     local cacheKey = "timelimitgoods:" .. uid 
    --     local leftseconds = do_redis({"ttl", cacheKey})
    --     leftseconds = math.floor(leftseconds or 0)
    --     if leftseconds <= 0 then
    --         return PDEFINE.RET.ERROR.PRODUCT_TIME_EXPIRE --限时礼包未开启
    --     end
    -- end

    local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
    local productid = pay.getProductId(shop, platform)

    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    local ip = playerInfo.login_ip
    local now = os.time()

    --是否首次付费
    local first = isFirstBuy(uid, shopid)
    local user_coin = playerInfo.coin or 0 --用户当前金币
    user_coin = math.floor(user_coin)
    local user_level = playerInfo.level or 1
    local orderCount = shop.count or 0

    local sendRate = getSendRate(uid, shopid)
    local sendcoin = 0
    if not isSkinItem(shopid) then
        if sendRate > 0 then
            sendcoin = math.floor(sendRate * shop.count)
        end
        if sendcoin > 0 and (stype == PDEFINE.SHOPSTYPE.DIAMOND or stype == PDEFINE.SHOPSTYPE.COIN) then
            orderCount = shop.count + sendcoin 
        end
    else
        shop.title = shop.title_en
    end

    if stype == PDEFINE.SHOPSTYPE.MONEYBAG then
        local moneybag = playerInfo.moneybag
        local canbuycoin = handle.moduleCall("player", "getMaxCanBuyCoin", moneybag)
        if shop.count > canbuycoin then  --超出能购买的金猪范围
            return PDEFINE.RET.ERROR.PIG_LEVEL
        end
    end

    local login_type = 0
    local ok, loginData = pcall(cluster.call, "master", ".userCenter", "getOnlineData", uid)
    if ok and loginData ~= nil then
        login_type = loginData.logintype
    end
    LOG_DEBUG(" ipayOrder user_coin:", user_coin)
    sql =
        string.format(
        "insert into s_shop_order(orderid,uid,shopid,productid,title,count,amount,status,platform,version,client_ip,create_time,update_time,isfirst,pay_channel,posid,stype,cat,user_level, user_coin,appid,login_type) values('%s',%d,%d,'%s','%s',%d,%f,%d,%d,'%s','%s',%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)",
        orderid,
        uid,
        shopid,
        productid,
        shop.title,
        orderCount,
        shop.amount,
        0,
        platform,
        version,
        ip,
        now,
        now,
        first,
        pay_channel,
        posid,
        stype,
        cat,
        user_level,
        user_coin,
        appId,
        login_type
    )
    local ret = skynet.call(".mysqlpool", "lua", "execute", sql)
    if ret then
        local retobj = {
            c = math.floor(recvobj.c),
            code = PDEFINE.RET.SUCCESS,
            orderid = orderid,
            productid = productid,
            shopid = shopid,
            stype = stype
        }
        return resp(retobj)
    end
    return PDEFINE.RET.ERROR.ORDER_CREATED_FAIL
end

-- 获取商品列表
-- stype : 1商城
function pay.getGoods(uid, platform, level, stype, isDiscount, catid)
    local shopInfoList = {}
    local type = 1 --默认是正常情况，获取商城列表使用
    local rs = getShopList(stype)
    local isHuawei = handle.isHuaWei()
    -- LOG_DEBUG("pay.getGoods type:", type, " rs:", rs, " platform:",platform, ' isHuawei:', isHuawei)
    if nil ~= rs and #rs > 0 then
        if stype == PDEFINE.SHOPSTYPE.STORE then -- 金币，用钻石兑换
            table.sort(rs, function(a, b) return a.amount > b.amount end) --从大到小排序
            for _, row in pairs(rs) do
                local discount = getSendRate(uid, row.id)
                local sendcoin = 0
                if discount > 0 then
                    sendcoin = math.floor(discount * row.count)
                end
                    
                local shopInfo = {
                    id = row.id,
                    amount = row.amount, --需要钻石数量
                    unit= UNIT_STRING,
                    count = sendcoin + row.count, --数量
                    ocount = row.count, --原始数量
                    discount = (1+discount) * 100,
                    hot= 0,
                }
                --第1个免费领取
                -- if tonumber(row.id) == 6 then
                --     shopInfo.free = 1
                --     local timeout = getFreeTime(uid, 'coin')
                --     shopInfo.timeout = timeout
                --     shopInfo.count  = PDEFINE.SHOP_SEND.coin
                --     shopInfo.ocount = PDEFINE.SHOP_SEND.coin
                -- end
                table.insert(shopInfoList, shopInfo)
            end
        elseif stype == PDEFINE.SHOPSTYPE.TIMELIMITED then -- 进不不足，限时弹框
            table.sort(rs, function(a, b) return a.amount > b.amount end) --从大到小排序
            for _, row in pairs(rs) do
                local shopInfo = {
                    id = row.id,
                    amount = row.amount, --需要钻石数量
                    unit= UNIT_STRING,
                    count =  row.count, --数量
                    ocount = row.ocount, --原始数量
                    discount = row.discount,
                    vipexp = row.vipExp, --vip经验值
                    hot= 0,
                }
                shopInfo.productid = pay.getProductId(row, platform)
                if row.id == 135 then
                    shopInfo.hot = 1 --热销商品
                end
                table.insert(shopInfoList, shopInfo)
            end
        elseif stype == PDEFINE.SHOPSTYPE.DIAMOND then -- 非折扣，获取商品列表
            for _, row in pairs(rs) do
                local discount = getSendRate(uid, row.id)
                local sendcoin = 0
                if discount > 0 then
                    sendcoin = math.floor(discount * row.count)
                end

                local shopInfo = {
                    id = row.id,
                    amount = row.amount,
                    unit= UNIT_STRING,
                    count = (sendcoin + row.count), --数量
                    ocount = row.count, --原始数量
                    discount = (1+discount) * 100,
                    hot= 0,
                }
                -- if row.id == 101 then --第1个免费领取
                --     shopInfo.free = 1
                --     local timeout = getFreeTime(uid, 'diamond')
                --     shopInfo.timeout = timeout
                --     shopInfo.count  = PDEFINE.SHOP_SEND.diamond
                --     shopInfo.ocount = PDEFINE.SHOP_SEND.diamond
                -- end
                shopInfo.productid = pay.getProductId(row, platform)
                table.insert(shopInfoList, shopInfo)
            end
        elseif stype == PDEFINE.SHOPSTYPE.VIP5 then --vip
            local first = isFirstBuy(uid, rs[1].id)
            if first > 0 then
                local shopInfo = {
                    id = rs[1].id,
                    amount = rs[1].amount,
                    diamond = rs[1].count,
                    count = rs[1].count, --钻石
                    countday = 0, --每日获取
                    unit= UNIT_STRING
                }
                shopInfo.productid = pay.getProductId(rs[1], platform)
                table.insert(shopInfoList, shopInfo)
            end
            
        elseif stype == PDEFINE.SHOPSTYPE.CARDWEEK or stype == PDEFINE.SHOPSTYPE.CARDMONTH then --周卡月卡/骑士爵士
            local shopInfo = {
                id = rs[1].id,
                amount = rs[1].amount,
                diamond = rs[1].ocount,
                count = rs[1].count, --金币数量
                countday = rs[1].sendcoin, --每日获取
                unit= UNIT_STRING
            }
            shopInfo.productid = pay.getProductId(rs[1], platform)
            table.insert(shopInfoList, shopInfo)
        elseif stype == PDEFINE.SHOPSTYPE.PROPACK or stype == PDEFINE.SHOPSTYPE.SUPERPACK then
            for _, row in pairs(rs) do
                local shopInfo = {
                    id = row.id,
                    amount = row.amount, --现价
                    count = row.count, --金币数量
                    oamount = row.oamount, --原价
                    unit= UNIT_STRING,
                    rewards = {}, --赠送的权益
                }
                local ok, prizetbl = pcall(jsondecode, row.prize)
                if ok then
                    local tbl = prizetbl
                    for _, val in pairs(tbl) do
                        val.type = val.s
                        val.count = val.n
                        val.s = nil
                        val.n = nil
                    end
                    table.insert(tbl, {
                        ['type'] = PDEFINE.PROP_ID.COIN,
                        ['count']=row.count
                    })
                    shopInfo.rewards = tbl
                end
                shopInfo.productid = pay.getProductId(rs[1], platform)
                table.insert(shopInfoList, shopInfo)
            end
        elseif stype == PDEFINE.SHOPSTYPE.ONETIME then --新手/优惠礼包
            local shopInfo = {
                id = rs[1].id,
                amount = rs[1].amount, --现价
                count = rs[1].count, --金币数量
                oamount = rs[1].oamount, --原价
                discount = rs[1].discount, --折扣
                unit= UNIT_STRING,
                rewards = {}, --赠送的权益
            }
            local ok, prizetbl = pcall(jsondecode, rs[1].prize)
            if ok then
                local tbl = prizetbl
                for _, val in pairs(tbl) do
                    val.type = val.s
                    val.count = val.n
                    val.s = nil
                    val.n = nil
                end
                table.insert(tbl, {
                    ['type'] = PDEFINE.PROP_ID.COIN,
                    ['count']=rs[1].count
                })
                shopInfo.rewards = tbl
                table.insert(shopInfo.rewards, {['type'] = PDEFINE.PROP_ID.SKIN_FRAME, ['count']=1,img='avatarframe_newer', days=3}) --新手礼包送个头像框
            end
            shopInfo.productid = pay.getProductId(rs[1], platform)
            table.insert(shopInfoList, shopInfo)
        elseif stype == PDEFINE.SHOPSTYPE.PASS then -- 通行证
            for _, row in pairs(rs) do
                local shopInfo = {
                    id = row.id,
                    amount = row.amount,
                    count = row.count, --数量
                    unit= UNIT_STRING
                }
                shopInfo.productid = pay.getProductId(row, platform)
                table.insert(shopInfoList, shopInfo)
            end
        elseif stype == PDEFINE.SHOPSTYPE.MONEYBAG then --金猪
            table.sort(rs, function(a, b) return a.amount < b.amount end) --从小到大排序
            local isHuawei = handle.isHuaWei()
            for _, row in ipairs(rs) do
                local shopInfo = {
                    id = row.id,
                    amount = row.amount,
                    unit = UNIT_STRING,
                    count = row.count,
                    discount = row.discount,
                }
                shopInfo.productid = pay.getProductId(row, platform)
                table.insert(shopInfoList, shopInfo)
            end
        else
            -- 需要记录玩家请求的时间，写在redis中
            -- 不同位置的限时折扣不同，主键都是discountShop:uid
            local result = do_redis({"hget", "discountShop:", "uid:"..uid..":time"})
            -- 限时优惠的商品，根据位置不同需要做区分处理
            -- local idx = math.random(1, #rs) --TODO 限时优惠商品信息
            local idx = 1
            if nil ~= catid then
                for k, row in pairs(rs) do
                    if row.cat == catid then
                        idx = k
                        break
                    end
                end
            end

            if rs[idx].oamount == 0 then
                rs[idx].oamount = rs[idx].amount
            end
            local shopInfo = {
                id = rs[idx].id,
                -- title = rs[idx].title,
                count = rs[idx].count,
                amount = rs[idx].amount,
                oamount= rs[idx].oamount,
                unit= UNIT_STRING,
                icon = rs[idx].icon,
                rewards = {}, --赠送的权益
            }
            local ok, prizetbl = pcall(jsondecode, rs[idx].prize)
            if ok then
                local tbl = prizetbl
                for _, val in pairs(tbl) do
                    val.type = val.s
                    val.count = val.n
                    val.s = nil
                    val.n = nil
                end
                shopInfo.rewards = tbl
            end
            
            shopInfo.precount = rs[idx].ocount
            shopInfo.productid = pay.getProductId(rs[idx], platform)
            shopInfo.discount = rs[idx].discount --折扣
            shopInfo.discountTime = rs[idx].discountTime
            if result == nil then
                do_redis({"hset", "discountShop:uid:"..uid, "stype:"..stype..":time", os.time()})
            else
                local time = os.time() - result
                if time > rs[idx].discountTime then
                    shopInfo.discountTime = 0
                    do_redis({"hdel", "discountShop:uid:"..uid, "stype:"..stype..":time"})
                    -- 如果购买，也需要删除这个折扣字段
                else
                    shopInfo.discountTime = rs[idx].discountTime - time
                end
            end
            table.insert(shopInfoList, shopInfo)
        end
    end
    return shopInfoList, type
end

-- 获取周卡月卡的金币数
local function getCardInfo(uid)
    local collect = 0
    local now = os.time()
    local endtime =handle.dcCall("user_dc", "getvalue", uid, "vipendtime")
    if endtime and endtime > now then
        collect = 1 --已经购买了
        local vipLevel = handle.dcCall("user_dc", "getvalue", uid, "svip")
        local flag = do_redis({"get", PDEFINE.REDISKEY.CARD.GETWEEK .. vipLevel .. uid}, uid)
        if flag ~= nil then
            collect = 2
        end
    end
    return collect
end


-- 根据条件过滤掉列表中的类型，某些类型不显示
local function filterStypeList(stypeStr)
    local stypeArr = {1} --1:金币(用钻石兑换) 25:钻石 14 骑士(周卡) 15(月卡) 18(新人礼包) 27优惠礼包1 28优惠礼包2
    if #stypeStr > 0 then
        stypeArr = string.split(stypeStr, ",")
    end

    local is_tishen = handle.isTiShen()
    local filter_tishen = {PDEFINE.SHOPSTYPE.FUND, PDEFINE.SHOPSTYPE.CARDWEEK, PDEFINE.SHOPSTYPE.CARDMONTH, PDEFINE.SHOPSTYPE.SPRINGGIFT}
    -- 过滤掉已经购买过的商品
    for k, v in ipairs(stypeArr) do
        v = math.floor(v)
        if is_tishen then
            if table.contain(filter_tishen, v) then
                stypeArr[k] = nil
            end
        end
    end
    return stypeArr
end

local function loadShopData(stypeStr, uid, platform, isDiscount)
    local stypeArr = filterStypeList(stypeStr)
    local level = handle.dcCall("user_dc", "getvalue", UID, "level") --玩家级别
    local infoList = {} --所有商品信息的列表
    for _, type in pairs(stypeArr) do
        type = math.floor(type)
        local shopInfoList, retType = pay.getGoods(uid, platform, level, type, isDiscount, nil)
        if type == PDEFINE.SHOPSTYPE.CARDWEEK or type == PDEFINE.SHOPSTYPE.CARDMONTH then --基础vip 2种价格，不同周期
            shopInfoList[1].precount = nil
            shopInfoList[1].discountTime = nil
            shopInfoList[1].oamount = nil
            local collect = getCardInfo(uid)
            shopInfoList[1].collect = collect -- 0只能购买 1需要收集了 2今日已收集过了
        end
        if shopInfoList[1] and type == PDEFINE.SHOPSTYPE.VIP5 then
            shopInfoList[1].precount = nil
            shopInfoList[1].discountTime = nil
            shopInfoList[1].oamount = nil
        end
        if type == PDEFINE.SHOPSTYPE.ONETIME then --新手礼包
            shopInfoList[1].precount = nil
            shopInfoList[1].discountTime = nil
            shopInfoList[1].originalid = PDEFINE.VISTOR.IOS_ID
            if platform == 1 then
                shopInfoList[1].originalid = PDEFINE.VISTOR.ANDROID_ID
            end
        end
        infoList["data"..type] = shopInfoList
    end
    return infoList
end
--[[
    2: 限时礼包  按活动周期开启，周期内可以购买1次，活动结束或周期内购买了就不在显示
    8: one time only 玩家只能买1次，买完不能再买
]]
--! 竖版获取所有购买的商品信息
--@param stype 商品类型(1商城,8onetimeonly(新手礼包), 14周卡，15月卡,25钻石，27优惠礼包 30直达vip5)，多个类型用逗号隔开
function pay.getShopListPortraitVersion(msg)
    local recvobj = cjson.decode(msg)
    local cmd  = math.floor(recvobj.c) --指令
    local c_idx = recvobj.c_idx
    local uid = math.floor(recvobj.uid)
    local platform = recvobj.platform or 2 --平台 1安卓 2IOS
    platform = math.floor(platform)
    local stypeStr = recvobj.stype or ''
    local isDiscount =  0 --正常获取商城不需要传入，限时优惠传入 isDiscount：true
    local stypeArr = filterStypeList(stypeStr)
    local retobj = {c = cmd, code = PDEFINE.RET.SUCCESS, shoplist = {}, c_idx = c_idx, ad=1, timeout=0} --ad: 1显示，充值送100%
    retobj["shoplist"] = loadShopData(stypeStr, uid, platform, isDiscount)
    LOG_DEBUG("stypeArr:",stypeArr)
    for _, category in pairs(stypeArr) do
        if tonumber(category) == PDEFINE.SHOPSTYPE.TIMELIMITED then
            local cacheKey = "timelimitgoods:" .. uid 
            local first = do_redis({ "get", 'timelimit_today:' .. uid})
            first = math.floor(first or 0)
            local totalTimes = 24 * 3600 --限时礼包4小时有效
            local leftseconds = totalTimes
            --TODO: 先临时注释掉
            if first == 0 then
                leftseconds = totalTimes
                do_redis({ "setex", cacheKey, 1, totalTimes})
                do_redis({ "set", 'timelimit_today:' .. uid, 1})
            else
                leftseconds = do_redis({"ttl", cacheKey})
                leftseconds = math.floor(leftseconds or 0)
                if leftseconds <= 0 then
                    do_redis({ "set", 'timelimit_today:' .. uid, 0})
                    -- retobj["shoplist"] = {}
                end
            end
            retobj.timeout = leftseconds
            break
        end
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 获取商品列表
-- stype : 1商城
function pay.getGoodsTishen(uid, platform, stype, catid)
    local shopInfoList = {}
    local type = 1 --默认是正常情况，获取商城列表使用
    local rs = getShopList(stype, true)
    local isHuawei = handle.isHuaWei()
    LOG_DEBUG("pay.getGoods type:", type, " rs:", rs, " platform:",platform, ' isHuawei:', isHuawei)
    if nil ~= rs and #rs > 0 then
        if stype == PDEFINE.SHOPSTYPE.STORE then -- 非折扣，获取商品列表
            table.sort(rs, function(a, b) return a.amount > b.amount end) --从大到小排序
            for _, row in pairs(rs) do
                local shopInfo = {
                    id = row.id,
                    amount = row.amount, --需要钻石数量
                    unit= UNIT_STRING,
                    count =  row.count, --数量
                    ocount = row.count, --原始数量
                    discount = 100,
                    hot= 0,
                }
                shopInfo.productid = pay.getProductId(row, platform)
                --第1个免费领取
                if tonumber(row.id) == 3 then
                    shopInfo.free = 1
                    local timeout = getFreeTime(uid, 'coin')
                    shopInfo.timeout = timeout
                    shopInfo.count  = PDEFINE.SHOP_SEND.coin
                    shopInfo.ocount = PDEFINE.SHOP_SEND.coin
                end
                table.insert(shopInfoList, shopInfo)
            end
        elseif stype == PDEFINE.SHOPSTYPE.DIAMOND then -- 非折扣，获取商品列表
            for _, row in pairs(rs) do
                local discount = getSendRate(uid, row.id)
                local sendcoin = 0
                if discount > 0 then
                    sendcoin = math.floor(discount * row.count)
                end

                local shopInfo = {
                    id = row.id,
                    amount = row.amount,
                    unit= UNIT_STRING,
                    count = (sendcoin + row.count), --数量
                    ocount = row.count, --原始数量
                    discount = (1+discount) * 100,
                    hot= 0,
                }
                if row.id == 101 then --第1个免费领取
                    shopInfo.free = 1
                    local timeout = getFreeTime(uid, 'diamond')
                    shopInfo.timeout = timeout
                    shopInfo.count  = PDEFINE.SHOP_SEND.diamond
                    shopInfo.ocount = PDEFINE.SHOP_SEND.diamond
                end
                
                shopInfo.productid = pay.getProductId(row, platform)
                table.insert(shopInfoList, shopInfo)
            end
        elseif stype == PDEFINE.SHOPSTYPE.MONEYBAG then --金猪
            table.sort(rs, function(a, b) return a.amount < b.amount end) --从小到大排序
            local isHuawei = handle.isHuaWei()
            for _, row in ipairs(rs) do
                local shopInfo = {
                    id = row.id,
                    amount = row.amount,
                    unit = UNIT_STRING,
                    count = row.count,
                    discount = row.discount,
                }
                shopInfo.productid = pay.getProductId(row, platform)
                table.insert(shopInfoList, shopInfo)
            end
        else
            local result = do_redis({"hget", "discountShop:", "uid:"..uid..":time"})
            local idx = 1
            if nil ~= catid then
                for k, row in pairs(rs) do
                    if row.cat == catid then
                        idx = k
                        break
                    end
                end
            end

            if rs[idx].oamount == 0 then
                rs[idx].oamount = rs[idx].amount
            end
            local shopInfo = {
                id = rs[idx].id,
                -- title = rs[idx].title,
                count = rs[idx].count,
                amount = rs[idx].amount,
                oamount= rs[idx].oamount,
                unit= UNIT_STRING,
                icon = rs[idx].icon,
                rewards = {}, --赠送的权益
            }
            local ok, prizetbl = pcall(jsondecode, rs[idx].prize)
            if ok then
                local tbl = prizetbl
                for _, val in pairs(tbl) do
                    val.type = val.s
                    val.count = val.n
                    val.s = nil
                    val.n = nil
                end
                shopInfo.rewards = tbl
            end

            shopInfo.precount = rs[idx].ocount
            shopInfo.productid = pay.getProductId(rs[idx], platform)
            shopInfo.discount = rs[idx].discount --折扣
            shopInfo.discountTime = rs[idx].discountTime
            if result == nil then
                do_redis({"hset", "discountShop:uid:"..uid, "stype:"..stype..":time", os.time()})
            else
                local time = os.time() - result
                if time > rs[idx].discountTime then
                    shopInfo.discountTime = 0
                    do_redis({"hdel", "discountShop:uid:"..uid, "stype:"..stype..":time"})
                    -- 如果购买，也需要删除这个折扣字段
                else
                    shopInfo.discountTime = rs[idx].discountTime - time
                end
            end
            table.insert(shopInfoList, shopInfo)
        end
    end
    return shopInfoList, type
end

--！ 提审专用
function pay.getShopListTishen(msg)
    local recvobj = cjson.decode(msg)
    local cmd  = math.floor(recvobj.c) --指令
    local c_idx = recvobj.c_idx
    local uid = math.floor(recvobj.uid)
    local platform = recvobj.platform or 2 --平台 1安卓 2IOS
    platform = math.floor(platform)
    local stypeStr = recvobj.stype or ''
    local stypeArr = filterStypeList(stypeStr)
    local retobj = {c = cmd, code = PDEFINE.RET.SUCCESS, shoplist = {}, c_idx = c_idx, ad=1, timeout=0} --ad: 1显示，充值送100%
    LOG_DEBUG("stypeArr:",stypeArr)
    for _, type in pairs(stypeArr) do
        local shopInfoList, retType = pay.getGoodsTishen(uid, platform, math.floor(type))
        retobj["shoplist"]["data"..type] = shopInfoList
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 获取显示
function pay.getLimitTimeShop(msg)
    local recvobj = cjson.decode(msg)
    local cmd  = math.floor(recvobj.c) --指令
    local c_idx = recvobj.c_idx
    local uid = math.floor(recvobj.uid)
    local platform = recvobj.platform or 2 --平台 1安卓 2IOS
    platform = math.floor(platform)
    local stypeStr = recvobj.stype or ''
    local isDiscount =  0 --正常获取商城不需要传入，限时优惠传入 isDiscount：true

    local stypeArr = filterStypeList(stypeStr)
    local retobj = {c = cmd, code = PDEFINE.RET.SUCCESS, shoplist = {}, c_idx = c_idx, ad=1, timeout=0} --ad: 1显示，充值送100%
    
    retobj["shoplist"] = loadShopData(stypeStr, uid, platform, isDiscount)
    LOG_DEBUG("stypeArr:",stypeArr)
    for _, category in pairs(stypeArr) do
        if tonumber(category) == PDEFINE.SHOPSTYPE.TIMELIMITED then
            local cacheKey = "timelimitgoods:" .. uid 
            local first = do_redis({ "get", 'timelimit_today:' .. uid}) --今天是否访问过
            first = math.floor(first or 0)
            local totalTimes = 24 * 3600 --限时礼包4小时有效
            -- totalTimes = 60
            local leftseconds = 0
            if first == 0 then
                do_redis({"setex", 'timelimit_today:' .. uid, 1 , totalTimes})
                do_redis({"setex", cacheKey, 1, totalTimes})
                leftseconds = totalTimes
            else
                leftseconds = do_redis({"ttl", cacheKey})
                leftseconds = math.floor(leftseconds or 0)
                if leftseconds <= 0 then
                    retobj["shoplist"] = {}
                end
            end
            retobj.timeout = leftseconds
            break
        end
    end

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 周卡月卡领取(vip奖励)
function pay.getCard(msg)
    local recvobj = cjson.decode(msg)
    local cmd  = math.floor(recvobj.c) --指令
    local stype = recvobj.stype or 14 -- 14：周卡 15：月卡
    local uid = math.floor(recvobj.uid)
    if stype ~= PDEFINE.SHOPSTYPE.CARDWEEK and stype ~= PDEFINE.SHOPSTYPE.CARDMONTH then
        LOG_ERROR("参数错误, uid:", uid, " stype:", stype)
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end
    -- 已领取过的不能再领取
    local vipLevel = handle.dcCall("user_dc", "getvalue", uid, "svip")
    local flag_today = PDEFINE.REDISKEY.CARD.GETWEEK..vipLevel
    local flag = do_redis({"get", flag_today .. uid}, uid)
    if flag ~= nil then
        return PDEFINE.RET.ERROR.CARD_HAD_COLLECT
    end
    do_redis({"set", flag_today .. uid, 1}, uid)

    local now = os.time()
    local endTime = handle.dcCall("user_dc", "getvalue", uid, "vipendtime")
    if endTime < now then
        return PDEFINE.RET.ERROR.CARD_HAD_COLLECT
    end
    local retobj = {c = cmd, code = PDEFINE.RET.SUCCESS, stype=stype, rewards={}}
    local timeout = calRoundEndTime()
    retobj.timeout = timeout - now
    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    local vip = tonumber(playerInfo.svip or 0)
    local sendDiamond, sendCoin = 0, 0
    if vip >= 0 then
        local ok, vipCfg = pcall(cluster.call, "master", ".configmgr", "getVipUpCfg")
        if ok then
            local rewards = vipCfg[vip].rewards
            if vip > 1 then --成为VIP1后，每天还可以领取基础VIP的奖励
                local basicRewards = vipCfg[1].rewards
                for _, row in pairs(basicRewards) do
                    local added = false
                    for _, item in pairs(rewards) do
                        if item.s == row.s then
                            item.n = item.n + row.n
                            added = true
                            break
                        end
                    end
                    if not added then
                        table.insert(rewards, row)
                    end
                end
            end
            for _, item in pairs(rewards) do
                local contentStr = ''
                if item.s == PDEFINE.PROP_ID.DIAMOND then
                    contentStr = 'get_vip_rewards'
                end
                handle.addProp(item.s, item.n, 'card', nil, contentStr)
                if item.s == PDEFINE.PROP_ID.COIN then
                    table.insert(retobj.rewards, {['type'] = PDEFINE.PROP_ID.COIN, ['count']=item.n})
                    sendCoin = item.n
                elseif item.s == PDEFINE.PROP_ID.DIAMOND then
                    table.insert(retobj.rewards, {['type'] = PDEFINE.PROP_ID.DIAMOND, ['count']=item.n})
                    sendDiamond = item.n
                end
            end
        end
    end
    if sendCoin > 0 or sendDiamond > 0 then
        handle.notifyCoinChanged(playerInfo.coin, playerInfo.diamond, sendCoin, sendDiamond)
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 模拟购买
function pay.testBuyCoin(msg)
    if not DEBUG then
        return
    end
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local shopid = math.floor(recvobj.id) --产品id
    local platform = recvobj.platform or 3 --默认ios 1android  2apple 3h5 paymol
    local version = recvobj.version or ""
    local posid = recvobj.posid or 0
    local pay_channel = recvobj.channel or 0 --支付渠道
    local appId = recvobj.appId or 0 --渠道包id
    platform = math.floor(platform)
    pay_channel = math.floor(pay_channel)
    appId = math.floor(appId)
    local rs
    local shop
    local stype = 0
    local cat = 0
    if isSkinItem(shopid) then
        local sql = string.format("select * from s_shop_skin where shopid=%d", shopid)
        rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        shop = rs[1]
        stype = rs[1].stype
    else
        local sql = string.format("select * from s_shop where id=%d", shopid)
        rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        shop = rs[1]
        stype = rs[1].stype
        cat = rs[1].cat
    end
    if #rs ~= 1 then
        return PDEFINE.RET.ERROR.PRODUCT_NOT_FOUND
    end
    
    local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
    local productid = pay.getProductId(shop, platform)

    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    local ip = playerInfo.login_ip
    local now = os.time()

    --是否首次付费
    local first = isFirstBuy(uid, shopid)
    local user_coin = playerInfo.coin or 0 --用户当前金币
    user_coin = math.floor(user_coin)
    local user_level = playerInfo.level or 1

    local orderCount = 0
    if not isSkinItem(shopid) then
        orderCount = shop.count 
    else
        shop.title = shop.title_en or ""
    end
    
    local login_type = 0
    local ok, loginData = pcall(cluster.call, "master", ".userCenter", "getOnlineData", uid)
    if ok and loginData ~= nil then
        login_type = loginData.logintype
    end
    sql =
        string.format(
        "insert into s_shop_order(orderid,uid,shopid,productid,title,count,amount,status,platform,version,client_ip,create_time,update_time,isfirst,pay_channel,posid,stype,cat,user_level, user_coin,appid,login_type) values('%s',%d,%d,'%s','%s',%d,%f,%d,%d,'%s','%s',%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)",
        orderid,
        uid,
        shopid,
        productid,
        shop.title,
        orderCount,
        shop.amount,
        0,
        platform,
        version,
        ip,
        now,
        now,
        first,
        pay_channel,
        posid,
        stype,
        cat,
        user_level,
        user_coin,
        appId,
        login_type
    )
    skynet.call(".mysqlpool", "lua", "execute", sql)
    local result, retdata = updateOrder(uid, orderid, orderCount, '', shop.amount, shopid, playerInfo.level, '', true)
    if retdata ~= nil then
        local json = cjson.decode(retdata)
        json["purchaseTokenData"] = ''
        json["orderid"] = orderid
        retdata = cjson.encode(json)
    else
        local json = {["purchaseTokenData"] = ''}
        json["orderid"] = orderid
        retdata = cjson.encode(json)
    end
    LOG_DEBUG("result:", result)
    LOG_DEBUG("retdata:", retdata)
    return result, retdata
end

-- 内部模块调用接口
function pay.getStypeShopList(stype)
    local shopList = getShopList(stype)
    local datalist = {}
    local platform = handle.getPlatForm()
    for _ , row in pairs(shopList) do
        local productid = pay.getProductId(row, platform)
        local item = {
            ['id'] = row.id, --商品id
            ['coin'] = row.count, --金币数量
            ['count'] = row.ocount, --复活卡数量
            ['oamount'] = row.oamount, --原价
            ['amount'] = row.amount, --现价
            ['productid'] = productid, --商城id
            ['rewards'] = {},
        }

        if row.stype == PDEFINE.SHOPSTYPE.HAMME_SILVER or row.stype == PDEFINE.SHOPSTYPE.HAMME_GOLD then
            item['count'] = row.count
        end

        local ok, prizetbl = pcall(jsondecode, row.prize)
        if ok then
            for _, val in pairs(prizetbl) do
                val.type = val.s
                val.count = val.n
                val.s = nil
                val.n = nil
            end
            item.rewards = prizetbl
        end
        table.insert(datalist, item)
    end
    return datalist
end

--! 用钻石兑换金币
function pay.exchangeGods(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid) --当前登录的uid
    local frienduid = math.floor(recvobj.frienduid or 0) --6位
    local shopid = recvobj.id or 0 --金币id
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode =0, id = shopid}
    if shopid == 0 then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.SHOPINFO_NOT_FOUND --请选择金币商品
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    local shopInfo = getShopInfo(shopid)
    if not shopInfo then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.SHOPINFO_NOT_FOUND --请选择金币商品
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    if frienduid > 0 then
        local friend = player_tool.getPlayerInfo(frienduid)
        if not friend or not friend.uid then
            retobj.spcode = PDEFINE_ERRCODE.ERROR.USERNOTFOUND --好友未找到
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end

        if frienduid == uid then
            retobj.spcode = PDEFINE_ERRCODE.ERROR.USERNOTFOUND --不能送给自己, 好友未找到
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end
    end
    
    
    local diamond = shopInfo.vipExp --需要的金币数
    if playerInfo.diamond < diamond then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.LEAGUE_USER_DIAMOND --钻石不够，不能兑换
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    --扣钻石，给金币
    local leftDiamond = playerInfo.diamond - diamond
    local orderCount = shopInfo.count
    local sendRate = getSendRate(uid, shopid)
    local sendcoin = 0
    if sendRate > 0 then
        sendcoin = math.floor(sendRate * orderCount)
    end
    if frienduid > 0 then
        sendcoin = 0; --赠送的只给原来的
    else
        if sendcoin > 0 then
            orderCount = orderCount + sendcoin 
        end
    end
    
    handle.addProp(PDEFINE.PROP_ID.DIAMOND, -diamond, 'shop', nil, 'shop_exchange_coin', orderCount)

    if frienduid > 0 then --自己兑换给好友送金币
        local up_data = {
            addcoin = orderCount,
            uid = frienduid,
            diamond = 0,
        }
        pcall(cluster.send, "master", ".userCenter", "updateUserLevelInfo", frienduid, up_data)
        -- pcall(cluster.send, "master", ".userCenter", "apiAddCoin", frienduid, orderCount, '', 'FRIEND_SEND', nil)
    else --为自己兑换
        handle.addProp(PDEFINE.PROP_ID.COIN, orderCount, 'shop')
        setSendRate(uid, shopid)

        local notifyok = {}
        notifyok.c     = PDEFINE.NOTIFY.BUY_OK
        notifyok.code  = PDEFINE.RET.SUCCESS
        notifyok.uid   = uid
        notifyok.coin  = orderCount
        notifyok.type  = 1
        notifyok.shopid = shopid
        notifyok.stype  = PDEFINE.SHOPSTYPE.COIN
        notifyok.rewards = {{type=PDEFINE.PROP_ID.COIN, count=orderCount}}
        handle.sendToClient(cjson.encode(notifyok))

        local msgObj = {
            title_al = "إشعار شراء",
            title = 'Purchased Notice',
            msg_al = "لقد قمت بشراء العملات الذهبية بنجاح ويمكنك استخدامه أثناء اللعب ",
            msg = 'You have successfully purchased coins, which you can use in the game.',
            attach = {{type = PDEFINE.PROP_ID.COIN, count=orderCount}}
        }
        handle.sendBuyOrUpGradeEmail(msgObj, PDEFINE.MAIL_TYPE.SHOP)
    end

    local notifyobj = {}
    notifyobj.c = PDEFINE.NOTIFY.coin
    notifyobj.code = PDEFINE.RET.SUCCESS
    notifyobj.uid = uid
    notifyobj.deskid = 0
    notifyobj.count = orderCount
    if frienduid > 0 then
        notifyobj.count = 0
    end
    notifyobj.coin = playerInfo.coin
    notifyobj.diamond = leftDiamond
    notifyobj.addDiamond = 0
    notifyobj.type = 1
    notifyobj.rewards = {}
    handle.sendToClient(cjson.encode(notifyobj))

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 每天领取免费的
function pay.getFree(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid) --当前登录的uid
    local id = math.floor(recvobj.id or 0)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode =0, id = id}
    if id ~= 6 and id ~= 101 then
        retobj.spcode = PDEFINE.RET.ERROR.GET_FREE_ID --参数错误
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    local sendCoin, sendDiamond = 0, 0
    local rtype = 'coin'
    if id == 101 then
        rtype ='diamond'
        sendDiamond = PDEFINE.SHOP_SEND.diamond
    else
        sendCoin = PDEFINE.SHOP_SEND.coin
    end
    local timeout = getFreeTime(uid, rtype)
    if timeout > 0 then
        retobj.spcode = PDEFINE.RET.ERROR.GET_FREE_TIMES --今日已领取
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    cacheFreeGetTime(uid, rtype)
    if rtype =='diamond' then
        handle.addProp(PDEFINE.PROP_ID.DIAMOND, sendDiamond, 'shop', nil, 'shop_get_free')
        handle.moduleCall("quest", 'updateQuest', uid, PDEFINE.QUEST_TYPE.NEWER, PDEFINE.QUESTID.NEW.PAYMENT, 1)

        handle.moduleCall("upgrade","useVipDiamond", sendDiamond)
        handle.addStatistics(uid, 'shop_free', sendDiamond, 0, 1, PDEFINE.PROP_ID.DIAMOND)
    else
        handle.addProp(PDEFINE.PROP_ID.COIN, sendCoin, 'shop')
        handle.addStatistics(uid, 'shop_free', sendCoin, 0, 1, PDEFINE.PROP_ID.COIN)
    end
    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)

    local notifyobj = {}
    notifyobj.c = PDEFINE.NOTIFY.coin
    notifyobj.code = PDEFINE.RET.SUCCESS
    notifyobj.uid = uid
    notifyobj.deskid = 0
    notifyobj.count = sendCoin
    notifyobj.coin = playerInfo.coin
    notifyobj.diamond = playerInfo.diamond
    notifyobj.addDiamond = sendDiamond
    notifyobj.type = 1
    notifyobj.rewards = {}
    handle.sendToClient(cjson.encode(notifyobj))

    local notifyok = {}
    notifyok.c     = PDEFINE.NOTIFY.BUY_OK
    notifyok.code  = PDEFINE.RET.SUCCESS
    notifyok.uid   = uid
    notifyok.coin  = 0
    notifyok.type  = 1
    notifyok.shopid = id
    notifyok.stype  = PDEFINE.SHOPSTYPE.COIN
    notifyok.rewards = {}
    if sendDiamond > 0 then
        notifyok.rewards = {{type=PDEFINE.PROP_ID.DIAMOND, count=sendDiamond}}
        table.insert(notifyok.rewards, {type = PDEFINE.PROP_ID.VIP_POINT, count=sendDiamond})
    end
    if sendCoin > 0 then
        notifyok.rewards = {{type=PDEFINE.PROP_ID.COIN, count=sendCoin}}
    end
    handle.sendToClient(cjson.encode(notifyok))

    handle.moduleCall("player", "syncLobbyInfo", uid)


    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--vip可领取的倒计时
function pay.getVipInfo(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)

    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode =0}
    retobj.collect  = getCardInfo(uid)
    retobj.leftdays = 0 
    local timeout = calRoundEndTime()
    retobj.timeout = timeout - os.time()
    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    if playerInfo.vipendtime then
        local now = os.time()
        if playerInfo.vipendtime > now then
            retobj.leftdays = math.floor((playerInfo.vipendtime - now)/86400)
        end
    end
    retobj.rewards = {}
    local vip = tonumber(playerInfo.svip or 0)
    local ok, vipCfg = pcall(cluster.call, "master", ".configmgr", "getVipUpCfg")
    if vip > 0 then
        local rewards = vipCfg[vip].rewards
        if vip > 1 then --成为VIP1后，每天还可以领取基础VIP的奖励
            -- local basicRewards = vipCfg[1].rewards
            -- for _, row in pairs(basicRewards) do
            --     local added = false
            --     for _, item in pairs(rewards) do
            --         if item.s == row.s then
            --             item.n = item.n + row.n
            --             added = true
            --             break
            --         end
            --     end
            --     if not added then
            --         table.insert(rewards, row)
            --     end
            -- end
        end
        -- for _, row in pairs(rewards) do
        --     table.insert(retobj.rewards, {type = row.s, count= row.n})
        -- end
    else --不是vip用户, 显示基础vip的
        -- local rewards = vipCfg[6].rewards 
        -- if vip > 1 then --成为VIP1后，每天还可以领取基础VIP的奖励
        --     local basicRewards = vipCfg[1].rewards
        --     for _, row in pairs(basicRewards) do
        --         local added = false
        --         for _, item in pairs(rewards) do
        --             if item.s == row.s then
        --                 item.n = item.n + row.n
        --                 added = true
        --                 break
        --             end
        --         end
        --         if not added then
        --             table.insert(rewards, row)
        --         end
        --     end
        -- end
        -- for _, row in pairs(rewards) do
        --     table.insert(retobj.rewards, {type = row.type, count= row.count * 30}) --默认显示30天的
        -- end
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 获取需要本地化的商品id列表
function pay.getProductIds(platform, isHuaWei, bundleid)
    local productIds = {}
    local ok, shopList = pcall(cluster.call, "master", ".shopmgr", "getShopList")
    if ok then
        local field = 'productid_gp'
        if isHuaWei then
            field = 'productid_huawei'
        else
            if bundleid and PDEFINE.APPS.PRODUCT_FIELDS[bundleid] then
                field = PDEFINE.APPS.PRODUCT_FIELDS[bundleid][platform]
            else
                if platform == 2 then
                    field = 'productid'
                end
            end
        end
        local tmp = {}
        for _, typeList in pairs(shopList) do
            for _, row in pairs(typeList) do
                if row[field] and not tmp[row[field]] then
                    tmp[row[field]] = 1
                end
            end
        end
        productIds = table.indices(tmp)
    end
    return productIds
end

-- 单个商品的productid
function pay.getProductId(row, platform)
    if handle.isHuaWei() then
        platform = 4
    end
    if platform == 2 then
        return row.productid
    elseif platform == 4 then
        return row.productid_huawei
    else
        return row.productid_gp
    end
end

return pay