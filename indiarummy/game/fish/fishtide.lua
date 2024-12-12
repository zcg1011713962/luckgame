-- 鱼潮构建
-- 样式类型
-- 1: 一带三小
-- 2: 旋转的圆(双环)
-- 3: 三纵三横
-- 4: 交叉组合
-- 5: 三角阵型
-- 6: 发射双环(带旋转)
-- 7: 平移的圈
-- 8: 相对的圆
-- 9: 放射圆环
--10: 一带五小阵列
--11: 上下穿插
--12: 左右穿插
--13: 分列两旁
--14: 田径跑道
--15: 四重双环

local fishtide = {}

-- 鱼潮样式1：一带三小
function fishtide.buildfishtide1(ft1, ft2, ft3, ft4)
    -- 共出两轮，每轮1条大白鲨，带3个乌龟，以及40条小丑鱼围成的2个圈，以及20条黄背刺鱼组成的队列
    local fts = {}
    for i = 1, 2 do
        table.insert(fts, ft1)       --大白鲨x1
        for j=1, 3 do
            table.insert(fts, ft2)    --乌龟x3
        end
        for j=1, 40 do
            table.insert(fts, ft3)    --小丑鱼x40
        end
        for j=1, 20 do
            table.insert(fts, ft4)    --背刺鱼x20
        end
    end
    return fts
end

-- 鱼潮样式2：旋转的圆
function fishtide.buildfishtide2(ft1, ft2, ft3, ft4)
    --共出两个同心圈，每个同心圈4层，中心1条海龟，第2圈8条粉红刺鱼，第3圈12条黄蓝纹鱼，第4圈24条小丑鱼
    local fts = {}
    for i = 1, 2 do
        table.insert(fts, ft1)       --海龟x1
        for j = 1, 8 do             --粉红刺鱼x8
            table.insert(fts, ft2)
        end
        for j = 1, 12 do            --黄蓝纹鱼x12
            table.insert(fts, ft3)
        end
        for j = 1, 24 do            --小丑鱼x24
            table.insert(fts, ft4)
        end
    end
    return fts
end

-- 鱼潮样式3：三纵三横
function fishtide.buildfishtide3(ft1, ft2, ft3, ft4)
    -- 大鱼：黄金鲨+大白鲨鲸，共出3轮
    -- 小鱼：背刺鱼20x3，小丑鱼20*3
    local fts = {}
    for i = 1, 3 do
        table.insert(fts, ft1)
        table.insert(fts, ft2)
    end
    for i = 1, 60 do
        table.insert(fts, ft3)
        table.insert(fts, ft4)
    end
    return fts
end

-- 鱼潮样式4：交叉组合
function fishtide.buildfishtide4(ft1, ft2)
    --6条鳐鱼,60条鸳鸯鱼
    local fts = {}
    for i = 1, 6 do
        table.insert(fts, ft1)
    end
    for i = 1, 60 do
        table.insert(fts, ft2)
    end
    return fts
end

-- 鱼潮样式5：三角阵型
function fishtide.buildfishtide5(ft1, ft2, ft3)
    --共出两组，每组烛光鱼x16,背刺鱼x16，鸳鸯鱼x4
    local fts = {}
    for i = 1, 2 do
        for j = 1, 16 do             --烛光鱼x16
            table.insert(fts, ft1)
        end
        for j = 1, 16 do             --背刺鱼x16
            table.insert(fts, ft2)
        end
        for j = 1, 4 do              --鸳鸯鱼x4
            table.insert(fts, ft3)
        end
    end
    return fts
end

-- 鱼潮样式6：发射双环
function fishtide.buildfishtide6(ft1, ft2, ft3, ft4, ft5)
    --共出两个圆环，每个圆环发射5次，每次发射8条鱼
    local fts = {}
    for i = 1, 2 do
        for j = 1, 12 do             --蓝热带鱼x8
            table.insert(fts, ft1)
        end
        for j = 1, 12 do            --红热带鱼x8
            table.insert(fts, ft2)
        end
        for j = 1, 12 do            --红刺鱼x8
            table.insert(fts, ft3)
        end
        for j = 1, 12 do            --黄刺鱼x8
            table.insert(fts, ft4)
        end
        for j = 1, 12 do            --大颌鱼x8
            table.insert(fts, ft5)
        end
    end
    return fts
end

-- 鱼潮样式7：平移的圈
function fishtide.buildfishtide7(ft1, ft2, ft3, ft4, ft5, ft6, ft7, ft8, ft9, ft10, ft11, ft12)
    --共出8个圆环，从右到左平移，每个圈15条鱼
    local ft = {ft1, ft2, ft3, ft4, ft5, ft6, ft7, ft8, ft9, ft10, ft11, ft12}
    local fts = {}
    for i = 1, 12 do
        for j = 1, 15 do             --每个圈15条鱼
            table.insert(fts, ft[i])
        end
    end
    return fts
end

