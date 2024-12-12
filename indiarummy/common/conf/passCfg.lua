local cfg = {}
local R_TYPE = PDEFINE.PROP_ID

-- 等级配置
-- 排位赛等级奖励配置
cfg.LevelConfig = {
    [1] = {level=1, exp=1, rewards={{type=R_TYPE.DIAMOND, count=20}}, superRewards={{type=R_TYPE.DIAMOND, count=60}}},
    [2] = {level=2, exp=2, rewards={{type=R_TYPE.DIAMOND, count=40}}, superRewards={{type=R_TYPE.DIAMOND, count=120}}},
    [3] = {level=3, exp=3, rewards={{type=R_TYPE.DIAMOND, count=80}}, superRewards={{type=R_TYPE.DIAMOND, count=240}}},
    [4] = {level=4, exp=4, rewards={{type=R_TYPE.DIAMOND, count=120}}, superRewards={{type=R_TYPE.DIAMOND, count=360}}},
    [5] = {level=5, exp=5, rewards={{type=R_TYPE.DIAMOND, count=160}}, superRewards={{type=R_TYPE.DIAMOND, count=480}}},
    [6] = {level=6, exp=6, rewards={{type=R_TYPE.DIAMOND, count=200}}, superRewards={{type=R_TYPE.DIAMOND, count=600}}},
    [7] = {level=7, exp=7, rewards={{type=R_TYPE.DIAMOND, count=400}}, superRewards={{type=R_TYPE.DIAMOND, count=1200},{type=PDEFINE.PROP_ID.SKIN_EMOJI, count=1, category=6, img=PDEFINE.SKIN.TASK_GROUTH.EMOJI.img}}},
}

-- 赛季配置
cfg.SeasonCfg = {
    [1] = {
        id = 1,
        begin=os.time({day=1, month=12, year=2021, hour=0, minute=0, second=0}),
        stop=os.time({day=1, month=3, year=2022, hour=0, minute=0, second=0})
    },
    [2] = {
        id = 2,
        begin=os.time({day=1, month=3, year=2022, hour=0, minute=0, second=0}),
        stop=os.time({day=1, month=6, year=2022, hour=0, minute=0, second=0})
    },
    [3] = {
        id = 3,
        begin=os.time({day=1, month=6, year=2022, hour=0, minute=0, second=0}),
        stop=os.time({day=1, month=9, year=2022, hour=0, minute=0, second=0})
    },
    [4] = {
        id = 4,
        begin=os.time({day=1, month=9, year=2022, hour=0, minute=0, second=0}),
        stop=os.time({day=1, month=12, year=2022, hour=0, minute=0, second=0})
    }
}

-- 任务类型
cfg.QuestType = PDEFINE.PASS.QUEST_TYPE

-- 最大任务类型id
cfg.MaxQuestType = 10

-- 任务难度
cfg.QuestLevel = {
    Easy = 1,  -- 容易
    General = 2,  -- 普通
    Diffcult = 3,  -- 困难
}

