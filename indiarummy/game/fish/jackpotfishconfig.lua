-- 918海王捕鱼终极版 配置文件

-- 捕鱼基础概率
-- 倍数[2,3]  r=1/倍数*0.9
-- 倍数[4,5] r=1/倍数*0.95
-- 倍数[6,7] r=1/倍数*0.96
-- 倍数[8,9] r=1/倍数*0.98
-- 倍数[10,14] r=1/倍数*1
-- 倍数[15,19] r=1/倍数*1.02
-- 倍数[20,39] r=1/倍数*1.03
-- 倍数[40,99] r=1/倍数*1.04
-- 倍数[100, 1000] r=1/倍数*1.5

-- 炸弹类型
-- boom=1: 局部炸弹  半径400范围内的鱼被捕获
-- boom=2: 全屏炸弹  屏幕内的鱼被捕获
-- boom=3: 同类炸弹  同类型的鱼被捕获
-- boom=4: 随机炸弹  随机捕获其他5条鱼

local fishtide = require("fish.fishtide")

local fishconfig = {}

-- 座位数量
fishconfig.seat_count = 4

-- 场景数量
fishconfig.scene_count = 5

-- 设计宽度/高度
fishconfig.resolution_width  = 1136
fishconfig.resolution_height = 640

-- 时钟间隔
fishconfig.tick_interval = 33

--奖池
fishconfig.jackpot = {
    {id=1, value=600},  --极速中奖
    {id=2, value=2500}, --幸运大奖
    {id=3, value=15000} --超级巨奖
}

-- 炮台倍率
function fishconfig.getMults()
    return  {1,2,3,5,8,10,20,50,80,100,200,300,500}
end

-- AI配置
function fishconfig.getAiInfo(gameid, ssid)
    return {
        mults = {1, 2, 3, 5, 10},
        cannons = {1, 2},
    }
end

fishconfig.lyfb = {
    base_drop_ratio = 0,--0.0005,  -- 基础掉落概率  1/2000
    drop_need_revenue = 100,   -- 掉落的系统收分条件
    duration = 30,         -- 持续时间（秒）
    max_free_count = 120,   -- 最大免费次数
}

-- 鱼属性配置
fishconfig.fish = {
    [1] = {name="扇尾小鱼", ratio=0.45, multiple={2}, speed=10, w=24, h=40, group={chance=20, count=6}},

    [2] = {name="小丑鱼", ratio=0.3, multiple={3}, speed=12, w=32, h=26, group={chance=15, count=5}},

    [3] = {name="黄蓝纹鱼", ratio=0.235, multiple={4}, speed=10, w=60, h=32, group={chance=14, count=5}},

    [4] = {name="绿鳞纹鱼", ratio=0.19, multiple={5}, speed=12, w=50, h=40, group={chance=10, count=5}},

    [5] = {name="黄刺鱼", ratio=0.16, multiple={6}, speed=10, w=60, h=70},

    [6] = {name="海龟", ratio=0.14, multiple={8}, speed=10, w=64, h=54},

    [7] = {name="水母", ratio=0.123, multiple={10}, speed=15, w=66, h=52, group={chance=10, count=5}},

    [8] = {name="龙虾", ratio=0.11, multiple={12}, speed=10, w=100, h=50, group={chance=10, count=4}},

    [9] = {name="黄红纹鱼", ratio=0.10, multiple={15}, speed=18, w=80, h=70},

    [10] = {name="紫红章鱼", ratio=0.084, multiple={20}, speed=15, w=84, h=60, group={chance=7, count=4}},

    [11] = {name="绿剑鱼", ratio=0.068, multiple={25}, speed=18, w=100, h=70, group={chance=7, count=4}},

    [12] = {name="蝠鲼", ratio=0.057, multiple={30}, speed=14, w=160, h=60},

    [13] = {name="双髻鲨", ratio=0.0515, multiple={35}, speed=15, w=140, h=100, group={chance=4, count=4}},

    [14] = {name="黄金神仙鱼", ratio=0.0515, multiple={50}, speed=14, w=200, h=100},

    [15] = {name="黄金小丑鱼", ratio=0.0515, multiple={55}, speed=12, w=180, h=90},

    [16] = {name="黄金蝠鲼", ratio=0.0515, multiple={60}, speed=14, w=160, h=110},

    [17] = {name="盔甲鱼", ratio=0.026, multiple={20,30}, crit=5, speed=17, w=200, h=80},   --暴击5倍

    [18] = {name="安康鱼", ratio=0.016, multiple={30,40}, crit=5, speed=19, w=250, h=150},   --暴击5倍

    [19] = {name="招财龟", ratio=0.0105, multiple={40,50}, crit=5, speed=20, w=340, h=150},   --暴击5倍

    [20] = {name="雷霆鲨", ratio=0.006, multiple={70,90}, speed=10, w=1000, h=200},

    [21] = {name="鱼雷蟹", ratio=0.0035, multiple={80,100}, speed=20, w=260, h=220, boom=1},

    [22] = {name="海葵", ratio=0.0035, multiple={90,110}, speed=20, w=360, h=320},

    [23] = {name="霸王鱿鱼", ratio=0.0035, multiple={60,180}, speed=20, w=100, h=100},

    [24] = {name="黄金鲨", ratio=0.0035, multiple={80,240}, speed=20, w=1000, h=300},

    [25] = {name="永生海王", ratio=0.0105, multiple={168,666}, speed=12, w=100, h=80},

    [26] = {name="彩金鱼", ratio=0.013125, multiple={66,168}, jp=1, speed=12, w=90, h=80},

    [27] = {name="彩金龙", ratio=0.013125, multiple={160,320}, jp=1, speed=12, w=80, h=80},
}

