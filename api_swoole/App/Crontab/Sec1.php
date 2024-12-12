<?php
namespace App\Crontab;

use EasySwoole\EasySwoole\Crontab\AbstractCronTask;
use App\Crontab\CronDB;
use App\Model\Constants\MysqlTables;
use App\Model\Curl;
use App\Utility\MDB;
use App\Model\ModelAssemble;
use EasySwoole\EasySwoole\Logger;

class Sec1 extends AbstractCronTask
{
    use CronDB;
    
    public static function getRule(): string
    {
        // TODO: Implement getRule() method.
        return '*/1 * * * *';
    }
    
    public static function getTaskName(): string
    {
        // TODO: Implement getTaskName() method.
        // 定时任务名称
        return 'Sec1';
    }
    
    static function run(\swoole_server $server, int $taskId, int $fromWorkerId, $flags = null)
    {
        // TODO: Implement run() method.
        // 定时任务处理逻辑

        for ($i = 1; $i < 61; $i++) {
            swoole_timer_after($i*1000, function() {
                $time = time();
                $_mysql = new MDB();
                $_curl = new Curl();
                $list = $_mysql->getDb()->where('next_time', $time)->where('status', 0)->get(MysqlTables::SYS_ROLLINGNOTICE);
                echo date('Y-m-d H:i:s', $time) . ' count:'.count($list) .PHP_EOL;
                foreach ($list as $row) {
                    $data = [
                        'data' => [$row['content'], $row['contenten']]
                    ];
                    $res = $_curl->pushSystemsettingNoticeRolling($data);
                    echo PHP_EOL;
                    var_dump($res);
                    echo PHP_EOL;
                    // 更新下次发送时间
                    if (($row['next_time'] - $row['start_time']) < (($row['counts'] - 1) * $row['interval'] * 60)) {
                        $_mysql->getDb()->where('id', $row['id'])->update(MysqlTables::SYS_ROLLINGNOTICE, ['next_time' => ($row['next_time'] + $row['interval'] * 60)]);
                    }
                }
            });
        }
    }
}
