<?php
namespace App\Task;

use EasySwoole\EasySwoole\Swoole\Task\AbstractAsyncTask;
use App\Utility\MDBSC;
use EasySwoole\Component\Pool\PoolManager;

class MysqlQuery extends AbstractAsyncTask
{
    protected function run($taskData, $taskId, $fromWorkerId, $flags = null)
    {
        $mysql = new MDBSC();
        
        if (is_string($taskData)) {
            $mysql->getDb()->rawQuery($taskData);
        } elseif (is_array($taskData)) {
            foreach ($taskData as $sql) {
                $mysql->getDb()->rawQuery($sql);
            }
        }
        
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