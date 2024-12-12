<?php
namespace App\Crontab;

use EasySwoole\EasySwoole\Crontab\AbstractCronTask;
use App\Crontab\CronDB;
use App\Utility\Helper;
use App\Model\Constants\MysqlTables;
use App\Model\Curl;
use App\Utility\MDB;

class Minute30 extends AbstractCronTask
{
    use CronDB;
    
    public static function getRule(): string
    {
        // TODO: Implement getRule() method.
        return '*/30 * * * *';
    }
    
    public static function getTaskName(): string
    {
        // TODO: Implement getTaskName() method.
        // 定时任务名称
        return '获取统计：每30分钟';
    }
    
    static function run(\swoole_server $server, int $taskId, int $fromWorkerId, $flags = null)
    {
        // TODO: Implement run() method.
        // 定时任务处理逻辑
        
        /**
         * 报表
         * 30分钟
         * 所有玩家余额总额
         */
        swoole_timer_after(1, function() {
            $mysql = new MDB();
            $_newd = [];
            $_newd['datetime'] = date("Y-m-d H:i:00");
            $_coin = $mysql->getDb()->where('agent', 0)->sum(MysqlTables::ACCOUNT, 'coin');
            $_newd['coin'] = $_coin ? Helper::format_money($_coin) : Helper::format_money(0);
            $mysql->getDb()->insert(MysqlTables::STAT_COIN_PLAYER, $_newd);
        });
        
        /**
         * 报表
         * 30分钟
         * 玩家在线人数
         */
        swoole_timer_after(1, function() {
            $mysql = new MDB();
            $curl = new Curl();
            $_newd = [];
            $_num = (int)$curl->getStatServerOnlineTotal();
            $_newd['datetime'] = date("Y-m-d H:i:00");
            $_newd['count'] = $_num;
            $mysql->getDb()->insert(MysqlTables::STAT_ONLINE_PLAYER, $_newd);
        });
    }
}