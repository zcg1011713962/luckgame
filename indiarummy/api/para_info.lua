--约定数据结构
--[[
gameinfo_para = {
    gameid = xx, --游戏id
    deskid = xx, --桌子id
    subgameid = xx, --子游戏id
    isjp = 0/1, --是否需要开JP奖 0表示不需要开jp，1表示需要jp
    deskuuid = xx, --桌子唯一id
    platforminfo = {
        platform = xx, --平台id
        platform_name = xx, --平台名称
        gamelog_tp = xx, --第三方平台的日志数据
    },
    roundinfo = {
        bet = xx, --下注
        win = xx, --赢钱
        result = xx, --游戏结果
        event_type = xx, PDEFINE.POOLEVENT_TYPE
        event_id = xx, --eventid api端传过来的参数
    }
}

poolround_para = {
    uniid = xx, --唯一id
    pooltype = xx, --pooltype  PDEFINE.POOL_TYPE
    poolround_id = xx, --pr的唯一id
}

altercoin_para = {
    altercoin_id = xx, --修改金币的唯一id
    before_coin = xx, --修改之前的金币
    alter_coin = xx, --修改量
    after_acoin = xx, --修改之后的金币数量
    type = xx, --修改金币的类型 PDEFINE.ALTERCOINTAG
    desc = xx, --修改日志
}

]]