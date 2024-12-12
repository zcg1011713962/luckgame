<?php
namespace App\Utility;

use App\Utility\Pool\MysqlObject;
use EasySwoole\Component\Pool\PoolManager;
use App\Utility\Pool\MysqlPool;
use EasySwoole\EasySwoole\Config;

class MDB
{
    private $db = null;
    private $flag = 0;
    
    function __construct(){}
    
    public function setFlag($flag = 1)
    {
        $this->flag = $flag;
        return $this;
    }
    
    function getDb() : MysqlObject
    {
        if(! $this->db) {
            if(
                ! ($this->db = PoolManager::getInstance()->getPool(MysqlPool::class)->getObj(Config::getInstance()->getConf('MYSQL.POOL_TIME_OUT')))
                || ! ($this->db instanceof MysqlObject)
            ) {
                if ($this->flag) {
                    echo "<pre>";
                    print_r("回调创建mysql ".time());
                    echo "</pre>".PHP_EOL;
                }
                
                return $this->getDb();
            }
            
            if ($this->flag) {
                echo "<pre>";
                print_r("创建mysql ".time());
                echo "</pre>".PHP_EOL;
            }
        } else {
            if ($this->flag) {
                echo "<pre>";
                print_r("复用mysql ".time());
                echo "</pre>".PHP_EOL;
            }
        }
        
        return $this->db;
    }
    
    function __destruct()
    {
        if ($this->db instanceof MysqlObject) {
            if ($this->flag) {
                echo "<pre>";
                print_r("释放mysql ".time());
                echo "</pre>".PHP_EOL;
            }
            
            PoolManager::getInstance()->getPool(MysqlPool::class)->recycleObj($this->db);
        }
    }
}