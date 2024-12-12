--[[
    魅力值
    好友A赠送魅力值道具给好友B：
    好友A消耗金币或钻石
    好友B根据道具属性增加魅力值或者减少魅力值
]]
local cjson   = require "cjson"
local skynet = require "skynet"
local cluster = require "cluster"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local cmd = {}
local handle
local UID = 0
local GAME_SEND_CMD = 1000 --游戏内赠送道具，外面已经扣费用了，里面不在扣除
local getCharmPackTime = 0 --领取礼包时间

function cmd.bind(agent_handle)
	handle = agent_handle
end

function cmd.initUid(uid)
    UID = uid
end

function cmd.init(uid)
    UID = uid
end

local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 道具列表
function cmd.propList(category)
    local datalist= {}
    local ok, row = pcall(cluster.call, "master", ".configmgr", "getCharmPropList")
    local isEnglish = handle.isEnglish()
    for _, item in pairs(row) do
        if not isEnglish then
            item.title = item.title_al
            item.title_al = nil
        end
        if tonumber(item.cat) == tonumber(category) then
            table.insert(datalist, item)
        end
    end
    return datalist
end

local function sendCharm(cmd, id, frienduid)
    local retobj = {c = cmd, code=PDEFINE.RET.SUCCESS, spcode =0}
    local ok, row = pcall(cluster.call, "master", ".configmgr", "getCharmPropList")
    if not ok or row[id]==nil then
        retobj.spcode = PDEFINE.RET.ERROR.CHARM_SEND
        return retobj
    end
    local now = os.time()
    local item = row[id]
    LOG_DEBUG("cmd.send charm item:", item)
    local prodId = tonumber(item.type) --prod_id
    local count = item.count
    -- local coin = item.coin
    local userInfo = handle.moduleCall("player", "getPlayerInfo", UID)
    if cmd ~= GAME_SEND_CMD then
        local caltimes = minus_send_charm_time(UID, item.img)
        LOG_DEBUG("caltimes:",caltimes , ' uid:', UID, ' phiz.img:',item.img)
        if not caltimes then
            if prodId == PDEFINE.PROP_ID.COIN and userInfo.coin < count then
                retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
                return retobj
            end
            if prodId == PDEFINE.PROP_ID.DIAMOND and userInfo.diamond < count then
                retobj.spcode = PDEFINE.RET.ERROR.LEAGUE_USER_DIAMOND
                return retobj
            end
            local content = ''
            local act = 'charm'
            local remark = ''
            if prodId == PDEFINE.PROP_ID.DIAMOND then
                content = 'send_charm'
                local skin = {
                    ['id'] = item.id,
                    ['title'] = item.title or item.title_al,
                    ['img'] = item.img or "",
                    ['diamond'] = item.count or 0,
                    ['tbl'] = 's_send_charm',
                }
                remark = cjson.encode(skin)
            end
            handle.addProp(prodId, -count, act, nil, content, remark) --扣金币
            
            local diamond = handle.dcCall("user_dc", "getvalue", UID, "diamond")
            local coin = handle.dcCall("user_dc", "getvalue", UID, "coin")
            local notifyobj = {}
            notifyobj.c = PDEFINE.NOTIFY.coin
            notifyobj.code = PDEFINE.RET.SUCCESS
            notifyobj.uid = UID
            notifyobj.deskid = 0
            notifyobj.count = 0
            notifyobj.coin = coin
            notifyobj.diamond = diamond
            notifyobj.addDiamond = 0
            notifyobj.type = 1
            notifyobj.rewards = {}
            handle.sendToClient(cjson.encode(notifyobj))
        end
    end

    handle.moduleCall("quest", 'updateQuest', UID, PDEFINE.QUEST_TYPE.NEWER, PDEFINE.QUESTID.NEW.SENDGIFT, 1)

    local sql = string.format("insert into d_user_sendcharm(uid1, uid2, create_time, charmid,title,title_al,img,coin,charm) values (%d, %d, %d, %d,'%s','%s','%s',%d,%d)", UID, frienduid, now, id, item.title, item.title_al,item.img, item.count, item.charm) --默认为不能领
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    LOG_DEBUG('d_user_sendcharm insertid:', rs.insert_id)
    if rs and rs.insert_id then
        local content = string.format("%d;%d;%d", frienduid, id, rs.insert_id)
        handle.sendInviteMsg(content, PDEFINE.CHAT.MsgType.CHARM)
    end

    pcall(cluster.call, "master", ".userCenter", "updateFriendCharm", frienduid, item.charm) --更新好友魅力值
    if item.lamp > 0 then
        -- 全服广播魅力值赠送消息跑马灯
        pcall(cluster.send, "master", ".userCenter", "sendGiftNotice", UID, frienduid, item.charm, item.title, item.title_al)
    end

    --广播动画
    local friendInfo = handle.moduleCall("player", "getPlayerInfo", frienduid)
    -- handle.dcCall("user_dc", "user_addvalue", UID, "charm", item.charm) 
    pcall(cluster.send, "master", ".userCenter", "updateFriendCharm", UID, item.charm)
    local sender = {
        uid = UID,
        playername = userInfo.playername,
        usericon = userInfo.usericon,
        level = userInfo.level,
        svip = userInfo.svip,
        charm = userInfo.charm or 0,
        avatarframe = userInfo.avatarframe or '',
    }
    local recevier = {
        uid = frienduid,
        playername = friendInfo.playername or '',
        usericon = friendInfo.usericon or '',
        level = friendInfo.level or 1,
        svip = friendInfo.svip or 0,
        charm = friendInfo.charm or 0,
        avatarframe = friendInfo.avatarframe or '',
    }
    local msg = {c=PDEFINE.NOTIFY.CHARM_INFO, code=PDEFINE.RET.SUCCESS, receive= recevier, send=sender,}
    msg.info = {
        id = item.id,
        img = item.img,
        title = item.title,
        title_al = item.title_al,
        coin = item.coin,
        charm = item.charm
    }
    LOG_DEBUG("charm send msg:", msg)
    pcall(cluster.call, "master", ".userCenter", "pushInfo", cjson.encode(msg))
    retobj.recevier = {
        uid = frienduid,
        charm = friendInfo.charm
    }
    local charmlist = get_send_charm_list(UID)
    retobj.charmlist = charmlist
    handle.syncUserInfo({uid=UID, charmlist = charmlist})

    -- 更新主线任务
    -- local updateMainObjs = {
    --     {kind=PDEFINE.MAIN_TASK.KIND.CharmGift, count=1},
    -- }
    -- handle.moduleCall("maintask", "updateTask", UID, updateMainObjs)

    return retobj
