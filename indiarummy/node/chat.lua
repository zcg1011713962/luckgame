local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local queue = require "skynet.queue"
local cjson = require "cjson"
local player_tool = require "base.player_tool"
local clubDb = require "base.club_db"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local cs = queue()
local CMD = {}

local MaxSize = 100 -- 保留聊天记录条数
local REDISQUEUE = "chat_list"
local ClubRedisMsg = "chat_club:"
local ClubChatId = "chat_id_club:"
local MsgType = PDEFINE.CHAT.MsgType
local USERS = {}

local RoomStatus = {
    Active = 1,  -- 可用的
    Disabled = 2,  -- 不可用
}

--世界聊天服

local Queue = {}
function Queue.new ()
  return {first = 0,last = -1}
end

function Queue.pushleft(list,value)
    local first = list.first - 1
    list.first = first
    list[first] = value
  end

function Queue.pushright(list,value)
    local last = list.last + 1
    list.last = last
    list[last] = value
end

function Queue.popleft(list)
    local first = list.first
    if first > list.last then return end
    local value = list[first]
    list[first] = nil        -- to allow garbage collection
    list.first = first + 1
    return value
end

function Queue.popright(list)
    local last = list.last
    if list.first > last then return end
    local value = list[last]
    list[last] = nil         -- to allow garbage collection
    list.last = last - 1
    return value
end

local Items       --最近1000条聊天记录
local ClubChats = {}   -- 俱乐部聊天室, 存放玩家
local ClubChatMsg = {}  -- 俱乐部聊天室记录

local function genChatId(cid)
    local redis_key = 'chatId:0001'
    if cid then
        redis_key = ClubChatId..cid
    end
    local id = do_redis({'incr', redis_key})
    return id
end

local function timeout(outtime, func, uid, cid, nowtime)
    local function t()
        if func then
            func(uid, cid, nowtime)
        end
    end
    skynet.timeout(outtime, t)
    return function() func = nil end
end

-- 服务器启动 初始化数据
local function initClubMsg(cid)
    local items = Queue.new()
    local rs = do_redis({"zrevrangebyscore", ClubRedisMsg..cid, 50, 1})
    rs = make_pairs_table(rs)
    if rs ~= nil then
        for jsonstr, _ in pairs(rs) do
            if jsonstr ~= nil and jsonstr ~="null" then
                local ok, item = pcall(jsondecode, jsonstr)
                if ok and item ~= nil and type(item) == 'table' then
                    -- 重启，则将所有房间邀请信息，都置为过期
                    -- 需求更改，过期后都不显示了，所以不需要加到缓存中
                    if tonumber(item.stype) == MsgType.PrivateRoom or tonumber(item.stype) == MsgType.ClubRoom then
                        if item.room then
                            item.room.status = RoomStatus.Disabled
                        else
                            item.room = {
                                statue = RoomStatus.Disabled
                            }
                        end
                    else
                        Queue.pushright(items, item)
                    end
                end
            end
        end
    end
    ClubChatMsg[cid] = items
end

-- 给同一俱乐部的不在线的用户推送消息
local function pushNotice(cid)
    if not cid then
        return
    end
    local res = clubDb.getClubAllUid(cid)
    local uids = {}
    for _, row in pairs(res) do
        table.insert(uids, row['uid'])
    end
    -- local ok , online_list = pcall(cluster.call, "master", ".userCenter", "checkOnline", uids)
    -- if ok then
    --     for i=#uids, 1, -1 do
    --         if nil ~= online_list[uids[i]] then
    --             table.remove(uids, i)
    --         end
    --     end
    -- end
    if #uids > 0 then
        skynet.send('.pushmsg', 'lua', 'send', uids, PDEFINE.PUSHMSG.ONE)
    end
end

