const WebSocket = require("ws");
const wsMap = new Map()

class Loginws {
    constructor(userId) {
        this.ws = new WebSocket('ws://192.168.127.131:9951/ws');
        this.userId = userId
        wsMap.set(userId, this.ws)
    }

    getWsByUserId(userId){
        return wsMap.get(userId)
    }

    getWS(){
        return this.ws
    }

    getUserId(){
        return this.userId
    }
}

module.exports = Loginws