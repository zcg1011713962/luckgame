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

-- 炮台倍率
function fishconfig.getMults()
    return  {1,2,3,5,8,10,20,50,80,100,200,300}
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
    [1] = {name="绿叶小鱼", ratio=0.45, multiple={2}, speed=10, w=24, h=40, group={chance=20, count=6}},

    [2] = {name="小丑鱼", ratio=0.3, multiple={3}, speed=12, w=32, h=26, group={chance=15, count=5}},

    [3] = {name="黄蓝纹鱼", ratio=0.235, multiple={4}, speed=10, w=60, h=32, group={chance=14, count=5}},

    [4] = {name="粉红刺鱼", ratio=0.19, multiple={5}, speed=12, w=50, h=40, group={chance=10, count=5}},

    [5] = {name="紫衫鱼", ratio=0.16, multiple={6}, speed=10, w=60, h=70},

    [6] = {name="黄鳊鱼", ratio=0.14, multiple={7}, speed=10, w=64, h=54},

    [7] = {name="小龙虾", ratio=0.123, multiple={8}, speed=15, w=66, h=52, group={chance=10, count=5}},

    [8] = {name="紫旗鱼", ratio=0.11, multiple={9}, speed=10, w=100, h=50, group={chance=10, count=4}},

    [9] = {name="八爪鱼", ratio=0.10, multiple={10}, speed=18, w=80, h=70},

    [10] = {name="灯笼鱼", ratio=0.084, multiple={12}, speed=15, w=84, h=60, group={chance=7, count=4}},

    [11] = {name="海龟", ratio=0.068, multiple={15}, speed=18, w=100, h=70, group={chance=7, count=4}},

    [12] = {name="锯齿鲨", ratio=0.057, multiple={18}, speed=14, w=160, h=60},

    [13] = {name="蓝魔鬼鱼", ratio=0.0515, multiple={20}, speed=15, w=140, h=100, group={chance=4, count=4}},

    [14] = {name="精英小丑鱼", ratio=0.0515, multiple={10,30}, speed=14, w=200, h=100},

    [15] = {name="精英黄蓝纹鱼", ratio=0.0515, multiple={10,30}, speed=12, w=180, h=90},

    [16] = {name="精英粉红刺鱼", ratio=0.0515, multiple={10,30}, speed=14, w=160, h=110},

    [17] = {name="鲨鱼", ratio=0.026, multiple={20,60}, speed=17, w=200, h=80},

    [18] = {name="杀人鲸", ratio=0.016, multiple={30,100}, speed=19, w=250, h=150},

    [19] = {name="帝王鲸", ratio=0.0105, multiple={100}, speed=20, w=340, h=150},

    [20] = {name="狂暴火龙", ratio=0.006, multiple={100,250}, speed=10, w=1000, h=200},

    [21] = {name="深海狂鳌", ratio=0.0035, multiple={100,500}, speed=20, w=260, h=220},

    [22] = {name="暗夜魔兽", ratio=0.0035, multiple={100,500}, speed=20, w=360, h=320},

    [23] = {name="深海章鱼", ratio=0.0035, multiple={100,500}, speed=20, w=100, h=100},

    [24] = {name="史前巨鳄", ratio=0.0035, multiple={100,500}, speed=20, w=1000, h=300},

    [25] = {name="钻头炮蟹(局部炸弹)", ratio=0.0105, multiple={100}, speed=12, w=100, h=80, boom=1},

    [26] = {name="电磁炮蟹(局部炸弹)", ratio=0.013125, multiple={80}, speed=12, w=90, h=80, boom=1},

    [27] = {name="炸弹蟹(局部炸弹)", ratio=0.013125, multiple={80}, speed=12, w=80, h=80, boom=1},

    [28] = {name="连锁闪电(随机炸弹)", ratio=0.0174, multiple={60}, speed=14, w=120, h=120, boom=4},

    [29] = {name="旋风鱼(同类炸弹)", ratio=0.025, multiple={40}, speed=14, w=100, h=100, boom=3},

    [30] = {name="海王", ratio=0.003, multiple={200,500}, speed=20, w=180, h=480},
}

-- 小型鱼
function fishconfig.getSmallFishes()
    local fishes = {}
    table.insert(fishes, {count=math.random(3, 4), ids={1,2,3,4,5,6,7}})
    table.insert(fishes, {count=math.random(2, 4), ids={8,9,10}})
    return fishes
end

-- 中型鱼
function fishconfig.getMediumFishes()
    local fishes = {}
    table.insert(fishes, {count=math.random(1, 2), ids={11,12,13}})
    table.insert(fishes, {count=1, ids={14,15,16}})
    if math.random(1, 100) <= 40 then
        table.insert(fishes, {count=1, ids={17}})
    end
    if math.random(1, 100) <= 25 then
        table.insert(fishes, {count=1, ids={28,29}})
    end
    return fishes
end

-- 次大型鱼
function fishconfig.getSubBigFishes(gameid, state)
    local fishes = {}
    if state == 0 then    --龙不和boss一起刷；龙不和海王一起刷
        if math.random(1, 100) <= 60 then
            table.insert(fishes, {count=1, ids={20}})
        end
    end
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
