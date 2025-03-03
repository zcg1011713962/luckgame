<?php
namespace App\Utility\ConsoleCommand;

use EasySwoole\EasySwoole\Config;
use EasySwoole\EasySwoole\Console\ModuleInterface;
use EasySwoole\Socket\Bean\Caller;
use EasySwoole\Socket\Bean\Response;

class TrackerLogCategory implements ModuleInterface
{
    public function moduleName(): string
    {
        // TODO: Implement moduleName() method.
        return 'category';
    }

    public function exec(Caller $caller, Response $response)
    {
        // TODO: Implement exec() method.

        $args = $caller->getArgs();

        if (empty($args)) {
            // 如果不传入参数 则获取当前的设置项
            $category = Config::getInstance()->getDynamicConf('TrackerLogCategory');
            if (!$category) {
                $response->setMessage('no category is set up.');
            } else {
                $response->setMessage('current category set : ' . implode('|', $category));
            }
        } else {
            // 如果传入了参数 则参数为需要监听的分类 all 则监听全部
            if (in_array('all', $args)) {
                $args = [ 'all' ];
            }
            Config::getInstance()->setDynamicConf('CONSOLE.TRACKER_LOG_CATEGORY', $args);
            $response->setMessage('set category success.');
        }
    }

    public function help(Caller $caller, Response $response)
    {
        // TODO: Implement help() method.
        
        $help = <<<HELP
用法 : TrackerLogCategory [categoryName...]

参数 : categoryName 需要监听的分类,可以填写多个,用空格隔开
不带参数返回当前监听的分类
HELP;
        return $help;
    }
}