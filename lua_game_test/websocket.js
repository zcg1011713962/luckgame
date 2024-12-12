const WebSocket = require('ws');
const msgpack = require('msgpack-lite');
let ws;
let uid = 0


// 启动客户端
startClient()

function startClient() {
    // 连接服务器
    ws = new WebSocket('ws://192.168.127.131:9951/ws');
    ws.on('open', function open() {
        // 登录游戏
        login()
    });

    ws.on('message', function incoming(data) {
        let msg = data.toString()
        msg = msg.slice(11)
        msg = JSON.parse(msg)
        switch (msg.c){
            case 1:
                // 登录响应
                loginResponse(msg)
                break
            default:
                break
        }
        ws.close();
    });

    ws.on('close', function close() {
        console.log('Connection closed');
    });
}

function login(){
    // 消息内容
    /*const msg = "{\n" +
        "    \"c\": 1,\n" +
        "    \"user\": \"Guest6217\",\n" +
        "    \"passwd\": \"Guest6217\",\n" +
        "    \"app\": 17,\n" +
        "    \"v\": \"1.0.0.3\",\n" +
        "    \"t\": 1,\n" +
        "    \"accessToken\": \"82e7dc47b6e48728ecd526a25e50a0da\",\n" +
        "    \"platform\": \"Windows\",\n" +
        "    \"phone\": \"Web_Windows\",\n" +
        "    \"token\": \"1721791529808_24937723\",\n" +
        "    \"bwss\": 0,\n" +
        "    \"LoginExData\": 1,\n" +
        "    \"language\": 2,\n" +
        "    \"client_uuid\": \"1721791529802.485\",\n" +
        "    \"bundleid\": \"com.pokerslotgame.play888\",\n" +
        "    \"deviceid\": \"0\",\n" +
        "    \"dinfo\": \"\",\n" +
        "    \"c_ts\": 1724310812722,\n" +
        "    \"c_idx\": 0\n" +
        "}";*/

    const msg = "{\n" +
        "    \"c\": 1,\n" +
        "    \"user\": \"Guest5483\",\n" +
        "    \"passwd\": \"Guest5483\",\n" +
        "    \"lineuserid\": \"U4af4980629\",\n" +
        "    \"linedisplayName\": \"Brown\",\n" +
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
        "}";
    // 发送消息
    ws.send(msgToBuf(msg));
}

function loginResponse(msg){
    // 登录响应
    if(!msg.spcode && msg.code === 200){
        // 登录成功
        console.log('登录成功', msg)
        const nodeAddress = msg.net
        const token = msg.token
        uid = msg.uid
        const subid = msg.subid

        // 连接node服务
        const node_ws = new WebSocket('ws://'+ nodeAddress +'/ws');
        node_ws.on('open', function open() {
            // 去node服务校验，返回登录信息
            getUserInfo(node_ws, token, uid, subid)
            // 获取德州扑克场次
            // getSessList(node_ws, uid, 293)
            // 获取桌子列表
            /*setTimeout(()=>{
                getBetDesk(node_ws, uid, 16)
            },500)*/
            //setTimeout(()=>{
                //创建桌子信息
                // createDesk(node_ws, uid, 293, 1)
                // 查询桌子列表
                // searchDesks(node_ws)
                // 随机匹配房间或者创建密码房间
                // matchSess(node_ws, uid, 293, 1)
            //},1000)
            // 给好友赠金币
            // giveCoin(node_ws, 13025, 13023, 1)
        });
        node_ws.on('message', function incoming(data) {
            let msg = data.toString()
            msg = msg.slice(11)
            try{
                msg = JSON.parse(msg)
            }catch (e){
                console.log('协议响应非预期:', msg)
                return
            }
            switch (msg.c){
                case 2:
                    getUserInfoResponse(msg)
                    break
                case 30:
                    getSessListResponse(msg)
                    break
                case 31:
                    getDeskResponse(node_ws, msg)
                    break
                case 43:
                    getDeskResponse(node_ws,msg)
                    break
                case 64:
                    getDeskListResponse(node_ws, msg)
                    break
                case 65:
                    break
                case 66:
                    searchDesksResponse(msg)
                    break
                case 34:
                    roomResponse(node_ws,msg)
                    break
                // case 43:
                //     enterRoomResponse(node_ws, msg)
                //     break
                case 37:
                    console.log('投注响应', msg.code)
                    break
                case 279:
                    console.log('赠送响应', msg)
                    break
                case 128001:
                    const time = msg.time
                    console.log(time, "秒后开始下一轮投注")
                    if(i > 5){
                        i = 0
                        console.log("重新登录-------------------")
                        ws.close()
                        setTimeout(function () {
                            startClient()
                        }, 500)
                    }else{
                        setTimeout(function () {
                            bet(16, node_ws)
                        }, time * 1000 + 500)
                    }
                    break;
                default:
                     //console.log('响应', msg)
                    break
            }
            // node_ws.close();
        });
    }
}