-- 生成新的对象
local function newChat(uid, cid, stype, content, create_time, packinfo)
    local playerInfo = player_tool.getSimplePlayerInfo(uid)
    if nil ~= playerInfo then
        local newMsgID = genChatId(cid)
        local item = {
            ["id"] = newMsgID,
            ["uid"] = uid,
            ["cid"] = cid,
            ["name"] = playerInfo.playername,
            ["levelexp"] = playerInfo.levelexp,
            ["avatar"] = playerInfo.usericon,
            ["avatarframe"] = playerInfo.avatarframe or 0,
            ["vip"] = playerInfo.svip or 0,
            ["stype"] = stype,
            ["create_time"] = create_time,
            ['chatskin'] = playerInfo.chatskin or 0, --聊天框
            ['frontskin'] = playerInfo.frontskin or 0,
        }
        if stype == MsgType.Emoji then
            item['content'] = content
        elseif stype == MsgType.VipRoom then
            local users = {}
            item['viproom'] = {
                ["deskid"] = packinfo.deskid,
                ["entry"] = packinfo.entry,
                ['open'] = 1, --是否能加入
                ['users'] = users --TODO: vip房间暂时未做分享
            }
        elseif stype == PDEFINE.CHAT.MsgType.CHARM  then
            item['content'] = content
            if type(content) == 'string' then
                local info = string.split_to_number(content, ";")
                local sql = string.format("select * from d_user_sendcharm where id=%d", info[3])
                local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
                if #rs > 0 and rs[1] then
                    local friendInfo = player_tool.getSimplePlayerInfo(rs[1].uid2)
                    if nil == friendInfo then
                        friendInfo = {
                            uid = rs[1].uid2,
                            playername = "Guest"..rs[1].uid2,
                            levelexp = 1,
                            avatar = 1,
                            avatarframe = '',
                        }
                    end
                    item['charmpack'] = {
                        ["uid"] = rs[1].uid2,
                        ["name"] = friendInfo.playername or "",
                        ["levelexp"] = friendInfo.levelexp or 1,
                        ["avatar"] = friendInfo.usericon or "",
                        ["avatarframe"] = friendInfo.avatarframe or 0,
                        ["vip"] = friendInfo.svip or 0,
                        ["charmid"] = rs[1].charmid,
                        ["create_time"] = rs[1].charmid,
                        ["title"] = {
                            ['ar'] = rs[1].title_al,
                            ['en'] = rs[1].title,
                        },
                        ["img"] = rs[1].img,
                        ["charm"] = rs[1].charm,
                    }
                end
            end
        elseif stype == MsgType.PrivateRoom or stype == MsgType.ClubRoom then
            item['content'] = content
            if type(content) == 'string' then
                local info = string.split_to_number(content, ";")
                local users = {}
                local ok, deskAgent
                if stype == MsgType.ClubRoom then
                    ok, deskAgent = pcall(cluster.call, "master", ".balclubroommgr", "getDeskInfoFromCache", info[2], info[1], cid)
                else
                    ok, deskAgent = pcall(cluster.call, "master", ".balprivateroommgr", "getDeskInfoFromCache", info[2], info[1])
                end
                local roominfo = {
                    gameid = info[1],
                    deskid = info[2],
                    status = RoomStatus.Active,
                    private = 0, --无密码
                    users = {}
                }
                if deskAgent.pwd and deskAgent.pwd ~= "" then
                    roominfo['private'] = 1
                end
                if ok and deskAgent then
                    local ok, deskInfo = pcall(cluster.call, deskAgent.server, deskAgent.address, "getDeskInfo", {uid=0})
                    if ok and deskInfo then
                        for _, userInfo in pairs(deskInfo.users) do
                            table.insert(users, {
                                ['uid'] = userInfo.uid,
                                ['playername'] = userInfo.playername,
                                ['usericon'] = userInfo.usericon,
                                ['avatarframe'] = userInfo.avatarframe
                            })
                        end
                        roominfo['entry'] = deskInfo.bet
                    end
                end
                roominfo['users'] = users
                item['room'] = roominfo
            end
            if stype == MsgType.ClubRoom then
                user_timeout_call(100, pushNotice, cid)
            end
        elseif stype == MsgType.LevelUp then
            item['level'] = packinfo.level
            item['msg'] = {}
            item['rewards'] = packinfo.rewards
            for lang, msg in pairs(content) do
                if lang == PDEFINE.USER_LANGUAGE.Arabic then
                    item['msg']['ar'] = msg
                elseif lang == PDEFINE.USER_LANGUAGE.English then
                    item['msg']['en'] = msg
                end
            end
        else
            item['content'] = content
        end
        return item
    end
