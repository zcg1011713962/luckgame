<?php
namespace App\Crontab;

use EasySwoole\EasySwoole\Config;
use App\Utility\Pool\MysqlObject;

trait CronDB
{
    static function getRedisDb()
    {
        //redis连接
        $redis = new \Redis();
        $conf = Config::getInstance()->getConf('REDIS');
        //尝试创建连接
        if ($redis->connect($conf['host'], $conf['port'])) {
            //验证
            if (!empty($conf['auth'])) {
                $redis->auth($conf['auth']);
            }
            //选择db
            if (isset($conf['db']) && !empty($conf['db'])) {
                $redis->select($conf['db']);
            }
        } else {
            $redis = null;
        }
        
        return $redis;
    }
    
    static function getMysqlDb()
    {
        $conf = Config::getInstance()->getConf("MYSQL");
        $dbConf = new \EasySwoole\Mysqli\Config($conf);
        
        return new MysqlObject($dbConf);
    }
}