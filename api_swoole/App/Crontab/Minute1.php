<?php
namespace App\Crontab;

use EasySwoole\EasySwoole\Crontab\AbstractCronTask;
use App\Crontab\CronDB;
use App\Model\Constants\RedisKey;
use App\Model\Constants\MysqlTables;
use App\Utility\Helper;
use App\Model\Curl;
use App\Utility\RDB;
use App\Utility\MDB;
use App\Model\ModelAssemble;
use EasySwoole\EasySwoole\Config;

class Minute1 extends AbstractCronTask
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
        return '获取统计：每1分钟';
    }
    
    static function run(\swoole_server $server, int $taskId, int $fromWorkerId, $flags = null)
    {
        swoole_timer_after(1, function() {
            
            $mysql = new MDB();
            //游戏数据统计 -- 获取所有游戏列表
            $_mods = new ModelAssemble();
            $_games = $_mods->getModels()->curl_model->getGameLists(1);
            if (is_array($_games) && count($_games) && isset($_games[0]['id'])) {
                foreach ($_games as $g) {
                    if (isset($g['collector'])) {
                        $mysql->getDb()->where('game_id', $g['id'])->update(MysqlTables::STAT_GAMES, ['num_favorite'=> $g['collector']]);
                    }
                }
            }
            
            $statGames = [];
            $_statGames = $mysql->getDb()->orderBy('game_id', 'ASC')->get(MysqlTables::STAT_GAMES);
            foreach ($_statGames as $sg) {
                $statGames[$sg['game_id']] = $sg;
            }
            
            $mysql->getDb()->insert(MysqlTables::STAT_GAMES_LOG, ['time'=> strtotime(date("Y-m-d H:i").":00"), 'datas'=> json_encode($statGames)]);
        });

        //EVO真人游戏记录
        // if (Config::getInstance()->getConf('APPTYPE') == '2') {
        //     swoole_timer_after(1, function() {
        //         $model = new ModelAssemble();
        //         $model->getModels()->system_model->getCurlEvolutionGameHistoryToDB();
        //     });
        // }
        
        // TODO: Implement run() method.
        // 定时任务处理逻辑
        
        /* swoole_timer_after(1, function() {
            $redis = new RDB();
            $redis->setFlag(time());
            $redis->getDb()->set('abc1233334445555', time());
            
            $mysql = new MDB();
            $mysql->setFlag(time());
            $mysql->getDb()->where('id', 100)->getOne(MysqlTables::ACCOUNT, 'id');
        }); */
        
        /* echo "<pre>";
        print_r(time());
        echo "</pre>".PHP_EOL; */
        
    }
}