-- 任务配置
cfg.QuestCfg = {
    -- 容易
    [1] = {type=cfg.QuestType.OnlineTime, level=cfg.QuestLevel.Easy, refreshDiamond=5, completeDiamond=5, need=30*60, exp=50, lang_title={en="30 minutes online", ar="30 دقيقة عبر الإنترنت"}},
    [2] = {type=cfg.QuestType.GameTime, level=cfg.QuestLevel.Easy, refreshDiamond=5, completeDiamond=5, need=20*60, exp=50, lang_title={en="20 minutes of game", ar="20 دقيقة من المباراة"}},
    [3] = {type=cfg.QuestType.AnyGameCnt, level=cfg.QuestLevel.Easy, refreshDiamond=5, completeDiamond=5, need=1, exp=50, lang_title={en="Play any game", ar="العب أي لعبة"}},
    [4] = {type=cfg.QuestType.HandLeagueGameCnt, level=cfg.QuestLevel.Easy, refreshDiamond=5, completeDiamond=5, need=1, exp=50, lang_title={en="Play a hand qualifying round", ar="العب جولة تصفيات توزيع الورق"}},
    [5] = {type=cfg.QuestType.BalootSpScore, level=cfg.QuestLevel.Easy, refreshDiamond=5, completeDiamond=5, need=50, exp=50, lang_title={en="Get a special score of 50 points in the baloot game", ar="احصل على مجموع 50 نقطة في لعبة البلوت"}},
    [6] = {type=cfg.QuestType.GoDownScore, level=cfg.QuestLevel.Easy, refreshDiamond=5, completeDiamond=5, need=100, exp=50, lang_title={en="Go down score reaches 100 in hand or hand Saudi", ar="درجة النزول تصل إلى 100 في متناول اليد أو تسليم السعودي"}},
    [7] = {type=cfg.QuestType.MatchGameWinCnt, level=cfg.QuestLevel.Easy, refreshDiamond=5, completeDiamond=5, need=1, exp=50, lang_title={en="Win any match game", ar="اربح أي لعبة مباراة"}},
    [8] = {type=cfg.QuestType.LeagueGameWinCnt, level=cfg.QuestLevel.Easy, refreshDiamond=5, completeDiamond=5, need=1, exp=50, lang_title={en="Win a ranked game", ar="اربح لعبة مصنفة"}},
    [9] = {type=cfg.QuestType.GameWinCoin, level=cfg.QuestLevel.Easy, refreshDiamond=5, completeDiamond=5, need=1000, exp=50, lang_title={en="Win 1,000 coins in the game", ar="اربح 1000 قطعة نقدية في اللعبة"}},
    [10] = {type=cfg.QuestType.TotalGainCoin, level=cfg.QuestLevel.Easy, refreshDiamond=5, completeDiamond=5, need=5000, exp=50, lang_title={en="Get 5,000 gold coins today", ar="احصل اليوم على 5000 قطعة ذهبية"}},
    -- 普通
    [11] = {type=cfg.QuestType.OnlineTime, level=cfg.QuestLevel.General, refreshDiamond=5, completeDiamond=10, need=60*60, exp=100, lang_title={en="60 minutes online", ar="60 دقيقة عبر الإنترنت"}},
    [12] = {type=cfg.QuestType.GameTime, level=cfg.QuestLevel.General, refreshDiamond=5, completeDiamond=10, need=40*60, exp=100, lang_title={en="40 minutes of game", ar="40 دقيقة من المباراة"}},
    [13] = {type=cfg.QuestType.AnyGameCnt, level=cfg.QuestLevel.General, refreshDiamond=5, completeDiamond=10, need=5, exp=100, lang_title={en="Play five games at will", ar="العب خمس مباريات حسب الرغبة"}},
    [14] = {type=cfg.QuestType.HandLeagueGameCnt, level=cfg.QuestLevel.General, refreshDiamond=5, completeDiamond=10, need=3, exp=100, lang_title={en="Perform three rounds of hand qualifying", ar="قم بأداء ثلاث جولات من تصفيات توزيع الورق"}},
    [15] = {type=cfg.QuestType.BalootSpScore, level=cfg.QuestLevel.General, refreshDiamond=5, completeDiamond=10, need=100, exp=100, lang_title={en="Get a special score of 100 points in the baloot game", ar="احصل على مجموع 100 نقطة في لعبة البلوت"}},
    [16] = {type=cfg.QuestType.GoDownScore, level=cfg.QuestLevel.General, refreshDiamond=5, completeDiamond=10, need=200, exp=100, lang_title={en="Go down score reaches 200 in hand or hand Saudi", ar="درجة النزول تصل إلى 200 في متناول اليد أو تسليم السعودي"}},
    [17] = {type=cfg.QuestType.MatchGameWinCnt, level=cfg.QuestLevel.General, refreshDiamond=5, completeDiamond=10, need=3, exp=100, lang_title={en="Win any three matching games", ar="اربح أي ثلاث مباريات متطابقة"}},
    [18] = {type=cfg.QuestType.LeagueGameWinCnt, level=cfg.QuestLevel.General, refreshDiamond=5, completeDiamond=10, need=3, exp=100, lang_title={en="Win three ranked games", ar="فز بثلاث مباريات مرتبة"}},
    [19] = {type=cfg.QuestType.GameWinCoin, level=cfg.QuestLevel.General, refreshDiamond=5, completeDiamond=10, need=5000, exp=100, lang_title={en="The game won 5,000 gold coins", ar="فازت اللعبة بـ 5000 قطعة ذهبية"}},
    [20] = {type=cfg.QuestType.TotalGainCoin, level=cfg.QuestLevel.General, refreshDiamond=5, completeDiamond=10, need=10000, exp=100, lang_title={en="Get 10,000 gold coins today", ar="احصل اليوم على 10000 قطعة ذهبية"}},
    -- 困难
    [21] = {type=cfg.QuestType.OnlineTime, level=cfg.QuestLevel.Diffcult, refreshDiamond=5, completeDiamond=20, need=120*60, exp=200, lang_title={en="120 minutes online", ar="120 دقيقة عبر الإنترنت"}},
    [22] = {type=cfg.QuestType.GameTime, level=cfg.QuestLevel.Diffcult, refreshDiamond=5, completeDiamond=20, need=60*60, exp=200, lang_title={en="60 minutes of game", ar="60 دقيقة من المباراة"}},
    [23] = {type=cfg.QuestType.AnyGameCnt, level=cfg.QuestLevel.Diffcult, refreshDiamond=5, completeDiamond=20, need=10, exp=200, lang_title={en="Play ten games at will", ar="العب عشر مباريات حسب الرغبة"}},
    [24] = {type=cfg.QuestType.HandLeagueGameCnt, level=cfg.QuestLevel.Diffcult, refreshDiamond=5, completeDiamond=20, need=5, exp=200, lang_title={en="Perform five rounds of hand qualifying", ar="أداء خمس جولات من التأهيل اليدوي"}},
    [25] = {type=cfg.QuestType.BalootSpScore, level=cfg.QuestLevel.Diffcult, refreshDiamond=5, completeDiamond=20, need=150, exp=200, lang_title={en="Get a special score of 150 points in the baloot game", ar="احصل على مجموع 150 نقطة في لعبة البلوت"}},
    [26] = {type=cfg.QuestType.GoDownScore, level=cfg.QuestLevel.Diffcult, refreshDiamond=5, completeDiamond=20, need=500, exp=200, lang_title={en="Go down score reaches 500 in hand or hand Saudi", ar="درجة النزول تصل إلى 500 في متناول اليد أو تسليم السعودي"}},
    [27] = {type=cfg.QuestType.MatchGameWinCnt, level=cfg.QuestLevel.Diffcult, refreshDiamond=5, completeDiamond=20, need=5, exp=200, lang_title={en="Win any five matching games", ar="اربح أي خمس مباريات متطابقة"}},
    [28] = {type=cfg.QuestType.LeagueGameWinCnt, level=cfg.QuestLevel.Diffcult, refreshDiamond=5, completeDiamond=20, need=5, exp=200, lang_title={en="Win five ranked games", ar="فز بخمس مباريات مرتبة"}},
    [29] = {type=cfg.QuestType.GameWinCoin, level=cfg.QuestLevel.Diffcult, refreshDiamond=5, completeDiamond=20, need=10000, exp=200, lang_title={en="The game won 10,000 gold coins", ar="فازت اللعبة بـ 10000 قطعة ذهبية"}},
    [30] = {type=cfg.QuestType.TotalGainCoin, level=cfg.QuestLevel.Diffcult, refreshDiamond=5, completeDiamond=20, need=20000, exp=200, lang_title={en="Get 20,000 gold coins today", ar="احصل اليوم على 20000 قطعة ذهبية"}},
}