end

local function addRecord(item, create_time)
    local ext = {}
    if item.stype == MsgType.VipRoom then
        ext = item.viproom
    elseif item.stype == MsgType.CHARM then
        ext = item.charmpack 
    elseif item.stype == MsgType.PrivateRoom or item.stype == MsgType.ClubRoom then
        ext = item.room
    elseif item.stype == MsgType.LevelUp then
        ext = {
            ['level'] = item.level,
            ['msg']   = item.msg,
            ['rewards'] = item.rewards,
        }
    end
    if nil == create_time then
        create_time = os.time()
    end
    local sql = string.format([[
        insert into d_chat(create_time,msgid,uid,cid,stype,name,levelexp,avatar,svip,avatarframe,chatskin,frontskin,content,ext) 
                    value (%d,%d,%d, %d, %d,'%s',%d,      '%s',  %d,  '%s',       '%s',    '%s',     '%s', '%s')
    ]], create_time, item.id, item.uid, item.cid or 0, item.stype, mysqlEscapeString(item.name), item.levelexp, item.avatar, item.vip, item.avatarframe, item.chatskin, item.frontskin, mysqlEscapeString(item.content), mysqlEscapeString(cjson.encode(ext)))
    do_mysql_queue(sql)
end

-- 广播消息给所有聊天室用户
local function broadcast(item, cid, create_time)
    addRecord(item, create_time) --延迟到这里来加记录
    local retobj = {c=PDEFINE.NOTIFY.NOTIFY_CHAT_CONTENT, code= PDEFINE.RET.SUCCESS, data = {items={}}, cid=cid}
    table.insert(retobj.data.items, item)
    local msg = cjson.encode(retobj)
    local users = cid and ClubChats[cid] or USERS
    for i = 1, #users do
        -- 这里要排除下送礼，送礼自己也要广播
        if users[i] ~= item.uid or item.stype == PDEFINE.CHAT.MsgType.CHARM then
            pcall(cluster.call, "master", ".userCenter", "pushInfoByUid", users[i], msg)
        end
    end
end

local function broadcastChangeMsg(userInfo, desk, cid)
    local retobj = {c=PDEFINE.NOTIFY.NOTIFY_CHANGE_CHAT, code= PDEFINE.RET.SUCCESS, room=desk, userInfo = userInfo, cid=cid}
    local msg = cjson.encode(retobj)
    local allUsers
    if cid then
        allUsers = {USERS, ClubChats[cid]}
    else
        allUsers = {USERS}
    end
    for _, users in ipairs(allUsers) do
        for i = 1, #users do
            pcall(cluster.call, "master", ".userCenter", "pushInfoByUid", users[i], msg)
        end
    end
end

-- 往数据库里添加聊天内容
local function addItem(uid, stype, content, packinfo, cid)
    return cs(
        function()
            local nowtime = os.time()
            local item = newChat(uid, cid, stype, content, nowtime,packinfo)
            LOG_DEBUG("chat addItem item:", uid, cid, stype, content)
            local items = cid and ClubChatMsg[cid] or Items
            Queue.pushright(items, item)
            if (items.last - items.first) >= MaxSize then
                Queue.popleft(items)
            end
            local json = cjson.encode(item)
            if cid then
                do_redis({"zadd", ClubRedisMsg..cid, nowtime, json})
            else
                do_redis({"zadd", REDISQUEUE, nowtime, json})
            end
            timeout(80, broadcast, item, cid, nowtime)
            
            return item
        end
    )
