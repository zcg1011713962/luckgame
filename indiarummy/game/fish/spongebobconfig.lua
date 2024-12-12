--   海绵宝宝 配置文件

-- 捕鱼基础概率
-- 倍数[2,10]  r=1/倍数
-- 倍数(10, 20] r=1/倍数*1.02
-- 倍数(20, 30] r=1/倍数*1.04
-- 倍数(30,50] r=1/倍数*1.05
-- 倍数(50,80] r=1/倍数*1.06
-- 倍数(80,150] r=1/倍数*1.07
-- 倍数(150,200] r=1/倍数*1.08
-- 倍数(200, 1000] r=1/倍数*1.1

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
fishconfig.scene_count = 3

-- 设计宽度/高度
fishconfig.resolution_width  = 1280
fishconfig.resolution_height = 720

-- 时钟间隔
fishconfig.tick_interval = 25

-- 炮台倍率
function fishconfig.getMults()
    return  {0.1,0.2,0.3,0.5,0.8,1.0,2.0,5.0,8.0,10.0,20.0,30.0}
end

-- AI配置
function fishconfig.getAiInfo()
    return {
        mults = {0.1, 0.2, 0.3},
        cannons = {1},
    }
end

-- 技能炮配置
fishconfig.skill = {
    base_drop_ratio = 0.001,  -- 基础掉落概率
    drop_need_revenue = 80,   -- 掉落的系统收分条件
    min_multiple = 4,         -- 保底赔率
    items = {                 -- 技能类型
        {id=31, max_multiple=80, boom=1, weight=40},
        {id=32, max_multiple=80, boom=1, weight=40},
        {id=33, max_multiple=160,boom=2, weight=20},
    },
}

-- 鱼属性配置
fishconfig.fish = {
    [1]={name="小银鱼", ratio=0.45, multiple={2}, speed=10, w=64, h=20},

    [2]={name="小棕鱼", ratio=0.3, multiple={3}, speed=10, w=70, h=20},

    [3]={name="海马", ratio=0.23, multiple={4}, speed=14, w=64, h=80},

    [4]={name="胖大星", ratio=0.23, multiple={4}, speed=14, w=64, h=64},

    [5]={name="小丑水母", ratio=0.19, multiple={5}, speed=14, w=84, h=72},

    [6]={name="龙虾", ratio=0.19, multiple={5}, speed=12, w=84, h=80},

    [7]={name="飞鱼", ratio=0.1225, multiple={8}, speed=8, w=90, h=140},

    [8]={name="海龟", ratio=0.1225, multiple={8}, speed=14, w=110, h=120},

    [9]={name="海螺水母", ratio=0.10, multiple={10}, speed=12, w=144, h=80},

    [10]={name="鳐鱼", ratio=0.10, multiple={10}, speed=12, w=144, h=96},

    [11]={name="弹头水母", ratio=0.084, multiple={12}, speed=12, w=100, h=80},

    [12]={name="棘刺鱼", ratio=0.0672, multiple={15}, speed=12, w=150, h=150},

    [13]={name="裙摆鱼", ratio=0.0565, multiple={18}, speed=14, w=160, h=120},

    [14]={name="灯泡鱼", ratio=0.051, multiple={20}, speed=14, w=140, h=140},

    [15]={name="娃娃鱼", ratio=0.0408, multiple={25}, speed=12, w=150, h=110},

    [16]={name="铠甲鲨", ratio=0.0341, multiple={30}, speed=12, w=240, h=160},

    [17]={name="双髻鲸", ratio=0.0259, multiple={40}, speed=14, w=256, h=160},
    
    [18]={name="大白鲸", ratio=0.0208, multiple={50}, speed=16, w=280, h=180},
    
    [19]={name="社会鲸", ratio=0.0105, multiple={100}, speed=18, w=420, h=240},

    [20]={name="同类炸弹", ratio=0.0208, multiple={50}, speed=14, w=240, h=240, boom=3},

    [21]={name="海底爆破(全屏炸弹)", ratio=0.00525, multiple={200}, speed=16, w=320, h=500, boom=2},
}

-- 小型鱼
function fishconfig.getSmallFishes()
    local fishes = {}
    table.insert(fishes, {count=math.random(5, 6), ids={1,2,3,4,5,6}})
    table.insert(fishes, {count=math.random(2, 3), ids={7,8,9}})
    return fishes
end

-- 中型鱼
function fishconfig.getMediumFishes()
    local fishes = {}
    table.insert(fishes, {count=math.random(2, 3), ids={10,11,12,13}})
    table.insert(fishes, {count=1, ids={14,15}})
    return fishes
end

-- 次大型鱼
function fishconfig.getSubBigFishes()
    local fishes = {}
    table.insert(fishes, {count=math.random(1, 2), ids={16,17,18}})
    return fishes
end

-- 大型鱼
function fishconfig.getBigFishes()
    local fishes = {}
    table.insert(fishes, {count=1, ids={19}})
    if math.random(1, 100) <= 66 then
        table.insert(fishes, {count=1, ids={20}})
    end
    return fishes
end

-- 阵法鱼
function fishconfig.getArrayFishes()
    local fishes = {}
    table.insert(fishes, {count=1, ids={21}})
    return fishes
end

-- BOSS鱼
function fishconfig.getBossFishes()
    return {}
end

-- 场景鱼潮
function fishconfig.buildfishtide()
    local styles = {1,3,5,6}
    local style = styles[math.random(1,#styles)]
    if style == 1 then
        return style, fishtide.buildfishtide1(10, 6, 2, 3)  -- 一带三小
    elseif style == 3 then
        return style, fishtide.buildfishtide3(11, 10, 3, 2)  -- 三纵三横
    elseif style == 5 then
        return style, fishtide.buildfishtide5(4, 3, 7)  -- 三角阵型
    elseif style == 6 then
        return style, fishtide.buildfishtide6(5, 6, 7, 8, 9)  -- 发射鱼环
    end
end


return fishconfig
