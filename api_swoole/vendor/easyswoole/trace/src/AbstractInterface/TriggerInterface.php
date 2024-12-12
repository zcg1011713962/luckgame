<?php
namespace EasySwoole\Trace\AbstractInterface;

use EasySwoole\Trace\Bean\Location;

interface TriggerInterface
{
    public function error($msg,int $errorCode = E_USER_ERROR,Location $location = null);
    public function throwable(\Throwable $throwable);
}