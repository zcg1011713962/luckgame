local skynet = require "skynet"
local cjson = require "cjson"
local cluster = require "cluster"
local confDefine = require"cashslots.common.config"
local configcontrol =  require "cashslots.config.configcontrol"
local def = require "cashslots.control.def"
local algorithm = require "cashslots.control.algorithm"
local stgydata = require "cashslots.control.stgydata"

local NUMERICAL_DEBUG = skynet.getenv("NUMERICAL_DEBUG")
local DEBUG = skynet.getenv("DEBUG")

-- 控制模块
-- 整体思路：
-- 抓大放小，局部波动上充分利用slots子游戏本身的随机性和波动性，附加一定的总体随机波动

local MIN_ROUND_SPINS = 30  --控制轮次最小spin次数
local MAX_ROUND_SPINS = 50 --控制轮次最大spin次数
local INIT_CFREE_COUNT = 40
local INIT_CBONUS_COUNT = 50
local MIN_RTP = 0.5     -- 最小rtp
local MAX_RTP = 2       -- 最大rtp
local LOW_RTP_THRESHOLD = 0.8 -- 低rtp阈值
local HIGH_RTP_THRESHOLD = 1.2 -- 高rtp阈值
local SETTING_RTP = 0.96 --设定rtp
local FRESH_TOTAL_SPIN = 50 --新手期spin次数

local STRATEGY_TAG = {
    NORMAL = 0,   --非特定
    FRESH_PROTECT = 1, --新手破产保护
    FRESH_RANDOM = 2, --新手随机
    RANDOM = 3, --随机
    SET_HIGH_RTP = 4,   --设定高rtp
    SET_LOW_RTP = 5,    --设定低rtp
    PAID = 6,   --充值
    CONDITION_TOTAL_RTP = 7,    --条件:总rtp
    CONDITION_LATELY_RTP = 8,   --条件:近期rtp
    CONDITION_EXPECTED_RTP = 9, --条件:预期rtp
    CONDITION_CONTINUED_HIGH_RTP = 10,   --条件:连续高rtp
    CONDITION_CONTINUED_LOW_RTP = 11,    --条件:连续低rtp
    CONDITION_CONTINUED_HIGH_BALANCE = 12,   --条件:连续高balance
    CONDITION_CONTINUED_LOW_BALANCE = 13,    --条件:连续低balance
}

local Strategy = class()

function Strategy:ctor()
    self._cfg = nil
    self._sdata = nil
    self._autofree = false  --自动优化免费触发
    self._autobonus = false --自动优化bonus触发
    self._protect = nil
end

function Strategy:init(deskInfo, userInfo)
    local gameid = deskInfo.gameid
    local cfg = nil
    if configcontrol[gameid] then
        cfg = table.copy(configcontrol[gameid])
    end
    -- if not NUMERICAL_DEBUG then
    --     local ok, game = pcall(cluster.call, "master", ".gamemgr", "getRow", gameid)
    --     if ok and game.control then
    --         local okjson, control = pcall(cjson.decode, game.control)
    --         if okjson then
    --             cfg = control
    --         end
    --     end
    -- end
    self._cfg = cfg

    self._sdata = stgydata.load(deskInfo.user.uid)

    if not TEST_RTP then
        --是否需要更新策略
        local ok, ret = pcall(cluster.call, "master", ".strategymgr", "getSlotsStrategy", userInfo.svip, userInfo.tagid)
        if not ok then
            LOG_ERROR("getSlotsStrategy call failed")
        end
        if ok and ret then
            local ssid = ret.id
            if self._sdata.ssid ~= ssid then
                local tag = STRATEGY_TAG.NORMAL
                local rtp = ret.rtp/100
                if rtp >= SETTING_RTP then
                    tag = STRATEGY_TAG.SET_HIGH_RTP
                else
                    tag = STRATEGY_TAG.SET_LOW_RTP
                end
                rtp = algorithm.checkValue(rtp, MIN_RTP, MAX_RTP)
                LOG_INFO("initSettingStrategy", userInfo.uid, ssid, rtp, tag)
                self:changeStrategy(ssid, rtp, tag)
            end
        else
            if self._sdata.ssid > 0 then  --先进入随机策略
                LOG_INFO("initRandomStrategy")
                local rtp = algorithm.randomRange(1, 0.1)
                self:changeStrategy(0, rtp, STRATEGY_TAG.RANDOM)
            end
        end
    end

    if table.contain(def.AUTO_OPTIMIZE_FREE_TRIGGER_GAME_ID, gameid) then
        self._autofree = true
        self:active(deskInfo, "free")
    end
    if table.contain(def.AUTO_OPTIMIZE_BONUS_TRIGGER_GAME_ID, gameid) then
        self._autobonus = true
        self:active(deskInfo, "bonus")
    end
