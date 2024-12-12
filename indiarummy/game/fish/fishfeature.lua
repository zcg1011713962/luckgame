local skynet    = require "skynet"
local cluster   = require "cluster"

--捕鱼特殊玩法基类

FishFeature = class()

--构造函数
--fishdelegate: agent代理
function FishFeature:ctor(fishdelegate)
    self.delegate = fishdelegate
end

--发送消息
function FishFeature:sendmsg(userInfo, msg)
    if userInfo.cluster_info then
        pcall(cluster.send, userInfo.cluster_info.server, userInfo.cluster_info.address, "sendToClient", msg)
    end
end

--广播消息
function FishFeature:broadcast(deskInfo, msg, exuid)
    for _, user in pairs(deskInfo.users) do
        if user.cluster_info and exuid~=user.uid then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", msg)
        end
    end
end

--定时器
--dt: 事件间隔(秒)
function FishFeature:onUpdate(deskInfo)
end

--初始化
--fishconfig: 捕鱼配置
function FishFeature:init(fishconfig)
end

--玩家进入
--deskInfo: 桌子信息
--userInfo: 玩家信息
function FishFeature:onUserEnter(deskInfo, userInfo)
end

--玩家离开
--deskInfo: 桌子信息
--userInfo: 玩家信息
function FishFeature:onUserLeave(deskInfo, userInfo)
end

--玩家发射
--deskInfo: 桌子信息
--userInfo: 玩家信息
--bulletInfo: 子弹信息
function FishFeature:onUserFire(deskInfo, userInfo, bulletInfo)
end

--玩家击中
--deskInfo: 桌子信息
--userInfo: 玩家信息
--fishInfo: 鱼信息
function FishFeature:onUserTryCatch(deskInfo, userInfo, fishInfo, bulletInfo, rate)
    return -1
end

--玩家捕获
--deskInfo: 桌子信息
--userInfo: 玩家信息
--fishInfo: 鱼信息
--bulletInfo: 子弹信息
function FishFeature:onUserCatched(deskInfo, userInfo, fishInfo, bulletInfo)
    return nil
end

--玩家炸弹
--deskInfo: 桌子信息
--userInfo: 玩家信息
--boomInfo: 炸弹信息
--score： 炸弹得分
function FishFeature:onUserBomb(deskInfo, userInfo, boomInfo, score)
end

--玩家抽奖
--deskInfo: 桌子信息
--userInfo: 玩家信息
--recvobj: 消息对象
function FishFeature:onUserLuckDraw(deskInfo, userInfo, recvobj)
    return -1
end

--桌子重置
function FishFeature:onDeskReset()
end


