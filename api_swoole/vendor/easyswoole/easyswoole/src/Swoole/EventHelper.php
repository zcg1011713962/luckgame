<?php
namespace EasySwoole\EasySwoole\Swoole;

class EventHelper
{
    public static function register(EventRegister $register,string $event,callable $callback):void
    {
        $register->set($event,$callback);
    }

    public static function registerWithAdd(EventRegister $register,string $event,callable $callback):void
    {
        $register->add($event,$callback);
    }

    public static function on(\swoole_server $server,string $event,callable $callback)
    {
        $server->on($event,$callback);
    }
}