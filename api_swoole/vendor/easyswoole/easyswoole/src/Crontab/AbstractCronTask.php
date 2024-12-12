<?php
namespace EasySwoole\EasySwoole\Crontab;

use EasySwoole\EasySwoole\Swoole\Task\QuickTaskInterface;

abstract class AbstractCronTask implements QuickTaskInterface
{
    abstract public static function getRule():string ;
    abstract public static function getTaskName():string ;
}