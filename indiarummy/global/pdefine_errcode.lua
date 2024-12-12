PDEFINE_ERRCODE =
{
    ["SUCCESS"] = 200,              -- 成功
    ["UNDEFINE"] = 300,             -- 未定义错误
    ["ERROR"] =
    {
        ["EXIT_RESET"] = 199, --主動退出
        ["REGISTER_ALREADY"] = 201, --已注册
        ["REGISTER_NOT"] = 202, --未注册
        ["LOGIN_FAIL"] = 203, --账号或者密码错误
        ["REGISTER_FAIL"] = 208, --登录失败,请重新登录
        ["PARAM_NIL"] = 209, --参数为空
        ["PARAM_ILLEGAL"] = 210, --参数非法
        ["TOKEN_ERR"] = 211, --token失效
        ["DBPUSH_ERR"] = 212, --系统错误-数据库-更新
        ["PASSWD_ERR"] = 213, --密码错误
        ["RES_VERSION_ERR"] = 214,  --资源版本号错误需要更新
        -- ["APP_VERSION_ERR"] = 215,  --APP版本号错误需要更新
        ["IP_ADDR_LIMIT"] = 216, --IP限制
        ["DDI_ADDR_LIMIT"] = 217, --设备限制
        ['PHONE_LIMIT'] = 218, --手机型号受限制
        ['INVITE_FREQUENTLY'] = 398, --邀请太多频繁
        ["NOT_BUY_TURNTABLE"] = 399,  --没购买轮盘资格
        ['LOGIN_PASSWD_ERR'] = 333, --手机号登录密码错误
        ['OTP_IS_ERR'] = 334, --手机号验证码错误
        ['OTP_IS_EMPTY'] = 335, --需要手机号验证码
        ['DINFO_IS_NULL'] = 336, --缺少dinfo字段信息
        ['DINFO_GID_NULL'] = 337, --dinfo字段信息缺少gid
        ['DINFO_SID_NULL'] = 338, --dinfo字段信息缺少sid

        ["CALL_FAIL"] = 400,        -- 调用错误
        ["DB_FAIL"] = 401,      -- 数据库错误
        ["BAD_REQUEST"] = 402,      -- 错误请求
        ["UNAUTHORIZED"] = 403,     -- 认证失败
        ["INDEX_EXPIRED"] = 404,    -- 重连索引过期
        ["PLAYER_NOT_FOUND"] = 405, -- 找不到玩家
        ["FORBIDDEN"] = 406,        -- 登录繁忙
        ["ALREADY_LOGIN"] = 407,    -- 已经登录
        ["DECODE_FAIL"] = 408,      -- 解析protocbuf错误
        ["NAME_ALREADY"] = 409,     -- 已经存在该名字
        ["ACTION_ERROR"] = 410,     -- 操作错误
        ["PLAYER_EXISTS"] = 411,    -- 已经存在角色
        ["ACCOUNT_ERROR"] = 412,    -- 账号被冻结暂不能登录
        ["HEARTBEAT_BROKEN"] = 415,
        ["ACCOUNT_ERROR_5"] = 416, --账号被冻结5秒
        ["ACCOUNT_ERROR_10"] = 417, --账号被冻结10秒
        ["ACCOUNT_ERROR_20"] = 418, --账号被冻结20秒
        ["ACCOUNT_ERROR_600"] = 419, --账号被冻结600秒
        ["SERVER_NOTREADY"] = 420, --服务器未准备好
        ["FORBIDDEN_LOGIN"] = 421, --禁止登录
        ["FORBIDDEN_AREA_LOGIN"] = 422, --账号禁止在该区域登录
        ["USERNOTFOUND"] = 423, --未找到好友信息

        ["VIP_TASK_CANNOT_GET"] = 424, --不能领取vip升级奖励
        ["GAME_NOT_OPEN"] = 425,      --游戏未开启
        ["REGISTER_NOT_OPEN"] = 426,    --注册未开放
        ['PROMO_NOT_FOUND'] = 427, --未找到促销信息
        ['PROMO_NOT_OPEN'] = 418, --促销信息未打开
        
        --大厅相关错误码450~500
        ["SIGN_NOT_VIP"] = 449, --签到vip等级不够
        ["TIMEOUT"] = 450, --金币还没有到领取时间
        ["LOCKGETMAILKEY"] = 451, --一键领取功能暂未解锁
        ["ALREADY_SIGN"] = 452, --今日已签到
        ["STAMP_SESSION_NOT_OPEN"] = 453, --邮票赛季未开启
        ["MISSION_SESSION_NOT_OPEN"] = 454, --任务赛季未开启
        ["ACTIVITY_DATE_NOT_FOUND"] = 455,  -- 找不到用户的活跃度数据
        ["ACTIVITY_NOT_ENOUGH"] = 456,  -- 找不到用户的活跃度数据
        ["HADGOTGIFT"] = 460, --已领取过礼盒金币
        ["GOTGIFTFAIL"] = 461, --取过礼盒失败
        ["MAIL_NO_ATTACH"] = 470, --无附件
        ["MAIL_ATTACH_ALREADY_TAKE"] = 471, --附件已领取
        ["MAIL_NOT_EXISTS"] = 472, --邮件不存在
        ["GIFT_NOT_FOUND"] = 480, --礼包不存在
        ["GIFT_ALREADY_TAKE"] = 481, --礼包已领取
        ["GIFT_NO_REWARD"] = 482, --礼包无奖励
        ['CHAT_FORBID'] = 483, --被禁止聊天
        ['FRIEND_ADD_FORBID'] = 484, --被禁止加好友
        ["FRIEND_NOT_EXISTS"] = 490, --好友信息不存在
        ["FRIEND_PRESENT_ALREADY_TAKE"] = 491, --好友赠送已了领取
        ["FRIEND_JACKPOT_NOT_EXISTS"] = 492, --好友Jackpot不存在
        ["FRIEND_JACKPOT_ALREADY_TAKE"] = 493, --好友Jackpot已领取
        ["FRIEND_HAD_SEND"] = 494, --您今天已经赠送过了
        ["FRIEND_NOT_EXISTS_TIMES"] = 495, --好友不存在过滤频繁
        ["CARD_HAD_COLLECT"] = 496, --今日奖励已经领取
        ["ITEM_ENOUGH"] = 501,      -- 物品不足
        ["AlREADY_READY"] = 502,    -- 该用户已准备
        ["GAME_NOT_SART"] = 503,    -- 游戏未开始
        ["FOLLOW_FAULT"] = 504,     -- 跟注错误
        ["COMPARE_FAULT"] = 505,    -- 比牌失败
        ["ALREADY_JOIN"]  = 506,    -- 已经加入
        ["ALCODE"]  = 507,    -- 已经加入
        ["COMPARE_SEECARD_ERROE"]  = 508, -- 不能跟自己比牌
        ["AlREADY_BACK"] = 509,    -- 用户已退出
        ["VIPDESK_PASSWD_FALSE"] = 510, --口令错误
        ["GAME_ALREADY_SART"] = 511,    -- 游戏已经开始
        ["GAME_ALREADY_END"] = 512,    -- 游戏已经结束
        ["GAME_NO_SEAT"] = 513,    -- 房间人数已满
        ["GAME_NOT_CURRENTITEM"] = 514, --未设置底注
        ["GAME_NOT_JOIN_GAME"] = 515, --未在桌子上
        ["SEE_CARD_ERROR"]  = 516, -- 看牌错误
        ["CHANG_DESK_ERROR"]  = 517, -- 加入错误
        ["LEVE_DESK_ERROR"]  = 518, -- 离开
        ["GAME_ING_ERROR"]  = 519, -- 该局游戏正在进行中
        ["CREATE_DESK_ERROR"]  = 520, -- 创建游戏信息有误
        -- ["SHOW_CARD_ERROR"]  = 521, -- 摊牌信息有误
        ["GAME_ALREADY_DELTE"]  = 522, -- 有人已经发起了解散
        ["CARD_TDAO_ERROR"]  = 523, -- 头道不能大于中道
        ["CARD_ZDAO_ERROR"]  = 524, -- 中道不能大于尾道
        ["ERRCODE"]  = 525,    -- 不存在改验证码
        ["CURSTART_ERROR"]  = 526,    -- 不存在改验证码
        ["USER_IN_GAME"]  = 527,    -- 玩家在游戏内，不让充值
        ["JOIN_RACE_ERROR"]  = 528,    -- 加入赛事失败
        ["CAN_NOT_FOUND_SESS"] = 529,  -- 找不到场次信息
        ["SESS_COIN_LIMIT"] = 530,  -- 场次金币限制

        ["TN_REGISTERED"] = 531,  -- 已报名
        ["TN_UNREGISTERED"] = 532,  -- 未报名
        ["TN_CANNOT_REGISTER"] = 533,  -- 不能报名
        ["TN_STATE_ERROR"] = 534,  -- 状态不对
        ["TN_ALREADY_USERED"] = 535,  -- 无法再次进入
        ["TN_WEED_OUT"] = 536,  -- 用户被淘汰
        ["TN_JOIN_ERROR"] = 537,  -- 加入房间失败

        ["GAME_SVIP_LOW"] = 538,  -- 游戏svip等级太低
        ['KYC_INFO_ERR'] = 539, --KYC信息错误
        ['DRAW_EMPTY_ACCOUNT']  = 540, --账号不能为空
        ['DRAW_EMPTY_USERNAME'] = 541, --UserName不能为空
        ['DRAW_EMPTY_IFSC']     = 542, --IFSC不能为空
        ['DRAW_EMPTY_BANK']     = 543, --银行名不能为空
        ['DRAW_EMPTY_EMAIL']    = 544, --Email不能为空
        ['DRAW_EMPTY_PHONE']    = 545, --Phone不能为空
        ['DRAW_EMPTY_UPI']      = 546, --UPI不能为空
        ['DRAW_EMPTY_USDTADDR'] = 547, --Usdt Addr 不能为空
        ['DRAW_ERR_PARAM_COIN'] = 548, --draw 金币必须大于0
        ['DRAW_ERR_BANKINFO']   = 549, --draw 账户信息不存在
        ['DRAW_COIN_NOT_ENOUGH']= 550 ,--draw 金币不足

        ['PARAM_MOBILE'] = 551, --绑定手机号不能为空
        ['PARAM_SMSCODE']= 552, --绑定手机，验证码错误
        ['PARAM_PASSWD'] = 553, --绑定手机，密码错误
        ['HAD_BANDING_MOBILE'] = 554, --绑定手机的账号已经绑定过
        ['MOBILE_HAD_BANDING'] = 555, --手机号已经绑定过
        ['DRAW_ACCOUNT_EXISTS'] = 556, --此账户已经存在
        ['NEED_BIND_MOBILE'] = 557, -- 需要绑定手机
        ['DRWA_ERR_CHANNEL'] = 558, --提现渠道不存在
        ["GAME_SVIP_LIMIT"] = 559,  -- 游戏svip限制
        ["GAME_NOT_BIND_PHONE"] = 560,  --没有绑定手机
        ["GAME_NOT_BIND_KYC"] = 561,  --没有绑定KYC
        ['PARAM_NAME'] = 562, --绑定手机，fullname为空

        ["MAIL_NOT_FOUND"] = 604,   -- 邮件找不到
        ["NO_ACTION_ERROR"] = 605,    --不改你操作
        ["ERROR_ACTION_ERROR"] = 606,   --错误操作

        ["USER_AGENT_ERROR"] = 607,   --只有代理商可以查看哦
        ["USER_CASH_ZERO"]   = 608,   --可提现金额为0
        ["USER_CASH_FAIL"]   = 609,   --提现失败
        ["BET_NOT_ENOUGH"] = 610, --押注金币值错误
        ["BANKER_CANNOT_APPLY"]   = 611,   --您已经是庄家了

        ["BANK_USER_COIN_NOT_ENOUGH"] = 612, --玩家可使用的金币不足
        ['LOGIN_AREACODE'] = 613, --账号不能在此区域登录

        ["BANK_PASSWD_ERROR"] = 614;         --银行密码错误
        ["BANK_PASSWD_TIMES_LOCKED"]  = 615; --银行密码错误超过次数,锁定10分钟
        ["BANK_TOKEN_ERROR"]  = 616;         --银行登录信息过期，请重启登录银行
        ["BANK_COIN_NOT_ENOUGH"] = 617;      --银行可使用的金币不足
        -- ["HALL_COIN_EXCEED"] = 618, --进入大厅超出最大金额

        ["CALCOIN_LOG_MUST"] = 618,      --修改玩家金币的时候必须带日志

        ["FRIEND_SELF_MAXNUM"] = 619, --您的好友数量已达上限
        ["FRIEND_SELF_EXISTS"] = 620, --好友关系已经存在
        ["FRIEND_FRIENDSHIP_MAXNUM"] = 621, --对方好友数量已达上限
        ["FRIEND_FRIENDSHIP_EXISTS"] = 622, --好友关系在己方已经存在了
        ["FRIEND_ADD_SELF"] = 623, --不能加自己为好友

        ["EXPRESS_ID_ERR"] = 624, --游戏内互动表情id错误
        ["EXPRESS_VIP_LEVEL"] = 625, --VIP等级不够

        ["EGG_NOTTIME"] = 630, --不是砸蛋日
        ["EGG_NOHAMME"] = 631, --锤子数量不足
        ["EGG_STATUS_ERROR"] = 631, --锤子状态不对

        ['PIG_LEVEL'] = 632, --金猪 等级不够
        ['PIG_FREE_TIMES'] = 633, --金猪 免费次数已领取
        ['PIG_FAILED'] = 634, --金猪 领取失败

        ['NO_SPIN_COUNT'] = 635, -- 没有转盘次数

        ['SHOP_NOT_FOUND'] = 636, --商品信息不存在
        ['RP_NOT_ENOUGH'] = 637, --rp值不够
        ["QUEST_NOT_DONE"] = 638, --未完成
        ["QUEST_HAD_GET"] = 639, --已领取

        ["CLUB_NOT_APPLEY"] = 640, --俱乐部，用户未收到邀请
        ["USER_IN_OTHER_CLUB"] = 641, --俱乐部，用户已在其他俱乐部中
        ["CLUB_IS_FULL"] = 642, --俱乐部，已满员
        ["CLUB_NO_PERMISSION"] = 643, --俱乐部，无权限解散俱乐部
        ["CLUB_NAME_NOT_EMPTY"] = 644, --俱乐部名称已被占用
        ["CLUB_NOT_FOUND"] = 645, --俱乐部不存在
        ["CLUB_OWNER_CANT_QUIT"] = 646, --俱乐部管理员不能退出
        ["USER_NOT_IN_CLUB"] = 647, --用户未加入俱乐部

        ["GAME_IS_RUNNING"] = 649, --游戏已开始
        ["CHAT_FREQUENTLY"] = 650, --用户发言太频繁
        ['USER_NOT_VIP'] = 651, --用户不是vip
        ["LEAGUE_USER_DIAMOND"] = 652, --用户的钻石不足
        ["LEAGUE_USER_TIMES"] = 653, --今日已不能参加排位赛
        ["LEAGUE_PARTER_COIN"] = 654, --队友金币不足
        ["LEAGUE_PARTER_DIAMOND"] = 655, --队友钻石不足
        ["LEAGUE_PARTER_TIMES"] = 656, --队友今日已不能参加排位赛
        ["PARTER_NOT_ONLINE"] = 657, --队友已离开
        ["PARTERID_EMPTY"] = 658, --好友id不能为空

        ["DESKID_NOT_FOUND"] = 659,  -- 房间号不存在(房间已解散)
        ["DESK_NO_SEAT"] = 660,  -- 房间已满
        ["DESK_IS_PLAYING"] = 661,  -- 房间已开始
        ["ALREADY_IN_GAME"] = 662,  -- 还在游戏中，不能加入其它房间
        ["NOT_SAME_CLUB"] = 663,  -- 不是同一个俱乐部
        ["FRIEND_OFFLINE"] = 664,  -- 好友不在线
        ["PARTER_NOT_VIP"] = 665, --好友不是VIP
        ["DESKID_FAIL"]  = 700, -- 房间号错误
        ["PLAYER_EXISTS_DESK"] = 710,    -- 已经在该房间
        ["ROOMCARD_NOT_ENOUGH"] = 720,    -- 房卡不足
        ["DESK_TYPE_ERROR"] = 730,    -- 房间类型不存在
        ["NOT_OWER_ERROR"] = 740,    -- 不是房主 游戏未开始不能发起解散
        ["HUPAI_ERROR"] = 750,    -- 硬自摸 带财神 平胡不让胡
        ["PASSWORD_ERROR"] = 751,    -- 密码不正确
        ["ROOM_CNT_NO_ENOUGH"] = 752,    -- 已经达到最大房间数
        ['LEAGUE_USER_HAND_SIGNED'] = 753, --已经报名过了
        ["NOT_BANKRUPT_COIN"] = 754, --没有破产金币可领取
        ["CAN_NOT_GETBANKRUPT"] = 755, --不能领取
        ["RAKE_BACK_NOT_FOUND"] = 756, --找不到记录
        ["RAKE_BACK_EXPIRE"] = 757, -- 记录已过期
        ["LEADERBOARD_NOT_REGISTER"] = 758, -- 未报名
        ["LEADERBOARD_REGISTERED"] = 759, -- 已报名
        ["LEADERBOARD_CONFIG_ERROR"] = 760, -- 配置错误
        ['USER_KICKED'] = 761, --被踢掉后，短时间内禁止登录
        ["RAKE_BACK_ONLY_VIEW"] = 762, -- 记录只能看，不能领
        
        ["MUST_RESTART"] = 801, --客户端必须重启
        ["ROOM_NOT_EXIST"] = 802, --房间已经不存在了
        ["ERROR_GAME_FIXING"] = 803, --游戏维护中
        
        ["COIN_NOT_ENOUGH"] = 804, --金币不足
        ["GIVE_UP_CARD"] = 805, --看牌失败，已经弃牌了
        ["FOLLOW_NOT_ALIVE"] = 806,     -- 跟注错误
        ["FOLLOW_COIN"] = 807, --下注金额错误
        ["FOLLOW_NOT_SEAT"] = 808, --不是此座位说话
        ["ROUND_NOT_ENOUGH"] = 809, --必闷轮数不够
        ["RESERVE_OR_LIMIT_NOT_ENOUGH"] = 810, --储备金或者提取额度不足
        ["HALL_COIN_EXCEED"] = 811, ----进入大厅超出最大金额
        ["GAME_COIN_EXCEED"] = 812,             --游戏过程中
        ["ERROR_BROKEN_TIMES"] = 813, --1092, --破产后，加入最低金币值为xxx
        ["SHOPINFO_NOT_FOUND"] = 814, --未找到商品信息
        ["CODE_HAD_USED"] = 815, -- 兑换码已用完了
        ["NOT_FOUND_CODE"] = 816, -- 兑换码不存在
        ["CODE_FREQUENT_ERR"] = 817, --兑换码错误次数太多，请稍后再试
        ["CODE_FREQUENT_OK"] = 818, --兑换码功能使用频繁，请稍后再试
        ["CHAT_BANED"] = 819, --被禁言了
        ["MIN_COIN_LIMIT"] = 820, -- 最小金额限制
        ["ACT_AT_SAME_TIME"] = 898, --操作太频繁哦
        ["BANKER_CAN_NOT_BET"] = 899, --庄家不能下注哦
        ["EXISTS_BANNER"] = 900, --庄已存在
        ["NOT_BANKER"] = 901, --没选庄
        ["NOT_BET"] = 902, --没下注
        ["NOT_READY"] = 903, --没准备 没牌
        ["NOT_NORMAL_CARDS"] = 904, --牌数据错误
        ["NOT_IN_HANDLE"] = 905, --出牌不在手牌中

        ["NOT_IN_ACTION"] = 906, --不能执行此操作
        ["CAN_NOT_JOIN"] = 907, -- 没开启中途加入不能准备
        ["NOT_IN_SEAT"] = 908, --没坐下哦

        --龙争虎斗
        ["WAIT_NEXT_ROUND"] = 909, --等下一回合
        ["NOT_FOUND_PLACE"] = 910, --方位错误
        ["CAN_NOT_BET_AT_SAME_TIME"] = 911, --龙虎不能同时下

        ["EXCEED_BET_AMOUNT"]  = 912, --超过最大允许的押注
        ["GAME_NO_ALLOW_JOIN"] = 913,    -- 房间不允许中途加入
        ["USER_NOT_READY"] = 914,    --用户未准备
        ["USER_SEATID_NO_FOUND"] = 915,    --未找到该座位用户
        ["MULTIPLE_ERROR"] = 916, --倍数超范围
        ["BET_RANGE_ERRO"] = 917, --底注超范围
        ["LEFTCOIN_RANGE_ERRO"] = 918, --离场金币错误
        ["MINCOIN_RANGE_ERRO"] = 919, --入场金币错误
        ["TYPE_RANGE_ERRO"] = 920, --类型错误
        ["NOT_IN_ROOM"] = 921, --玩家不在房间内
        ["ERROR_HAD_SITDOWN"] = 922, --玩家已经坐下
        ["ERROR_MORETHAN_SEAT"] = 923, --座位号超过最大人数
        ['ERROR_SEAT_EXISTS_USER'] = 924, --此座位已经有人
        ["NOT_ROOM_OWNER"] = 925, --不是房主
        ["SOMEONE_NOT_READY"] = 926, --有人没准备

        ["PERSON_NOT_ENOUGH"] = 927, --人数不足
        ["DESK_NOT_ENOUGH"] = 928, --服务器房间数不够
        ["VIRTUAL_COIN_NOT_ENOUGH"] = 929, --体验币不足
        ["FB_AUTH_FAIL"] = 930, --FB玩家才可创建该房间
        ["RELOAD"] = 931, --房间不存在 玩家还卡在房间中
        ["SURPASS_MAX_MULT"] = 932, --水浒传加注倍数超过最大倍数
        ["SURPASS_MAX_SCORE"] = 933, --水浒传加注倍数超过最大金币

        ["JOINING_DESK"] = 934, --房间加载中
        ["ALREADY_AWARD"] = 935, --奖励已领取
        ["FGR_COIN_NOT_ENOUGH"] = 936, --开房金币不足
        ["PAY_FAILD"] = 937, --支付下单失败
        ["WECHAT_AUTH_FAILD"] = 940, --微信登录失败
        ["FACEBOOK_AUTH_FAILD"] = 941, --fb登录失败
        ["SURPASS_MAX_LINE"] = 943, --拉霸游戏超过最大押注线
        ["POOL_NOMAL_NOT_ENOUGH"] = 944, --normalpool余额不足
        ["LEVEL_NOT_ENOUGH"] = 945, --玩家等级不够,不能解锁游戏

        ["FUND_NOT_FOUND"] = 946, --未找到
        ["FUND_NOT_BUY"] = 947, --需要购买后才能购买
        ["FUND_COLLECTED"] = 948, --已经领取过了
        ["FUND_LEVEL"] = 949, --等级不够，不能领取
        ["CHARM_SEND"] = 950, --赠送魅力值道具错误

        --推广员错误码
        ["ACCOUNT_HAD_EXIST"] = 950, --用户名已经存在
        ["EMAIL_HAD_EXIST"]   = 951, --Email已经存在
        ["INVAlID_CODE"]      = 952, --邀请码不存在
        ["EMAIL_SEND_FAIL"]   = 953, --邮件发送失败
        ["INVAlID_CODE_FAIL"] = 954, --找回密码重设,验证码不存在或错误
        ["ACCOUNT_NOT_FOUND"] = 955, --账号不存在
        ["BALANCE_NOT_ENOUG"] = 956, --当前没有可提现收益
        ["PASSWD_ERROR"]      = 957, --支付密码错误
        ["TRANSFER_ERROR"]      = 958, --转账失败
        ["TRANSFER_RELATION_ERROR"] = 959, --必须是直接上下级关系才能转账

        ["ACCOUNT_TOO_SHORT"] = 960, --用户名必须为6位或以上字符
        ["PASSWD_IS_EMPTY"]   = 961, --用户名必须填写
        ["EMAIL_IS_EMPTY"]    = 962, --密码必须填写
        ["PCODE_IS_ERROR"]     = 963, --邀请码错误
        ["BONUS_NOT_FULL"]     = 964, --红点没有全部点完
        ["BONUS_HAD_GET"]     = 965, --已领取过红点bonus任务

        ["SLOT_ERROR"]     = 967, --流程错误

        ["BINGO_NOT_FOUND"]     = 968, -- 活动未开放
        ["BINGO_COUNT_FULL"]     = 969, -- 用户点数已满
        ["BINGO_COUNT_EMPTY"]     = 970, -- 用户没有点数
        ["BINGO_CONFIG_ERROR"]     = 971, -- 活动配置错误

        ["NEWBIE_CONFIG_ERROR"]     = 972, -- 新手任务配置错误
        ["NEWBIE_STATE_ERROR"]     = 973, -- 新手任务状态错误
        ["USER_HAS_VOTED"] = 974, -- 用户已经选举过
        ["TIMEOUT_KICK_OUT"] = 975, -- 超时踢人
        ['CHARM_GIFT_PACK_GETED'] = 976, --大礼包已获取过
        ['BONUS_COLLECT_FREQUENTLY'] = 977, --bonus collect太频繁
        
        ['SMS_GET_FAILED'] = 978, --短信获取失败
        
        ["PUT_CARD_ERROR"] = 8928, --出牌操作错误
        ["SEATID_EXIST"] = 9929, --玩家已退出
        ["SHOW_CARD_ERROR"] = 9930, --摊牌异常
        ["KICK_ERROR"] = 9931, --不是房主不能踢
        ['IN_OTHER_ROOM'] = 9932, --在其他房间中
        ["GET_FREE_ID"] = 9933, --获取免费类型错误
        ["GET_FREE_TIMES"] = 9934, --今日已经领取

        
        ["DESK_ERROR"] = 1000, --房间数据异常
        
        ["PRODUCT_TIME_EXPIRE"] = 1402, --限时礼包已过期
        ["PRODUCT_PURCHASED"] = 1403, --one time only 不能重复购买
        ["PRODUCT_NOT_FOUND"] = 1404, --商品找不到
        ["ORDER_CREATED_FAIL"]= 1405, --IAP下单失败
        ["CAN_NOT_BET_TWO_PLACE"] = 1406, --不能同时下注2个方位
        ["CAN_NOT_REPORT_SELF"] = 1407, --不能举报自己
        ["REPORT_LACK_OF_DATA"] = 1408, --举报缺少资料
        ["REPORT_TOO_FREQUENT"] = 1409, --举报太频繁失败
        ["REPORT_FAILED"] = 1450, --举报失败
        ["SKIN_NOT_FOUND"] = 1451, --道具不存在

        ['INVITE_HAD_BINDED'] = 1452, --已经绑定过邀请码
        ['INVITE_BIND_SELF'] = 1453, --不能绑定自己的邀请码
        ['INVITE_BIND_IN_CIRCLE'] = 1454, --不能绑定下级的邀请码
        ['INVITE_BIND_ERR'] = 1455, --绑定错误
        ['INVITE_BIND_OUTTIME'] = 1456, --注册3分钟后，不允许绑码
        ['INVITE_BIND_FORBID'] = 1457, --邀请码被禁用

        ["ROUND_BET_SUM_COIN_NO_LEFT"] = 1051, --本轮投注额已满
        ['REPEAT_SUBMIT_FEEDBACK'] = 1052, --玩家重复提交
        ['PARAM_IS_EMPTY']  = 1055,  --玩家重复提交
        ['USER_HAD_CERTIF'] = 1056,  --玩家已认证过
        ["CAN_NOT_BET"] = 1057,      --自己是庄家 不能下注


        ["ORDER_PAID_EMPTY_PARAMS"] = 1058, --支付失败（订单等参数不能为空）
        ["ORDER_PAID_VERIFY_RECEIPT_FAILED"]= 1059, --支付验证凭证失败
        ["ORDER_PAID_VERIFY_PRODUCT_FAILED"]= 1060, --支付验证商品失败
        ["ORDER_PAID_ORDER_NOT_FOUND"] = 1061, --支付验证订单号错误
        ["ORDER_PAID_USER_ERROR"] = 1062, --支付验证订单归属错误
        ["ORDER_PAID_VERIFY_STATUS_FAILED"] = 1063, --支付验证, 未成功支付
        ["ORDER_PAID_UPDATE_FAILED"] = 1064, --支付验证，更新订单失败

        -- 以下错误码没给过客户端
        ["APPLY_OFF_BANKER_STATE_FAIL"] = 1065, --只能在空闲时间内下庄哦
        ["BET_COIN_NOT_ENOUGH"] = 1066, --金币不足，选用小一点的筹码
        ["ERROR_NO_JOINMIDDLE"] = 1067, --此房间不允许中途加入

        ["BIND_FB_VALIDATE"] = 1068, --绑定验证失败
        ["BIND_FB_DATA"]     = 1069, --绑定获取信息失败
        ["BIND_FB_AGAIN"]    = 1070, --此账号已经绑定过，不能重复绑定
        ["BIND_FB_USEAGAIN"] = 1071, --系统已存在此FB账号

        ["TASK_NOT_FINISH"] = 1072, --此任务还未完成
        ["NICKNAME_INCLUCE_ILLEGAL_CHARACTER"] = 1073, --您的昵称包含非法字，请重新修改
        ["NICKNAME_HAD_USED"] = 1074, --昵称已经被使用
        ["TOO_REPEAT"] = 1075, --频率太频繁
        ["CAN_NOT_BROADCAST"] = 1076, --用户没有发送权限
        ["BANKER_COIN_NOT_ENOUGH"] = 1077, --百人牛牛，上庄金币不足

        ["YABAO_COIN"] = 1078, --押宝金币不能小于0
        ["YABAO_PLACE"] = 1079, --押宝方位不对

        ["HBULL_COIN_NOT_ENOUGH"] = 1080, --剩余金币须大于50K才能下注
        ["WAIT_FOR_NEXT_TIME"] = 1081, --请等待下次哟

        --绑定微信
        ["BIND_WX_AGAIN"]    = 1082, --此账号已经绑定过微信，不能重复绑定
        ["BIND_WX_VALIDATE"] = 1083, --绑定微信验证失败
        ["BIND_WX_DATA"]     = 1084, --绑定微信获取信息失败
        ["BIND_WX_USEAGAIN"] = 1085, --系统已存在此微信账号

        ["DRAW_ERROR"] = 1086, --摸牌错误
        ["ERROR_PENG_ERROR"] = 1087, --碰牌错误
        ["ERROR_GANG_ERROR"] = 1088, --杠牌错误
        ["TASK_HAD_CLOSE"] = 1089, --该任务已经关闭
        ["APPLY_OFF_BANKER"] = 1090,      --该阶段不可下庄
        ["CANNOT_OFF_BANKER"] = 1091,     --您是庄家不能退出哦
        ["BENZ_COIN_NOT_ENOUGH"] = 1387, --剩余金币须大于50K才能下注
        ["ERROR_HUPAI_ERROR"] = 1089, --杠牌错误
        ["FINISHGAME_ERR"] = 1388, --业务游戏结算失败
        ["DAILYTASK_NOT_DONE"] = 1093, --未完成
        ["NOT_FOUND_FRIEND"] = 1094, -- 好友不在线
        ["NO_LEAGUE_REWARD"] = 1095, -- 没有排位赛奖励可领取
        ["NO_AVAILABLE_ROOM"] = 1096, -- 没有可用桌子
        ["USER_OFFLINE"] = 1097, -- 用户离线
        ["FRIEND_IS_INGAME"] = 1098, --好友在游戏中

        ['NOT_THIS_USER'] = 1099, --不是他操作
        ['DICES_MIN_ERR'] = 1100, --用户从未摇骰子
        ['DICES_RULE_ERR'] =1101, --上一次是6，继续摇，不能重置
        ['INVITE_FRIEND_HAD_SEND'] = 1102, --已经邀请过了
        ['AUTO_COUNT_LIMIT'] = 1103, -- 托管超过次数
        ["SWITCH_DESK"] = 1104,     --换桌

        -- 特用于saudi deal 游戏
        ['CARD_NOT_FOUND'] = 3001,  -- 找不到该手牌
        ['CARD_CFG_NOT_FOUND'] = 3002,  -- 找不到该卡牌配置
        ['CARD_ACTION_ILLEGAL'] = 3003,  -- 卡牌非法操作
        ['USER_ACTION_ILLEGAL'] = 3004,  -- 用户操作非法
        ['CARD_COLOR_MISS'] = 3005,  -- 没有指定颜色
        ['LAND_COLOR_MISS'] = 3006,  -- 没有指定颜色
        ['LAND_TYPE_ERROR'] = 3007,  -- 土地类型错误
        ['HAND_GET_TESTSALON'] = 3008, --已经获取过测龙测试道具
        ["INVAlID_ERROR"] = 20000, --摸牌错误
        ["CREATE_AT_THE_SAME_TIME"] = 10005,

        ["PLAYER_HAD_ACT"] = 102101, --玩家已经操作过
        ["PLAYER_CANT_SPLIT"] = 102102, --玩家不能拆牌
        ["PLACE_ERROR"] = 102103, --玩家操作位置错误
        ["PLAYER_HAD_BET"] = 102104, --您已经要过牌了
        ["PLAYER_CANT_BUYSAFE"] = 102105, --您不能购买保险
        ["PLAYER_CANT_JUMPSAFE"] = 102106, --您不能跳过保险

        -- 牌桌内错误
        ["PARAMS_ERROR"] =  101001,  -- 参数错误
        ["USER_NOT_FOUND"] =  101002,  -- 用户未找到
        ["USER_STATE_ERROR"] = 101003,  -- 用户状态错误
        ["MUST_SAME_SUIT"] = 101004, -- 必须同花色
        ["CAN_NOT_PASS"] =  101005,  -- 不能pass
        ["HAND_CARDS_ERROR"] = 101006, -- 手牌未找到
        ["CAN_NOT_DASH"] = 101007, -- 最后一个人不能dash call
        ["CAN_NOT_JOKER"] = 101008,  -- 不能出王
        ["ALREADY_SEAT_DOWN"] = 101009,  -- 已经坐下
        ["ILLEGAL_MELD"] = 101010,  -- 非法组合
        ["EMPTY_HAND_ERROR"] = 101011,  -- 不能空手牌，必须留一张
        ["MELD_ID_NOT_FOUND"] = 101012,  -- 指定牌组未找到
        ["MELD_NOT_SATISFIED"] = 101013,  -- 指定牌组不满足要求
        ["MUST_GO_DOWN_FIRST"] = 101014,  -- 必须先godown才能进行操作
        ["DESK_STATE_ERROR"] = 101015,  -- 牌桌状态错误
        ["MUST_TALYEEKH"] = 101016, -- 必须Talyeekh
        ["DISCARD_ERROR"] = 101017, -- 出牌不符合规则
        ["TAKE_ERROR"] = 101018,    -- 拿牌错误
        ["MUST_BET_BORROW_CARD"] = 101019,  -- 必须godown摸上来的那张牌
        ["CONCAN_ERROR"] = 101020,  -- concan失败
        ["CAN_NOT_DONE"] = 101021,  -- 不能done
        ["SCORE_NO_ENOUGH"] = 101022, -- 分数不够
        ["CAN_NOT_UNO"] = 101023, -- 不能uno
        ["UNO_ALREADY"] = 101024, -- 已经uno过了
        ["CAN_NOT_CHECK"] = 101025, -- 目前不能check, 只能下注和跟注

        -- teenpatti特用错误码
        ["PREV_USER_NO_SEEN"] = 101026, -- 上家未看牌
        ["USER_COUNT_NO_ENOUGH"] = 101027, -- 人数不满足side show


        ["HULUJI_NOBETCOIN"] = 21601, --葫芦机玩法中 开堵的时候赌注总和为0
        ["NOT_NOT_SUBGAME"] = 10001, -- 拉霸小游戏已经玩过了，再请求就会报错
        ["ISBILLING"] = 3000001, --正在交易中

        ["DAILYSHAREDONE"] = 2001, --每日FB分享已完成
    },
    ["ERROR_API"] =
    {
        ["CLUB"] = 10000000, --俱乐部
    }
}
return PDEFINE_ERRCODE
