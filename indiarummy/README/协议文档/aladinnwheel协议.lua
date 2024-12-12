

--通知类：
    --结算阶段
    {
        c = BET_STATE_SETTLE(128002),  
        time = 10,
        result = {
            res = {{1},{2,5,7}}, --中奖结果
            win = {{place=1, mult=5},{place=3, mult=12}},  -- 位置对应的倍率
            sp = 0,  -- 是否显示神灯
            op1 = 0,  -- 特效类型1
            op2 = 0,  -- 特效类型2
        },
        coinPot = 1000,--奖池
        user = {    --我自己的信息
            coin = 1000,
            wincoin = 100,
        }
    }
    
    
--中奖结果
    Results = {
        -- 神灯, 老虎*5, 奖杯*2, 头盔*10, 奖杯*10, 人物*50, 人物*120, 老虎*5, 老虎*2, 钥匙*10, 宝石*20, 宝石*2 
        0, 8, 5, 7, 5, 1, 1, 8, 8, 6, 4, 4, 
        -- 神灯, 老虎*5, 头盔*2, 头盔*10, 奖品*10, 猴子*2, 猴子*40, 老虎*5, 钥匙*2, 钥匙*10, 飞毯*30, 飞毯*2
        0, 8, 7, 7, 5, 2, 2, 8, 6, 6, 3, 3
    }

--中奖位置
    Places = {
        Lantern = 0,  -- 神灯
        People = 1,  -- 人物
        Monkey = 2,-- 猴子
        Carpet = 3,  -- 飞毯
        Diamond = 4, -- 宝石
        Cup = 5,  -- 奖杯
        Key = 6, -- 钥匙
        Helmet = 7,  -- 头盔
        Tiger = 8,  -- 老虎
    }
    
--记录类型
    RecordType = {
        Common = 1,  -- 普通
        Lantern = 2,  -- 神灯
        Triple = 3,  -- 10倍三连中
        Tiger = 4, -- 老虎*4
        Train3 = 5, -- 火车*3
        Train4 = 6, -- 火车*4
        Train5 = 7, -- 火车*5
        Clover = 8 -- 四叶草
    },
--游戏记录
    local game_record = {type=config.RecordType.Common, place=2, mult=5}