/**
 * 加入指定桌子
 */
function joinDeskById(node_ws, ssid, deskid, gameid, uid){
    const msg = "{\n" +
        "    \"c\": 65,\n" +
        "    \"ssid\": "+ ssid +",\n" +
        "    \"deskid\": "+ deskid +",\n" +
        "    \"gameid\": "+ gameid +",\n" +
        "    \"c_ts\": 1724310812722,\n" +
        "    \"c_idx\": 26,\n" +
        "    \"uid\": "+ uid +",\n" +
        "    \"language\": 2\n" +
        "}"
    // 发送消息
    console.log('加入指定桌子协议:', msg)
    node_ws.send(msgToBuf(msg));
}
function searchDesksResponse(msg){
    console.log('加入桌子响应', msg)
}

function giveCoin(node_ws, fromuid, touid, coin){
    const msg = "{\n" +
        "    \"c\": 279,\n" +
        "    \"fromuid\": "+ fromuid +",\n" +
        "    \"touid\": "+ touid +",\n" +
        "    \"coin\": "+ coin +",\n" +
        "    \"c_ts\": 1724310812722,\n" +
        "    \"c_idx\": 26,\n" +
        "    \"uid\": "+ uid +",\n" +
        "    \"language\": 2\n" +
        "}"
    // 发送消息
    console.log('赠送金币:', msg)
    node_ws.send(msgToBuf(msg));
}

function roomResponse(node_ws,msg){
    console.log('房间列表响应', msg)
    const items = msg.rooms
    const deskid = items[0].deskid
    console.log('deskid', deskid)
    matchSess(node_ws, uid, 16, 0, deskid)
}
let i = 0
function bet(gameid, node_ws){
    // const cts = Date.now()
    // const msg = "{\n" +
    //     "    \"c\": 37,\n" +
    //     "    \"chips\": [[0,0,0,0,0,0,0],[1,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0]],\n" +
    //     "    \"c_ts\": "+ cts +",\n" +
    //     "    \"c_idx\": 666,\n" +
    //     "    \"uid\": "+ uid +",\n" +
    //     "    \"language\": 2,\n" +
    //     "}"
    // 发送消息
    const msg = "{\n" +
        "    \"c\": 37,\n" +
        "    \"chips\": [\n" +
        "        [\n" +
        "            10,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0\n" +
        "        ],\n" +
        "        [\n" +
        "            10,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0\n" +
        "        ],\n" +
        "        [\n" +
        "            0,\n" +
        "            1,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0\n" +
        "        ],\n" +
        "        [\n" +
        "            0,\n" +
        "            3,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0\n" +
        "        ],\n" +
        "        [\n" +
        "            5,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0,\n" +
        "            0\n" +
        "        ]\n" +
        "    ],\n" +
        "    \"c_ts\": 1729669434085,\n" +
        "    \"c_idx\": 655,\n" +
        "    \"uid\": 13023,\n" +
        "    \"language\": 3\n" +
        "}"
    console.log("开始投注次数", i++)
    node_ws.send(msgToBuf(msg));
}

/**
 * 匹配
 */
function matchSess(node_ws, uid, gameid, ssid, deskid){
    const cts = Date.now()
    const msg = "{\n" +
        "    \"c\": 43,\n" +
        "    \"ssid\": "+ ssid +",\n" +
        "    \"gameid\": "+ gameid +",\n" +
        "    \"c_ts\":"+ cts +",\n" +
        "    \"c_idx\": 283,\n" +
        "    \"uid\": "+ uid +",\n" +
        "    \"language\": 2,\n" +
        "    \"deskid\": "+ deskid +"\n" +
        "}"
    console.log("发送匹配信息:", msg)
    // 发送消息
    node_ws.send(msgToBuf(msg));
}

// 创建桌子
function createDesk(node_ws, uid, gameid, ssid){
    const cts = Date.now()
    const msg = "{\n" +
        "    \"c\": 31,\n" +
        "    \"gameid\": "+ gameid +",\n" +
        "    \"c_ts\":"+ cts +",\n" +
        "    \"c_idx\": 26,\n" +
        "    \"uid\": "+ uid +",\n" +
        "    \"language\": 2,\n" +
        "    \"pwd\": 123456,\n" +
        "    \"conf\": {\"mincoin\": 5000.00, \"maxcoin\": 500000.00, \"param1\": 500.00, \"param2\": 1000.00, \"roomtype\": 1, \"round\": 6, \"name\": \"创建匹配房\", \"seat\": 9, \"score\": 500 }\n"+
        "}"
    console.log("发送创建桌子信息:", msg)
    // 发送消息
    node_ws.send(msgToBuf(msg));
}