end

--! 桌子未开始前，同步用户信息
function CMD.changeDeskInfoUsers(deskid, gameid, users, cid)
    local roomUsers = {}
    for _, userInfo in pairs(users) do
        table.insert(roomUsers, {
            ['uid'] = userInfo.uid,
            ['playername'] = userInfo.playername,
            ['usericon'] = userInfo.usericon,
            ['avatarframe'] = userInfo.avatarframe
        })
    end


    local desk = {
        deskid=deskid,
        gameid=gameid,
        status=RoomStatus.Active,
        users = roomUsers
    }
    local allItems
    if cid and ClubChatMsg[cid] then
        allItems = {Items, ClubChatMsg[cid]}
    else
        allItems = {Items}
    end
    local hasDesk = false  -- 是否包含该房间，如果没有，则不需要广播
    for _, items in ipairs(allItems) do
        if items.last >= items.first then
            for i = items.first, items.last do
                if nil ~= items[i] and (items[i].stype == MsgType.PrivateRoom or items[i].stype == MsgType.ClubRoom) then
                    local room = items[i].room
                    if room and tonumber(room.deskid) == tonumber(deskid) and tonumber(room.gameid) == tonumber(gameid) then
                        LOG_DEBUG("roomStart item msgid:", items[i].id)
                        items[i]['room']['users'] = roomUsers
                        hasDesk = true
                        break
                    end
                end
            end
        end
    end
    if hasDesk then
        broadcastChangeMsg(nil, desk, cid)
    end
end

--! 用户修改了资料，同步到世界聊天中 call by player
function CMD.changeUserData(userInfo, cid)
    local changedMsg = {
        uid = userInfo.uid,
        vip = userInfo.svip,
        avatarframe = userInfo.avatarframe,
        playername = userInfo.playername,
        levelexp = userInfo.levelexp,
        avatar = userInfo.usericon,
        chatskin = userInfo.chatskin,
        frontskin = userInfo.frontskin,
    }
    local allItems = {Items}
    broadcastChangeMsg(changedMsg, nil, nil)
    
    for _, items in ipairs(allItems) do
        if items.last >= items.first then
            for i = items.first, items.last do
                if nil ~= items[i] and items[i].uid == userInfo.uid then
                    LOG_DEBUG("changeUserData item msgid:", items[i].id)
                    items[i].vip = userInfo.svip
                    items[i].avatarframe = userInfo.avatarframe
                    items[i].name = userInfo.playername
                    items[i].levelexp = userInfo.levelexp
                    items[i].avatar = userInfo.usericon
                    items[i].chatskin = userInfo.chatskin
                    items[i].frontskin = userInfo.frontskin
                end
            end
        end
    end
    if not cid then
        local clubInfo = clubDb.getClubByUid(userInfo.uid)
        if clubInfo then
            cid = clubInfo.cid
        end
    end
    if cid and ClubChatMsg[cid] then
        allItems = {Items, ClubChatMsg[cid]}
        broadcastChangeMsg(changedMsg, nil, cid)
        for _, items in ipairs(allItems) do
            if items.last >= items.first then
                for i = items.first, items.last do
                    if nil ~= items[i] and items[i].uid == userInfo.uid then
                        LOG_DEBUG("changeUserData item msgid:", items[i].id, " cid:", cid)
                        items[i].vip = userInfo.svip
                        items[i].avatarframe = userInfo.avatarframe
                        items[i].name = userInfo.playername
                        items[i].levelexp = userInfo.levelexp
                        items[i].avatar = userInfo.usericon
                        items[i].chatskin = userInfo.chatskin
                        items[i].frontskin = userInfo.frontskin
                    end
                end
            end
        end
    end
end

