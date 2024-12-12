'use strict';
/** 启动页面 */
//根路径
global.APP_ROOT = __dirname;
//全局常量定义
global.Const = require('./common/const');
//全局配置项
global.config = require('./config/config');
//全局公共函数
global.funcs = require('./common/funcs');
//express
const app = require('./core/express');
//debug
const debug = require('debug')('express:server');
//http
const http = require('http');
//path
const path = require('path');
//cluster
const cluster = require('cluster');
//port
const ports = config.port || 7000;
//启动http服务
const scriptName = path.parse(__filename).name;
const appRoot = path.parse(path.parse(path.parse(__filename).dir).dir).name;
if (cluster.isPrimary) {
    let numCPUs = require('os').cpus().length;
    console.log("Run Master Process......");
    // Fork workers.
    for (let i = 0; i < numCPUs; i++) {
        cluster.fork();
    }
    cluster.on('listening', function (worker, address) {
        console.log('Run Worker ' + worker.process.pid + ', Port:' + address.port);
    });
    cluster.on('exit', function (worker, code, signal) {
        console.log('Worker ' + worker.process.pid + ' Exited');
    });
    process.title = `${appRoot} Master Manager Process `;
} else {
    //server port
    var port = normalizePort(ports);
    app.set('port', port);
    var server = http.createServer(app);
    server.listen(port, '0.0.0.0');
    server.on('error', onError);
    server.on('listening', onListening);
    process.title = `${appRoot} Worker Process ${scriptName}`;
}

/**
 * port convert
 * @param val
 * @returns {*}
 */
function normalizePort(val) {
    const port = parseInt(val, 10);
    if (isNaN(port)) {
        return val;
    }
    if (port >= 0) {
        return port;
    }
    return false;
}

/**
 *
 * Normalize a port into a number, string, or false.
 * @param error
 */
function onError(error) {
    if (error.syscall !== 'listen') {
        throw error;
    }
    const bind = typeof port === 'string'
        ? 'Pipe ' + port
        : 'Port ' + port;
    // handle specific listen errors with friendly messages
    switch (error.code) {
        case 'EACCES':
            console.error(bind + ' requires elevated privileges');
            process.exit(1);
            break;
        case 'EADDRINUSE':
            process.exit(1);
            break;
        default:
            throw error;
    }
}

/**
 * Event listener for HTTP server "listening" event.
 */
function onListening() {
    const addr = server.address();
    const bind = typeof addr === 'string'
        ? 'pipe ' + addr
        : 'port ' + addr.port;
    debug('Express Listening on ' + bind);
}
