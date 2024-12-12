PDEFINE_MSG = {}
--协议
-- 接口协议对应处理函数
PDEFINE_MSG.PROTOFUN =
{
    ["11"] = "player.heartBeat",
    ["2"]  = "player.getLoginInfo",
    ["3"]  = "player.getLoginInfo", --断线重连使用
    ["4"]  = "player.getDeskInfo", --断线重连使用
    ["25"] = "jackpot.getHallAndJp", --获取大厅bigbang跟游戏奖金池

    --大厅相关消息起止协议号201~299  切勿占号 加拉米相关协议

    -----------------------银行功能---------------------
    ["100"] = "bank.enter", --进入银行
    ["101"] = "bank.info", --银行大厅信息
    ["102"] = "bank.save", --存款
    ["103"] = "bank.draw", --取款
    ["104"] = "bank.record", --银行记录
    ["105"] = "bank.changepasswd", --修改密码
    ["106"] = "bank.exit", --退出银行
    ["107"] = "bank.drawInGame", --游戏内快速取款
    ["108"] = "cluster.game.dsmgr.chooseLin", --游戏内快速取款


    ["134"] = "player.bindmobile", --绑定手机号
    ["135"] = "player.sendsms", --发送短信验证码

    ["199"] = "player.changeLanguage", --切换语言

    ['201'] = "mailbox.deleteAll", --一键删除所有邮件
    ["202"] = "mailbox.getMailList",  --获取邮件列表
    ["203"] = "mailbox.readMail",     --读取邮件
    ["204"] = "mailbox.getAttach",    --领取邮件附件
    ["215"] = "mailbox.getAllAttach",   --邮件一键领取附件

    -- ["205"] = "player.getOnlineCoin",  --领取在线金币
    ["206"] = "player.rewardOnline",   --获取在线奖励信息
    ["208"] = "player.getSpineConf",    --获取幸运大转盘配置-- rtype:1免费
    ["209"] = "player.collectionCoins", --收集金币(在线奖励)
    ["210"] = "player.getTurnTableData",--获取幸运大转盘结果
    ["211"] = "player.changeUserInfo",--客户端游客登录，更换系统头像
    ["212"] = "viplvtask.getInfo",--获取vip信息
    ["213"] = "viplvtask.getRewards", --获取vip奖励信息
    
    ["333"] = "player.getCfgData", --获取一些配置数据
    
    
    ["216"] = "quest.getInfoRequest",--获取每日任务信息
    ["217"] = "quest.getQuestReward",--获取任务奖励
    ["218"] = "quest.newbie", --新手任务
    ["219"] = "quest.getNewBieRewards", --领取奖励
    ["221"] = "quest.getDailyBonus", 

    ["220"] = "player.collectOfflineAwards", --收取离线金币奖励
    ["222"] = "player.report", --用户举报
    ["223"] = "player.reportmsg", --用户举报聊天内容
    ["240"] = "quest.getFBInfo", --获取FB分享能拿到的金币
    ["241"] = "quest.shareDaily", --FB分享成功
    ["242"] = "player.getRankList", --获取金币时榜
    ["243"] = "player.getTopRankList", --获取简要排行榜
    ["244"] = "player.bindFaceBook", --FB绑定
    ["245"] = "player.statistics", --数据统计打点
    ["246"] = "player.testbindFaceBook", --测试绑定fb
    ["247"] = "quest.shareTurntable", --FB分享轮盘抽奖
    -- ["249"] = "player.getMoneyBag", --金猪系统

    -- ["248"] = "mailbox.addZBMatchInfo", --争霸赛前三名填信息
    -- ["250"] = "player.getBoostOrDoubleXP", --等级条下面是否要展示升级加速的条
    ["251"] = "player.getDotBonus", --标签页红点奖励
    ["252"] = "leveluptask.getLeveUpTaskInfo", -- 拉取升级任务信息
    ["253"] = "leveluptask.getLeveUpTaskAward", -- 领取升级任务奖励

    ["254"] = "invite.info", --邀请信息
    ["255"] = "invite.myrefers", --我的下级列表
    ["256"] = "invite.comm", --我的奖励列表
    ["257"] = "invite.bindCode", --被邀请人绑定邀请码
    ["259"] = "invite.commdetail", --我某天的收益详情
    ["260"] = "viplvtask.getTransferCfg", --获取bonus转出的vip配置信息
    ["258"] = "player.getRankTop5", --获取某个榜的前5

    ["261"] = "invite.myagents", --我的下级列表
    ["262"] = "invite.myrefersnew", --我的奖励列表

    ["263"] = "pay.getShopListPortraitVersion", --获取所有购买信息列表，竖版Cash 使用
    ["293"] = "pay.getShopListTishen", --提审专用，配合商城
    ["285"] = "pay.getLimitTimeShop", --和263
    ["264"] = "pay.getFree", --领取免费的金币或钻石
    ["425"] = "pay.collectFirstPayGift", -- 领取首充奖励(也可以单独的获取礼包内容)
    ["429"] = "pay.exchangeGods", --用户使用钻石兑换金币
    ["70"] = "pay.ipayOrder",     --下单
    ["71"] = "pay.ipayVerify",    --验证
    ['356'] = "pay.testBuyCoin", --购买钻石测试

    ["267"] = "invite.commcarousel",    --收益轮播
   
    ["265"] = "mail.getMailList",  --获取邮件列表(新的)
    ["266"] = "mail.getMailDetail",  --获取邮件详情(新的)
    ["268"] = "mail.takeAttach",  --领取附件(新的)
    ["269"] = "mail.takeAllAttach",  --领取所有附件(新的)

    ["270"] = "friend.getList",  --赠送列表
    -- ["271"] = "friend.present",  --赠送
    ["271"] = "friend.closeChat", --关闭私聊
    ["272"] = "friend.presentAll",  --一键赠送
    ["273"] = "friend.addFriend",  --添加好友
    ["274"] = "friend.removeFriend",  --删除好友
    ["278"] = "friend.getRecommends", --刷新推荐列表

    ["281"] = "player.getBonusInfo",  --获取bonus相关信息
    ["284"] = "player.addGuide", --记录新手引导步骤
    ["289"] = "player.initCache", --初始化缓存数据

    ["290"] = "quest.getSpecialQuest", -- 获取当日特殊任务信息
    ["291"] = "quest.getSpecialQuestReward", -- 获取当日特殊任务奖励

    ["294"] = "cluster.master.tournamentmgr.getList", -- 获取赛事房间列表
    ["295"] = "cluster.master.tournamentmgr.detail", -- 赛事详细信息
    ["296"] = "cluster.master.tournamentmgr.register", -- 报名赛事
    ["297"] = "cluster.master.tournamentmgr.enterRoom", -- 进入赛事房间

    ["310"] = "player.getRandUsers",  -- 获取随机在线用户
    ["311"] = "player.getSessUser", --根据游戏id获取每个场次的人数
    ["315"] = "player.bonuslog", --获取bonuslog
    ["322"] = "player.chat",  -- 聊天 拉所有数据
    ["334"] = "player.chat",  -- 聊天 --发送内容
    ["335"] = "player.invite2Room",  -- 发送邀请加入房间到世界聊天
    ["336"] = "player.getSalonTest", --3天沙龙体验卡

    ["342"] = "maintask.getTaskList", -- 获取任务信息
    ["343"] = "maintask.getTaskReward", -- 获取任务奖励
    ["344"] = "quest.loginBonus", --login bonus可获取的范围
    ["345"] = 'quest.getWheelRecords', --获取用户的转盘记录

    -- ["354"] = "player.gameDisAreaInfo", --游戏区域分布信息
    -- ["355"] = "player.gameDisArea", --游戏区域分布
    ["357"] = "player.rateStar", --5星好评
    ["360"] = "friend.getFbShare", --好友系统一键领取fb分享加倍
    ["361"] = "player.expression", --游戏内使用互动表情

    ['362'] = "player.promolist", --促销信息
    ['363'] = "player.promodetail", --促销详情

    ["414"] = "knapsack.exprestimes", --能使用的魅力值道具次数列表
    ["415"] = "knapsack.getList", --背包列表
    ["416"] = "sign.getVIPInfo",  --获取vip周登录情况
    ["417"] = "sign.doVIPSign",  --vip周登录奖励签到

    ["418"] = "viplvtask.traninfo", --获取可转的现金余额的信息
    ["419"] = "viplvtask.tranjob", --将bonus转到可用现金

    ["420"] = "knapsack.useSkinExp", --使用经验值道具
    ['421'] = "player.getSkins", --获取皮肤商城列表
    ['422'] = 'player.exchangeSkin',
    ['423'] = 'player.chatHeartbeat', --聊天室心跳包
    ['424'] = 'player.leaveChat', -- 离开聊天室
    
    ["430"] = "quest.shareVarWhatapp", --分享whatapp
    ["448"] = "friend.procRequest", --审核通过/拒绝
    ["449"] = "friend.addRequestList", --待我审核的请求列表
    ["450"] = "friend.getGameUsers", --获取最近一起玩游戏的玩家列表
    ["451"] = "friend.chat", --好友之间私聊
    ["452"] = "friend.chatlist", --好友之间的聊天列表
    ["453"] = "friend.sigleChatList", --单个好友间的聊天记录
    ["460"] = "quest.doneView", --完成查看vip权益或排行榜
    ["463"] = "friend.allchatlist", --好友私聊汇聚一起
    ["468"] = "friend.getLikeUIDs", --更加搜索uid显示列表
    ["469"] = "friend.delChat", --删除好友间私聊信息

    ["471"] = "club.getRecommendList",  -- 获取推荐俱乐部
    ["472"] = "club.getRankList",  -- 获取俱乐部排名
    ["473"] = "club.create",  -- 创建一个俱乐部
    ["474"] = "club.getInfo",  -- 获取单个俱乐部详情
    ["475"] = "club.apply",  -- 申请加入一个俱乐部
    ["476"] = "club.applyList",  -- 获取申请列表
    ["477"] = "club.handleApply",  -- 审核申请
    ["478"] = "club.deleteFromClub",  -- 剔除一个用户
    ["479"] = "club.fetchMember",  -- 获取俱乐部成员列表
    ["480"] = "club.signIn",  -- 俱乐部签到
    ["481"] = "club.exitClub",  -- 退出俱乐部
    ["482"] = "club.modifyClub",  -- 修改俱乐部
    ["483"] = "club.getRoomList",  -- 获取俱乐部列表
    ["484"] = "club.createRoom",  -- 创建俱乐部房间
    ["485"] = "club.joinRoom",  -- 加入俱乐部房间
    ["486"] = "club.inviteFriend",  -- 邀请加入俱乐部房间

    ["500"] = "privateroom.createRoom",  -- 私人房创房
    ["501"] = "privateroom.joinRoom",  -- 加入私人房
    ["502"] = "privateroom.queryGame",  -- 根据房间号查询私人房对用的游戏第
    ["503"] = "privateroom.inviteFriend",  -- 邀请加入私人房
    ["504"] = "privateroom.dismissRoom",  -- 解散房间
    ["505"] = "privateroom.incomeRecode",  -- 获取房间收益记录
    ["506"] = "privateroom.getIncome", --手动领取房间收益

    ["510"] = "cluster.master.raceroommgr.raceInfo",  -- 比赛场入口信息
    ["511"] = "cluster.master.raceroommgr.joinRace",  -- 进入比赛场
    ["512"] = "player.getRaceInfo",  -- 获取当前信息
    ["513"] = "player.player777Game",  -- 玩777小游戏
    ["514"] = "player.getCustomerService", --获取客服信息   
    --- 多系统通用协议号 start --- 
    ["660"] = "charm.buy", --背包中购买魅力值道具
    ["661"] = "charm.send", --赠送魅力值道具
    ["662"] = "charm.sendList", --赠送出去的列表
    ["663"] = "charm.receiveList", --收到的列表
    ["664"] = "exchange.activate", --兑换码激活
    ["665"] = "charm.getCharmPack", --获取新人大礼包魅力值道具
    --- 多系统通用协议号 end --- 

    ["700"] = "player.getRecentGameRecord", -- 获取最近战绩

    ["29"] = "player.getCoin",  --获取玩家金币
    ["30"] = "player.getGameSessList", --游戏场次列表（牌类）
    ["34"] = "player.getGameRoomList", --游戏房间列表（百人类）
    ["31"] = "cluster.game.dsmgr.createDeskInfo",
    ["32"] = "cluster.game.dsmgr.joinDeskInfo",

    ["33"] = "cluster.game.dsmgr.sitdown",     --坐下
    ["35"] = "cluster.game.dsmgr.ready",    --准备
    ["36"] = "cluster.game.dsmgr.grab",     --抢庄
    ["37"] = "cluster.game.dsmgr.bet",      --押注(闲)
    ["38"] = "cluster.game.dsmgr.read",     --搓牌
    ["39"] = "cluster.game.dsmgr.show",     --亮牌
    ["40"] = "cluster.game.dsmgr.exitG",    --退出房间
    ["41"] = "cluster.game.dsmgr.getGPS",   --查看房间GPS
    ["42"] = "cluster.game.dsmgr.getVistors", --查看房间围观群众
    ["43"] = "cluster.game.dsmgr.matchSess",  --匹配房间

    -----------------------拉霸游戏通用相关协议-----------------------------
    ["44"] = "cluster.game.dsmgr.start",      --开始游戏
    ["45"] = "cluster.game.dsmgr.setBaseMult", --下注倍数

    ["46"] = "cluster.game.dsmgr.joinSubGame", --加入小游戏
    ["47"] = "cluster.game.dsmgr.exitSubGame", --退出小游戏
    ["50"] = "cluster.game.dsmgr.selectFreeParam",  -- 选择免费游戏参数
    ["51"] = "cluster.game.dsmgr.gameLogicCmd", --通用游戏业务内逻辑
    ["52"] = "cluster.game.dsmgr.switchDesk",    --退出房间

     -----------------------拉霸所有的免费游戏选参数走这条协议-----------------------------
    ["53"] = "player.getNotice",   --获取系统消息
    -- ["57"] = "player.readMgs",       --读取消息
    ["58"] = "player.exitG",         --退出游戏
    ["59"] = "player.pushmsg",       --大厅获取跑马灯

    ["62"] = "player.getUserInfo",  --获取个人信息
    -- ["63"] = "player.exchangeAvatarFrame", --兑换头像框

    ["81"] = "cluster.game.dsmgr.cashout", --Crash游戏 提起资金

    ["95"] = "cluster.game.dsmgr.shoufen", --水浒传
    ["96"] = "player.getVersion", --获取大厅版本号

    ["112"] = "cluster.game.dsmgr.sendChatMsg", --房间内聊天

    ["149"] = "player.getBankruptInfo", --获取破产信息
    ["150"] = "player.refreshLeagueExp", --子游戏回大厅，刷新最高leagueexp值
    ["151"] = "player.collectBankrupt", --玩家收集破产补助
    -- ["152"] = "player.getVipRewards", --一键领取vip奖励(激活vip或升级vip后)
    ---------------------------------

    ["168"] = "quest.getChangeNickRewards", --修改昵称后，直接领取奖励
    ["169"] = "player.feedback", --用户反馈
    -- ["170"] = "cluster.master.balmatchmgr.joinMatch", --进入匹配场
    -- ["171"] = "cluster.master.balmatchmgr.cancelMatch", --取消匹配
    ["172"] = "cluster.master.balviproommgr.createVipRoom", --创建VIP房
    ["173"] = "cluster.master.balviproommgr.joinVipRoom", --加入vip房
    ["174"] = "cluster.master.balviproommgr.exitVipRoom", --退出vip房(等待人满前)
    -- ["175"] = "cluster.master.balviproommgr.getVipRoomList", --获取vip房间列表
    -- ["176"] = "cluster.master.balviproommgr.exitRoomList", --退出房间列表
    -- ["177"] = "cluster.master.balviproommgr.seatVipRoom", --vip房间列表直接坐下

    ["175"] = "cluster.master.balprivateroommgr.getRoomList", --获取vip房间列表
    ["176"] = "cluster.master.balprivateroommgr.exitRoomList", --退出房间列表
    ["177"] = "privateroom.seatRoom", --vip房间列表直接坐下

    -- ["178"] = "league.info", --排位赛信息
    -- ["179"] = "league.invite", --邀请好友排位赛或匹配房
    -- ["180"] = "league.kickout", --踢掉好友
    -- ["181"] = "cluster.master.balmatchmgr.joinLeague", --开始排位赛
    -- ["182"] = "league.accept", --同意好友邀请进入排位赛或匹配房
    -- ["183"] = "cluster.master.balmatchmgr.cancelLeagueh", --取消排位赛匹配
    -- ["184"] = "league.leave", --退出组队
    -- ["185"] = "league.enteronline", --进入匹配房
    -- ["186"] = "cluster.master.balmatchmgr.changeSess", --切换场次(邀请好友组队后再切换场次)
    ["187"] = "league.signup", --联赛报名
    ["188"] = "league.signupinfo", --联赛签到信息
    ["189"] = "league.gameRankHistory", --该游戏排位赛历届总冠军
    ["190"] = "league.getPrevSeasonReward", -- 领取赛季奖励
    ["191"] = "player.getFBShareRewardsInGame", --房间内分享完fb后，领取金币奖励
    ["192"] = "player.acceptInvite", --处理邀请
    ["193"] = "player.getBetRecords", --获取游戏投注记录
    ["194"] = "player.getRakeBackInfo", -- 获取游戏反水记录
    ["195"] = "player.getRakeBackReward", -- 领取游戏反水记录
    ["196"] = "player.getGameRecords", --获取游戏历史开奖记录
    ["197"] = "player.getLeaderBoard", -- 获取排行榜信息
    ["198"] = "player.registerLeaderBoard", -- 开启排行榜
    ["200"] = "player.getLeaderBoardCfg", -- 获取排行榜配置
    ["207"] = "player.getLeaderBoardRewards", --获取排行榜奖励配置

    ["390"] = "player.updateFcmToken", --更新用户的google推送token

    ["1093"] = "player.cancelAccount", --注销账号
    ["1112"] = "cluster.game.dsmgr.actionSubGame", --具体小游戏操作
    ["1120"] = "cluster.game.dsmgr.getRecords",  --获取游戏记录(趋势图)
    ["1121"] = "cluster.game.dsmgr.getUserList", --获取房间内的玩家列表
    ["1122"] = "cluster.game.dsmgr.getRankList", -- 获取游戏内排行榜
    ["1123"] = "cluster.game.dsmgr.getResRecords",  --获取游戏开奖结果记录

    ---------------------- 捕鱼 ---------------------------------
    ["2401"] = "cluster.game.dsmgr.matchSess",          --匹配房间
    ["2402"] = "cluster.game.dsmgr.fire",               --玩家发射
    ["2403"] = "cluster.game.dsmgr.catch",              --玩家捕获
    ["2404"] = "cluster.game.dsmgr.ionEnd",             --离子炮结束
    ["2405"] = "cluster.game.dsmgr.bomb",               --炸弹
    ["2406"] = "cluster.game.dsmgr.luckdraw",           --抽奖

    ----------------------- 21点 ------------------------------
    ["25501"] = "cluster.game.dsmgr.bet",           --下注
    ["25502"] = "cluster.game.dsmgr.stand",         --停牌
    ["25503"] = "cluster.game.dsmgr.hit",           --要牌
    ["25504"] = "cluster.game.dsmgr.double",        --加倍
    ["25505"] = "cluster.game.dsmgr.split",         --拆牌
    ["25506"] = "cluster.game.dsmgr.insure",        --投保/拒保

    --baloot
    ['25601'] = "cluster.game.dsmgr.chooseGameType", --选择玩法
    ['25602'] = "cluster.game.dsmgr.putCard", --出牌
    ['25603'] = "cluster.game.dsmgr.sira",
    ['25604'] = "cluster.game.dsmgr.actLockOrOpen",
    ['25605'] = "cluster.game.dsmgr.GAHWAOrPass",
    ['25606'] = "cluster.game.dsmgr.cancelAuto",
    ['25607'] = "cluster.game.dsmgr.chooseSuit",
    ['25608'] = "cluster.game.dsmgr.sendChat", --房间内聊天
    ['25609'] = "cluster.game.dsmgr.sawa", --sawa
    ['25610'] = "cluster.game.dsmgr.exitG", --exitgame
    ['25611'] = "cluster.game.dsmgr.chatIcon", --切换语聊按钮

    -- 下面的命令会通用
    ['25701'] = "cluster.game.dsmgr.goDown",  -- 放置牌组到桌面上
    ['25702'] = "cluster.game.dsmgr.discard",  -- 丢牌
    ['25703'] = "cluster.game.dsmgr.draw",  -- 摸牌，可以摸上家牌或者牌堆牌
    ['25704'] = "cluster.game.dsmgr.insertMeld",  -- 放置牌到桌面牌组中
    ['25705'] = "cluster.game.dsmgr.sendChat", --房间内聊天
    ['25706'] = "cluster.game.dsmgr.exitG", --exitgame
    ['25707'] = "cluster.game.dsmgr.cancelAuto",  -- 取消托管
    ['25708'] = "cluster.game.dsmgr.ready",  -- 准备
    ['25709'] = "cluster.game.dsmgr.start",  -- 开始

    ['25710'] = "cluster.game.dsmgr.choose",  -- 叫庄
    ['25711'] = "cluster.game.dsmgr.chooseSuit",  -- 选择主牌

    ['25712'] = "cluster.game.dsmgr.applyDismiss",  -- 发起解散
    ['25713'] = "cluster.game.dsmgr.replyDismiss",  -- 同意/拒绝 解散
    ['25714'] = "cluster.game.dsmgr.showCard",  -- 选择亮牌
    ['25715'] = "cluster.game.dsmgr.pass",  -- 过(要不起)
    ['25716'] = "cluster.game.dsmgr.dashCall",  -- dashCall
    ['25717'] = "cluster.game.dsmgr.chooseScore",  -- 选择分数

    ['25718'] = "cluster.game.dsmgr.enterAuto",  -- 进入托管
    ['25719'] = "cluster.game.dsmgr.seatDown",  -- 选择座位坐下
    ['25720'] = "cluster.game.dsmgr.chooseRule",  -- 选择游戏规则

    ['25721'] = "cluster.game.dsmgr.switchCard",  -- 换牌
    ['25722'] = "cluster.game.dsmgr.chooseInitScore",  -- 选择初始化分数
    ['25723'] = "cluster.game.dsmgr.concan",  -- 选择concan
    ['25724'] = "cluster.game.dsmgr.darba",  -- darba

    ['25725'] = "cluster.game.dsmgr.uno",  -- uno
    ['25726'] = "cluster.game.dsmgr.unoChallenge",  -- uno challenge
    ['25727'] = "cluster.game.dsmgr.challenge",  -- challenge 质疑
    ['25728'] = "cluster.game.dsmgr.intentCard", -- uno里面出牌前指定的意向牌

    ['25729'] = "cluster.game.dsmgr.chooseUser", -- saudi deal 中选择一个玩家
    ['25730'] = "cluster.game.dsmgr.chooseCard", -- saudi deal 中选择一张卡
    ['25731'] = "cluster.game.dsmgr.actionReponse", -- saudi deal 中响应卡牌操作
    ['25732'] = "cluster.game.dsmgr.oppose",  -- saudi deal 出抵抗牌
    ['25733'] = "cluster.game.dsmgr.refuseOppose",  -- saudi deal 出抵抗牌

    ['25734'] = "cluster.game.dsmgr.updateUserMic",  -- 更改用户麦克风状态

    -- teenpatti相关命令
    ['25735'] = "cluster.game.dsmgr.bet",  -- 下注
    ['25736'] = "cluster.game.dsmgr.seeCards",  -- 查看自己牌
    ['25737'] = "cluster.game.dsmgr.sideShow",  -- 申请比对上家的牌
    ['25738'] = "cluster.game.dsmgr.sideShowRes",  -- 是否同意比牌
    ['25739'] = "cluster.game.dsmgr.show",  -- 最后两人比牌
    ['25740'] = "cluster.game.dsmgr.pack",  -- 弃牌

    -- 德州扑克相关命令
    ['25741'] = "cluster.game.dsmgr.showCard",  -- 认输后亮牌
    ['25742'] = "cluster.game.dsmgr.check",  -- 用户check

    --ludo
    ["26901"] = "cluster.game.dsmgr.rollDice", --摇骰子
    ["26902"] = "cluster.game.dsmgr.moveChess", --走棋子
    ['26903'] = "cluster.game.dsmgr.ready",  -- 准备
    ['26904'] = "cluster.game.dsmgr.resetDice", --摇完骰子后花钻石继续摇一下

    --durak
    ["27401"] = "cluster.game.dsmgr.take", --take
    ["27402"] = "cluster.game.dsmgr.done", --done

    --rummy
    ["29201"] = "cluster.game.dsmgr.drop",      --弃牌
    ["29202"] = "cluster.game.dsmgr.draw",      --摸牌
    ["29203"] = "cluster.game.dsmgr.show",      --亮牌
    ["29204"] = "cluster.game.dsmgr.discard",   --出牌
    ["29205"] = "cluster.game.dsmgr.arrange",   --理牌
    ["29206"] = "cluster.game.dsmgr.confirm",   --定牌
}

