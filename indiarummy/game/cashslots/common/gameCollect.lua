local freeTool = require "cashslots.common.gameFree"
local updateFreeData = freeTool.updateFreeData

--========================收集能量游戏===========================
--[[
	客户端区分地图免费还是正常免费，通过44是否下发collect来判断
]]
local CFG = {
	MINBETIDX = 3,
	TOTAL = 200,
	MAP = {
		CNT  = 10, 				--地图中的免费时10次
		FREE = {2, 7, 13, 20},	--停留在这些位置，会触发10次免费游戏
		MULTS = {[2]={2, 5}, [7]={2, 10}, [13]={3, 25}, [20]={5, 100}},  --免费翻倍区间，中间的wild翻倍
		MIN = 1,
		MAX = 20,
	}
}
local collect = {}

collect.setCFG = function(gameCfg)
	if gameCfg ~= nil then
		CFG = gameCfg
	end
end
--===能量条以及地图初始化
collect.init = function(deskInfo)
	local needbet = deskInfo.needbet or CFG.MINBETIDX
	deskInfo.collect = {
		min = needbet, 				--进度条开始时的等级
		total  = CFG.TOTAL,			--进度条需要的总进步数值
        totaldef = CFG.TOTAL,			--进度条需要的总进步数值
        totalpass = CFG.TOTAL_PASS, --单个关卡需要收集的数值
		num = 0,						--目前总金币(每执行完一个子游戏需要清零处理)
		idx = 0,						--玩家目前所在的地图位置
		open = 0,						--玩家目前正在执行的子游戏 1 N77  2 free
		--------新增-----------------
		bet = 0,						--玩家在地图关卡应当使用的押注额
		coin = 0, 						--收集过程中的总押注金币
		cnum = 0,						--收集次数
		-- free = 0,						--免费关卡中的次数
	}
    if CFG.TOTAL_PASS and CFG.TOTAL_PASS[1] then
        deskInfo.collect.total = CFG.TOTAL_PASS[1]
    end
end
-- ====棋盘格中有boom增加能量条====
collect.add = function(deskInfo, cards, info)
    if deskInfo.currmult >= deskInfo.collect.min and deskInfo.collect.num < deskInfo.collect.total then
        local min, max 
        if type(info) == "table" then
            min = info[1] 
            max = info[2]  
        else
            min = info
            max = info
		end
		local num = 0
        for idx, v in ipairs(cards)do
			if v >= min  and v <= max then	
				num = num + 1
			end
		end
		if num > 0 then
			deskInfo.collect.num =  deskInfo.collect.num + num
			deskInfo.collect.cnum =  deskInfo.collect.cnum + 1
			deskInfo.collect.coin =  deskInfo.collect.coin + deskInfo.totalBet
		end
		if deskInfo.collect.num >= deskInfo.collect.total then
			deskInfo.collect.bet = math.floor(deskInfo.collect.coin/deskInfo.collect.cnum)
			--开启集能量小游戏
			deskInfo.collect.idx = deskInfo.collect.idx + 1
			if deskInfo.collect.idx > CFG.MAP.MAX then
				deskInfo.collect.idx = 1
			end
			--根据idx,找到玩家下一步触发的游戏
			if not table.contain(CFG.MAP.FREE, deskInfo.collect.idx) then
				deskInfo.collect.open = 1	--N77
			else
				deskInfo.collect.open = 2	--免费游戏
				deskInfo.collect.free = CFG.MAP.CNT
			end
			deskInfo.select = {state = true, rtype = deskInfo.collect.open}

            if deskInfo.collect.totalpass then
                local nextid = deskInfo.collect.idx + 1
                if nextid > CFG.MAP.MAX then
                    nextid = 1
                end
                deskInfo.collect.total = deskInfo.collect.totalpass[nextid] or deskInfo.collect.totaldef
            end    
		end
	end
	return deskInfo.collect	
end

-- ====N77小关游戏====

-- ===大关免费游戏===
collect.inFree = function(deskInfo)
	if table.contain(CFG.MAP.FREE, deskInfo.collect.idx) and deskInfo.collect.open == 2 then
		return true
	end
end

--更新开启免费游戏
collect.startFree = function (deskInfo)
	if collect.inFree(deskInfo) then
        LOG_DEBUG("collect start free====>>>>", deskInfo.gameid, deskInfo.collect)
		local idx = deskInfo.collect.idx
		if collect.inFree(deskInfo) and CFG.MAP.MULTS[idx] then
			deskInfo.collect.mult = math.random(CFG.MAP.MULTS[idx][1], CFG.MAP.MULTS[idx][2])
		else
			deskInfo.collect.mult = 1
		end
		updateFreeData(deskInfo, 1, CFG.MAP.CNT, deskInfo.collect.mult, 0)
	end
end

--结束地图免费游戏
collect.clearFree = function(deskInfo)
end

--清楚免费数据
collect.clear = function(deskInfo)
	-- print("collect.clear, CFG:", CFG)
	deskInfo.collect.mult = nil
	deskInfo.collect.num = 0
	deskInfo.collect.open = 0
	deskInfo.collect.bet = 0
	deskInfo.collect.cnum = 0
	deskInfo.collect.coin = 0
	if deskInfo.collect.idx == CFG.MAP.MAX then
		deskInfo.collect.idx = 0
	end
end

collect.settleBigGame = function(deskInfo, winCoin, zjLuXian)
	if not table.empty(zjLuXian) then
		local ratio = deskInfo.collect.bet / deskInfo.totalBet  --此处取整可能为0，因为收集的影响因子可能为0.**
		for _, rs in pairs(zjLuXian) do
			rs.coin = math.round_coin(rs.coin * ratio)
		end
		winCoin = math.round_coin(winCoin * ratio)
	end
	return winCoin, zjLuXian
end

return collect