local function rmItem(msgid)
    return cs(
        function()
            local del = false
            if Items.last >= Items.first then
                for i = Items.last, Items.first, -1 do
                    if nil ~= Items[i] then
                        LOG_DEBUG(Items[i].id , ' vs ', msgid)
                    end
                    if nil ~= Items[i] and (tonumber(Items[i].id) == msgid) then
                        -- table.remove(Items, i)
                        Items[i] = nil
                        del = true
                        LOG_DEBUG(' delItems i ', i)
                        break
                    end
                end
            end
            return del
        end
    )
end

-- 删除记录, 支持单条或者多条
function CMD.delItems(msgids)
    LOG_DEBUG('delItems:', msgids)
    local arr = string.split_to_number(msgids, ',')
    LOG_DEBUG('delItems:', arr)
    for _, msgid in pairs(arr) do
        if nil ~= msgid and msgid > 0 then
            local del = rmItem(msgid) --是否已删除
            LOG_DEBUG('delItems result del ', del)
            if del then
                local sql = string.format("select msgid, create_time from d_chat where msgid=%d", msgid)
                local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
                LOG_DEBUG('delItems rs: ', rs)
                if #rs > 0 then
                    do_redis({"zremrangebyscore", REDISQUEUE, rs[1].create_time, rs[1].create_time})
                    local retobj = {c=PDEFINE.NOTIFY.NOTIFY_CHAT_DEL, code= PDEFINE.RET.SUCCESS, msgid=msgid}
                    local msg = cjson.encode(retobj)
                    local users = USERS
                    for i = 1, #users do
                        LOG_DEBUG('delItems send uid ', users[i])
                        pcall(cluster.send, "master", ".userCenter", "pushInfoByUid", users[i], msg)
                    end
                end
            end
        end
    end
    return PDEFINE.RET.SUCCESS
end



function CMD.roomStart(deskid, gameid, cid)
    local desk = {
        deskid=deskid,
        gameid=gameid,
        status=RoomStatus.Disabled
    }
    local allItems
    if cid and ClubChatMsg[cid] then
        allItems = {Items, ClubChatMsg[cid]}
    else
        allItems = {Items}
    end
    local hasDesk = false  -- 是否包含该房间，如果没有，则不需要广播
    for _, items in ipairs(allItems) do
        if items.last >= items.first then
            for i = items.first, items.last do
                if nil ~= items[i] and (items[i].stype == MsgType.PrivateRoom or items[i].stype == MsgType.ClubRoom) then
                    local room = items[i].room
                    if room and tonumber(room.deskid) == tonumber(deskid) and tonumber(room.gameid) == tonumber(gameid) then
                        LOG_DEBUG("roomStart item msgid:", items[i].id)
                        room.status = RoomStatus.Disabled
                        hasDesk = true
                    end
                end
            end
        end
    end
    if hasDesk then
        broadcastChangeMsg(nil, desk, cid)
    end
end

-- 接受用户聊天
-- 如果带了cid，说明是俱乐部聊天
function CMD.chat(uid, cid, lastMsgID, content, stype)
    if cid then
        if not ClubChats[cid] then
            ClubChats[cid] = {}
        end
        if not table.contain(ClubChats[cid], uid) then
            table.insert(ClubChats[cid], uid)
        end
        if not ClubChatMsg[cid] then
            initClubMsg(cid)
        end
    else
        if not table.contain(USERS, uid) then
            table.insert(USERS, uid)
        end
    end

    local resItems = {}
    if content ~="" then
        local packinfo = nil --TODO: 房间id信息等
        local item = addItem(uid, stype, content, packinfo, cid)
        table.insert(resItems, item)
        -- pcall(cluster.send, "master", ".userCenter", "updateQuest", uid, PDEFINE.QUESTID.NEW.SPEAKINWORD, 1)
        return resItems
    end

    local items = cid and ClubChatMsg[cid] or Items

    if items.last >= items.first then
        local start = items.first
        if (items.last - items.first) > MaxSize then
            start = items.last - MaxSize
        end
        if items.last - start > 20 then
            start = items.last - 20
        end
        for i = start, items.last do
            if nil ~= items[i] then
                if items[i].id > lastMsgID then
                    if stype == nil or (items[i].stype == stype) then
                        if items[i].stype == MsgType.VipRoom then
                            -- Items[i].viproom.open = 1
                            LOG_DEBUG('cardshare.packid: i:',i, ' packid: ', items[i].cardshare.packid)
                            -- if getPackOpenTag(Items[i].cardshare.packid, uid) then
                            --     Items[i].viproom.open = 0
                            -- end
                        end
                        if nil == items[i].vip or nil == items[i].avatarframe then
                            local playerInfo = player_tool.getSimplePlayerInfo(uid)
                            items[i].vip = playerInfo.svip
                            items[i].avatarframe = playerInfo.avatarframe
                        end
                        -- 需求更改，过期后都不显示了，所以不需要发送给前端
                        -- if not items[i].room or items[i].room.status == RoomStatus.Active then
                            table.insert(resItems, items[i])
                        -- end
                    end
                end
            else
                LOG_DEBUG("itemis nil 这个i为nil了:",i, items)
            end
        end
    end
    return resItems