function getUserInfo(node_ws, token, uid, subid){
    const cts = Date.now()
    const msg = "{\n" +
        "    \"c\": 2,\n" +
        "    \"uid\": "+ uid +",\n" +
        "    \"openid\": \"\",\n" +
        "    \"server\": \"node\",\n" +
        "    \"subid\": "+ subid +",\n" +
        "    \"token\": \""+ token +"\",\n" +
        "    \"deviceid\": \"0\",\n" +
        "    \"appver\": \"1.0.0\",\n" +
        "    \"app\": 17,\n" +
        "    \"bundleid\": \"com.pokerslotgame.play888\",\n" +
        "    \"v\": \"1.0.0.3\",\n" +
        "    \"c_ts\":"+ cts +",\n" +
        "    \"c_idx\": 1,\n" +
        "    \"language\": 3\n" +
        "}"
    // 发送消息
    node_ws.send(msgToBuf(msg));
}

function getUserInfoResponse(msg){
    console.log('登录node服，返回登录信息:', msg);
}

/**
 * 获取场次列表
 */
function getSessList(node_ws, uid, gameid){
    const msg = "{\n" +
        "    \"c\": 30,\n" +
        "    \"gameid\": "+ gameid +",\n" +
        "    \"c_ts\": 1724312852534,\n" +
        "    \"c_idx\": 23,\n" +
        "    \"uid\": "+ uid +",\n" +
        "    \"language\": 2\n" +
        "}"
    // 发送消息
    node_ws.send(msgToBuf(msg));
}

/**
 * 获取桌子列表
 */
function searchDesks(node_ws){
    const msg = "{\n" +
        "    \"c\": 64,\n" +
        "    \"c_ts\": 1724312852534,\n" +
        "    \"c_idx\": 23,\n" +
        "    \"language\": 2\n" +
        "}"
    // 发送消息
    node_ws.send(msgToBuf(msg));
}

/**
 * 获取桌子列表
 * @param node_ws
 * @param uid
 * @param gameid
 */
function getDesk(node_ws, uid, gameid){
    const msg = "{\n" +
        "    \"c\": 64,\n" +
        "    \"gameid\": "+ gameid +",\n" +
        "    \"c_ts\": 1724312852534,\n" +
        "    \"c_idx\": 23,\n" +
        "    \"uid\": "+ uid +",\n" +
        "    \"language\": 2\n" +
        "}"
    // 发送消息
    console.log('获取桌子列表协议:', msg)
    node_ws.send(msgToBuf(msg));
}


function getBetDesk(node_ws, uid, gameid){
    const msg = "{\n" +
        "    \"c\": 34,\n" +
        "    \"gameid\": "+ gameid +",\n" +
        "    \"c_ts\": 1724312852534,\n" +
        "    \"c_idx\": 23,\n" +
        "    \"uid\": "+ uid +",\n" +
        "    \"language\": 2\n" +
        "}"
    // 发送消息
    console.log('获取桌子列表协议:', msg)
    node_ws.send(msgToBuf(msg));
}

function getSessListResponse(msg){
    console.log('场次信息响应:', msg)
}

function getDeskResponse(node_ws,msg){
    console.log('房间响应:', msg)
    const deskinfo = msg.deskinfo
    const time = deskinfo.time
    console.log("延时", time, "秒进行下注")
    setTimeout(function () {
        // 投注
        bet(16, node_ws)
    }, time * 1000 + 500)

}

function getDeskListResponse(node_ws, msg){
    console.log('桌子列表响应:', msg)

    const ssid = msg.desks[0].deskid
    const deskid = msg.desks[0].deskid

    console.log(uid, '加入桌子', deskid)
    joinDeskById(node_ws, ssid, deskid, 293, uid)
}




function msgToBuf(message){
    // 打包消息
    const packedData = msgpack.encode(message);

    // 计算消息体大小
    const messageSize = Buffer.byteLength(packedData);

    // 创建消息头
    const head = Buffer.alloc(8);
    head.writeUInt16BE(messageSize, 0);  // 将消息体大小写入前 2 个字节

    // 生成校验和
    const body = Buffer.from(packedData);
    const checksum = genSum(body, Math.min(messageSize, 128));
    head.writeUInt16BE(checksum, 2);  // 将校验和写入第 3 和第 4 个字节

    // 时间戳（4 字节）
    const timestamp = Math.floor(Date.now() / 1000);  // 以秒为单位的时间戳
    head.writeUInt32BE(timestamp, 4);  // 将时间戳写入最后 4 个字节

    // 创建完整的消息
    return Buffer.concat([head, body])
}



// 生成校验和
function genSum(data, size) {
    let sum = 65535;
    for (let i = 0; i < size; i++) {
        const byte = data.readUInt8(i); // 读取数据的每个字节
        sum ^= byte;
        if ((sum & 1) === 0) {
            sum = sum >>> 1;
        } else {
            sum = (sum >>> 1) ^ 0x70B1;
        }
    }
    return sum & 0xffff; // 返回 2 字节的校验和
}

// 保持进程运行
process.stdin.resume();