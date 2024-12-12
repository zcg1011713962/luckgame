<?php
namespace App\Utility;

use App\Utility\Pool\MysqlObject;
use EasySwoole\Component\Pool\PoolManager;
use EasySwoole\EasySwoole\Config;
use App\Utility\Pool\MysqlPoolAsync;

class MDBSC
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
                ! ($this->db = PoolManager::getInstance()->getPool(MysqlPoolAsync::class)->getObj(Config::getInstance()->getConf('MYSQL.POOL_TIME_OUT')))
                || ! ($this->db instanceof MysqlObject)
            ) {
                if ($this->flag) {
                    echo "<pre>";
                    print_r("回调创建mysqlAsync ".time());
                    echo "</pre>".PHP_EOL;
                }
                
                return $this->getDb();
            }
            
            if ($this->flag) {
                echo "<pre>";
                print_r("创建mysqlAsync ".time());
                echo "</pre>".PHP_EOL;
            }
        } else {
            if ($this->flag) {
                echo "<pre>";
                print_r("复用mysqlAsync ".time());
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
            
            PoolManager::getInstance()->getPool(MysqlPoolAsync::class)->recycleObj($this->db);
        }
    }
}