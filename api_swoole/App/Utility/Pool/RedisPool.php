<?php
namespace App\Utility\Pool;

use EasySwoole\Component\Pool\AbstractPool;
use EasySwoole\EasySwoole\Config;

class RedisPool extends AbstractPool
{
    protected function createObject()
    {
        // TODO: Implement createObject() method.
        $redis = new RedisObject();
        $conf = Config::getInstance()->getConf('REDIS');
        if ($redis->connect($conf['host'],$conf['port'])) {
            if (!empty($conf['auth'])) {
                $redis->auth($conf['auth']);
            }
            
            if (isset($conf['db']) && !empty($conf['db'])) {
                $redis->select($conf['db']);
            }
            
            return $redis;
        } else {
            return null;
        }
    }
}