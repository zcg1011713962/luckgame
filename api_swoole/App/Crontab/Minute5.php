<?php
namespace App\Crontab;

use EasySwoole\EasySwoole\Crontab\AbstractCronTask;
use App\Crontab\CronDB;
use App\Model\Constants\RedisKey;
use App\Model\Constants\MysqlTables;
use App\Utility\Helper;
use App\Model\Curl;
use App\Utility\MDB;
use App\Utility\RDB;
use App\Model\ModelAssemble;
use EasySwoole\EasySwoole\Config;

class Minute5 extends AbstractCronTask
{
    use CronDB;
    
    public static function getRule(): string
    {
        // TODO: Implement getRule() method.
        return '*/5 * * * *';
    }
    
    public static function getTaskName(): string
    {
        // TODO: Implement getTaskName() method.
        // 定时任务名称
        return '获取统计：每5分钟';
    }
    
    static function run(\swoole_server $server, int $taskId, int $fromWorkerId, $flags = null)
    {
        // TODO: Implement run() method.
        // 定时任务处理逻辑
        
        /**
         * 报表
         * 5分钟
         * 彩池库存
         */
        swoole_timer_after(1, function() {
            $mysql = new MDB();
            $redis = new RDB();
            $_newd = [];
            $_newd['datetime'] = date("Y-m-d H:i:00");
            $_newd['coin'] = $redis->getDb()->get(RedisKey::SYSTEM_BALANCE_POOLNORMAL);
            $mysql->getDb()->insert(MysqlTables::STAT_POOL_NORMAL, $_newd);
        });
        
        /**
         * 报表
         * 5分钟
         * JP池库存
         */
        swoole_timer_after(1, function() {
            $mysql = new MDB();
            $redis = new RDB();
            $_system_setting = Helper::is_json_str($redis->getDb()->get(RedisKey::SYSTEM_SETTING));
            $_newd = [];
            $_newd['datetime'] = date("Y-m-d H:i:00");
            $_newd['coin'] = $redis->getDb()->get(RedisKey::SYSTEM_BALANCE_POOLJP);
            $_newd['outline'] = isset($_system_setting['pool_jp_outline']) ? $_system_setting['pool_jp_outline'] : "0.00";
            $mysql->getDb()->insert(MysqlTables::STAT_POOL_JP, $_newd);
        });
        
        /**
         * 报表
         * 5分钟
         * TAX池库存
         */
        swoole_timer_after(1, function() {
            $mysql = new MDB();
            $redis = new RDB();
            $_system_setting = Helper::is_json_str($redis->getDb()->get(RedisKey::SYSTEM_SETTING));
            $_newd = [];
            $_newd['datetime'] = date("Y-m-d H:i:00");
            $_newd['coin'] = !! ($__TAX_LAST = $redis->getDb()->get(RedisKey::SYSTEM_BALANCE_TAX_LAST)) && Helper::format_money((string)$__TAX_LAST) > Helper::format_money('0') ? Helper::format_money((string)$__TAX_LAST) : Helper::format_money((string)$redis->getDb()->get(RedisKey::SYSTEM_BALANCE_TAX_NOW));
            $_newd['limitup'] = isset($_system_setting['pool_tax_limitup']) ? $_system_setting['pool_tax_limitup'] : "0.00";
            $mysql->getDb()->insert(MysqlTables::STAT_POOL_TAX, $_newd);
        });
        
        /**
         * 报表
         * 5分钟
         * 玩家在线人数
         */
        swoole_timer_after(1, function() {
            $mysql = new MDB();
            $curl = new Curl();
            $_newd = [];
            $_r = $curl->getStatServerGameOnline('-1');
            $_ds = [];
            if (is_array($_r) && $_r && count($_r) > 0) {
                foreach ($_r as $_g) {
                    $_ds[(int)$_g['gameid']] = (int)$_g['onlinenum'];
                }
                $_newd['datetime'] = date("Y-m-d H:i:00");
                $_newd['counts'] = json_encode($_ds, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
                $mysql->getDb()->insert(MysqlTables::STAT_ONLINE_GAME, $_newd);
            }
        });
        
        /**
         * 下注次数
         * 5分钟
         */
        swoole_timer_after(1, function() {
            $mysql = new MDB();
            $_newd = [];
            $endTime = time();
            $startTime = $endTime - 300;
            $betNums = $mysql->getDb()->where('create_time', [$startTime, $endTime], 'BETWEEN')
            ->where('type', 3)
            ->groupBy('game_id')
            ->get(MysqlTables::COINS_PLAYER, null, 'game_id, COUNT(1) AS nums');
            if ($betNums) {
                $betNums = array_column($betNums, 'nums', 'game_id');
            }
            $_newd['minute'] = strtotime(date('Y-m-d H:i:00', $endTime));
            $_newd['data'] = json_encode($betNums, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
            $mysql->getDb()->insert(MysqlTables::STAT_BET_NUMS, $_newd);
        });
    }
}