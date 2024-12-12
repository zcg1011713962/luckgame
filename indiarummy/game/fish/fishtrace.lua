-- 鱼游动路线构建
-- 路线类型
-- 0: 静止不动  (海王章鱼)
-- 1: 随机直线
-- 2: 随机贝塞尔曲线
-- 3: 采点取样
-- 4: 圆
-- 5: 多段线段  (海王技能蟹)
-- 1: 上下直线  (海王巨鳄)
-- 1: 坐标轴直线  (海王火龙)
-- 1: 左右直线 (海王魔兽)
-- 1: 上下左右直线 (海王魔兽)

local fishtrace = {}


-- 随机端点
local function getRandonExtremePoint(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    local w = resolutionWidth
    local h = resolutionHeight
    local bw = boxWidth
    local bh = boxHeight

    local factor = 1  --方向因子
    if math.random(1, 100) <= 50 then
        factor = -1
    end

    local startPoint, endPoint
    local rand = math.random(1, 100)

    if rand <= 70 then      --70% 左<->右
        startPoint = {x=factor*(-w/2-bw), y=math.random(-h/2, h/2)}
        endPoint = {x=factor*(w/2+bw), y=math.random(-h/2, h/2)}
    elseif rand <= 85 then  --15% 左上 <-> 右下
        startPoint = {x=math.random(-w/2, 0), y=h/2+bh}
        endPoint = {x=math.random(0, w/2), y=-h/2-bh}
    else                    --15% 左下 <-> 右上
        startPoint = {x=math.random(-w/2, 0), y=-h/2-bh}
        endPoint = {x=math.random(0, w/2), y=h/2+bh}
    end

    return startPoint, endPoint
end

-- 0: 静止不动
function fishtrace.buildPosition(x_, y_)
    return {{x=x_,y=y_}}
end

-- 1: 随机直线
function fishtrace.buildRandomLine(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    local s, e = getRandonExtremePoint(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    local trace = {}
    if math.random(1, 100) <= 50 then
        trace[1] = s
        trace[2] = e
    else        -- 交换起点和终点
        trace[1] = e
        trace[2] = s
    end
    return trace
end

-- 2: 随机贝塞尔曲线
function fishtrace.buildRandomBezier(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    local s, e = getRandonExtremePoint(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    local w = resolutionWidth
    local h = resolutionHeight
    local trace = {}
    if math.random(1, 100) <= 50 then
        trace[1] = s
        trace[2] = {x=math.random(-w/2, w/2), y=math.random(-h/2, h/2)}
        trace[3] = {x=math.random(-w/2, w/2), y=math.random(-h/2, h/2)}
        trace[4] = e
    else        -- 交换起点和终点
        trace[1] = e
        trace[2] = {x=math.random(-w/2, w/2), y=math.random(-h/2, h/2)}
        trace[3] = {x=math.random(-w/2, w/2), y=math.random(-h/2, h/2)}
        trace[4] = s
    end
    return trace
end

-- 3: 采点取样
function fishtrace.buildCardinalSpline(index)
    local trace
    if index == 1 then  -- 第一条正向
        trace = {{x=-250,y=-240},{x=0,y=-240},{x=250,y=-240},{x=400,y=-180},
            {x=480,y=0},{x=400,y=180},{x=250,y=240},{x=0,y=240},{x=-250,y=240},
            {x=-400,y=180},{x=-480,y=0},{x=-400,y=-180},{x=-250,y=-240}}
    elseif index == 2 then  -- 第二条偏移
        trace = {{x=-480,y=0},{x=-400,y=180},{x=-250,y=240},{x=0,y=240},
            {x=250,y=240},{x=400,y=180},{x=480,y=0},{x=400,y=-180},{x=250,y=-240},
            {x=0,y=-240},{x=-250,y=-240},{x=-400,y=-180},{x=-480,y=0}}
    else  -- 第三条反向
        trace = {{x=-250,y=-240},{x=-400,y=-180},{x=-480,y=0},{x=-400,y=180},
            {x=-250,y=240},{x=0,y=240},{x=250,y=240},{x=400,y=180},{x=480,y=0},
            {x=400,y=-180},{x=250,y=-240},{x=0,y=-240},{x=-250,y=-240}}
    end
    return trace
end

-- 4: 圆
function fishtrace.buildCircle(x_, y_, r_)
    return {{x=x_,y=y_,r=r_}}
end

-- 5: 多段线段
function fishtrace.buildMultiLine(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    local trace
    local rand = math.random(1, 4)
    if rand == 1 then
        trace = {{x=-resolutionWidth/2-boxWidth, y=0}, {x=-80, y=0}, {x=80, y=0}, {x=resolutionWidth/2+boxWidth, y=0}}
    elseif rand == 2 then
        trace = {{x=resolutionWidth/2+boxWidth, y=0}, {x=80, y=0}, {x=-80, y=0}, {x=-resolutionWidth/2-boxWidth, y=0}}
    elseif rand == 3 then
        trace = {{x=0, y=resolutionHeight/2+boxHeight}, {x=0, y=60}, {x=0, y=-60}, {x=0, y=-resolutionHeight/2-boxHeight}}
    elseif rand == 4 then
        trace = {{x=0, y=-resolutionHeight/2-boxHeight}, {x=0, y=-60}, {x=0, y=60}, {x=0, y=resolutionHeight/2+boxHeight}}
    end
    return trace
end

-- 1: 上下直线
function fishtrace.buildUpDownLine(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    local px = math.random(-resolutionWidth/4, resolutionWidth/4)
    local trace
    if math.random(1, 100) <= 50 then
        trace = {{x=px, y=resolutionHeight/2+boxWidth/2}, {x=px, y=-resolutionHeight/2-boxWidth/2}}
    else
        trace = {{x=px, y=-resolutionHeight/2-boxWidth/2}, {x=px, y=resolutionHeight/2+boxWidth/2}}
    end
    return trace
end

-- 1: 坐标轴直线 （水平或垂直，经过中心点）
function fishtrace.buildAxisLine(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    local trace
    local factor = 1
    if math.random(1, 100) <= 50 then
        factor = -1
    end
    if math.random(1, 100) <= 67 then  --左右
        trace = {{x=(-resolutionWidth/2-boxWidth/2)*factor, y=0}, {x=(resolutionWidth/2+boxWidth/2)*factor, y=0}}
    else  --上下
        trace = {{x=0, y=(resolutionHeight/2+boxWidth/2)*factor}, {x=0, y=(-resolutionHeight/2-boxWidth/2)*factor}}
    end
    return trace
end

-- 1: 左右直线
function fishtrace.buildLeftRightLine(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    local py = math.random(-resolutionHeight/4, resolutionHeight/4)
    local trace
    if math.random(1, 100) <= 50 then
        trace = {{x=resolutionWidth/2+boxWidth/2, y=py}, {x=-resolutionWidth/2-boxWidth/2, y=py}}
    else
        trace = {{x=-resolutionWidth/2-boxWidth/2, y=py}, {x=resolutionWidth/2+boxWidth/2, y=py}}
    end
    return trace
end

-- 1: 上下左右直线
function fishtrace.buildUpDownLeftRightLine(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    if math.random(1, 100) <= 67 then  -- 左右
        return fishtrace.buildLeftRightLine(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    else
        return fishtrace.buildUpDownLine(resolutionWidth, resolutionHeight, boxWidth, boxHeight)
    end
end

return fishtrace
