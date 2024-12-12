<?php
namespace App\Process;

use App\Model\Constants\MysqlTables;
use EasySwoole\Component\Process\AbstractProcess;
use Swoole\Process;
use EasySwoole\EasySwoole\Config;
use EasySwoole\Utility\Random;
use App\Model\Constants\RedisKey;
use EasySwoole\EasySwoole\Logger;
use App\Model\ModelAssemble;

class CoinPlayerQueue extends AbstractProcess
{
    public function run($arg)
    {
        // TODO: Implement run() method.
        //是否重置系统参数
        $isRestSystemSetting = false;
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
                    $this->addTick(500, function () use (&$isRestSystemSetting, &$isRun, &$redis) {
                        $model = new ModelAssemble();
                        if (! $isRestSystemSetting) {
                            if ($model->getModels()->system_model->_resetRedisSystemParameters()) {
                                $isRestSystemSetting = true;
                                echo "[√] 重置系统参数成功" . PHP_EOL;
                            } else {
                                $isRun = true;
                                echo "[×] >>> 重置系统参数失败 >>>" . PHP_EOL;
                            }
                        }
                        if (! $isRun) {
                            $isRun = true;
                            $sql_prefix   = 'insert into '. MysqlTables::COINS_PLAYER. '(account_id,`type`,game_id,`before`,coin,`after`,altercoin_id,game_timestamp,create_time,game_identification,`desc`, log_id) values ';
                            $sql          = '';
                            $batch_insert = 0;
                            //取队列数据
                            while (true) {
                                $_r = $redis->evaluateSha(
                                    $model->getModels()->rediscli_model->getLuaSha1s('_luascript_queue_coin_player'),
                                    [
                                        RedisKey::LOGS_COINS_PLAYER,
                                        RedisKey::LOGS_COINS_PLAYER_HISTORY, //玩家金币修改队列
                                        time() . Random::number(5)
                                    ],
                                    2
                                );
                                if (! (isset($_r[0]) && $_r[0])) {
                                    //目前队列为空
                                    break;
                                }
                                //用户余额
                                if (isset($_r[0]) && $_r[0]) {
                                    $_httplogstr = is_string($_r[0]) ? $_r[0] : var_export($_r[0], true);
                                    Logger::getInstance()->log($_httplogstr, 'queue-coins-player');

                                    $_logs = json_decode($_r[0], true);
                                    if($_logs) {
                                        $now = time();
                                        $sql .= " ('{$_logs['account_id']}',{$_logs['type']},{$_logs['game_id']}, {$_logs['before']}, {$_logs['coin']}, {$_logs['after']},{$_logs['altercoin_id']},{$_logs['game_timestamp']},{$now},{$_logs['game_identification']},'{$_logs['desc']}',{$_logs['log_id']}),";
                                        $batch_insert++;
                                        if($batch_insert % 50 == 0) {
                                            $sql = substr( $sql,0, strlen($sql)-1 );
                                            Logger::getInstance()->log($sql_prefix . $sql . "\r\n", 'queue-coins-player-test-sql');
                                            $model->getModels()->finance_model->exeSql($sql_prefix . $sql);
                                            $batch_insert = 0;
                                            $sql = '';
                                        }
                                        $model->getModels()->finance_model->postCoinsPlayer($_logs);
                                    }
                                }
                            }
                            if(!empty($sql)) {
                                $sql = substr( $sql,0, strlen($sql)-1 );
                                Logger::getInstance()->log($sql_prefix . $sql . "\r\n", 'queue-coins-player-test-sql2');
                                $model->getModels()->finance_model->exeSql($sql_prefix . $sql);

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