end

-- 接受用户分享的卡牌活动信息
function CMD.addShareItem(uid, cardid, packid)
    if cardid <= 0 then
        return
    end
    local packinfo = {
        cardid = cardid,
        packid = packid
    }
    addItem(uid, 3, '', packinfo)
end

-- 用户升级发送升级消息
function CMD.userLevelUp(uid, msg, packinfo)
    addItem(uid, MsgType.LevelUp, msg, packinfo)
end

-- 服务器启动 初始化数据
local function initItems()
    Items = Queue.new()
    local rs = do_redis({"zrevrangebyscore", REDISQUEUE, MaxSize, 0})
    if rs ~= nil and #rs > 0 then
        for i = #rs, 1, -1 do
            local jsonstr = rs[i]
            if jsonstr ~= nil and jsonstr ~="null" then
                local ok, item = pcall(jsondecode, jsonstr)
                if ok and item ~= nil and type(item) == 'table' then
                    if tonumber(item.stype) == MsgType.PrivateRoom or tonumber(item.stype) == MsgType.ClubRoom then
                        if item.room then
                            item.room.status = RoomStatus.Disabled
                        else
                            item.room = {
                                statue = RoomStatus.Disabled
                            }
                        end
                    end
                    Queue.pushright(Items, item)
                end
            end
        end
    end
end

function CMD.start()
    initItems()
end

-- 清空聊天室
function CMD.cleardata()
    do_redis({"del", REDISQUEUE})
    initItems();
    local retobj = {c=PDEFINE.NOTIFY.NOTIFY_CLEAR_CHAT, code= PDEFINE.RET.SUCCESS}
    local msg = cjson.encode(retobj)
    local users = USERS
    for i = 1, #users do
        pcall(cluster.send, "master", ".userCenter", "pushInfoByUid", users[i], msg)
    end
end

-- 心跳
function CMD.heartbeat(uid, cid)
    if not uid then
        return
    end
    if cid then
        if not ClubChats[cid] then
            ClubChats[cid] = {}
        end
        if not table.contain(ClubChats[cid], uid) then
            table.insert(ClubChats[cid], uid)
        end
        if not ClubChatMsg[cid] then
            initClubMsg(cid)
        end
    else
        if not table.contain(USERS, uid) then
            table.insert(USERS, uid)
        end
    end
end

-- 离开聊天室
function CMD.leave(uid, cid)
    if not uid then
        return
    end
    if cid then
        if not ClubChats[cid] then
            ClubChats[cid] = {}
        end
        if table.contain(ClubChats[cid], uid) then
            for i=#ClubChats[cid], 1 , -1 do
                if ClubChats[cid][i] == uid then
                    table.remove(ClubChats[cid], i)
                    break
                end
            end
        end
    else
        if table.contain(USERS, uid) then
            for i=#USERS, 1 , -1 do
                if USERS[i] == uid then
                    table.remove(USERS, i)
                    break
                end
            end
        end
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".chat")
end)