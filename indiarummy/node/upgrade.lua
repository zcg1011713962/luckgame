local skynet = require "skynet"
require "skynet.manager"
local cjson = require "cjson"
local cluster = require "cluster"
local player_tool = require "base.player_tool"
local maintaskCfg = require "conf.maintaskCfg"
local sysmarquee = require "sysmarquee"

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

--升级： 用户个人等级 和 排位赛个人升级

local CMD = {}
local handle
local UID
local level_list = {} --个人等级
local league_list = {} --排位赛信息
local VIP_UP_CFG = {} --vip升级配置(用户消耗钻石，vip升级)

local MIN_QUESTID = 33
local MAX_QUESTID = 62
local questid_list = {} --user level quest
local DIRECT_VIP5_LEVEL = 4 --直冲到VIP3

local function initVIPUpCfg()
    local ok, res = pcall(cluster.call, "master", ".configmgr", "getVipUpCfg")
    if ok then
        VIP_UP_CFG = res
    end
end

-- 加载升级相关配置数据
local function loadConfig()
    local ok, res = pcall(cluster.call, "master", ".cfglevel", "getAll")
    if ok then
        level_list = res
    end

    ok, res = pcall(cluster.call, "master", ".cfgleague", "getAll")
    if ok then
        league_list = res
    end

    for i = MIN_QUESTID, MAX_QUESTID do
        table.insert(questid_list, i)
    end

    for i = PDEFINE.VIPLEVELUP.MIN, PDEFINE.VIPLEVELUP.MAX do
        table.insert(questid_list, i)
    end

    initVIPUpCfg()
end

function CMD.initUid(uid)
    UID = uid
end

function CMD.init(uid)
    UID = uid
    loadConfig()
end

function CMD.bind(agent_handle)
	handle = agent_handle
end

function CMD.reload()
    loadConfig()
end

-- 获取等级信息
local function getLvInfo(lv)
    if nil == level_list[lv] then
        return {}
    end
    return level_list[lv]
end

-- 个人等级或vip等级上升 通知客户端
-- gameid: 游戏id
-- cur_level:级别
-- info: 下发的数据
-- type_str: 协议类型
-- coin: 加完后的金币
-- addcoin: 加多少金币
local function notifyMsg(gameid, curLevel, info, stype, coin, addCoin)
    coin = coin or 0
    local retobj = {c = PDEFINE.NOTIFY.UPDATE_VIP_INFO, code=PDEFINE.RET.SUCCESS, uid = UID, coin=coin, info = info, gameid=gameid}
    if stype == "level" then
        retobj.coin = coin
        retobj.c = PDEFINE.NOTIFY.UPDATE_LEVEL
        local lvInfo = getLvInfo(curLevel+1)
        retobj.next_level_reward = lvInfo.rewards or 0 --获取下一级的升级奖励
        retobj.info.coin = addCoin --升级真实奖励的金币数
    elseif stype == "levelexp" then
        retobj.c = PDEFINE.NOTIFY.UPDATE_LEVEL_EXP
    end
    handle.sendToClient(cjson.encode(retobj))
end

--个人经验值变化
local function notifyLevelExp(gameid, curLevel, curExp, betcoin, nextInfo)
    local ret = {}
    ret["levelexp"] = curExp + betcoin
    notifyMsg(gameid, curLevel, ret, "levelexp", nil, nil)
end

local function getCurrentLeagueLevel(totalscore)
    local target = 1
    for i=#league_list, 1, -1 do
        if totalscore >= league_list[i].score then
            target = i
            break
        end
    end
    return target
end

--等级经验直接升级跳跃
local function findNextLevel(curLevel, total, stype)
    local target = 0
    if stype == 'league' then
        for i=#league_list, curLevel, -1 do
            if total >= league_list[i].score then
                target = i
                break
            end
        end
    else
        for i=#level_list, 1, -1 do
            if total >= level_list[i].exp then
                target = i
                break
            end
        end
    end
    return target
end