PDEFINE_MSG.NOTIFY =
{
    msg     = 1001, --新邮件，消息，跑马灯通知
    online  = 1002, --上线通知指令
    join    = 1003, --加入房间
    sitdown = 1004, --坐下
    ready   = 1005, --准备
    start   = 1006, --开始
    sendcard= 1007, --发牌
    grab    = 1008, --抢庄
    banker  = 1009, --庄家来了
    coin    = 1010, --玩家金币减少
    show    = 1011, --玩家亮牌
    blance  = 1012, --一局结算
    leave    = 1013, --有人离开房间  围观群众离开
    bet     = 1014, --有人押注
    betfinish = 1015, --全部现家押注完
    exit      = 1016, --玩家离开
    otherlogin = 1017,--你的账号已在其它设备上登陆
    RED_LUCK_TURNTABLE = 1018, --后台掉落转盘奖品
    SYNCLOBBYINFO = 1019,       -- 同步大厅任务信息
    storegift = 1020, -- 商城礼包
    changefield = 1021, --修改客户端某些缓存字段值
    -- 梭哈
    giveup     = 1030, --有人弃牌
    nextaction = 1031, --下一个人说话
    pass       = 1032, --过
    follow     = 1033, --跟注
    fill       = 1034, --加注

    BUY_OK = 1035, --购买成功
    REWARD_ONLINE = 1036,-- 在线奖励通知
    UQEST_DONE = 1037,--任务有完成
    REWARD_PRAISE = 1038,-- 可以好评了
    RED_PACKET_INGAME = 1039, --游戏中获得红包bb
    LUNCKSPINE_ONLINE = 1040,      -- 幸运大转盘
    TURNTABLE_STATE = 1041,   --转盘领取奖励(大厅)
    CHARM_INFO = 1042, --谁给谁送道具了，魅力值道具
    LEAGUE_STATUS = 1043, --排位赛开启状态变更
    UPDATE_LEVEL = 1050, --个人等级上升了
    UPDATE_VIP_INFO = 1051, --vip等级上升了
    UPDATE_LEVEL_EXP = 1052, --个人经验值变化
    QUEST_PROCESS = 1053, --玩家任务进度
    -- UPDATE_USERWINRANK = 1054, --游戏排行榜刷新
    -- UPDATE_SLOTWINKRANK = 242, --游戏排行榜刷新,客户端请求以及同协议号推送
    USER_HAVE_SPEFFECT = 1055,  -- 有玩家在游戏中触发了spEffect
    STAMP = 1056, -- 集邮系统推送
    BANKRUPT_NOTICE = 1057, --破产通知
    MAIL_STATUS = 1058, -- 邮件状态推送
    FRIEND_ADDED = 1059, --有人添加你为好友了

    ONE_TIME_ONLY_OVER = 10056, --新手礼包关闭协议
    POP_LIST = 1060, --弹窗通知
    FUND_BUYED = 1061, --基金购买成功
    CARD_BUYED = 1062, --周卡月卡购买成功
    HAMME_BUYED = 1063, --锤子购买成功
    HEROCARD_DROP = 1064,    --英雄卡牌掉落
    REVIVE_BUYED = 1065, --复活卡购买成功
    BINGO_BUFF_BUYED = 1066, -- bingo buff 购买
    BINGO_GIFT_BUYED = 1067, -- bingo point 购买

    NEWBIE_TASK_UPDATE = 1068, -- 新手任务更新
    REVIVE_BOSSCARD_BUYED = 1069, --超级复活卡购买成功
    QUEST_UPDATED = 1070, --任务完成了通知客户端(新手任务和每日任务)

    NOTIFY_CHANGE_CHAT = 1091, --字段值更新到聊天室
    NOTIFY_CHAT_CONTENT = 1092, --广播聊天消息内容
    NOTIFY_CHAT_DEL = 1094, --广播删除单条聊天
    NOTIFY_CLEAR_CHAT = 1095, --清空聊天室

    NOTIFY_CLUB_JOIN = 1080,  -- 通知俱乐部加入信息
    NOTIFY_CLUB_REMOVE = 1081,  -- 通知俱乐部被提消息

    DOMINUO_SEND_COIN = 1082, --domino的金币，pass 给金币给上家

    NOTIFY_SWITCH_DESK = 1083,  -- 通知切换桌子

    NOTIFY_TN_GAME_START = 1084,  -- 锦标赛开始
    NOTIFY_TN_GAME_UPDATE = 1085,  -- 锦标赛更新
    NOTIFY_TN_GAME_OVER = 1086,  -- 锦标赛结束(淘汰)
    NOTIFY_TN_GAME_WAIT_SWITCH = 1087,  -- 锦标赛等待换桌
    NOTIFY_TN_GAME_WAIT_SETTLE = 1088,  -- 锦标赛等待结算
    NOTIFY_TN_GAME_SETTLE = 1089,  -- 锦标赛结算
    NOTIFY_TN_GAME_REFUND = 1090,  -- 锦标赛退款

    VOTE_COUNTRY = 10355, --国家投票后通知

    MUST_RESTART = 801, --必须重启
    ALL_GET_OUT = 100050, --后台API 解散房间 T回大厅
    NOTIFY_NOTICE_HALL = 100051, --大厅推送消息
    NOTIFY_NOTICE_GAME = 100052, --游戏跑马灯消息
    NOTIFY_MAIL = 100053,     --邮件通知
    NOTIFY_SYS_KICK = 100054, --系统T掉某个人 T到登录界面
    MARQUEE_ALL  = 100055, --全服推送跑马灯
    NOTIFY_CAHT_ALL = 100056, --全服推送chat
    NOTIFY_USER_INFO = 100057, --玩家信息更新

    
    NOTIFY_LEVEL_INFO    = 100058, --段位信息配置变化
    NOTIFY_GAMELIST_INFO = 100059, --子游戏状态更新
    NOTIFY_BIGBANG       = 100060, --bigbang更新
    NOTIFY_RELOGIN       = 100061, --通知客户端重新走一遍登录
    NOTIFY_DESKUSER_INFO = 100062, --通知客户端更新游戏内的玩家信息
    NOTIFY_LEVELUP_TASK  = 100063, --通知客户端升级任务状态改变
    ONLINEMULT_CHANGE  = 100064, --通知客户端倍数变更
    MONEYBAG_IS_FULL = 100065, --金猪满了
    PUBLIC_NOTICE = 100066, --自动7天签到
    NOTIFY_LEAGUE_EXP = 100067,  --游戏联赛段位积分
    NOTIFY_LEAGUE_UPGRADE = 100068, --最高段位提升了(本来段位是按游戏来的)

    NOTIFY_RACE_UPDATE = 100069,  -- 比赛信息更新
    NOTIFY_RACE_END = 100070,  -- 比赛结束

    NOTIFY_GAME_START        = 100071, -- 游戏开始倒计时
    NOITFY_CHAT_ADS        = 100072, -- 聊天置顶公告更新
    
    --房间内聊天
    NOTIFY_ROOM_CHAT         = 100202, --房间内聊天
    NOTIFY_FRIEND_CHAT       = 100203, --好友私聊

    NOTIFY_KICK              = 100906, --踢掉不准备玩家
    -- 捕鱼
    NOTIFY_FISH_JOIN        = 1003, --通知有玩家进入房间
    NOTIFY_FISH_EXIT        = 1016, --通知有玩家退出房间
    NOTIFY_FISH_ADD_FISH    = 102405, --增加鱼
    NOTIFY_FISH_SWITCH_SNENE= 102406, --切换场景
    NOTIFY_FISH_TIDE        = 102407, --鱼潮
    NOTIFY_FISH_STATE       = 102408, --房间状态
    NOTIFY_FISH_PROG        = 102409, --鱼的击杀进度
    NOTIFY_FISH_EVENT       = 102410, --捕鱼特定事件通知

    BALOOT_ROUND_START       = 125601, --开启本轮
    BALOOT_CARD              = 125602, --发牌
    BALOOT_SELECT_START      = 125603, --开始选择玩法
    BALOOT_SELECT_RESULT     = 125604, --单个用户选择完玩法的广播
    BALOOT_SELECTED          = 125605, --用户选择玩法通知
    BALOOT_SELECT_END        = 125606, --用户确认玩法
    BALOOT_GAME_START        = 125607, --本轮游戏正式开始(牌都发完了)
    BALOOT_PUT_CARD          = 125608, --出牌
    BALOOT_ROUND_OVER        = 125609, --本轮结束
    BALOOT_GAME_OVER         = 125610, --本局结束
    BALOOT_EXIT_ROOM         = 125611, --有人离开房间
    BALOOT_CHOOSE_SUIT       = 125612, --通知选花色
    BALOOT_CAN_SIRA          = 125613, --can sira
    BALOOT_GAME_SIRA_RESULT         = 125614, --sira result
    BALOOT_SUIT_SELECTED     = 125615, --花色选定
    BALOOT_USER_AUTO         = 125616, --用户进入或取消自动状态
    BALOOT_SAWA              = 125617, --sawa
    BALOOT_MATH_RESULT       = 125618, --匹配成功
    BALOOT_JOIN_VIPROOM      = 125619, --加入vip房间成功
    BALOOT_REFLASH_VIPROOM   = 125620, --刷新VIP列表页面
    BALOOT_DISMISS_VIPROOM   = 125621, --VIP房间解散
    
    BALOOT_LEAGUE_INVITE     = 125622, --好友邀请加入排位赛
    BALOOT_LEAGUE_ACCEPT     = 125623, --好友同意
    BALOOT_LEAGUE_REFUSE     = 125624, --好友拒绝
    BALOOT_LEAGUE_KICKOUT    = 125625, --被好友踢掉了
    BALOOT_GAME_SIRA_ACT     = 125626, --sira act

    -- 通用协议
    -- 以后有新增协议，直接往后加
    -- 单个玩家相关的已 Player 开头
    -- 牌局相关的以 Game 开头
    GAME_DESKINFO              = 126000, -- 广播桌子信息
    PLAYER_ENTER_ROOM          = 126001, -- 加入房间
    PLAYER_READY               = 126002, -- 玩家准备
    GAME_DEAL                  = 126003, -- 游戏开始发牌
    PLAYER_AFK                 = 126004, -- 玩家托管
    GAME_ROUND_OVER            = 126005, -- 小结算
    GAME_OVER                  = 126006, -- 大结算
    PLAYER_DISCARD             = 126007, -- 玩家出牌
    PLAYER_DRAW                = 126008, -- 玩家抓牌
    PLAYER_GODOWN              = 126009, -- 玩家下牌
    PLAYER_INSERT_MELD         = 126010, -- 玩家插牌到桌面牌组
    PLAYER_EXIT_ROOM           = 126011, -- 玩家退出房间
    GAME_DISMISS_ROOM          = 126012, -- 解散房间
    PLAYER_BIDDING             = 126013, -- 玩家叫牌
    PLAYER_CHOOSE_SUIT         = 126014, -- 玩家选择主牌
    PLAYER_APPLY_DISMISS       = 126015, -- 玩家申请解散
    PLAYER_REPLY_DISMISS       = 126016, -- 玩家选择(拒绝/同意)解散
    GAME_DEAL_IN_PLAY          = 126017, -- 牌局中发牌
    PLAYER_CHOOSE_METHOD       = 126018, -- 玩家选择玩法
    PLAYER_SHOW_CARD           = 126019, -- 玩家选择亮牌
    GAME_AUTO_START_BEGIN      = 126020, -- 游戏自动开始倒计时
    GAME_AUTO_START_STOP       = 126021, -- 游戏停止开始倒计时
    PLAYER_DASH_CALL           = 126022, -- 玩家选择dash call
    PLAYER_CHOOSE_SCORE        = 126023, -- 玩家选择期望分数
    PLAYER_CHOOSE_CHATICON     = 126025, -- 玩家操做语聊按钮
    PLAYER_AUTO_DISCARD_CARD   = 126024, -- 自动将所有玩家牌打出
    PLAYER_SEAT_DOWN           = 126026, -- 广播玩家坐下消息
    PLAYER_CHOOSE_GAME_RULE    = 126027, -- 选择游戏规则
    PLAYER_VIEWER_ENTER_ROOM   = 126028, -- 有人进入房间观战
    PLAYER_VIEWER_EXIT_ROOM    = 126029, -- 有人退出房间观战
    PLAYER_UPDATE_INFO         = 126030, -- 用户更新信息
    PLAYER_PASS                = 126031, -- 玩家pass
    PLAYER_DANGER_COIN         = 126032, -- 玩家金币快不足了
    PLAYER_SWITCH_CARD         = 126033, -- 玩家换牌
    PLAYER_SWITCH_CARD_RESULT  = 126034, -- 玩家换牌结果
    PLAYER_CHOOSE_INIT_SCORE   = 126035, -- 玩家选择初始分数
    PLAYER_DARBA               = 126036, -- 玩家darba

    PLAYER_CHOOSE_USER         = 126037, -- 玩家选择玩家
    PLAYER_CHOOSE_CARD         = 126038, -- 玩家选择卡牌
    PLAYER_ACTION_RESPONSE     = 126039, -- 玩家响应操作
    PLAYER_OPPOSE              = 126040, -- 玩家拒绝操作
    GAME_DISMISS_TIMEOUT       = 126041, -- 游戏解散超时
    GAME_DISMISS_CANCEL        = 126042, -- 游戏取消解散
    PLAYER_MIC_STATUS          = 126043, -- 玩家麦克风状态变更

    PLAYER_OVER_RESET_DICE     = 126044, -- Ludo玩家结束重置色子
    GAME_BET                   = 126045, -- 游戏开始下注 (blackjack)
    GAME_INSURE_OVER           = 126046, -- 保险结束 (blackjack)

    PLAYER_TAKE                = 127401, -- durak玩家take
    PLAYER_DONE                = 127402, -- durak玩家done
    PLAYER_CONCAN              = 127403, -- 玩家concan
    PLAYER_UNO                 = 127404, -- 玩家uno
    PLAYER_UNO_CHALLENGE       = 127405, -- 玩家举报uno challenge
    PLAYER_CHALLENGE           = 127406, -- 玩家质疑上家出的+4牌
    PLAYER_CAN_UNO_CHALLENGE   = 127407, -- 有玩家可以被Uno挑战
    PLAYER_COLLECT_LAST_CARDS  = 127408, -- ronda中玩家收集最后的牌

    CLUB_JOIN_ROOM           = 126101,  -- 加入俱乐部房间
    CLUB_INVITE_GAME         = 126102,  -- 邀请加入俱乐部游戏

    FRIEND_INVITE_GAME       = 126201,  -- 邀请加入游戏
    FRIEND_INVITE_BACK      = 126202,  -- 邀请反馈

    -- teenpatti 相关命令
    PLAYER_BET                 = 126301,  -- 用户下注
    PLAYER_SEE_CARDS           = 126302,  -- 用户看牌
    PLAYER_SIDE_SHOW           = 126303,  -- 用户比牌(剩余两个人以上，和上家比牌，上家已看牌)
    PLAYER_SIDE_SHOW_RESP      = 126304,  -- 用户比牌响应
    PLAYER_SHOW                = 126305,  -- 用户比牌(剩余两个人)
    PLAYER_PACK                = 126306,  -- 用户弃牌
    PLAYER_TURN_TO             = 126307,  -- 轮到某用户操作
    PLAYER_SIT_UP              = 126308,  -- 玩家站起来
    GAME_BOARD_DEAL            = 126309,  -- 公共牌发牌
    PLAYER_FOLD_SHOW           = 126310,  -- 用户弃牌后公示牌
    PLAYER_CHECK               = 126311,  -- 用户Check

    ROLLE_RESULT = 126901, --摇骰子的结果
    MOVE_RESULT = 126902,


    --押注类百人游戏通用通知
    BET_STATE_FREE = 128000,    --空闲阶段
    BET_STATE_BETTING = 128001, --下注阶段
    BET_STATE_SETTLE = 128002,  --结算阶段
    BET_USER_BET= 128003,       --玩家下注
    BET_PLAYER_COUNT = 128004,  --玩家人数
    BET_USER_CASHOUT = 128005,  --玩家提取资金(Crash)
    BET_STATE_PALY = 128006,    --游戏阶段(Crash开始发射)

    NOTIFY_READY = 2000, --准备通知
    NOTIFY_PUT_CARD = 2001,--出牌通知
    NOTIFY_PASS_CARD = 2002,--通知弃牌
    NOTIFY_NO_READY_DELTE_GAME = 2003, --游戏未开始房主直接解散
    NOTIFY_READY_DELTE_GAME = 2004,     --游戏开始发起解散
    NOTIFY_VOTE = 2005,                 --投票解散
    NOTIFY_CHAT = 2006,                 --聊天通知
    ROUND_OVER = 2007,                   --小结算
    ROOM_OVER = 2008,                   --大结算
    NOTIFY_ONLINE = 2009,               --在线或者离线通知
    NOTIFY_TOUCH_CARD = 2010,           --通知玩家出牌
    NOTIFY_TOUCH_START = 2011,           --通知开始
    NOTIFY_GIVEUP = 2012,           -- 通知弃牌
    NOTIFY_CONFIRM_START = 2013,           -- 通知确认开始
    NOTIFY_CONFIRM = 2014,           -- 通知确认
    NOTIFY_AUTO_START = 2015,


    -- slot类型
    SLOT_SELECT_FREE = 11130,

 
}

return PDEFINE_MSG
