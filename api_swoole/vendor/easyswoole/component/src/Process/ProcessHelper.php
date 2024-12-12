<?php
namespace EasySwoole\Component\Process;

class ProcessHelper
{
    static function register(\swoole_server $server,AbstractProcess $process):bool
    {
        return $server->addProcess($process->getProcess());
    }
}