--获取升级的金币奖励(包括跳级的情况)
local function findLevelUpReward(curLevel, nextLevel, stype, gameid)
    local rewards = 0
    if stype == 'league' then
        for i=curLevel+1, nextLevel do
            rewards = rewards + league_list[i].rewards
        end
    else
        for i=curLevel+1, nextLevel do
            rewards = rewards + level_list[i].rewards
        end
    end
    return rewards
end

-- 排位赛加经验值
local function betLeague(playerInfo, score, gameid)
    local addExp = score
    addExp = math.floor(addExp/100) --配合数值缩小
    LOG_DEBUG("betLeague uid:", UID, ' addLeague:', addExp, 'gameid:', gameid)
    local topLeagueLevel = getCurrentLeagueLevel(playerInfo.leagueexp)
    --只计算发邮件，具体取值还是从redis中获取
    local redis_key = string.format('rank_list:%s:%d', PDEFINE.RANK_TYPE.GAME_LEAGUE, gameid)
    local curExp = do_redis({"zscore", redis_key, UID}) --当前排位分
    if not curExp then
        curExp = 0
    else
        curExp = tonumber(curExp)
    end
    -- pcall(cluster.send, "master", ".winrankmgr", "addRank", UID, {{rtype=PDEFINE.RANK_TYPE.GAME_LEAGUE, gameid=gameid, coin=addExp}})


    -- local notify = {c = PDEFINE.NOTIFY.NOTIFY_LEAGUE_EXP, code=PDEFINE.RET.SUCCESS, uid=UID, gameid=gameid, exp=(curExp+addExp)}
    -- handle.sendToClient(cjson.encode(notify))

    -- local expAfterAdd = (curExp + addExp)
    -- local nextLevel = getCurrentLeagueLevel(expAfterAdd)
    -- if nextLevel > topLeagueLevel then --最高排位分升级了
    --     local leagueExp, _ = player_tool.getPlayerLeagueInfo(UID)
    --     if expAfterAdd > leagueExp then
    --         notify = {c = PDEFINE.NOTIFY.NOTIFY_LEAGUE_UPGRADE, code=PDEFINE.RET.SUCCESS, uid=UID, gameid=gameid, exp=expAfterAdd}
    --         handle.sendToClient(cjson.encode(notify))
    --     end
    --     handle.moduleCall("pass", "addExp", UID, (nextLevel-topLeagueLevel))
    -- end
end