end

function cmd.sendInGame(id, frienduid)
    return sendCharm(GAME_SEND_CMD, id, frienduid)
end

--! 赠送道具
function cmd.send(msg)
    local recvobj = cjson.decode(msg)
    local uid = recvobj.uid
    local iscache = recvobj.cache --是否缓存请求
    local frienduid   = math.floor(recvobj.friendid)
    local id = math.floor(recvobj.id) --道具id

    if not iscache then
        handle.addStatistics(uid, 'send_charm', id..','..frienduid)
    end
    local retobj = sendCharm(math.floor(recvobj.c), id, frienduid)
    return resp(retobj)
end

--! 赠送列表
function cmd.sendList(msg)
    local recvobj   = cjson.decode(msg)
    local curPage   = math.floor(recvobj.page or 1)
    if curPage < 1 then
        curPage = 1
    end
    
    local pageSize = 20
    local start = (curPage -1) * pageSize
    local sql = string.format("select count(*) as t from d_user_sendcharm where uid1=%d", UID)
    local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
    local hasNextPage = false
    if #rs > 0 and rs[1].t>(curPage*pageSize) then
        hasNextPage = true
    end

    local sql = string.format("select * from d_user_sendcharm where uid1=%d order by id desc limit %d, %d", UID, start, pageSize)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local items = {}
    if #rs > 0 then
        local UIDs = {}
        for _, _item in pairs(rs) do
           table.insert(UIDs, _item.uids)
        end
        local _, onlinelist = pcall(cluster.call, "master", ".userCenter", "checkOnline", UIDs)
        for _, _item in pairs(rs) do
            local friendInfo = handle.moduleCall("player", "getPlayerInfo", _item.uid2)
            local item = {
                id = _item.id,
                charmid = _item.charmid,
                title = _item.title,
                img = _item.img,
                coin = _item.coin,
                time = _item.create_time,
                uid = _item.uid2,
                playername = friendInfo.playername,
                usericon = friendInfo.usericon,
                avatarframe = friendInfo.avatarframe,
                isonline = 0,
            }
            if nil ~= onlinelist and nil ~= onlinelist[_item.uid] then
                item.isonline = 1
            end
            table.insert(items, item)
        end
    end
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, curPage = curPage, hasNextPage = hasNextPage, data = items, spcode=0}
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 接收列表
function cmd.receiveList(msg)
    local recvobj   = cjson.decode(msg)
    local curPage   = math.floor(recvobj.page or 1)
    if curPage < 1 then
        curPage = 1
    end
    local pageSize = 20
    local start = (curPage -1) * pageSize
    local sql = string.format("select count(*) as t from d_user_sendcharm where uid2=%d", UID)
    local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
    local hasNextPage = false
    if #rs > 0 and rs[1].t>(curPage*pageSize) then
        hasNextPage = true
    end
    
    local sql = string.format("select * from d_user_sendcharm where uid2=%d order by id desc limit %d, %d", UID, start, pageSize)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local items = {}
    if #rs > 0 then
        local UIDs = {}
        for _, _item in pairs(rs) do
           table.insert(UIDs, _item.uids)
        end
        local _, onlinelist = pcall(cluster.call, "master", ".userCenter", "checkOnline", UIDs)
        for _, _item in pairs(rs) do
            local friendInfo = handle.moduleCall("player", "getPlayerInfo", _item.uid1)
            local item = {
                id = _item.id,
                charmid = _item.charmid,
                title = _item.title,
                img = _item.img,
                coin = _item.coin,
                time = _item.create_time,
                uid = _item.uid1,
                playername = friendInfo.playername,
                usericon = friendInfo.usericon,
                avatarframe = friendInfo.avatarframe,
                isonline = 0,
            }
            if nil ~= onlinelist and nil ~= onlinelist[_item.uid] then
                item.isonline = 1
            end
            table.insert(items, item)
        end
    end
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, curPage = curPage, hasNextPage = hasNextPage, data = items, spcode=0}
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 自己的背包中购买魅力值道具
function cmd.buy(msg)
    local recvobj   = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local img = recvobj.img or ""
    -- local id = math.floor(recvobj.id or 0)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, img=img}
	
    local ok, row = pcall(cluster.call, "master", ".configmgr", "getCharmPropList")
    local item
    for _, rs in pairs(row) do
        if rs.img == img then
            item = rs
            break
        end
    end
    if item == nil then
        retobj.spcode = PDEFINE.RET.ERROR.CHARM_SEND
        handle.addStatistics(uid, 'charm_buy', '1', 0, 3, item.id)
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    local prodId = tonumber(item.type) --prod_id
    local count = item.count
    local userInfo = handle.moduleCall("player", "getPlayerInfo", UID)
    LOG_DEBUG("user charm.buy uid:", UID , ' charmid:', prodId, ' prodId:', prodId, ' prize:', count, ' img:', item.img)
    if prodId == PDEFINE.PROP_ID.COIN and userInfo.coin < count then
        retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        handle.addStatistics(uid, 'charm_buy', '2', 0, 3, item.id)
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    if prodId == PDEFINE.PROP_ID.DIAMOND and userInfo.diamond < count then
        retobj.spcode = PDEFINE.RET.ERROR.LEAGUE_USER_DIAMOND
        handle.addStatistics(uid, 'charm_buy', '3', 0, 3, item.id)
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    local skin = {
        ['id'] = item.id,
        ['title'] = item.title or item.title_al,
        ['img'] = item.img or "",
        ['diamond'] = item.count or 0,
        ['tbl'] = 's_send_charm',
    }
    handle.addProp(prodId, -count, 'charm', nil, 'buy_charm_skin', cjson.encode(skin)) --扣金币
    add_send_charm_times(uid, item.img)
    local diamond = handle.dcCall("user_dc", "getvalue", UID, "diamond")
    local coin = handle.dcCall("user_dc", "getvalue", UID, "coin")
    local notifyobj = {}
    notifyobj.c = PDEFINE.NOTIFY.coin
    notifyobj.code = PDEFINE.RET.SUCCESS
    notifyobj.uid = UID
    notifyobj.deskid = 0
    notifyobj.count = 0
    notifyobj.coin = coin
    notifyobj.diamond = diamond
    notifyobj.addDiamond = 0
    notifyobj.type = 1
    notifyobj.rewards = {}
    handle.sendToClient(cjson.encode(notifyobj))
    handle.addStatistics(uid, 'charm_buy', '0', 0, 3, item.id)
    local charmlist = get_send_charm_list(UID)
    handle.syncUserInfo({uid=UID, charmlist=charmlist})
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--!获取新人大礼包
function cmd.getCharmPack(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)

    local retobj = {c = math.floor(recvobj.c) , code = PDEFINE.RET.SUCCESS, spcode = 0, rewards={}}
    local ispopbindphone = 0
    local ok, row = pcall(cluster.call, "master", ".configmgr", "get", "popbindphone")
    if ok then
        ispopbindphone = tonumber(row.v or 0)
    end

    local userInfo = handle.moduleCall("player", "getPlayerInfo", UID)
    if (nil==userInfo.isbindphone or userInfo.isbindphone == 0) and ispopbindphone == 1 then
        retobj.code = PDEFINE.RET.ERROR.GAME_NOT_BIND_PHONE
        return resp(retobj)
    end
    
    if os.time() < getCharmPackTime + 30 then
        retobj.spcode = PDEFINE.RET.ERROR.CHARM_GIFT_PACK_GETED
        return resp(retobj)
    end
    getCharmPackTime = os.time()

    local time = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.CHARM_GIFT_PACK)
    if time > 0 then
        retobj.spcode = PDEFINE.RET.ERROR.CHARM_GIFT_PACK_GETED
        handle.addStatistics(uid, 'newcome_gift', retobj.spcode)
        return resp(retobj)
    end
    handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.CHARM_GIFT_PACK, os.time())

    

    local leftCoin = userInfo.coin
    local leftDiamond = userInfo.diamond
    local ok, row = pcall(cluster.call, "master", ".configmgr", "get", 'charmpack')
    if not ok then
        retobj.spcode = PDEFINE.RET.ERROR.CALL_FAIL
        return resp(retobj)
    end
    local addCoin = tonumber(row.v)
    handle.addProp(PDEFINE.PROP_ID.COIN, addCoin, 'charm_giftpack', 0, '新手大礼包')
    table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN, count=addCoin})
    -- for _, item in pairs(PDEFINE.CHARM_GIFT_PACK) do
    --     if item.type == PDEFINE.PROP_ID.SKIN_CHARM then
    --         table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.SKIN_CHARM, count=item.count, img=item.img})
    --         for i=1, item.count do
    --             add_send_charm_times(uid, item.img)
    --         end
    --     elseif item.type == PDEFINE.PROP_ID.COIN then
    --         table.insert(retobj.rewards, {type=item.type, count=item.count})
    --         handle.addProp(PDEFINE.PROP_ID.COIN, item.count, 'charm_giftpack', 0, '新手大礼包')
    --         addCoin = addCoin + item.count
    --     end
    -- end
    handle.addStatistics(uid, 'newcome_gift', retobj.spcode)
    handle.notifyCoinChanged((leftCoin+addCoin), leftDiamond, addCoin, 0)

    -- local charmlist = get_send_charm_list(UID)
    -- handle.syncUserInfo({uid=UID, charmlist=charmlist})
    return resp(retobj)
end

return cmd