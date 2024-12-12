local cjson = require "cjson"
local cluster = require "cluster"
local confDefine = require"cashslots.common.config"
local configcontrol =  require "cashslots.config.configcontrol"
local skynet = require "skynet"

local NUMERICAL_DEBUG = skynet.getenv("NUMERICAL_DEBUG")

-- 押注挡位额调节值
local STAKE_ADJUST_RATE = {1.3, 1.25, 1.2, 1.15, 1.1, 1.05, 1.05, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.95, 0.95, 0.9, 0.9, 0.9} 

-- 取加权绝对值最大的概率值
local function getRateByAbsolutelyWeight(rates, weights)
    local maxValue = 0
    local maxIndex = 1
    for i = 1, #rates do
        local value = math.abs((rates[i]-1)*weights[i])
        if maxValue < value then
            maxValue = value
            maxIndex = i
        end
    end
    return rates[maxIndex]
end

-- 取游戏中的概率
local function get(gameid, uid, deskInfo, userInfo)
    local control = configcontrol[gameid] and table.copy(configcontrol[gameid]) or nil
    if not NUMERICAL_DEBUG then
        local ok, game = pcall(cluster.call, "master", ".gamemgr", "getRow", gameid)
        if ok and game.control then
            local okjson, mycontrol = pcall(cjson.decode, game.control)
            if okjson then
                control = mycontrol
            end
        end
    end

    if not TEST_RTP then
        local isFree = deskInfo.state == confDefine.GAME_STATE["FREE"]
            --免费游戏内中免费游戏概率，后台免费概率* 0.1 / 免费次数
        if not isFree then
            local ok, levelRateOfReturn, levelRateFree, levelRateSub = pcall(cluster.call, "master", ".vipCenter", "getRateByType", uid, gameid)
            if not ok or NUMERICAL_DEBUG then
                levelRateOfReturn = 1.0
                levelRateFree = 1.0
                levelRateSub = 1.0
            end
            local stakeRate = 1
            if userInfo.betIndex <= #STAKE_ADJUST_RATE then
                stakeRate = STAKE_ADJUST_RATE[userInfo.betIndex]
            else
                stakeRate = STAKE_ADJUST_RATE[#STAKE_ADJUST_RATE]
            end
            local rateOfReturn = getRateByAbsolutelyWeight({levelRateOfReturn, stakeRate}, {7, 3})
            local rateFree = levelRateFree * rateOfReturn
            local rateSub = levelRateSub * rateOfReturn

            LOG_DEBUG("uid:"..uid.." gameid:"..gameid, "getRateByType ok:",ok, "levelRateFree:",levelRateFree, "levelRateSub:",levelRateSub,
             "levelRateOfReturn:",levelRateOfReturn, "stakeRate:",stakeRate, "rateOfReturn:",rateOfReturn, "rateFree:",rateFree, "rateSub:",rateSub)

            if nil ~= control.threshold and nil ~= control.threshold.common then
                local setControl = control.threshold.common
                local threshold_common = setControl
                if rateOfReturn <= 0.6 then
                    threshold_common = threshold_common * 0.6
                elseif rateOfReturn > 0.6 and rateOfReturn < 1.5 then
                    threshold_common = threshold_common * rateOfReturn
                elseif rateOfReturn >= 1.5 then
                    threshold_common = threshold_common *  1.5
                end
                threshold_common = math.floor(threshold_common+0.5)
                threshold_common = math.max(threshold_common, 50)  --不低于50
                LOG_DEBUG("uid:", uid, "gameid:", gameid, "threshold common：", control.threshold.common.." => "..threshold_common)
                control.threshold.common = threshold_common
            end
            if nil~= control.freeControl and control.freeControl.probability ~= nil then
                local setControl = control.freeControl.probability/1000
                local free_probability = rateFree * setControl * 1000 --直接修改比例
                LOG_DEBUG("uid:", uid, "gameid:", gameid, "free_probability：", control.freeControl.probability.." => "..free_probability)
                control.freeControl.probability = free_probability
            end
            if nil~= control.subControl and control.subControl.probability ~= nil then
                local setControl = control.subControl.probability/1000
                local sub_probability = rateSub * setControl * 1000 --直接修改比例
                LOG_DEBUG("uid:", uid, "gameid:", gameid, "sub_probability：", control.subControl.probability.." => "..sub_probability)
                control.subControl.probability = sub_probability
            end
            if nil~= control.bonusControl and control.bonusControl.probability ~= nil then
                local setControl = control.bonusControl.probability/1000
                local bonus_probability = rateSub * setControl * 1000 --直接修改比例
                LOG_DEBUG("uid:", uid, "gameid:", gameid, "bonus_probability：", control.bonusControl.probability.." => "..bonus_probability)
                control.bonusControl.probability = bonus_probability
            end

        end
    end
    return control
end

return {
    get = get,                        --根据配置取概率
}