--! 游戏结算加经验值
function CMD.bet(gameid, addexp, stype, roomtype)
    local playerInfo = handle.moduleCall("player", "getPlayerInfo", UID)
    if stype == 'league' then
        return betLeague(playerInfo, addexp, gameid)
    end
    local cur_level    = playerInfo.level or 1
    local cur_levelexp = playerInfo.levelexp or 0
    local cur_svip     = playerInfo.svip or 0
    local next_level_info = getLvInfo(cur_level+1) --下一级等级信息

    local up_data = {
        level      = cur_level,
        addlevelexp= addexp, --等级经验值增量
        svip       = cur_svip,
        addsvipexp = 0, --vip经验值增量
        addcoin    = 0,
    }
    notifyLevelExp(gameid, cur_level, cur_levelexp, addexp, next_level_info)
    local expAfterAdd = cur_levelexp + addexp
    LOG_DEBUG("CMD.bet cur_level:", cur_level, ' cur_levelexp:', cur_levelexp, ' addexp:', addexp, ' expAfterAdd:', expAfterAdd)
    local nextLevel = findNextLevel(cur_level, expAfterAdd, 'level')
    handle.dcCall("user_dc", "setvalue", UID, "levelexp", expAfterAdd)
    LOG_DEBUG("CMD.bet cur_level nextLevel:", nextLevel)
    if nextLevel > 0 and nextLevel~=cur_level then
        --可以升级, 比如，从第1级升级到第2级，那么当前我已经是第2级了，这里的next_level其实是第2级，实际需要从第2级升级到下1级(第3级)的经验值
        local levelInfoAfterUpGrade = getLvInfo(nextLevel)

        handle.dcCall("user_dc", "setvalue", UID, "level", levelInfoAfterUpGrade.level)
        local newLevelInfo = table.copy(levelInfoAfterUpGrade)
        newLevelInfo.id = nil
        newLevelInfo.levelexp = expAfterAdd
        
        -- 如果在游戏中,通知桌子更新信息
        pcall(cluster.send, "master", ".agentdesk", "callAgentFun", UID, 'updateUserInfo', UID)
      
        -- local levelAvatar = PDEFINE.SKIN.UPGRADE.AVATAR[nextLevel] --等级头像框奖励
        -- if levelAvatar ~= nil then
        --     handle.moduleCall("player", "addSkinImg", UID, levelAvatar.img, levelAvatar.category)
        -- end

        -- local levelChat = PDEFINE.SKIN.UPGRADE.CHAT[nextLevel] --等级聊天框奖励
        -- if levelChat ~= nil then
        --     handle.moduleCall("player", "addSkinImg", UID, levelChat.img, levelChat.category)
        -- end

        -- local levelTable = PDEFINE.SKIN.UPGRADE.TABLE[nextLevel] --等级桌面奖励
        -- if levelTable ~= nil then
        --     handle.moduleCall("player", "addSkinImg", UID, levelTable.img, levelTable.category)
        -- end

        local updateMsg = {uid=UID, level = levelInfoAfterUpGrade.level, levelexp=newLevelInfo.levelexp}
        handle.syncUserInfo(updateMsg)
    end
    
    handle.moduleCall("player", "setPersonalExp", UID, up_data)
    LOG_DEBUG("setPersonalExp: ", UID, "up_data: ", up_data)
    return up_data
end

local function get_level_by_exp(diamondUsed)
    if nil == diamondUsed or diamondUsed <= 0 then
        return -1 --基础vip
    end
    local target = -1
    if table.empty(VIP_UP_CFG) then
        initVIPUpCfg()
    end
    for i=#VIP_UP_CFG, 1, -1 do
        if diamondUsed >= VIP_UP_CFG[i].diamond then
            target = i
            break
        end
    end
    return target
end

local function sendVipChangedMsg(svip, svipexp)
    local notify = {c = PDEFINE.NOTIFY.UPDATE_VIP_INFO, code=PDEFINE.RET.SUCCESS, uid = UID, svip=svip, svipexp = svipexp}
    notify.nextvipexp = handle.getNextVipInfoExp(svip)
    handle.sendToClient(cjson.encode(notify))
    -- 更新主线任务
    -- local updateMainObjs = {
    --     {kind=PDEFINE.MAIN_TASK.KIND.VipLevel, count=svip},
    -- }
    -- handle.moduleCall("maintask", "updateTask", UID, updateMainObjs)
end

local function send_vip_upgrade_email(vip_level, bonus, weekbonus, monthbonus)
    local msgObj = {
        title = 'VIP level upgraded',
        title_al ='VIP level upgraded',
        msg_al = '',
        msg = '',
        attach = {{type = PDEFINE.PROP_ID.VIP_LEVEL, count=1, lv = vip_level}}
    }
    msgObj.msg = string.format("Great Job! You've achieved to %s,now you can claim level up bonus %s and enjoy weekly bonus %s ,monthly bonus %s.Upgrade your VIP level to claim more level up/weekly/monthly bonus !",vip_level , bonus, weekbonus, monthbonus)
    handle.sendBuyOrUpGradeEmail(msgObj, PDEFINE.MAIL_TYPE.VIP)
end

--! 记录购买vip后能获得的奖励, 让vip自己点击触发领取
local function addVipRewards(uid, item)
    local cacheKey = PDEFINE.REDISKEY.OTHER.viprewards .. uid
    local vipRewards = do_redis({"get", cacheKey})
    if nil == vipRewards or "" == vipRewards then
        vipRewards = "[]"
    end
    vipRewards = cjson.decode(vipRewards)
    table.insert(vipRewards, item)
    do_redis({"set", cacheKey, cjson.encode(vipRewards)})
