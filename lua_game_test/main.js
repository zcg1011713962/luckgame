const LoginWS = require("./loginws")
const NodeWS = require("./nodews")
const util = require("./utils");

// 用户人数
let userCount = 1

for (let i = 1; i <= userCount; i++){
    const userName = "Test" + i
    const userId = "AAAAAA" + i
    const loginUser = createUser(userId, userName)

    const gameId = 541 // 游戏ID
    const lang = 3 // 语言ID
    const betIndex = 1 // 投注金币挡位
    start(userId, loginUser, gameId, lang, betIndex)
}

function start(userId, loginUser, gameId, lang, betIndex){
    const loginSocket= new LoginWS(userId)
    const ws = loginSocket.getWS()
    ws.on('open', function open() {
        // 登录游戏
        util.login(ws, loginUser)
    });
    ws.on('message', function incoming(data) {
        let msg = data.toString()
        msg = msg.slice(11)
        msg = JSON.parse(msg)
        switch (msg.c){
            case 1:
                // 登录响应
                const loginResponse = util.loginResponse(msg)
                console.log(loginSocket.getUserId(), "进入登录服务成功")
                if(loginResponse.nodeAddress){
                    // 连接node服务
                    const nodeSocket= new NodeWS(userId, loginResponse.nodeAddress)
                    const node_ws = nodeSocket.getWS();

                    node_ws.on('open', function open() {
                        util.getUserInfo(node_ws, loginResponse.token, loginResponse.uid, loginResponse.subid)
                    })

                    node_ws.on('message', function incoming(data) {
                        let msg = data.toString()
                        console.log(msg)
                        msg = msg.slice(11)
                        try{
                            msg = JSON.parse(msg)
                        }catch (e){
                            console.log('协议响应非预期:', msg)
                            return
                        }
                        switch (msg.c){
                            case 2: // 登录响应
                                const ret2 = util.getUserInfoResponse(msg)
                                if(ret2){
                                    console.log(userId, '进入node服务成功')
                                }else{
                                    console.log(userId, '进入node服务失败')
                                }
                                break
                            case 43: // 匹配响应
                                const ret43 = util.getDeskResponse(node_ws,msg)
                                if(ret43){
                                    const deskId = msg.deskinfo.deskid
                                    console.log(userId, "匹配游戏", gameId ,"成功,当前桌子编号:", deskId)
                                    util.slotBet(node_ws, loginResponse.uid, betIndex, lang)
                                }else{
                                    console.log(userId, "匹配游戏", gameId ,"失败")
                                }
                                break
                            case 44: // 投注响应
                                    const ret44 = util.slotBetResponse(msg)
                                    if(ret44){
                                        const coin = msg.coin
                                        const winCoin = msg.wincoin > -1 ? msg.wincoin : msg.wincion;
                                        console.log(userId, "投注挡位", betIndex,"成功,赢金币:", winCoin, "剩余金币:", coin)
                                    }else{
                                        console.log(userId, "投注挡位", betIndex,"失败", msg)
                                    }
                                break
                            case 1019: // 登录node服务后，大厅通知
                                console.log(userId, "收得到大厅信息通知")
                                // 匹配游戏
                                util.matchSess(node_ws, loginResponse.uid, gameId, 0, lang)
                                break
                            default:
                                //console.log('响应', msg)
                                break
                        }
                        // node_ws.close();
                    });
                }else{
                    console.log(userId, "进入登录服务失败")
                }
                break
            default:
                break
        }
        ws.close();
    });
}



function createUser(userId, userName){
    return "{\n" +
        "    \"c\": 1,\n" +
        "    \"user\": \"Guest5483\",\n" +
        "    \"passwd\": \"Guest5483\",\n" +
        "    \"lineuserid\": \""+ userId +"\",\n" +
        "    \"linedisplayName\": \""+ userName +"\",\n" +
        "    \"linepictureUrl\": \"https://profile.line-scdn.net/abcdefghijklmn\",\n" +
        "    \"app\": 17,\n" +
        "    \"v\": \"1.0.0.3\",\n" +
        "    \"t\": 1,\n" +
        "    \"accessToken\": \"d18099dbce7ebbb199ed96570dad98a6\",\n" +
        "    \"platform\": \"Windows\",\n" +
        "    \"phone\": \"Web_Windows\",\n" +
        "    \"token\": \"1723621362517_23440307\",\n" +
        "    \"bwss\": 0,\n" +
        "    \"LoginExData\": 1,\n" +
        "    \"language\": 3,\n" +
        "    \"client_uuid\": \"1723621362511.2222\",\n" +
        "    \"bundleid\": \"com.pokerslotgame.play888\",\n" +
        "    \"deviceid\": \"0\",\n" +
        "    \"dinfo\": \"\",\n" +
        "    \"c_ts\": 1724310812722,\n" +
        "    \"c_idx\": 0\n" +
        "}"
}
