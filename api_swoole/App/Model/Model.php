<?php
namespace App\Model;

use App\Model\AbstractModel;
use App\Utility\MDB;
use App\Utility\RDB;
use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\MysqlTables;
use EasySwoole\Component\TableManager;

class Model extends AbstractModel
{
    public $err_code = 0;
    public $err_msg = "";
    public $err_msg_cover = false;
    public $err_data = [];
    
    /**
     * @var object
     */
    private $dbs = null;
    /**
     * @var array
     */
    private $vars = null;
    /**
     * @var Controller
     */
    protected $models = null;
    /**
     * TOKEN数组
     * @var array
     */
    private $token = [];
    /**
     * MYSQL操作
     * @var MDB $mysql
     */
    protected $mysql = null;
    /**
     * REDIS操作
     * @var RDB $redis
     */
    protected $redis = null;
    
    function __construct()
    {
        if (basename(str_replace('\\', '/', static::class)) === 'ModelAssemble') {
            $this->dbs = (object)$this->dbs;
            $this->vars = (array)$this->vars;
            $this->models = new ModelObject($this->dbs, $this->vars);
            $this->models->setModels($this->models);
            $this->setModels($this->models);
        }
    }
    
    protected function __destructModels()
    {
        $this->dbs = null;
        $this->vars = null;
        $this->models = null;
        $this->token = null;
        $this->mysql = null;
        $this->redis = null;
    }
    
    public function setModels(ModelObject &$modelsObject = null)
    {
        if (! is_null($modelsObject)) {
            $this->models = &$modelsObject;
            $this->dbs = &$this->models->getDbs();
            if (! isset($this->dbs->mysql)) {
                $this->mysql = $this->dbs->mysql = new MDB();
            } else {
                $this->mysql = $this->dbs->mysql;
            }
            if (! isset($this->dbs->redis)) {
                $this->redis = $this->dbs->redis = new RDB();
            } else {
                $this->redis = $this->dbs->redis;
            }
            $this->vars = &$this->models->getVars();
        }
    }
    
    public function &getModels()
    {
        return $this->models;
    }
    
    public function setErrCode($code = 0) : void
    {
        $this->vars['ApiErr']['ErrCode'] = $code;
        $this->err_code = $code;
    }
    
    public function getErrCode() : string
    {
        return (string)$this->err_code;
    }
    
    public function setErrMsg($msg = '', $cover = false) : void
    {
        $this->vars['ApiErr']['ErrMsg'] = [$msg, $cover];
        $this->err_msg = $msg;
        $this->err_msg_cover = $cover;
    }
    
    public function getErrMsg() : array
    {
        return [$this->err_msg, $this->err_msg_cover];
    }
    
    public function getErrMsgStr() : string
    {
        return (string)$this->err_msg;
    }
    
    public function setErrData($data = []) : void
    {
        $this->vars['ApiErr']['ErrData'] = $data;
        $this->err_data = $data;
    }
    
    public function getErrData() : array
    {
        return (array)$this->err_data;
    }
    
    protected function getAbutments() : array
    {
        return $this->vars;
    }
    
    protected function getAbutmentKey(string $key = '')
    {
        return $this->vars[$key] ?? null;
    }
    
    protected function getTokenObj() : \stdClass
    {
        if (isset($this->dbs->token) && is_array($this->dbs->token)) {
            return $this->array_to_object($this->dbs->token);
        }
        
        return new \stdClass();
    }
    
    protected function getTokenArray() : array
    {
        if (isset($this->dbs->token) && is_array($this->dbs->token)) {
            return $this->dbs->token;
        }
        
        return [];
    }
    
    /**
     * 数组转换为对象
     * @param array $arr
     * @return \stdClass
     */
    private function array_to_object(array $arr) : \stdClass
    {
        foreach ($arr as $k => $v) {
            if (gettype($v) == 'array' || getType($v) == 'object') {
                $arr[$k] = (object)$this->array_to_object($v);
            }
        }
        
        return (object)$arr;
    }
    
    protected function getTableFields(string $table = '', array $as = [], array $unsets = [], bool $diff = false)
    {
        $tables = TableManager::getInstance()->get('table.mysql.tables');
        $fields = explode(",", $tables->get($table, 'fields'));
        if ($unsets && $diff) {
            $fields = array_diff($fields, $unsets);
        } elseif ($unsets && ! $diff) {
            $fields = array_intersect($fields, $unsets);
        }
        
        if ($as && count($as) > 1) {
            if ($as[0]/* 表别名，如：account as a */ && $as[1]) {
                //遍历表字段集合
                foreach ($fields as $k => $field/* 字段名称 */) {
                    if (is_array($as[1])) {
                        $as[1][1][] = $as[1][0] . $field;
                        $fields[$k] = $as[0] . '.' . $field . ' as ' . $as[1][0] . $field;
                    } else {
                        $fields[$k] = $as[0] . '.' . $field . ' as ' . $as[1] . $field;
                    }
                    
                }
            }
            //仅按要求重置数组键名
            elseif ($as[0] === null && $as[1]) {
                //遍历表字段集合
                foreach ($fields as $k => $field/* 字段名称 */) {
                    unset($fields[$k]);
                    $fields[$as[1] . $field] = null;
                }
            }
            
            if (isset($as[2]) && is_string($as[2])) {
                //是否转换为字符串 $as[2]
                //是否在尾部追加字符 $as[3]
                $fields = implode($as[2], $fields).(isset($as[3])? $as[3] : '');
            }
        }
        
        return $fields;
    }

    /**
     * 获取game库中的表
     */
    protected function getTable($table) {
        $cfgInstance = \EasySwoole\EasySwoole\Config::getInstance();
        $game_db = $cfgInstance->getConf('GAME_DBNAME');
        return "{$game_db}.{$table}";
    }
}