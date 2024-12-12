#### vip权益功能协议

-- req :
{
    c:212,
    uid:100100
}

resp:
{
    "c": 212,
    "code": 200,
    "spcode": 0,
    "data": [
        {
             "id": 1, --vip等级
             "exp": 0, --达到需要的经验值

            "bonusl": [ --达到的奖励
                {
                    "count": 0,
                    "type": 1
                }
            ],
           
            "bonusw": [ --达到后的周奖励
                {
                    "count": 0,
                    "type": 1
                }
            ],
            "bonusm": [ --达到后的月奖励
                {
                    "count": 0,
                    "type": 1
                }
            ],
            "bonuss": [] --达到后的签到奖励
        },
        {
            "bonusl": [
                {
                    "count": 10,
                    "type": 1
                }
            ],
            "exp": 200,
            "id": 2,
            "bonusw": [
                {
                    "count": 5,
                    "type": 1
                }
            ],
            "bonusm": [
                {
                    "count": 10,
                    "type": 1
                }
            ],
            "bonuss": []
        },
        ...
    ],
    "user": {
        "nextvipexp": 200, --到下一级的经验值
        "uid": 62211, --uid
        "svip": 0, --当前vip等级
        "svipexp": 0 --当前经验值
    }
}

2、领取权益

可能返回spcode错误码:
651, --用户不是vip

req:
{
    c:213,
    uid:10101,
    type:1, --1:签到 2:weeklybonus 3:monthlybonus 4:levelbonus
    vip:2, --领取第几级的
}

resp:
{
    c:213,
    code:200,
    spcode:0,
    rewards:[
        {
            type:1,
            count:20,
        },
        ...
    ]
}