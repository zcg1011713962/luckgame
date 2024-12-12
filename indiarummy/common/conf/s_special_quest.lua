local cfg = {}

cfg.status = {
    Doing = 0,
    Done = 1,
    Compelte = 2,
}

cfg.type = {
    CreateSalon = 1,
    PlaySalon = 2,
}
-- 沙龙奖励配置
cfg.tasks = {
    [1] = { -- 创建一个沙龙房间
        id=1,
        type=cfg.type.CreateSalon,
        need=1,
        desc='Create a salon room',
        desc_al='قم بإنشاء غرفة صالون',
        rewards={
            {type=PDEFINE.PROP_ID.DIAMOND, count=20}
        },
        firstTime={
            {type=PDEFINE.PROP_ID.DIAMOND, count=100}
        }
    },
    [2] = {
        id=2,
        type=cfg.type.PlaySalon,
        need=1,
        desc='Played 1 game in your salon room',
        desc_al='لعبت لعبة في غرفة الصالون الخاصة بك',
        rewards={
            {type=PDEFINE.PROP_ID.DIAMOND, count=50}
        },
        firstTime={
            {type=PDEFINE.PROP_ID.DIAMOND, count=200}
        }
    }
}

return cfg