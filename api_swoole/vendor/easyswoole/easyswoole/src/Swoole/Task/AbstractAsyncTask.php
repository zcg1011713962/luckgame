<?php
namespace EasySwoole\EasySwoole\Swoole\Task;

abstract class AbstractAsyncTask
{
    private $data = null;
    
    final public function __construct($data = null)
    {
        $this->data = $data;
    }
    /*
     * if has return ,do finish call
     */
    function __onTaskHook($taskId,$fromWorkerId,$flags = null)
    {
        try{
            return $this->run($this->data,$taskId,$fromWorkerId,$flags);
        }catch (\Throwable $throwable){
            $this->onException($throwable);
        }
    }

    function __onFinishHook($finishData,$task_id)
    {
        try{
            $this->finish($finishData,$task_id);
        }catch (\Throwable $throwable){
            $this->onException($throwable);
        }
    }

    abstract protected function run($taskData,$taskId,$fromWorkerId,$flags = null);

    abstract protected function finish($result,$task_id);

    public function onException(\Throwable $throwable):void
    {
        throw $throwable;
    }
}