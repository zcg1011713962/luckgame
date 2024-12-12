<?php
namespace App\Process;

use EasySwoole\Component\Process\AbstractProcess;
use Swoole\Process;
use EasySwoole\EasySwoole\Config;
use EasySwoole\Utility\Random;
use App\Model\Constants\RedisKey;
use EasySwoole\EasySwoole\Logger;
use App\Model\ModelAssemble;

class GameEventQueue extends AbstractProcess
{
    public function run($arg)
    {
        // TODO: Implement run() method.
        
        //是否运行
        $isRun = false;
        //redis连接
        $redis = new \Redis();
        $conf = Config::getInstance()->getConf('REDIS');
        //尝试创建连接
        if ($redis->connect($conf['host'], $conf['port'])) {
            //验证
            if (!empty($conf['auth'])) {
                $redis->auth($conf['auth']);
            }
            //选择db
            if (isset($conf['db']) && !empty($conf['db'])) {
                $redis->select($conf['db']);
            }
            try {
                //查看服务是否运行
                if (in_array($redis->ping(), ['PONG','+PONG'])) {
                    $this->addTick(500, function () use (&$isRun, &$redis) {
                        $model = new ModelAssemble();
                        if (! $isRun) {
                            $isRun = true;
                            //取队列数据
                            while (true) {
                                $_r = $redis->evaluateSha(
                                    $model->getModels()->rediscli_model->getLuaSha1s('_luascript_queue_coin_player'),
                                    [
                                        RedisKey::LOGS_GEVENT,
                                        RedisKey::LOGS_GEVENT_HISTORY,
                                        time() . Random::number(5)
                                    ],
                                    2
                                );
                                if (! (isset($_r[0]) && $_r[0])) {
                                    //目前队列为空
                                    break;
                                }
                                //游戏日志
                                if (isset($_r[0]) && $_r[0]) {
                                    $_httplogstr = is_string($_r[0]) ? $_r[0] : var_export($_r[0], true);
                                    Logger::getInstance()->log($_httplogstr, 'queue-gevent');
                                    $model->getModels()->finance_model->postPlayerGameEvent($_r[0]);
                                }
                            }
                            $isRun = false;
                        }
                        $model->__destruct();
                    });
                } else {
                    echo "[×] >>> Redis Error >>> " . $this->getProcessName() . PHP_EOL . "PING 失败" . PHP_EOL;
                }
            } catch (\Throwable $throwable) {
                echo "[×] >>> Redis Error >>> " . $this->getProcessName() . PHP_EOL . $throwable->getMessage() . PHP_EOL;
            }
        } else {
            echo "[×] >>> Redis Error >>> " . $this->getProcessName() . PHP_EOL . "无法创建连接" . PHP_EOL;
        }
    }
    
    public function onShutDown()
    {
        // TODO: Implement onShutDown() method.
        echo "BillQueue process is onShutDown." . PHP_EOL;
    }
    
    public function onReceive(string $str)
    {
        // TODO: Implement onReceive() method.
        echo "BillQueue process is onReceive." . PHP_EOL;
    }
}