<?php
namespace EasySwoole\EasySwoole\Swoole\Task;

interface QuickTaskInterface
{
    static function run(\swoole_server $server,int $taskId,int $fromWorkerId,$flags = null);
}