cfg.BoxConfig = {
    [PDEFINE.PROP_ID.BOX_BRONZE] = {
        [1] = {type=PDEFINE.PROP_ID.DIAMOND, count=20, weight=45},
        [2] = {type=PDEFINE.PROP_ID.DIAMOND, count=30, weight=36},
        [3] = {type=PDEFINE.PROP_ID.DIAMOND, count=40, weight=10},
        [4] = {type=PDEFINE.PROP_ID.DIAMOND, count=50, weight=5},
        [5] = {type=PDEFINE.PROP_ID.DIAMOND, count=80, weight=3},
        [6] = {type=PDEFINE.PROP_ID.DIAMOND, count=100, weight=1},
    },
    [PDEFINE.PROP_ID.BOX_SILVER] = {
        [1] = {type=PDEFINE.PROP_ID.DIAMOND, count=30, weight=45},
        [2] = {type=PDEFINE.PROP_ID.DIAMOND, count=40, weight=36},
        [3] = {type=PDEFINE.PROP_ID.DIAMOND, count=50, weight=10},
        [4] = {type=PDEFINE.PROP_ID.DIAMOND, count=80, weight=5},
        [5] = {type=PDEFINE.PROP_ID.DIAMOND, count=100, weight=3},
        [6] = {type=PDEFINE.PROP_ID.DIAMOND, count=120, weight=1},
    },
    [PDEFINE.PROP_ID.BOX_GOLD] = {
        [1] = {type=PDEFINE.PROP_ID.DIAMOND, count=40, weight=45},
        [2] = {type=PDEFINE.PROP_ID.DIAMOND, count=50, weight=36},
        [3] = {type=PDEFINE.PROP_ID.DIAMOND, count=80, weight=10},
        [4] = {type=PDEFINE.PROP_ID.DIAMOND, count=100, weight=5},
        [5] = {type=PDEFINE.PROP_ID.DIAMOND, count=120, weight=3},
        [6] = {type=PDEFINE.PROP_ID.DIAMOND, count=150, weight=1},
    },
    [PDEFINE.PROP_ID.BOX_DIAMOND] = {
        [1] = {type=PDEFINE.PROP_ID.DIAMOND, count=50, weight=45},
        [2] = {type=PDEFINE.PROP_ID.DIAMOND, count=80, weight=36},
        [3] = {type=PDEFINE.PROP_ID.DIAMOND, count=100, weight=10},
        [4] = {type=PDEFINE.PROP_ID.DIAMOND, count=120, weight=5},
        [5] = {type=PDEFINE.PROP_ID.DIAMOND, count=150, weight=3},
        [6] = {type=PDEFINE.PROP_ID.DIAMOND, count=200, weight=1},
    },
}

return cfg