end

--TODO:后续道具补齐了 这里要改动
local function getVipSendSkin(vip_level, stype)
    --TODO: 临时写死，因为：VIP0-VIP5用的是同一个头像框，不用在背包中重复显示。VIP6-8也是同一个，VIP9-11也是
    if stype == 'avatarframe' then
        if nil ~= PDEFINE.SKIN.VIP.AVATAR[vip_level] then
            return PDEFINE.SKIN.VIP.AVATAR[vip_level].img, 1
        end
    elseif stype == 'charm' then
        if nil ~= PDEFINE.SKIN.VIP.CHARM[vip_level] then
            return PDEFINE.SKIN.VIP.CHARM[vip_level].img, PDEFINE.SKIN.VIP.CHARM[vip_level].times
        end
    elseif stype =='expression' then
        if nil ~= PDEFINE.SKIN.VIP.PROP[vip_level] then
            return PDEFINE.SKIN.VIP.PROP[vip_level].img, 1
        end
    else --聊天框
        if nil ~= PDEFINE.SKIN.VIP.CHAT[vip_level] then
            return PDEFINE.SKIN.VIP.CHAT[vip_level].img, 1
        end
    end
end

--获取奖励的金币数
local function getRewardCoin(rewards)
    for _, item in ipairs(rewards) do
        if item.type == PDEFINE.PROP_ID.COIN then
            return item.count
        end
    end
    return 0
end

-- 钻石购买
-- 用户在消耗钻石的同时，积累vip等级经验。一旦用户购买了基础vip，激活vip功能，所有消耗都算数
function CMD.useVipDiamond(diamond)
    if not UID then
        LOG_DEBUG('CMD.useVipDiamond uid is null diamond:', diamond)
        return false
    end
    local up_data = {
        addsvipexp = diamond, --vip经验值增量
    }
    local uid = UID
    
    handle.moduleCall("player", "setPersonalExp", uid, up_data)
    local vipUpdated = false
    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    local diamondUsed = playerInfo.svipexp or 0
    local curlVipLv = playerInfo.svip or 0
    local resp = {
        uid = uid,
        svip = curlVipLv,
        svipexp = diamondUsed,
        leftdays = 9999,
        ticket = playerInfo.ticket,
    }

    local vip_level = get_level_by_exp(diamondUsed)
    LOG_DEBUG("UID:", uid, ' diamondUsed:',diamondUsed, ' curlVipLv:',curlVipLv, ' vip_level:', vip_level)
    if vip_level > curlVipLv then
        vipUpdated = true
        handle.dcCall("user_dc", "setvalue", uid, "svip", vip_level)
        resp.svip = vip_level
        resp.svipexp = diamondUsed
        resp.nextvipexp = handle.getNextVipInfoExp(vip_level)

        local vipListKey= PDEFINE.REDISKEY.QUEUE.VIP_UPGRADE
        local res = {uid = uid, level = vip_level}
        do_redis({"lpush", vipListKey, cjson.encode(res)})

        for i=curlVipLv+1, vip_level do
            handle.moduleCall("viplvtask", "addNewTask", uid, i) --新增记录
        end
        
        -- 这里注意下，前端显示的vip等级是 vip_level-1
        -- if vip_level-1 >= 6 then
        --     pcall(cluster.send, "master", ".userCenter", "vipLevelUpNotice", UID, vip_level-1)
        -- end

        local maxCnt = VIP_UP_CFG[vip_level].friendscnt
        if maxCnt then
            handle.moduleCall("friend", "changeMaxCnt", maxCnt)
        end

        playerInfo.ticket = resp.ticket
        skynet.send('.chat', 'lua', 'changeUserData', playerInfo)
    end 
    if vipUpdated then
        local _, _, getviplist = CMD.canGetVipRewards(uid)
        resp.getviplv = getviplist
    end

    handle.syncUserInfo(resp)
    if vipUpdated then
        sendVipChangedMsg(vip_level, diamondUsed)
        --全服广播
        local cfg = VIP_UP_CFG[vip_level]
        if cfg then
            local bonus = getRewardCoin(cfg.rewards)
            local weekbonus = getRewardCoin(cfg.weeklybonus)
            local monthbonus = getRewardCoin(cfg.monthlybonus)
            send_vip_upgrade_email(vip_level, bonus, weekbonus, monthbonus)
            sysmarquee.onVipLevel(playerInfo.playername, vip_level, bonus, weekbonus, monthbonus)
        end
    end
    return true
