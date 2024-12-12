<?php
namespace App\Crontab;

use EasySwoole\EasySwoole\Crontab\AbstractCronTask;
use App\Crontab\CronDB;
use App\Model\Constants\RedisKey;
use App\Model\Constants\MysqlTables;
use App\Model\ModelObject;
use App\Utility\Helper;
use App\Model\Curl;
use App\Model\ModelAssemble;

class Minute10 extends AbstractCronTask
{
    use CronDB;
    
    public static function getRule(): string
    {
        // TODO: Implement getRule() method.
        return '*/10 * * * *';
    }
    
    public static function getTaskName(): string
    {
        // TODO: Implement getTaskName() method.
        // 定时任务名称
        return '获取统计：每10分钟';
    }
    
    static function run(\swoole_server $server, int $taskId, int $fromWorkerId, $flags = null)
    {
        $models = new ModelAssemble();
        $result = $models->getModels()->stat_model->statDailyCount();
        $models->getModels()->stat_model->checkAccount();
    }
}