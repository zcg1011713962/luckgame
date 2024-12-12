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

//正常彩池
class InnerPoolNormalQueue extends AbstractProcess
{
    public function run($arg)
    {
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

                            $sql_prefix   = 'insert into '. MysqlTables::POOL_NORMAL. '(log_id, account_id,game_id,`type`,coin,create_time) values ';
                            $sql          = '';
                            $batch_insert = 0;
                            //取队列数据
                            while (true) {
                                $_r = $redis->evaluateSha(
                                    $model->getModels()->rediscli_model->getLuaSha1s('_luascript_inner_queue'),
                                    [
                                        RedisKey::LOGS_INNER_POOL_NORMAL,
                                        RedisKey::LOGS_INNER_POOL_NORMAL_HISTORY,
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
                                    Logger::getInstance()->log($_httplogstr, 'queue-pool-normal');

                                    $_logs = json_decode($_r[0], true);
                                    if($_logs) {
                                        $sql .= " ({$_logs['log_id']},'{$_logs['account_id']}',{$_logs['game_id']},{$_logs['type']}, {$_logs['coin']}, {$_logs['create_time']}),";
                                        $batch_insert++;
                                        if($batch_insert % 50 == 0) {
                                            $sql = substr( $sql,0, strlen($sql)-1 );
                                            Logger::getInstance()->log($sql_prefix . $sql . "\r\n", 'queue-pool-jp-normal');
                                            $model->getModels()->finance_model->exeSql($sql_prefix . $sql);
                                            $batch_insert = 0;
                                            $sql = '';
                                        }
                                    }
                                }
                            }
                            if(!empty($sql)) {
                                $sql = substr( $sql,0, strlen($sql)-1 );
                                Logger::getInstance()->log($sql_prefix . $sql . "\r\n", 'queue-pool-jp-normal');
                                $model->getModels()->finance_model->exeSql($sql_prefix . $sql);
                                $batch_insert = 0;
                                $sql = '';
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