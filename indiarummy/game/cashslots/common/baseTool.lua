--[[
-- Author: 
-- Date: 2019-02-13
-- 功能描述:一些通用的方法
]] 
local skynet = require "skynet"
local cjson = require "cjson"
local cluster = require "cluster"
local api_service = require "api_service"
local player_tool = require "base.player_tool"

local function updateQuest(deskInfo, retobj, isBigGame, spEffect)
  local tmpEffect = retobj.spEffect
    if nil ~= spEffect then
      tmpEffect = spEffect
    end
    local nextQuestId  = cluster.call(deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "clusterModuleCall", "quest", "todayNextQuestId", deskInfo.user.uid)
    if nextQuestId > 0 then
        if nextQuestId == 1 and isBigGame then  --大游戏任意游戏押注30次
            cluster.call(deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "clusterModuleCall", "quest", "updateQuest", deskInfo.user.uid, 1, 1, 1)
        end
        if nextQuestId == 2 and isBigGame then  -- 赢取500k金币
            cluster.call(deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "clusterModuleCall", "quest", "updateQuest", deskInfo.user.uid, 1, 2, retobj.wincoin)
        end
        if nextQuestId == 3 and tmpEffect and tmpEffect.kind >= 1 then  --BIG WIN 3次
              cluster.call(deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "clusterModuleCall", "quest", "updateQuest", deskInfo.user.uid, 1, 3, 1)
        end

        if  nextQuestId == 4 and isBigGame then -- 累计押注额1M
            cluster.call(deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "clusterModuleCall", "quest", "updateQuest", deskInfo.user.uid, 1, 4, deskInfo.totalBet)
            cluster.call(deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "clusterModuleCall", "quest", "updateQuest", deskInfo.user.uid, 1, 6, deskInfo.totalBet)
        end

        if nextQuestId == 5 and tmpEffect and tmpEffect.kind >= 2 then --hugewin 2次
            cluster.call(deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "clusterModuleCall", "quest", "updateQuest", deskInfo.user.uid, 1, 5, 1)
        end
        if  nextQuestId == 6 and isBigGame then -- 在碎片游戏上累计押注额5M
            cluster.call(deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "clusterModuleCall", "quest", "updateQuest", deskInfo.user.uid, 1,6, deskInfo.totalBet)
        end
	end
end

local function updateNewQuest(deskInfo, retobj, isBigGame, spEffect, chips)
    local tmpEffect = retobj.spEffect
    if nil ~= spEffect then
      tmpEffect = spEffect
    end
    local uid = deskInfo.user.uid
    local updateObjs = {}
    -- 记录两次spin的间隔，如果超过30秒，则视为无效
    local prev_spin_time = do_redis({'get', PDEFINE.REDISKEY.GAME.spin_timestamp..uid})
    if not prev_spin_time then
        do_redis({'set', PDEFINE.REDISKEY.GAME.spin_timestamp..uid, os.time()})
    else
        prev_spin_time = tonumber(prev_spin_time)
        local delay = os.time() - prev_spin_time
        -- 如果大于1分钟，小于2分钟，则算一分钟
        if delay < 120 and delay > 60 then
            -- 游戏时长
            table.insert(updateObjs, {
                kind = PDEFINE.NEW_QUEST.KIND.PlayTime,
                count = 1
            })
            do_redis({'set', PDEFINE.REDISKEY.GAME.spin_timestamp..uid, os.time()})
        elseif delay > 120 then
            -- 如果大于2分钟，判定在玩，所以不给计数，重新开始
            do_redis({'set', PDEFINE.REDISKEY.GAME.spin_timestamp..uid, os.time()})
        end
    end
    -- 只能普通游戏算
    if isBigGame then
        -- 下注次数
        table.insert(updateObjs, {
            kind = PDEFINE.NEW_QUEST.KIND.Spin,
            count = 1
        })
        -- 下注达到多少金币
        table.insert(updateObjs, {
            kind = PDEFINE.NEW_QUEST.KIND.Bet,
            count = deskInfo.totalBet
        })
        -- 指定下注额进行下注多少次
        table.insert(updateObjs, {
            kind = PDEFINE.NEW_QUEST.KIND.SpecialBet,
            count = 1,
            limit = deskInfo.totalBet
        })
    end
    -- 只要结束的时候是普通游戏就算
    if deskInfo.state == 1 then
        -- 赢取指定数量金币
        table.insert(updateObjs, {
            kind = PDEFINE.NEW_QUEST.KIND.WinCoin,
            count = retobj.wincoin
        })
        -- 赢取到指定等级的金币
        table.insert(updateObjs, {
            kind = PDEFINE.NEW_QUEST.KIND.WinSize,
            count = 1,
            limit = tmpEffect.kind
        })
    end
    -- 不能算结束免费的那一把
    if isBigGame or deskInfo.state == 2 then
        -- 赢取指定金币多少次
        table.insert(updateObjs, {
            kind = PDEFINE.NEW_QUEST.KIND.SpecialWin,
            count = 1,
            limit = retobj.wincoin
        })
    end
    -- 所有都算
    if chips and chips > 0 then
        table.insert(updateObjs, {
            kind = PDEFINE.NEW_QUEST.KIND.Chips,
            count = chips
        })
    end
    if retobj.gameid then
        table.insert(updateObjs, {
            kind = PDEFINE.NEW_QUEST.KIND.DifferentSlots,
            gameid = retobj.gameid,
            count = 1
        })
    end
    cluster.send(deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "clusterModuleCall", "new_quest", "updateQuest", deskInfo.user.uid, updateObjs)
