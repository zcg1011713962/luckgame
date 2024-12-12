local ChipConfig = require "cashslots.config.configChip"
local utils = require "cashslots.common.utils"


-- 碎片收集游戏
-- 收集满几个碎片会触发金币奖励
-- 收集满整张图会触发免费游戏
-- 每收集满一次，免费游戏的倍率都会加高

--- @class SlotChipGame
local _M = {}

local mt = { __index = _M }

_M.probWeights = {1.3, 1.2, 1.1, 1}

--- @param self SlotChipGame
--- @return SlotChipGame
function _M.new(self, gameId)
    --- @type SlotChipGame
    local o = {}
    o.gameId = gameId  -- 游戏gameId
    o.state = 0  -- 0代表正常收集，1代表免费游戏，用于判断何时使用baseCoin
    --- @type ChipConfig[]
    o.cfg = ChipConfig.Chip[gameId]
    o.prob = ChipConfig.Prob[gameId]  -- 获得碎片的概率
    o.spinCnt = 0  -- spin的次数，用于计算平均值
    o.baseCoin = 0   -- 根据spin计算出的平均值
    o.needReset = false   -- 判断是否需要在下一次spin的时候重置spin数据

    --- @type number[][]
    o.chips = {}  -- 已收集到的碎片
    o.completeCnt = {}   -- 每张大图收集完的次数
    -- 初始化二维数组
    for i = 1, #o.cfg do
        if not o.chips[i] then
            o.chips[i] = {}
        end
        if not o.completeCnt[i] then
            o.completeCnt[i] = 0
        end
    end
    
    return setmetatable(o, mt)
end

--- 重载对象
--- @param chipGame SlotChipGame
--- @return SlotChipGame
function _M.load(self, chipGame)
    chipGame.cfg = ChipConfig.Chip[chipGame.gameId]
    chipGame.prob = ChipConfig.Prob[chipGame.gameId]  -- 获得碎片的概率
    for i = 1, #chipGame.cfg do
        if not chipGame.chips[i] then
            chipGame.chips[i] = {}
        end
        if not chipGame.completeCnt[i] then
            chipGame.completeCnt[i] = 0
        end
    end
    return setmetatable(chipGame, mt)
end

-- 游戏中spin一次，不能是免费游戏，和触发免费那一局
--- @param self SlotChipGame
--- @return {chip:{pid:number, cid:number}, freeInfo: {freeCnt:number, mult:number}}
function _M.spin(self, totalBet)
    -- 判断是否需要重置, 进入免费的时候设定这个参数，然后在下一次spin的时候重置
    -- 因为这个spin不会出现在非免费游戏中
    if self.needReset then
        self.spinCnt = 0
        self.baseCoin = 0
        self.needReset = false
    end
    -- 先计算平均值
    local totalCoin = self.spinCnt * self.baseCoin
    self.spinCnt = self.spinCnt + 1
    totalCoin = totalCoin + totalBet
    self.baseCoin = math.floor(totalCoin / self.spinCnt)
    -- 设置状态, 防止子游戏忘记设置
    self.state = 0
    -- 然后根据权重选择某一张图片
    --- @type ChipConfig
    local pid, rs = utils.randByWeight(self.cfg)
    -- 如果收集满了，则不能再触发碎片
    if #self.chips[pid] == rs.size then
        return nil
    end
    local probWeight = self.probWeights[#self.chips[pid]+1] or 1
    -- 根据概率计算出此次是否中碎片
    local randNum = math.random()
    -- 需要乘以每张碎片的权重
    local prob = self.prob * probWeight
    if randNum < self.prob then
        -- 统计所有未收集的碎片
        local unCollectChip = {}
        for i = 1, rs.size do
            if not table.contain(self.chips[pid], i) then
                table.insert(unCollectChip, i)
            end
        end
        -- 然后随机到某一个碎片
        local cid = unCollectChip[math.random(#unCollectChip)]
        local chip = {cid=cid, pid=pid}
        if not self.chips[pid] then
            self.chips[pid] = {}
        end
        table.insert(self.chips[pid], cid)

        -- 判断是否触发了节点奖励
        local winCoin = nil
        if table.contain(rs.coinIdx, #self.chips[pid]) then
            winCoin = rs.coinMult * self.baseCoin
        end

        return {
            chip = chip,
            winCoin = winCoin
        }
    end
    return nil
end

-- 刷新面板，用于检测是否有拼图集满，集满就需要刷新
--- @param self SlotChipGame
function _M.startFreeGame(self, pid)
    if not self.chips[pid] then
        return nil
    end
    -- 判断是否图标收集满了
    local freeInfo = nil
    local cfg = self.cfg[pid]
    if #self.chips[pid] == cfg.size then
        -- 记录图片的完成次数
        if not self.completeCnt[pid] then
            self.completeCnt[pid] = 1
        else
            self.completeCnt[pid] = self.completeCnt[pid] + 1
        end
        -- 计算出免费游戏的倍率
        local multIdx = self.completeCnt[pid] % #cfg.mults
        if multIdx == 0 then
            multIdx = #cfg.mults
            -- 设置下一次重置baseCoin
            self.needReset = true
        end
        -- 免费信息
        freeInfo = {
            freeCnt = cfg.freeCnt,
            addMult = cfg.mults[multIdx],
        }
        -- 重置图标
        self.chips[pid] = {}
        -- 设置状态
        self.state = 1
    end
    return freeInfo
end

return _M