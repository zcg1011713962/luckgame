<?php
namespace App\Crontab;

use EasySwoole\EasySwoole\Crontab\AbstractCronTask;
use App\Crontab\CronDB;
use App\Model\Constants\RedisKey;
use App\Model\Constants\MysqlTables;
use App\Model\ModelObject;
use App\Utility\Helper;
use App\Model\Curl;
use App\Utility\MDB;
use App\Model\ModelAssemble;

class Hour1 extends AbstractCronTask
{
    use CronDB;
    
    public static function getRule(): string
    {
        // TODO: Implement getRule() method.
        return '@hourly';
    }
    
    public static function getTaskName(): string
    {
        // TODO: Implement getTaskName() method.
        // 定时任务名称
        return '获取统计：每1小时';
    }
    
    static function run(\swoole_server $server, int $taskId, int $fromWorkerId, $flags = null)
    {
        swoole_timer_after(1, function() {
            
            $models = new ModelAssemble();
            $models->getModels()->stat_model->newStrategyCount();
            
        });
        
        swoole_timer_after(1, function() {
            
            $mysql = new MDB();
            $_mods = new ModelAssemble();
            
            //游戏数据统计 -- 获取所有游戏列表
            $_games = $_mods->getModels()->curl_model->getGameLists(1);
            if (is_array($_games) && count($_games) && isset($_games[0]['id'])) {
                foreach ($_games as $g) {
                    if (! $mysql->getDb()->where('game_id', $g['id'])->has(MysqlTables::STAT_GAMES)) {
                        $mysql->getDb()->insert(MysqlTables::STAT_GAMES, [
                            'game_id'=> $g['id'],
                            'num_favorite'=> $g['collector'] ?? '0'
                        ]);
                    }
                }
            }
            
        });
        
    }
}