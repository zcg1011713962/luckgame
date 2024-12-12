<?php
namespace EasySwoole\EasySwoole;

use EasySwoole\EasySwoole\AbstractInterface\Event;
use EasySwoole\EasySwoole\Swoole\EventRegister;
use App\Process\HotReload;
use EasySwoole\Http\Request;
use EasySwoole\Http\Response;
use \EasySwoole\Component\Pool\PoolManager;
use App\Utility\Pool\MysqlPool;
use EasySwoole\EasySwoole\Config;
use App\Utility\Pool\RedisPool;
use EasySwoole\EasySwoole\ServerManager;
use App\Utility\Pool\MysqlPoolAsync;
use EasySwoole\EasySwoole\Crontab\Crontab;
use App\Crontab\Minute5;
use App\Crontab\Minute30;
use App\Crontab\Day1;
use App\Crontab\Sec1;
use App\Crontab\Minute1;
use App\Crontab\Minute10;
use App\Crontab\Hour1;
use EasySwoole\Component\TableManager;
use Swoole\Table;
use App\Model\ModelAssemble;
use App\Process\CoinPlayerQueue;
use App\Process\GamePoolQueue;
use App\Process\GameLogQueue;
use App\Process\TpGameLogQueue;
use App\Process\GameEventQueue;

use App\Process\InnerPoolTaxQueue;
use App\Process\InnerPoolJpQueue;
use App\Process\InnerPoolNormalQueue;
use App\Process\UpdateGameState;


class EasySwooleEvent implements Event
{
    public static function initialize()
    {
        // TODO: Implement initialize() method.
        date_default_timezone_set('Asia/Ho_Chi_Minh');
    }
    
    public static function mainServerCreate(EventRegister $register)
    {
        // TODO: Implement mainServerCreate() method.
        
        $swooleServer = ServerManager::getInstance()->getSwooleServer();
        //$swooleServer->addProcess((new HotReload('HotReload', ['disableInotify' => false]))->getProcess());
        //队列处理
        $serverName = Config::getInstance()->getConf('SERVER_NAME');
//        for($i=1;$i<=3;$i++) {
//            $swooleServer->addProcess((new CoinPlayerQueue( $serverName. '.队列.玩家余额'.$i))->getProcess());
//            // $swooleServer->addProcess((new GamePoolQueue($serverName . '.队列.池子入款'.$i))->getProcess());
//        }
//        for($i=1;$i<=2;$i++) {
//
//            // $swooleServer->addProcess((new GameEventQueue($serverName . '.队列.池子出款' . $i))->getProcess());
//            $swooleServer->addProcess((new GameLogQueue($serverName . '.队列.游戏日志'. $i))->getProcess());
//
//            // $swooleServer->addProcess((new InnerPoolTaxQueue($serverName . '.队列.内部pool_tax落地'.$i))->getProcess());
//            // $swooleServer->addProcess((new InnerPoolJpQueue($serverName . '.队列.内部pool_jp落地'.$i))->getProcess());
//            // $swooleServer->addProcess((new InnerPoolNormalQueue($serverName . '.队列.内部pool_normal落地'.$i))->getProcess());
//        }

//        $swooleServer->addProcess((new UpdateGameState($serverName . '.队列.GameStat落地'))->getProcess());
        // $swooleServer->addProcess((new TpGameLogQueue($serverName . '.队列.第三方游戏日志'))->getProcess());
        //共享内存变量
        TableManager::getInstance()->add('table.mysql.tables', ['fields' => ['type' => Table::TYPE_STRING, 'size' => 1000]]);
        TableManager::getInstance()->add('table.redis.LuaSHa1s', ['sha1' => ['type' => Table::TYPE_STRING, 'size' => 50]]);
        
        //注册事件
        $register->add($register::onWorkerStart, function (\swoole_server $server, int $workerId) {
            if ($server->taskworker == false) {
                \EasySwoole\Component\Pool\PoolManager::getInstance()->getPool(MysqlPool::class)->preLoad();
                \EasySwoole\Component\Pool\PoolManager::getInstance()->getPool(RedisPool::class)->preLoad();
            } else {
                go(function() {
                    \EasySwoole\Component\Pool\PoolManager::getInstance()->getPool(MysqlPool::class)->preLoad();
                    \EasySwoole\Component\Pool\PoolManager::getInstance()->getPool(RedisPool::class)->preLoad();
                    \EasySwoole\Component\Pool\PoolManager::getInstance()->getPool(MysqlPoolAsync::class)->preLoad();
                });
            }
            
            if ($workerId == 1) {
                //缓存table.mysql.tables
                $model = new ModelAssemble();
                $model->getModels()->rediscli_model->setMysqlTableNameToTable();
                //缓存table.mysql.tables
                //if (! isset($model)) $model = new ModelAssemble();
                $model->getModels()->rediscli_model->loadLuaScript();
                $model = null;
            }
        });
        //添加crontab计划
        Crontab::getInstance()->addTask(Sec1::class)->addTask(Minute10::class);
    }
    
    public static function onRequest(Request $request, Response $response): bool
    {
        // TODO: Implement onRequest() method.
        return true;
    }
    
    public static function afterRequest(Request $request, Response $response): void
    {
        // TODO: Implement afterAction() method.
    }
}
