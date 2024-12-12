/**
 * express
 */
const express = require('express');
const app = express();
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
app.use((req, res, next) => {
    if (req.headers['content-encoding'] && req.headers['content-encoding'].toLowerCase() === 'utf-8') {
        delete req.headers['content-encoding'];
    }
    next();
    // 检查是否是 text/plain 并且编码是 utf-8
    // if (req.headers['content-type'] === 'text/plain; charset=utf-8') {
    //     let data = '';
    //     req.setEncoding('utf8');
    //     req.on('data', chunk => {
    //         data += chunk;
    //     });
    //     req.on('end', () => {
    //         req.body = data;
    //         next();
    //     });
    // } else {
    //     next();
    // }
});
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended: false}));
let session = require('express-session');
const FileStore = require('session-file-store')(session);
app.use(
    session({
        store: new FileStore(), // 使用文件存储
        secret: 'redg2trhb1ytnefr323hnh5secret',
        resave: false,
        saveUninitialized: true,
        cookie: {maxAge: 24 * 60 * 60 * 1000}
    })
);
({
    init: function () {
        this._initApp();
        this._initMiddleware();
        this._initRouter();
        this._initStatic();
        this._initTemplate();
        this._initI18N(APP_ROOT + "/common/lang", '.json');
        this._initError();
    },
    _initApp() {
        //初始化一些全局函数
        global.success = (data = {}, msg = 'ok', code = 0) => {
            return {code: code, msg: L(msg), data};
        };
        global.errors = (msg = 'some error occurred', data = {}, code = -1) => {
            return {code: code, msg: L(msg), data}
        };
    },
    _initMiddleware() {
        //初始化中间件
        let middlewareList = fs.readdirSync(APP_ROOT + '/middleware');
        middlewareList = middlewareList.filter(name => name.toString().includes('.js'));
        if (middlewareList.length > 0) {
            middlewareList = middlewareList.map(item => item.substring(0, item.indexOf('.')));
            for (let filename of middlewareList) {
                app.use(require(`${APP_ROOT}/middleware/${filename}`));
            }
        }
    },
    _initRouter() {
        //初始化路由
        let routerList = fs.readdirSync(APP_ROOT + '/router');
        routerList = routerList.filter(name => name.toString().includes('.js'));
        if (routerList.length > 0) {
            routerList = routerList.map(item => item.substring(0, item.indexOf('.')));
            for (let filename of routerList) {
                if (filename === 'index') {
                    app.use(`/`, require(`${APP_ROOT}/router/${filename}`));
                } else {
                    app.use(`/${filename}`, require(`${APP_ROOT}/router/${filename}`));
                }
            }
        }
        const routerDirs = ['callback', 'backend'];
        for (let item of routerDirs) {
            let cbList = fs.readdirSync(`${APP_ROOT}/router/${item}`);
            cbList = cbList.filter(name => name.toString().includes('.js'));
            if (cbList.length > 0) {
                cbList = cbList.map(item => item.substring(0, item.indexOf('.')));
                for (let filename of cbList) {
                    app.use(`/${item}/${filename}`, require(`${APP_ROOT}/router/${item}/${filename}`));
                }
            }
        }
    },
    _initStatic: function () {
        if (!config.staticConfig || !config.staticConfig.length) {
            app.use('/static', express.static('static'));
        } else {
            config.staticConfig.forEach(function (item, index, array) {
                app.use(item.router, express.static(`${APP_ROOT}/${item.path}`, {index: item.index ? item.index : 'index.html'}));
            });
        }
    },
    _initTemplate: function () {
        let tplPath = path.join(APP_ROOT, (config.templateConfig && config.templateConfig.viewsPath) ? (config.templateConfig.viewsPath) : 'views');
        let useCache = (config.templateConfig && config.templateConfig.useCache) ? config.templateConfig.useCache : false;
        let viewEngine = (config.templateConfig && config.templateConfig.viewEngine) ? config.templateConfig.viewEngine : 'artTemplate';
        let defaultTplExt = (config.templateConfig && config.templateConfig.extName) ? config.templateConfig.extName : '.html';
        let encoding = (config.templateConfig && config.templateConfig.encoding) ? config.templateConfig.encoding : 'utf-8';
        switch (viewEngine) {
            case 'artTemplate': {
                app.engine(defaultTplExt.replace(".", ""), require('express-art-template'));
                app.set('view options', {
                    base: '',
                    debug: true,
                    extname: defaultTplExt,
                    engine: defaultTplExt,
                    cache: useCache,
                    // views: `${APP_ROOT}/views`,
                    'encoding': encoding,
                });
                app.set('views', tplPath);
                app.set('view engine', defaultTplExt);
                global.renderToHtml = (view, data) => {
                    let template = require('art-template');
                    let parseFile = path.join(process.cwd(), 'views', view + defaultTplExt)
                    return template(parseFile, data);
                };
            }
        }
    },
    _initI18N(i18nPath, ext) {
        //国际化
        const locales = [];
        let files = fs.readdirSync(i18nPath);
        files.forEach(function (fileName, index) {
            if (fileName.lastIndexOf('.json') !== -1) {
                let i18nName = (fileName.indexOf('.') == -1) ? fileName : fileName.split('.')[0];
                locales.push(i18nName);
            }
        });
        if (locales.length > 0) {
            let i18n = require('i18n');
            i18n.configure({
                locales: locales,
                defaultLocale: 'en-US',
                directory: i18nPath,
                updateFiles: false,
                extension: ext,
                logDebugFn: function (msg) {
                    // console.log('debug', msg);
                },
                logWarnFn: function (msg) {
                    // console.log('warn', msg);
                },
                logErrorFn: function (msg) {
                    // console.log('error', msg);
                }
            });
            app.use(i18n.init);
            global.setLocale = (local) => {
                i18n.setLocale(local);
            };
            global.L = (...args) => i18n.__(...args);
        }
    },
    _initError() {
        //捕获异常
        app.use(function (req, res, next) {
            var err = new Error('500: server exception!');
            err.status = 500;
            next(err);
        });
        //错误处理
        app.use(function (err, req, res, next) {
            res.locals.message = err.message;
            res.locals.error = err;
            res.status(err.status || 500);
            res.json({
                code: err.status,
                msg: err.message
            });
        });
        //捕获promise reject错误
        process.on('unhandledRejection', (error, promise) => {
            console.log(error);
            console.error(error.toString());
        });
    }
}).init();
module.exports = app;

