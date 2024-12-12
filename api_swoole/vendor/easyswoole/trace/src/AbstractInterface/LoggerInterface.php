<?php
namespace EasySwoole\Trace\AbstractInterface;

interface LoggerInterface
{
    public function log(string $str,$logCategory = null,int $timestamp = null):?string ;
    public function console(string $str,$category = null,$saveLog = true):?string ;
}