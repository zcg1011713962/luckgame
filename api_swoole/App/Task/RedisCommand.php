<?php
namespace App\Task;

use EasySwoole\EasySwoole\Swoole\Task\AbstractAsyncTask;
use App\Utility\RDB;

class RedisCommand extends AbstractAsyncTask
{
    protected function run($taskData, $taskId, $fromWorkerId, $flags = null)
    {
        $redis = new RDB();
        $redis->getDb();
        // TODO: Implement run() method.
    }
    
    function finish($result, $task_id)
    {
        //Logger::getInstance()->log( "ok ".time() );
        //echo "task模板任务完成\n";
        return true;
        // TODO: Implement finish() method.
    }
}