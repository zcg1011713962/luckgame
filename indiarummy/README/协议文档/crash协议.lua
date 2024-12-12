--桌子状态
    State = {
        Betting = 2,  --押注阶段
        Play = 3,     --游戏阶段
    },
--桌子信息
--deskInfo增加字段
    {
        quad = {  --飞行二次函数系数(时间与倍数关系)  mult = a*t*t + b*t + c
            a = 0.0052,
            b = 0.025,
            c = 1
        },
        round = {
            launchtime = 0, --发射时间
            curtime = 0,    --当前时间
            crash = 0,      --是否爆炸
            mult = 1,       --最终倍数
        }
    }

--开始游戏（火箭起飞）
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_STATE_BETTING,
        launchtime = 154.54 --发射时间戳（秒）
    }

--游戏结束（火箭爆炸）
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_STATE_SETTLE,
        result = {mult=1.55}, --最终倍数
    }

--交互类
    --玩家下注(C->S) 不要太频繁，可以等玩家点完几次后再一次性上传
    {
        c = 37,
        uid = uid,
        betcoin = 10,   --押注额（点击Guess后一把押定，不能追加）
        flee = 120, --逃走值（x100）
    }
    --返回
    {
        c = 37,
        spcode = 0, --spcode不为0表示下注失败，前端从桌面移除筹码即可
        uid = uid,
        betcoin = 10,   --押注额
        flee = 1.15, --逃走值
    }

    --玩家提取(C->S)
    {
        c = 81,
        uid = uid,
    }
    --返回
    {
        c = 81,
        spcode = 0, --spcode==0表示提取成功，spcode==1表示提取失败，火箭已经爆炸
        uid = uid,
        wincoin = 100,      --赢得金币
        mult = 1.5,         --倍数
    }