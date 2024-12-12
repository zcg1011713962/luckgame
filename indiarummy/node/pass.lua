local skynet = require "skynet"
local cluster = require "cluster"
local cjson   = require "cjson"
local date = require "date"
local player_tool = require "base.player_tool"
local passCfg = require "conf.passCfg"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local pass = {}
local UID = nil
local handle
local act = "pass"

local function arrayToStr(arr)
    return table.concat(arr, ",")
end

local function strToArray(str)
    local arr = {}
    if str ~= nil and str ~= "" then
        return string.split_to_number(str, ",")
    end
    return arr
end

--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

local function resetPassData(pass_data)
    pass_data.exp = 1
    pass_data.is_super = 0
    pass_data.gain_rewards = ""
    pass_data.gain_super_rewards = ""
    pass_data.endtime = date.GetNextWeekDayTime(os.time(), 1)
    -- pass_data.endtime = os.time()+60
end

function pass.bind(agent_handle)
	handle = agent_handle
end

function pass.initUid(uid)
    UID = uid
end

function pass.init(uid)
    if not UID then
        UID = uid
    end
    local pass_data = handle.dcCall("pass_dc","get", uid)
    if not pass_data or table.empty(pass_data) then
        pass_data = {
            uid = uid,
        }
        resetPassData(pass_data)
        handle.dcCall("pass_dc","add", pass_data)
    end
end

local function resetPass(pass_data)
    resetPassData(pass_data)
    local mapData = {
        ["exp"] = pass_data.exp,
        ["is_super"] = pass_data.is_super,
        ["gain_rewards"] = pass_data.gain_rewards,
        ["gain_super_rewards"] = pass_data.gain_super_rewards,
        ["endtime"] = pass_data.endtime,
    }
    handle.dcCall("pass_dc","setvalue", pass_data.uid, mapData)
end

-- 获取当前等级的信息，主要用于获取奖品信息
local function getLevelCfg(level)
    for _, item in ipairs(passCfg.LevelConfig) do
        if item.level == level then
            return item
        end
    end
    return nil
end

-- 获取通行证信息
local function getInfo(uid)
    local pass_data = handle.dcCall("pass_dc","get", uid)
    if not pass_data then
        pass.init(uid)
        pass_data = handle.dcCall("pass_dc","get", uid)
    end
    local now = os.time()
    pass_data.endtime = tonumber(pass_data.endtime or 0)
    if pass_data.endtime < now then
        resetPass(pass_data)
    end
    local leagueExp, _ = player_tool.getPlayerLeagueInfo(uid)
    local ok, level = pcall(cluster.call, "master", ".cfgleague", "getCurLevel", leagueExp)
    if not ok then
        level = 1
    end
    pass_data.exp = level
    if pass_data.exp < 1 then --默认第1级 排位等级
        pass_data.exp = 1
    end
    return pass_data
end

-- 完成任务后增加经验
function pass.addExp(uid, exp)
    local pass_data = getInfo(uid)
    if not pass_data then
        return nil
    end
    pass_data.exp = (pass_data.exp or 0) + exp
    handle.dcCall("pass_dc", "setvalue", uid, "exp", pass_data.exp)
    return pass_data
end

-- 完成购买的回调
function pass.addPass(uid)
    local pass_data = getInfo(uid)
    if not pass_data then
        return nil
    end
    pass_data.is_super = 1
    handle.dcCall("pass_dc", "setvalue", uid, "is_super", pass_data.is_super)
    return PDEFINE.RET.SUCCESS
end

-- 其他进程获取pass信息
function pass.getData(uid)
    local pass_data = getInfo(uid)
    if not pass_data then
        return nil
    end
    local copy_pass_data = table.copy(pass_data)
    copy_pass_data.stop = copy_pass_data.endtime
    copy_pass_data.gain_rewards = strToArray(copy_pass_data.gain_rewards)
    copy_pass_data.gain_super_rewards = strToArray(copy_pass_data.gain_super_rewards)
    return copy_pass_data
end

-- 获取通行证信息
function pass.getInfo(msg)
	local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local pass_data = pass.getData(uid)
    local platform = handle.getPlatForm()

    local level = handle.dcCall("user_dc", "getvalue", UID, "level") --玩家级别
    local shopInfoList, _ = handle.moduleCall("pay", 'getGoods', uid, platform, level, 29, 0)

    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, pass_data = pass_data}
    retobj.shopinfo = shopInfoList[1]
    return resp(retobj)
end

