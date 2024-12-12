<?php
namespace App\Utility;

use Swoole\Coroutine\Redis;
use EasySwoole\Component\Pool\PoolManager;
use App\Utility\Pool\RedisPool;
use EasySwoole\EasySwoole\Config;

class RDB
{
    private $redis = null;
    private $flag = 0;
    
    function __construct(){}
    
    public function setFlag($flag = 1)
    {
        $this->flag = $flag;
        return $this;
    }
    
    function getDb() : Redis
    {
        if(! $this->redis) {
            if(
                ! ($this->redis = PoolManager::getInstance()->getPool(RedisPool::class)->getObj(Config::getInstance()->getConf('REDIS.POOL_TIME_OUT')))
                || ! ($this->redis instanceof Redis)
            ) {
                if ($this->flag) {
                    echo "<pre>";
                    print_r("回调创建redis ".time());
                    echo "</pre>".PHP_EOL;
                }
                
                return $this->getDb();
            }
            
            if ($this->flag) {
                echo "<pre>";
                print_r("创建redis ".time());
                echo "</pre>".PHP_EOL;
            }
        } else {
            if ($this->flag) {
                echo "<pre>";
                print_r("复用redis ".time());
                echo "</pre>".PHP_EOL;
            }
        }
        
        return $this->redis;
    }
    
    function __destruct()
    {
        if ($this->redis instanceof Redis) {
            if ($this->flag) {
                echo "<pre>";
                print_r("释放redis ".time());
                echo "</pre>".PHP_EOL;
            }
            PoolManager::getInstance()->getPool(RedisPool::class)->recycleObj($this->redis);
        }
    }
}