end

function Strategy:saveData(deskInfo)
    stgydata.save(deskInfo.user.uid, self._sdata)
end

function Strategy:getInRTP(deskInfo)
    local cfg = table.copy(self._cfg)
    if deskInfo.state == confDefine.GAME_STATE.FREE then
        return cfg
    end
    if deskInfo.ct and deskInfo.ct.cfree ~= nil and cfg.freeControl and cfg.freeControl.probability then
        local free_probability = algorithm.getTriggerFreq(cfg.freeControl.probability, deskInfo.ct.cfree)
        cfg.freeControl.probability = free_probability
    end
    return cfg
end

function Strategy:get(deskInfo, userInfo)
    local gameid = deskInfo.gameid
    local uid = deskInfo.user.uid
    local cfg = table.copy(self._cfg)
    if deskInfo.state == confDefine.GAME_STATE.FREE then
        return cfg
    end

    local levelRateOfReturn = 1
    local freshRatio = 1 --新手rtp系数
    if self._sdata.tspin < FRESH_TOTAL_SPIN and userInfo.betIndex <= 10 and self._sdata.ssid == 0 then
        freshRatio = 1.1 + 0.1 * (FRESH_TOTAL_SPIN-self._sdata.tspin)/FRESH_TOTAL_SPIN    --前120次spin的回报率系数为1.2~1.1
        levelRateOfReturn = math.max(freshRatio, self._sdata.crtp)
    else
        levelRateOfReturn = self._sdata.crtp
    end

    local stakeRate = 1
    if userInfo.betIndex <= #def.STAKE_ADJUST_RATE then
        stakeRate = def.STAKE_ADJUST_RATE[userInfo.betIndex]
    else
        stakeRate = def.STAKE_ADJUST_RATE[#def.STAKE_ADJUST_RATE]
    end

    local rateOfReturn = levelRateOfReturn * stakeRate

    local logs = {}
    logs[1] = "uid:"..uid.." level:"..userInfo.level.." gameid:"..gameid
    logs[#logs+1] = "levelRateOfReturn:"..levelRateOfReturn.." stakeRate:"..stakeRate.." rateOfReturn:"..rateOfReturn.." freshRatio:"..freshRatio

    if nil ~= cfg.threshold and nil ~= cfg.threshold.common then
        local threshold_common = cfg.threshold.common * algorithm.checkValue(rateOfReturn, 0.6, 1.5)
        threshold_common = math.floor(threshold_common+0.5)
        threshold_common = math.max(threshold_common, 50)  --不低于50
        logs[#logs+1] = "threshold_common:"..cfg.threshold.common.." => "..threshold_common
        cfg.threshold.common = threshold_common
    end

    if nil~= cfg.freeControl and cfg.freeControl.probability ~= nil then
        local free_probability = cfg.freeControl.probability
        if deskInfo.ct and deskInfo.ct.cfree ~= nil then
            free_probability = algorithm.getTriggerFreq(free_probability, deskInfo.ct.cfree)
        end
        local final = free_probability * rateOfReturn * freshRatio
        logs[#logs+1] = "free_probability:"..cfg.freeControl.probability.." => "..free_probability .. " => "..final
        free_probability = final
        cfg.freeControl.probability = free_probability
    end
    if nil~= cfg.bonusControl and cfg.bonusControl.probability ~= nil then
        local bonus_probability = cfg.bonusControl.probability
        bonus_probability = bonus_probability * rateOfReturn
        logs[#logs+1] = "bonus_probability:"..cfg.bonusControl.probability.." => "..bonus_probability
        cfg.bonusControl.probability = bonus_probability
    end
    if nil~= cfg.jackpotControl and cfg.jackpotControl.probability ~= nil then
        local jackpot_probability = cfg.jackpotControl.probability
        jackpot_probability = jackpot_probability * algorithm.checkValue(rateOfReturn, 0.8, 1.25)
        logs[#logs+1] = "jackpot_probability:"..cfg.jackpotControl.probability.." => "..jackpot_probability
        cfg.jackpotControl.probability = jackpot_probability
    end

    LOG_DEBUG(table.concat(logs, "\t"))

    return cfg
end

--激活统计项，暂时只处理free和bonus两类游戏玩法
function Strategy:active(deskInfo, key)
    if not deskInfo.ct then
        deskInfo.ct = {}
    end
    if key == "free" then
        if not deskInfo.ct.cfree then
            deskInfo.ct.cfree = INIT_CFREE_COUNT
            if self._cfg.freeControl and self._cfg.freeControl.probability > 0 then
                local avgcnt = 1000/self._cfg.freeControl.probability
                deskInfo.ct.cfree = math.floor(avgcnt/2)
            end
        end
    elseif key == "bonus" then
        if not deskInfo.ct.cbonus then
            deskInfo.ct.cbonus = INIT_CBONUS_COUNT
            if self._cfg.bonusControl and self._cfg.bonusControl.probability > 0 then
                local avgcnt = 1000/self._cfg.bonusControl.probability
                deskInfo.ct.cbonus = math.floor(avgcnt/2)
            end
        end
    end
end

function Strategy:calcRatio()
    local r1 = nil
    if self._sdata.tspin >= 1000 then
        r1 = self._sdata.twin / self._sdata.tbet
    end
    local r2 = nil
    if #(self._sdata.lwins) >= 2 then
        local lwin = table.sum(self._sdata.lwins) + self._sdata.lwin
        local lbet = table.sum(self._sdata.lbets) + self._sdata.lbet
        r2 = lwin / lbet
    end
    local r3 = nil
    if self._sdata.cspin > 80 then
        r3 = self._sdata.cwin / self._sdata.cbet
    end
    return r1, r2, r3
end

local function checkDivision(a, b)
    if b > 0 then
        return a / b
    else
        return a * 100000000
    end
end

--等级回收系数
local function calcLevelRetrieve(level)
    return 1
end

--尝试进入下一策略
function Strategy:tryEnterNextStrategy(userInfo)
    if TEST_RTP then
        if userInfo.stgy then
            --设定了策略，走设定策略
            return self:enterSettingStrategy(userInfo, userInfo.stgy)
        else
            --没有设定策略，走默认策略
            return self:tryEnterConditionStrategy(userInfo)
        end
    else
        local ok, ret = pcall(cluster.call, "master", ".strategymgr", "getSlotsStrategy", userInfo.svip, userInfo.tagid)
        if not ok then
            LOG_ERROR("getSlotsStrategy call failed")
        end
        if ok and ret then
            --设定了策略，走设定策略
            return self:enterSettingStrategy(userInfo, ret)
        else
            --没有设定策略，走默认策略
            return self:tryEnterConditionStrategy(userInfo)
        end
    end

end

--进入设定策略
function Strategy:enterSettingStrategy(userInfo, stgy)
    local ssid = stgy.id
    local rtp = 1
    local tag = STRATEGY_TAG.NORMAL
    local spincnt = math.random(MIN_ROUND_SPINS, MAX_ROUND_SPINS)

    if self._sdata.ssid == ssid then
        --继续当前策略
        local setrtp = stgy.rtp/100
        setrtp = algorithm.checkValue(setrtp, MIN_RTP, MAX_RTP)
        rtp = setrtp
        local detail = ""
        if self._sdata.cspin > 100 then
            local diff = 0.30
            if self._sdata.cspin > 2000 then
                diff = 0.025
            elseif self._sdata.cspin > 1000 then
                diff = 0.05
            elseif self._sdata.cspin > 640 then
                diff = 0.1
            elseif self._sdata.cspin > 320 then
                diff = 0.2
            elseif self._sdata.cspin > 160 then
                diff = 0.25
            end
            local cr = self._sdata.cwin / self._sdata.cbet
            if math.abs(cr-setrtp) >= diff then
                if cr > setrtp then
                    rtp = setrtp * setrtp / cr
                else
                    rtp = setrtp + setrtp - cr
                end
                rtp = algorithm.checkValue(rtp, setrtp-0.25, setrtp+0.25)
            end
            detail = string.format("detail: %.3f|%.3f|%.3f  %d|%.2f|%.2f", cr, setrtp, rtp, self._sdata.cspin, self._sdata.cwin, self._sdata.cbet)
        end
        rtp = algorithm.checkValue(rtp, MIN_RTP, MAX_RTP)
        if rtp >= SETTING_RTP then
            tag = STRATEGY_TAG.SET_HIGH_RTP
        else
            tag = STRATEGY_TAG.SET_LOW_RTP
        end
        LOG_INFO("continueSettingStrategy", userInfo.uid, userInfo.level, userInfo.coin, ssid, rtp, tag, detail)
        self:continueStrategy(ssid, rtp, tag, spincnt)
    else
        --换策略
        rtp = stgy.rtp/100
        rtp = algorithm.checkValue(rtp, MIN_RTP, MAX_RTP)
        if rtp >= SETTING_RTP then
            tag = STRATEGY_TAG.SET_HIGH_RTP
        else
            tag = STRATEGY_TAG.SET_LOW_RTP
        end
        LOG_INFO("enterSettingStrategy", userInfo.uid, userInfo.level, userInfo.coin, ssid, rtp, tag)
        self:changeStrategy(ssid, rtp, tag, spincnt)
    end
    return true
end

--尝试进入条件策略
function Strategy:tryEnterConditionStrategy(userInfo)
    local ssid = 0
    local rtp = 1
    local tag = STRATEGY_TAG.NORMAL
    local crtp = self._sdata.crtp
    local spincnt = math.random(MIN_ROUND_SPINS, MAX_ROUND_SPINS)

    --根据优先级决定策略
    local tr, lr, cr = self:calcRatio()
    if tr and math.abs(tr-1) >= 0.5 then    --整体回报率偏差
        rtp = checkDivision(SETTING_RTP, tr)
        tag = STRATEGY_TAG.CONDITION_TOTAL_RTP
    elseif lr and (lr < 0.4 or lr > 2.5) then   --最近回报率偏差
        rtp = checkDivision(SETTING_RTP, lr)
        tag = STRATEGY_TAG.CONDITION_LATELY_RTP --预期回报率偏差
    elseif cr and (math.abs(cr-crtp) >= 0.6) and self._sdata.tag ~= STRATEGY_TAG.CONDITION_EXPECTED_RTP then --只回溯1次
        rtp = crtp + crtp - cr
        tag = STRATEGY_TAG.CONDITION_EXPECTED_RTP
        spincnt = math.floor(spincnt * 0.67)
        rtp = algorithm.checkValue(rtp, MIN_RTP*1.2, MAX_RTP*0.8)
    else
        return false
    end

    rtp = algorithm.checkValue(rtp, MIN_RTP, MAX_RTP)
    LOG_INFO("enterConditionStrategy", userInfo.uid, userInfo.level, userInfo.coin, ssid, rtp, tag)
    self:changeStrategy(ssid, rtp, tag, spincnt)
    return true
end

--随机控制
function Strategy:enterRandomStrategy(userInfo)
    local rtp = 1
    local threshold = 0.5
    if self._sdata.crtp >= 1 then  --当前rtp
        threshold = 0.7
    else
        threshold = 0.3
    end
    if math.random() < threshold then
        rtp = algorithm.randomRange(0.75, 0.15) * SETTING_RTP
    else
        rtp = algorithm.randomRange(1.25, 0.25) * SETTING_RTP * calcLevelRetrieve(userInfo.level)
    end
    LOG_INFO("enterRandomStrategy", userInfo.uid, userInfo.level, rtp)
    self:changeStrategy(0, rtp, STRATEGY_TAG.RANDOM)
end

function Strategy:checkNeedProtect(userInfo)
    return false
end

--新手破产保护高回报率控制
function Strategy:enterNewProtectHighRtpStrategy(userInfo)
    self._protect = {rtp=2, spincnt=math.random(10,12), featbyspin = 1}
    LOG_INFO("enterNewProtectHighRtpStrategy", userInfo.uid, userInfo.level, self._protect.rtp, self._protect.spincnt, self._protect.featbyspin)
end

function Strategy:changeStrategy(ssid, rtp, tag, spincnt)
    if self._sdata.ssid ~= ssid then
        --清空近期下注
        self._sdata.lwins = {}
        self._sdata.lbets = {}
        self._sdata.lspin = 0
        self._sdata.lwin = 0
        self._sdata.lbet = 0
    end
    --清空当前阶段下注
    self._sdata.cspin = 0
    self._sdata.cwin = 0
    self._sdata.cbet = 0
    --更新数值
    self._sdata.prtp = self._sdata.crtp
    self._sdata.crtp = rtp
    self._sdata.tag = tag
    self._sdata.ctspin = spincnt or math.random(MIN_ROUND_SPINS, MAX_ROUND_SPINS)
    self._sdata.ctime = os.time()
    self._sdata.ssid = ssid
end

function Strategy:continueStrategy(ssid, rtp, tag, spincnt)
    self._sdata.ssid = ssid
    self._sdata.crtp = rtp
    self._sdata.tag = tag
    self._sdata.ctspin = self._sdata.ctspin + (spincnt or math.random(MIN_ROUND_SPINS, MAX_ROUND_SPINS))
    self._sdata.ctime = os.time()
end

--统计游戏事件
--spin一次，增加计数
function Strategy:onSpinStart(deskInfo, userInfo)
    if deskInfo.ct then
        if deskInfo.state == confDefine.GAME_STATE.NORMAL then
            if deskInfo.ct.cfree ~= nil then
                deskInfo.ct.cfree = deskInfo.ct.cfree + 1
            end
            if deskInfo.ct.cbonus ~= nil then
                deskInfo.ct.cbonus = deskInfo.ct.cbonus + 1
            end
        end
    end

    local basegame = (deskInfo.state == confDefine.GAME_STATE.NORMAL)
    stgydata.onSpin(self._sdata, basegame)

    if basegame then
        if self._sdata.crtp < LOW_RTP_THRESHOLD then
            self._sdata.lrtpcnt = self._sdata.lrtpcnt + 1
        else
            self._sdata.lrtpcnt = 0
        end

        if self._sdata.crtp > HIGH_RTP_THRESHOLD then
            self._sdata.hrtpcnt = self._sdata.hrtpcnt + 1
        else
            self._sdata.hrtpcnt = 0
        end
    end
end

function Strategy:onSpinEnd(deskInfo, userInfo)
    if deskInfo.state ~= confDefine.GAME_STATE.NORMAL then
        return
    end

    if self._protect then
        if self._protect.featbyspin > 0 then
            self._protect.featbyspin = self._protect.featbyspin - 1
        end
        self._protect.spincnt = self._protect.spincnt - 1
        if self._protect.spincnt <= 0 then
            self._protect = nil
        end
    end

    if self:checkNeedProtect(userInfo) then  --触发新手保护
        self:enterNewProtectHighRtpStrategy(userInfo) 
    elseif self._sdata.tspin >= FRESH_TOTAL_SPIN or self._sdata.ssid > 0 then
        --是否需要改变策略
        local t = os.time()
        if self._sdata.cspin > self._sdata.ctspin
        or (self._sdata.crtp < 0.9 and t - self._sdata.ctime > 86400) then
            --修改策略
            local ret = self:tryEnterNextStrategy(userInfo)
            if not ret then
                self:enterRandomStrategy(userInfo)
            end
        end
    end
end

--赢分
function Strategy:onWin(deskInfo, wincoin)
    stgydata.onWin(self._sdata, wincoin)
    local ssid = self._sdata.ssid
    local istest = deskInfo.user.istest
    if ssid > 0 and istest ~= 1 then
        local sql = "UPDATE s_config_kill SET totalprofit = totalprofit + "..wincoin.. " WHERE id = "..ssid.." and status = 1 LIMIT 1"
        skynet.send(".mysqlpool", "lua", "execute", sql)
    end
end

--押注
function Strategy:onBet(deskInfo, betcoin)
    stgydata.onBet(self._sdata, betcoin)
    local ssid = self._sdata.ssid
    local istest = deskInfo.user.istest
    if ssid > 0 and istest ~= 1 then
        local sql = "UPDATE s_config_kill SET totalbet = totalbet + "..betcoin.. " WHERE id = "..ssid.." and status = 1 LIMIT 1"
        skynet.send(".mysqlpool", "lua", "execute", sql)
    end
end

function Strategy:onBigwin(deskInfo)
    stgydata.onBigwin(self._sdata)
end

--触发免费一次，重置触发计数
function Strategy:onTriggerFree(deskInfo)
    if deskInfo.ct then
        deskInfo.ct.cfree = 0
    end
end

--触发bonus一次，重置触发计数
function Strategy:onTriggerBonus(deskInfo)
    if deskInfo.ct then
        deskInfo.ct.cbonus = 0
    end
end

--取牌时的自动触发免费，重置触发计数
--不能所有游戏都使用自动触发方式，因为有的游戏会换牌，即使cardProcessor.getCard拿到触发免费的牌，也有可能被后续行为替换掉,这类游戏需要手动重置触发计数
function Strategy:onAutoTriggerFree(deskInfo)
    if self._autofree and deskInfo.ct then
        deskInfo.ct.cfree = 0
    end
end

--取牌时的自动触发bonus，重置触发计数
--不能所有游戏都使用自动触发方式，因为有的游戏会换牌，即使cardProcessor.getCard拿到触发bonus的牌，也有可能被后续行为替换掉,这类游戏需要手动重置触发计数
function Strategy:onAutoTriggerBonus(deskInfo)
    if self._autobonus and deskInfo.ct then
        deskInfo.ct.cbonus = 0
    end
end



return Strategy