-- 领取奖励
function pass.take(msg)
	local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local gain_level     = math.floor(recvobj.level)
    local is_super      = math.floor(recvobj.is_super)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, level = gain_level, rewards = {}, pass_data = nil}
    local pass_data = pass.getData(uid)
    if not pass_data then
        LOG_ERROR("pass season not open")
        retobj.spcode = 1 -- 找不到通行证信息
        return resp(retobj)
    end
    if pass_data.is_super == 0 and is_super == 1 then
        retobj.spcode = 2  -- 未开通超级通行证
        return resp(retobj)
    end
    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    local currLevel = playerInfo.leaguelevel
    if currLevel < 1 then
        currLevel = 1
    end
    if currLevel < gain_level then
        retobj.spcode = 3 -- 等级未达到
        return resp(retobj)
    end
    if is_super == 0 then
        if table.contain(pass_data.gain_rewards, gain_level) then
            retobj.spcode = 4  -- 重复领取
            return resp(retobj)
        end
    else
        if table.contain(pass_data.gain_super_rewards, gain_level) then
            retobj.spcode = 4  -- 重复领取
            return resp(retobj)
        end
    end
    local levelCfg = getLevelCfg(gain_level)
    local rewards = table.copy(is_super == 1 and levelCfg.superRewards or levelCfg.rewards)
    LOG_DEBUG("pass.take is_super:", is_super, ' gain_level:', gain_level)
    LOG_DEBUG("pass.take rewards:", rewards)
    LOG_DEBUG("pass.take pass_data:", pass_data)
    -- 获取奖励
    for _, reward in ipairs(rewards) do
        if reward.type == PDEFINE.PROP_ID.SKIN_EMOJI  then
            handle.moduleCall("player", "addSkinImg", uid, reward.img, reward.category)
            table.insert(retobj.rewards, reward)
        else
            if reward.type == PDEFINE.PROP_ID.DIAMOND then
                handle.addProp(reward.type, reward.count, 'bonus', nil, 'task_growth')
            else
                handle.addProp(reward.type, reward.count, act)
            end
            table.insert(retobj.rewards, reward)
        end
    end
    if is_super == 0 then
        table.insert(pass_data.gain_rewards, gain_level)
        handle.dcCall("pass_dc", "setvalue", uid, "gain_rewards",arrayToStr(pass_data.gain_rewards))
    else
        table.insert(pass_data.gain_super_rewards, gain_level)
        handle.dcCall("pass_dc", "setvalue", uid, "gain_super_rewards",arrayToStr(pass_data.gain_super_rewards))
    end
    retobj.pass_data = pass_data
    handle.moduleCall("player","syncLobbyInfo", uid)
	return resp(retobj)
end

-- 获取当前是否有可领取任务
function pass.syncStatus(uid)
    if not UID then
        return 0
    end
    local pass_data = pass.getData(uid)
    if not pass_data then
        return 0
    end
    local total = 0
    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    -- LOG_DEBUG("syncStatus uid:", uid, ' pass_data:', pass_data)
    for _, cfg in ipairs(passCfg.LevelConfig) do
        if cfg.level <= playerInfo.leaguelevel then
            if not table.contain(pass_data.gain_rewards, cfg.level) then
                total = total + 1
            end
            if pass_data.is_super == 1 and not table.contain(pass_data.gain_super_rewards, cfg.level) then
                total = total + 1
            end
        end
    end
    return total
end

-- 一键领取所有可领取物品
function pass.takeAll(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, rewards = {}, pass_data = nil}
    local pass_data = pass.getData(uid)
    if not pass_data then
        LOG_ERROR("pass season not open")
        retobj.spcode = 1 -- 找不到通行证信息
        return resp(retobj)
    end
    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    local currLevel = playerInfo.leaguelevel
    local rewards = {}
    local lvs = {}
    for _, cfg in ipairs(passCfg.LevelConfig) do
        if cfg.level <= currLevel then
            -- 付费奖励
            if pass_data.is_super == 1 and not table.contain(pass_data.gain_super_rewards, cfg.level) then
                table.insert(pass_data.gain_super_rewards, cfg.level)
                for _, r in ipairs(cfg.superRewards) do
                    if rewards[r.type] then
                        rewards[r.type].count = rewards[r.type].count + r.count
                    else
                        rewards[r.type] = r
                    end
                end
            end
            -- 普通奖励
            if not table.contain(pass_data.gain_rewards, cfg.level) then
                table.insert(pass_data.gain_rewards, cfg.level)
                for _, r in ipairs(cfg.rewards) do
                    if rewards[r.type] then
                        rewards[r.type].count = rewards[r.type].count + r.count
                    else
                        rewards[r.type] = r
                    end
                end
            end
            table.insert(lvs, cfg.level)
        end
    end
    -- 获取奖励
    local totalRewards = {}
    for _, reward in pairs(rewards) do
        if reward.type == PDEFINE.PROP_ID.BOX_BRONZE 
            or reward.type == PDEFINE.PROP_ID.BOX_SILVER 
            or reward.type == PDEFINE.PROP_ID.BOX_GOLD 
            or reward.type == PDEFINE.PROP_ID.BOX_DIAMOND then
            local config = passCfg.BoxConfig[reward.type]
            local _, rs = randByWeight(config)
            handle.addProp(rs.type, rs.count, act)
            if totalRewards[rs.type] then
                totalRewards[rs.type].count = totalRewards[rs.type].count + rs.count
            else
                totalRewards[rs.type] = {type=rs.type, count=rs.count}
            end
        elseif reward.type == PDEFINE.PROP_ID.SKIN_FONT or reward.type == PDEFINE.PROP_ID.PASS_EMOJI  then
            handle.moduleCall("player", "addSkin", uid, reward.frameid)
            if totalRewards[reward.type] then
                totalRewards[reward.type].count = totalRewards[reward.type].count + reward.count
            else
                totalRewards[reward.type] = reward
            end
        else
            if reward.type == PDEFINE.PROP_ID.BOX_DIAMOND then
                handle.addProp(reward.type, reward.count, 'bonus', nil, 'task_collectall', cjson.encode(lvs))
            else
                handle.addProp(reward.type, reward.count, act)
            end
            
            if totalRewards[reward.type] then
                totalRewards[reward.type].count = totalRewards[reward.type].count + reward.count
            else
                totalRewards[reward.type] = {type=reward.type, count=reward.count}
            end
        end
    end
    for _, r in pairs(totalRewards) do
        table.insert(retobj.rewards, r)
    end
    if pass_data.is_super == 1 then
        handle.dcCall("pass_dc", "setvalue", uid, "gain_super_rewards",arrayToStr(pass_data.gain_super_rewards))
    end
    handle.dcCall("pass_dc", "setvalue", uid, "gain_rewards",arrayToStr(pass_data.gain_rewards))
    retobj.pass_data = pass_data
    handle.moduleCall("player","syncLobbyInfo", uid)
    return resp(retobj)
end

return pass