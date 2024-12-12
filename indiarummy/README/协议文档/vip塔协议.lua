--vip塔协议

--1、获取列表
--[[
    req:
    {
        c:345,
        uid:100100,
    }

    resp:
    {
        "data": [
            {
                "type": 1, --1:升级奖励 2:周奖励 3:月奖励
                "rewards": [ --当前奖励
                    {
                        "count": 10,
                        "type": 1
                    }
                ],
                "state": 0, --0, 1:可领取 2：已领取
                "monthlybonus": [ --月奖励
                    {
                        "count": 10,
                        "type": 1
                    }
                ],
                "upbonus": [ --升级奖励
                    {
                        "count": 10,
                        "type": 1
                    }
                ],
                "doing": 1,  --0:未开启 1:正在开启 2:已完成
                "level": 2,
                "diamond": 200, --需要的经验值
                "weeklybonus": [ --周奖励
                    {
                        "count": 5,
                        "type": 1
                    }
                ]
            },
            {
                "type": 1,
                "rewards": [
                    {
                        "count": 50,
                        "type": 1
                    }
                ],
                "state": 0,
                "monthlybonus": [
                    {
                        "count": 50,
                        "type": 1
                    }
                ],
                "upbonus": [
                    {
                        "count": 50,
                        "type": 1
                    }
                ],
                "doing": 0,
                "level": 3,
                "diamond": 1000,
                "weeklybonus": [
                    {
                        "count": 20,
                        "type": 1
                    }
                ]
            },
            ...
        ],
        "c": 345,
        "code": 200
    }


2、领取奖励
    req: {
        c:346,
        uid:100100
    }

    resp:
    {
        c:346,
        uid:1000100,
        spcode:0,  --424:任务未完成，不能领取
        rewards:{
            {
                type:1,
                count:10
            },
            ...
        }
    }
]]