-- 小型鱼
function fishconfig.getSmallFishes()
    local fishes = {}
    table.insert(fishes, {count=math.random(3, 4), ids={1,2,3,4,5}})
    table.insert(fishes, {count=math.random(2, 4), ids={6,7,8}})
    return fishes
end

-- 中型鱼
function fishconfig.getMediumFishes()
    local fishes = {}
    table.insert(fishes, {count=math.random(1, 2), ids={9,10,11}})
    table.insert(fishes, {count=1, ids={12,13}})
    return fishes
end

-- 次大型鱼
function fishconfig.getSubBigFishes(gameid, state)
    local fishes = {}
    table.insert(fishes, {count=1, ids={14,15,16}})
    return fishes
end

-- 大型鱼
function fishconfig.getBigFishes(gameid, state)
    local fishes = {}
    table.insert(fishes, {count=1, ids={18,19}})
    if state == 2 then
        if math.random(1, 100) <= 40 then
            table.insert(fishes, {count=1, ids={30}})
        end
    end
    return fishes
end

-- 阵法鱼
function fishconfig.getArrayFishes()
    local fishes = {}
    return fishes
end

-- 技能鱼
function fishconfig.getMagicFishes()
    local fishes = {}
    table.insert(fishes, {count=1, ids={25, 26, 27}})
    return fishes
end

-- BOSS鱼
function fishconfig.getBossFishes(sceceid, gameid, appid)
    local fishes = {}
    local sceneid2bossid = {
        [1] = 23,   --深海章鱼
        [2] = 24,   --史前巨鳄
        [3] = 21,   --深海狂鳌
        [4] = 22,   --暗夜魔兽
    }
    if math.random(1, 100) <= 50 then
        sceneid2bossid[5] = 22
    else
        sceneid2bossid[5] = 24
    end
    local bossid = sceneid2bossid[sceceid]
    if bossid == 21 then
        table.insert(fishes, {count=2, ids={bossid}})   -- 深海狂鳌刷2条
    else
        table.insert(fishes, {count=1, ids={bossid}})
    end
    return fishes
end

-- 场景鱼潮
function fishconfig.buildfishtide()
    local styles = {1,8,3,4,7}
    local style = styles[math.random(1,#styles)]
    if style == 1 then
        return style, fishtide.buildfishtide1(19, 10, 2, 3)  -- 一带三小
    elseif style == 8 then
        return style, fishtide.buildfishtide8(18, 18, 4, 3, 2)  -- 相对的圆
    elseif style == 3 then
        return style, fishtide.buildfishtide3(19, 18, 3, 2)  -- 三纵三横
    elseif style == 4 then
        return style, fishtide.buildfishtide4(13, 15)  -- 交叉组合
    elseif style == 7 then
        return style, fishtide.buildfishtide7(9, 8, 7, 4, 5, 6, 9, 4, 8, 7, 5, 4)  -- 平移的圈
    end
end



return fishconfig
