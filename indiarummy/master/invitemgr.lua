-- 邀请管理
local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local queue     = require "skynet.queue"
local cjson = require "cjson"
local cs = queue()
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

--接口
local CMD = {}
-- 邀请好友有关
local PAGE_USERS = {} --用户停留的页面 1:ONLINE 2:VIP 3:LEAGUE
local USER_PAGE = {} --用户->page
local USER_VIP_GAME = {} --用户在vip页中的哪个游戏列表中

--! 检查用户是否还在等待匹配界面
function CMD.getRoomType(uid)
    if USER_PAGE[uid] == nil or USER_PAGE[uid] == PDEFINE.BAL_ROOM_TYPE.VIP then
        return 0
    end
    return USER_PAGE[uid]
end

--! 进入页面 call by node
-- 1:online 2:vip 3:league
function CMD.enter(uid, rtype, gameid)
    if nil == PAGE_USERS[rtype] then
        PAGE_USERS[rtype] = {}
    end
    local old_type = USER_PAGE[uid]
    if old_type ~= nil and old_type ~= rtype then
        for i=#PAGE_USERS[old_type], 1, -1 do
            if PAGE_USERS[old_type][i] == uid then
                table.remove(PAGE_USERS[old_type], i)
                break
            end
        end
    end
    if rtype == PDEFINE.BAL_ROOM_TYPE.VIP then
        USER_VIP_GAME[uid] = gameid
    end
    USER_PAGE[uid] = rtype
    if not table.contain(PAGE_USERS[rtype], uid) then
        table.insert(PAGE_USERS[rtype], uid)
    end
    LOG_DEBUG("after enter: USER_PAGE:", USER_PAGE)
    LOG_DEBUG("after enter: PAGE_USERS:", PAGE_USERS)
end

--! 离开页面
function CMD.leave(uids, rtype)
    LOG_DEBUG("CMD.leave uids:", uids, ' rtype:', rtype)
    for _, uid in pairs(uids) do
        if rtype then --主动离开
            if nil ~= PAGE_USERS[rtype] then
                for i=#PAGE_USERS[rtype], 1, -1 do
                    if PAGE_USERS[rtype][i] == uid then
                        table.remove(PAGE_USERS[rtype], i)
                        break
                    end
                end
            end
            if rtype == PDEFINE.BAL_ROOM_TYPE.VIP and nil ~= USER_VIP_GAME[uid] then
                USER_VIP_GAME[uid] = nil
            end
        else    --断线或关闭app
            for j=1, 3 do
                local stop = false
                if nil ~= PAGE_USERS[j] then
                    for i=#PAGE_USERS[j], 1, -1 do
                        if PAGE_USERS[j][i] == uid then
                            table.remove(PAGE_USERS[j], i)
                            stop = true
                            break
                        end
                    end
                end
                if j == PDEFINE.BAL_ROOM_TYPE.VIP and nil ~= USER_VIP_GAME[uid] then
                    USER_VIP_GAME[uid] = nil
                end
                if stop then
                    break
                end
            end
        end
        LOG_DEBUG("CMD.leave uid:", uid, ' USER_PAGE:', USER_PAGE[uid])
        if USER_PAGE[uid] ~= nil then
            if USER_PAGE[uid] ~= PDEFINE.BAL_ROOM_TYPE.VIP then
                pcall(cluster.call, "master", ".userCenter", "leagueAct", uid, "leavePage")
            end
        end
        USER_PAGE[uid] = nil
    end
end

--! 获取这个页面上的所有用户
function CMD.getUidsByRoomType(roomtype)
    return PAGE_USERS[roomtype]
end

function CMD.getVipListUIDAndGame(rtype)
    local rtype = PDEFINE.BAL_ROOM_TYPE.VIP
    return PAGE_USERS[rtype], USER_VIP_GAME
end

function CMD.getRoomListUIDAndGame(rtype)
    return PAGE_USERS[rtype], USER_VIP_GAME
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = assert(CMD[cmd])
        skynet.retpack(f(...))
	end)
    skynet.register(".invitemgr")
    collectgarbage("collect")
end)