const WebSocket = require("ws");
const wsMap = new Map()

class Nodews {
    constructor(userId, nodeAddress) {
        this.ws = new WebSocket('ws://'+ nodeAddress +'/ws');
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

module.exports = Nodews