<?php
namespace App\Crontab;

use EasySwoole\EasySwoole\Crontab\AbstractCronTask;
use App\Crontab\CronDB;
use App\Utility\Helper;
use App\Model\Constants\MysqlTables;
use App\Utility\MDB;
use App\Utility\RDB;
use App\Model\Constants\RedisKey;

class Day1 extends AbstractCronTask
{
    use CronDB;
    
    public static function getRule(): string
    {
        // TODO: Implement getRule() method.
        return '@daily';
    }
    
    public static function getTaskName(): string
    {
        // TODO: Implement getTaskName() method.
        // 定时任务名称
        return '获取统计：每天';
    }
    
    static function run(\swoole_server $server, int $taskId, int $fromWorkerId, $flags = null)
    {
        // TODO: Implement run() method.
        // 定时任务处理逻辑
        
        swoole_timer_after(1, function() {
            $mysql = new MDB();
            $_newd = [];
            $_newd['date'] = date("Y-m-d", time()-60);
            $_d_s = $mysql->getDb()->rawQuery("SELECT SUM(IF(type=1,coin,0)) as outcoin,-1*SUM(IF(type=2,coin,0)) as incoin FROM ".MysqlTables::SCORE_LOG." WHERE agent=2")[0];
            $_newd['sysout'] = isset($_d_s['outcoin']) ? Helper::format_money($_d_s['outcoin']) : Helper::format_money(0);
            $_newd['sysin'] = isset($_d_s['incoin']) ? Helper::format_money($_d_s['incoin']) : Helper::format_money(0);
            $_d_s1 = $mysql->getDb()->rawQuery("SELECT SUM(IF(agent=0,coin,0)) as playercoin,SUM(IF(agent=1 OR agent=2,coin,0)) as agentcoin FROM ".MysqlTables::ACCOUNT." WHERE agent IN (0,1,2)")[0];
            $_newd['player'] = isset($_d_s1['playercoin']) ? Helper::format_money($_d_s1['playercoin']) : Helper::format_money(0);
            $_newd['agent'] = isset($_d_s1['agentcoin']) ? Helper::format_money($_d_s1['agentcoin']) : Helper::format_money(0);
            $_newd['syswin'] = $_newd['sysout'] - $_newd['sysin'] - $_newd['player'] - $_newd['agent'];
            $mysql->getDb()->insert(MysqlTables::STAT_SYSWIN, $_newd);
        });
        
        swoole_timer_after(1, function() {
            $mysql = new MDB();
            $_newd = [];
            $startTime = strtotime(date('Y-m-d', strtotime('-1 day')));
            $endTime = $startTime + 86400;
            $mainpoll = $mysql->getDb()->where("(create_time BETWEEN {$startTime} AND {$endTime})")
            ->whereIn('type', [1, 2])->groupBy('game_id')
            ->get(MysqlTables::POOL_NORMAL, null, "game_id,SUM(coin) AS coin");
            if ($mainpoll) {
                $mainpoll = array_column($mainpoll, 'coin', 'game_id');
            }
            $mainpoll[0] = array_sum($mainpoll); // 总库存
            foreach ($mainpoll as &$one) {
                $one = substr(sprintf("%.3f",$one), 0, -1);
            }
            $_newd['dtime'] = $startTime;
            $_newd['data'] = json_encode($mainpoll, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
            $mysql->getDb()->insert(MysqlTables::STAT_MAINPOLL, $_newd);
        });
    }
}