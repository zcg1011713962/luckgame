<?php
namespace App\Process;

use App\Model\Constants\MysqlTables;
use App\Utility\MDB;
use EasySwoole\Component\Process\AbstractProcess;
use Swoole\Process;
use EasySwoole\EasySwoole\Config;
use EasySwoole\Utility\Random;
use App\Model\Constants\RedisKey;
use EasySwoole\EasySwoole\Logger;
use App\Model\ModelAssemble;

//将gamestate的数据 从redis 更新到数据库
class UpdateGameState extends AbstractProcess
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
                    $this->addTick(5000, function () use (&$isRestSystemSetting, &$isRun, &$redis) {
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
                            $mysql = new MDB();
                            $_games = $model->getModels()->curl_model->getGameLists(1);
                            foreach ($_games as $g) {
                                $num_betofplayer = $model->getModels()->rediscli_model->getDb()->getSet('num_betofplayer_'.$g['id'], 0);
                                $num_betfullofplayer = $model->getModels()->rediscli_model->getDb()->getSet('num_betfullofplayer_'.$g['id'], 0);
                                $amount_bet = $model->getModels()->rediscli_model->getDb()->getSet('amount_bet_'.$g['id'], 0);
                                $amount_betfull = $model->getModels()->rediscli_model->getDb()->getSet('amount_betfull_'.$g['id'], 0);

                                $amount_payout = $model->getModels()->rediscli_model->getDb()->getSet('amount_payout_'.$g['id'], 0);
                                $amount_betfullpayout = $model->getModels()->rediscli_model->getDb()->getSet('amount_betfullpayout_'.$g['id'], 0);

                                $num_betofplayer = $num_betofplayer ?? 0;
                                $num_betfullofplayer = $num_betfullofplayer ?? 0;
                                
                                $amount_bet = $amount_bet ?? 0;
                                $amount_betfull = $amount_betfull ?? 0;

                                $amount_payout = $amount_payout ?? 0;
                                $amount_betfullpayout = $amount_betfullpayout ?? 0;


                                if (! $mysql->getDb()->where('game_id', $g['id'])->has(MysqlTables::STAT_GAMES)) {
                                    $mysql->getDb()->insert(MysqlTables::STAT_GAMES, [
                                        'game_id'=> $g['id'],
                                        'num_favorite'=> '0',
                                        'num_betofplayer'      => $num_betofplayer,
                                        'num_betfullofplayer'  => $num_betfullofplayer,
                                        'amount_bet'           => $amount_bet,
                                        'amount_betfull'       => $amount_betfull,
                                        'amount_payout'        => $amount_payout,
                                        'amount_betfullpayout' => $amount_betfullpayout
                                    ]);
                                } else {
                                    $sql = "update " . MysqlTables::STAT_GAMES . " set num_betofplayer=num_betofplayer+{$num_betofplayer},
                                        num_betfullofplayer=num_betfullofplayer+{$num_betfullofplayer},
                                        amount_bet=amount_bet+{$amount_bet},
                                        amount_betfull=amount_betfull+{$amount_betfull},
                                        amount_payout=amount_payout+{$amount_payout},
                                        amount_betfullpayout=amount_betfullpayout+{$amount_betfullpayout}
                                        where game_id={$g['id']}";

                                    $model->getModels()->finance_model->exeSql($sql);
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