-- 鱼潮样式8：相对的圆
function fishtide.buildfishtide8(ft1, ft2, ft3, ft4, ft5)
    --共出两个同心圈，每个同心圈4层，中心1条大白鲸/大黄鲸，第2圈18条气泡鱼，第3圈27条虾米鱼，第4圈36条小红鱼
    local fts = {}
    for i = 1, 2 do
        if i==1 then
            table.insert(fts, ft1)       --鲸x1
        else
            table.insert(fts, ft2)
        end
        for j = 1, 18 do             --气泡鱼x18
            table.insert(fts, ft3)
        end
        for j = 1, 27 do            --虾米鱼x27
            table.insert(fts, ft4)
        end
        for j = 1, 36 do            --小红鱼x36
            table.insert(fts, ft5)
        end
    end
    return fts
end

-- 9: 放射圆环
function fishtide.buildfishtide9(ft1, ft2, ft3, ft4, ft5, ft6, ft7, ft8, ft9, ft10)
    --从圆心不断发射出一环一环的鱼，每环分别为15,12,15,12,15,12,15,12,6,3条鱼，一共10环
    local fts = {}
    local cnt = {15,12,15,12,15,12,15,12,6,3}
    local ft = {ft1,ft2,ft3,ft4,ft5,ft6,ft7,ft8,ft9,ft10}
    for i = 1, #cnt do
        for j = 1, cnt[i] do
            table.insert(fts, ft[i])
        end
    end
    return fts
end

--10: 一带五小阵列
function fishtide.buildfishtide10(ft1, ft2, ft3, ft4, ft5, ft6, ft7, ft8)
    --每个大鱼周围5个小鱼，组成一个小阵列；6个小阵列+2个大鱼+1个超大鱼
    local fts = {}
    local fts1 = {ft1, ft3, ft5}
    local fts2 = {ft2, ft4, ft6}
    for i = 1, 3 do
        for j = 1, 2 do
            table.insert(fts, fts1[i])
            for k = 1, 5 do
                table.insert(fts, fts2[i])
            end
        end
    end
    table.insert(fts, ft7)
    table.insert(fts, ft7)
    table.insert(fts, ft8)
    return fts
end

--11: 上下穿插
function fishtide.buildfishtide11(ft1, ft2, ft3, ft4, ft5, ft6)
    -- 从下往上5列鱼，从上往下4列鱼，相互穿插
    local fts = {}
    local ft = {ft1, ft2, ft3, ft4, ft5}
    -- 下面
    for i = 1, 5 do
        for j = 1, 5 do
            table.insert(fts, ft[i])
        end
    end
    table.insert(fts, ft6)
    -- 上面
    for i = 1, 5 do
        for j = 1, 4 do
            table.insert(fts, ft[i])
        end
    end
    table.insert(fts, ft6)
    table.insert(fts, ft6)
    return fts
end

--12: 左右穿插
function fishtide.buildfishtide12(ft1, ft2, ft3, ft4, ft5, ft6, ft7, ft8)
    -- 从左往右4列，从右往左3列，相互穿插
    local fts = {}
    local ft = {ft1, ft2, ft3, ft4, ft5, ft6, ft7, ft8}
    --左边
    for i = 1, 8 do
        for j = 1, 4 do
            table.insert(fts, ft[i])
        end
    end
    --右边
    for i = 1, 8 do
        for j = 1, 3 do
            table.insert(fts, ft[i])
        end
    end
    return fts
end

--13: 分列两旁
function fishtide.buildfishtide13(ft1, ft2, ft3, ft4, ft5)
    -- 中间的鱼从右至左(左上，左下)移动，上下两侧各排列1排鱼
    local fts = {}
    -- 中间
    for i = 1, 3 do
        table.insert(fts, ft1)  --1白
        table.insert(fts, ft2)  --2黄
        table.insert(fts, ft2)
        table.insert(fts, ft1)  --2白
        table.insert(fts, ft1)
        table.insert(fts, ft2)  --2黄
        table.insert(fts, ft2)
    end
    -- 上下两侧
    local ft = {ft3, ft4, ft5}
    for i = 1, 3 do
        for j = 1, 60 do    -- 上下各30条，共60条
            table.insert(fts, ft[i])
        end
    end
    return fts
end

--14: 田径跑道
function fishtide.buildfishtide14(ft1, ft2, ft3, ft4)
    -- 两圈鱼围成田径场跑道的形状，中间两条金龙相对，并排布若干蝴蝶鱼
    local fts = {}
    -- 中间
    for i = 1, 2 do
        table.insert(fts, ft1)
    end
    for i = 1, 10 do
        table.insert(fts, ft2)
    end
    --外围
    for i = 1, 60 do
        table.insert(fts, ft3)
    end
    for i = 1, 80 do
        table.insert(fts, ft4)
    end
    return fts
end

--15: 四重双环
function fishtide.buildfishtide15(ft1, ft2, ft3, ft4, ft5, ft6, ft7, ft8, ft9, ft10)
    -- 两个大圆环，每个圆环由4圈鱼组成，中心点各有一条大鱼
    local fts = {}
    local ft = {{ft1,ft2,ft3,ft4,ft5}, {ft6,ft7,ft8,ft9,ft10}}  -- 两个鱼环的鱼的类型(由外而内)
    local count = {30, 24, 20, 18, 1}      -- 由外而内每一重的鱼的数量
    for i = 1, 2 do
        --由内而外
        for j = 1, 5 do
            for k = 1, count[j] do
                table.insert(fts, ft[i][j])
            end
        end
    end
    return fts
end

return fishtide