end

-- 购买了基础vip，激活vip
function CMD.activeVip(oldEndtime, directUpGradeVip5)
    if nil == directUpGradeVip5 then
        directUpGradeVip5 = false --是否直充vip5
    end
    local playerInfo = handle.moduleCall("player", "getPlayerInfo", UID)
    local user_svip = playerInfo.svip or 0
    local old_user_vip = user_svip
    local diamondUsed = playerInfo.svipexp or 0
    local endtime = playerInfo.vipendtime or 0
    local leftDays = 1
    local vip_level = 1
    local resp = {
        uid = UID,
        svip = vip_level, --只要激活就是基础vip，svip=1
        svipexp = 0,
        leftdays = 9999,
    }
    local vipUpdated = false
    if diamondUsed > 0 then
        if user_svip == 0 then
            vipUpdated = true
        end
        vip_level = get_level_by_exp(diamondUsed)
        if directUpGradeVip5 and (vip_level < DIRECT_VIP5_LEVEL) then
            diamondUsed = diamondUsed + VIP_UP_CFG[DIRECT_VIP5_LEVEL].diamond
            vipUpdated = true
        end
        local maxCnt = VIP_UP_CFG[vip_level].friendscnt
        if maxCnt then
            handle.moduleCall("friend", "changeMaxCnt", maxCnt)
        end
    else
        if vip_level ~= user_svip then
            vipUpdated = true
        end

        if directUpGradeVip5 and (vip_level < DIRECT_VIP5_LEVEL) then
            diamondUsed = VIP_UP_CFG[DIRECT_VIP5_LEVEL].diamond
            vipUpdated = true
        end
    end
    resp.svipexp = diamondUsed
    if diamondUsed > 0 then
        handle.dcCall("user_dc", "setvalue", UID, "svipexp", diamondUsed)
        pcall(cluster.send, "master", ".winrankmgr", "setVIPRank", UID, diamondUsed)

        vip_level = get_level_by_exp(diamondUsed)
        if vip_level < 0 then
            vip_level = 0
        end
    end
    resp.svip = vip_level
    handle.dcCall("user_dc", "setvalue", UID, "svip", vip_level)

    for i=old_user_vip, vip_level do
        local avatarframe, avatarTotal = getVipSendSkin(i, "avatarframe")
        if avatarframe ~= nil and avatarframe ~="" then
            addVipRewards(UID, {type=PDEFINE.PROP_ID.SKIN_FRAME, count=avatarTotal, img=avatarframe, vip=i, endtime=endtime})
        end
        local chatframe,chatTotal = getVipSendSkin(i, "chat")
        if chatframe ~=nil and chatframe ~="" then
            addVipRewards(UID, {type=PDEFINE.PROP_ID.SKIN_CHAT, count=chatTotal, img=chatframe, vip=i, endtime=endtime})
        end
        local charmprop, charmTotal = getVipSendSkin(i, "charm")
        if charmprop ~=nil and charmprop ~="" then
            addVipRewards(UID, {type=PDEFINE.PROP_ID.SKIN_CHARM, count=charmTotal, img=charmprop, vip=i, endtime=endtime})
        end
        local expression, expreTotal = getVipSendSkin(i, "expression") --交互表情
        if expression ~=nil and expression ~="" then
            addVipRewards(UID, {type=PDEFINE.PROP_ID.SKIN_CHARM, count=expreTotal, img=expression, vip=i, endtime=endtime})
        end
    end

    LOG_DEBUG("activeVip diamondUsed:",diamondUsed, ' uid:', UID, ' leftdays:', leftDays)

    if vipUpdated then
        local _, _, getviplist = CMD.canGetVipRewards(UID)
        resp.getviplv = getviplist
    end
    handle.syncUserInfo(resp)
    if vipUpdated then
        sendVipChangedMsg(vip_level, diamondUsed)
        if user_svip ~= resp.svip then
            send_vip_upgrade_email(resp.svip)
        end
        if leftDays == 0 then
            if diamondUsed == 0 then --配合客户端，新用户升级到vip
                diamondUsed = 1
            end
        end
        return diamondUsed
    end
    return 0
