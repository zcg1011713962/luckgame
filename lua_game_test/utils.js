const msgpack = require("msgpack-lite");


function login(ws, msg){
    ws.send(msgToBuf(msg));
}


function loginResponse(msg){
    // 登录响应
    if(!msg.spcode && msg.code === 200) {
        // 登录成功
        // console.log('登录成功', msg)
        const nodeAddress = msg.net
        const token = msg.token
        const uid = msg.uid
        const subid = msg.subid
        return {
            nodeAddress : nodeAddress,
            token: token,
            uid: uid,
            subid: subid
        }
    }
    return {}
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
    return msg.code === 200;
}



function matchSess(node_ws, uid, gameid, ssid, lang){
    const cts = Date.now()
    const msg = "{\n" +
        "    \"c\": 43,\n" +
        "    \"ssid\": "+ ssid +",\n" +
        "    \"gameid\": "+ gameid +",\n" +
        "    \"c_ts\":"+ cts +",\n" +
        "    \"c_idx\": 26,\n" +
        "    \"uid\": "+ uid +",\n" +
        "    \"language\": "+ lang +"\n" +
        "}"
    // 发送消息
    node_ws.send(msgToBuf(msg));
}


function slotBet(node_ws, uid, betIndex, lang){
    const cts = Date.now()
    const msg = "{\n" +
        "    \"c\": 44,\n" +
        "    \"betIndex\": "+ betIndex +",\n" +
        "    \"c_ts\":"+ cts +",\n" +
        "    \"c_idx\": 41,\n" +
        "    \"uid\": "+ uid +",\n" +
        "    \"language\": "+ lang +"\n" +
        "}"
    // 发送消息
    node_ws.send(msgToBuf(msg));
}

function slotBetResponse(msg){
    return msg.code === 200;
}

function getDeskResponse(node_ws,msg){
    return msg.code === 200;
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

module.exports = {
    login,
    loginResponse,
    getUserInfo,
    getUserInfoResponse,
    matchSess,
    getDeskResponse,
    slotBet,
    slotBetResponse
}