end

local function statistics(deskInfo, aidxs)
  local uid = deskInfo.user.uid
  local act = ""
  local ext = ''
  local cluster_info = deskInfo.user.cluster_info
  if cluster_info then
    if aidxs and #aidxs>0 then
      for _, idx in pairs(aidxs) do
          act = PDEFINE.ACTIONS.GAME[idx]..":"..deskInfo.gameid
          ext = deskInfo.user.coin
      end
    end
    pcall(cluster.call, cluster_info.server, cluster_info.address, "addStatistics", uid, act, ext)
  end
end

local function getTotalWincoin(deskInfo, retobj)
      local doubleAwardCoin = 0
      local subGameWinCoin = 0
      if deskInfo.gameid < 419 then
          if retobj.doubleAward.doubleAwardCoin > 0 then
              doubleAwardCoin = doubleAwardCoin + retobj.doubleAward.doubleAwardCoin
          end

          -- 小游戏
          if deskInfo.subGame.winCoin then
              if deskInfo.subGame.winCoin > 0 then
                  subGameWinCoin  = subGameWinCoin + deskInfo.subGame.winCoin
              end
          end
          -- 部分小游戏用的twinCoin
          if deskInfo.subGame.twinCoin then
              if deskInfo.subGame.twinCoin > 0 then
                  subGameWinCoin  = subGameWinCoin + deskInfo.subGame.twinCoin
              end
          end
          -- 部分小游戏用的是subAddCoin
          if deskInfo.subGame.subAddCoin and deskInfo.subGame.subAddCoin > 0 then
              subGameWinCoin  = subGameWinCoin + deskInfo.subGame.subAddCoin
          end

          --小游戏加分
          if deskInfo.subGame.cacheResult and deskInfo.subGame.cacheResult.winCoin > 0 then
              subGameWinCoin  = subGameWinCoin + deskInfo.subGame.cacheResult.winCoin
          end       

          --start2小游戏加分
          if retobj.subGameReport and retobj.subGameReport.win_coin > 0 then
            subGameWinCoin = subGameWinCoin + retobj.subGameReport.win_coin
          end
      end

      return (retobj.wincoin  + subGameWinCoin + doubleAwardCoin)
end

return {
  updateQuest = updateQuest,
  updateNewQuest = updateNewQuest,
  statistics = statistics,
  getTotalWincoin = getTotalWincoin,
}