end

-- 赠送皮肤商品
function CMD.sendSkins(img, endtime, uid)
    uid = uid or UID
    send_timeout_skin(img, endtime, uid)
end

--! 是否可以获取vip奖励
function CMD.canGetVipRewards(uid)
    
    local lv, flag, lvlist = 0, false, {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    if nil == uid then
        return 0, flag, lvlist
    end
    local cacheKey = PDEFINE.REDISKEY.OTHER.viprewards .. uid
    local vipRewards = do_redis({"get", cacheKey})
    local svipexp = handle.dcCall("user_dc", "getvalue", uid, "svipexp")
    local svip = handle.dcCall("user_dc", "getvalue", uid, "svip")
    local endtime = handle.dcCall("user_dc", "getvalue", uid, "vipendtime")
    svipexp = math.floor(svipexp or 0)
    local now = os.time()
    endtime = endtime or 0
    if endtime <= now then
        return 0, flag, lvlist
    end
    local user_vip = get_level_by_exp(svipexp)
    if endtime > now and svip == 1 then
        user_vip = 1
    end
    local tmpLV = {}
    if nil == vipRewards or "" == vipRewards then
        lv = user_vip
        table.insert(tmpLV, user_vip)
    else
        vipRewards = cjson.decode(vipRewards)
        lv = user_vip
        for k, level in ipairs(lvlist) do ---1:待领取  2:已领取; 0:未激活
            if k <= lv then
                lvlist[k] = 2
            end
        end
        if #vipRewards > 0 then
            for _, row in pairs(vipRewards) do
                if not table.contain(tmpLV, row.vip) then
                    table.insert(tmpLV, row.vip)
                end
                if row.vip and row.vip <= lv then
                    lv = row.vip
                end
                lvlist[row.vip] = 1
            end
            flag = true
        end
    end
    return #tmpLV, flag, lvlist
end

function CMD.getVipRewards(uid, lv)
    lv = lv + 1 --客户端传的vip 比服务器存储的小1
    local rewards = {}
    local cacheKey = PDEFINE.REDISKEY.OTHER.viprewards .. uid
    local vipRewards = do_redis({"get", cacheKey})
    if nil ~= vipRewards and "" ~= vipRewards then
        local imgs = {}
        local nowtime = os.time()
        vipRewards = cjson.decode(vipRewards)
        if #vipRewards > 0 then
            for i=#vipRewards, 1, -1 do
                local row = vipRewards[i]
                LOG_DEBUG("getVipRewards row:", i, ' row:', row)
                if row.endtime < nowtime then
                    table.remove(vipRewards, i)
                else
                    if row.vip == lv then
                        LOG_DEBUG("getVipRewards get row.vip:", row.vip)
                        if not table.contain(imgs, row.img) then
                            table.insert(imgs, row.img)
                            add_send_charm_times(uid, row.img, false, row.count)
                            table.insert(rewards, {type=row.type, count=row.count, img=row.img})
                        end
                        table.remove(vipRewards, i)
                    end
                end
            end
            do_redis({"set",cacheKey, cjson.encode(vipRewards)})
        end
    end
    LOG_DEBUG("getVipRewards rewards:", rewards)
    return rewards
end

return CMD