/**
 * 模板引擎配置文件
 * FileName: template.js
 * Date:2023/02/11
 */

module.exports = {
    //模板引擎配置
    templateConfig: {
        viewsPath: 'views',
        useCache: false,
        viewEngine: 'artTemplate',
        extName: '.html',
        encoding: 'utf8'
    },
    //静态目录配置
    staticConfig: [
        {
            router: '/',
            path: 'public',
            index: 'index.html'
        }
    ],
};