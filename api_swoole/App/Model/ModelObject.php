<?php
namespace App\Model;

use App\Utility\Helper;

class ModelObject extends \stdClass
{
    private $_modelname = "";
    private $_dbs = null;
    private $_vars = null;
    private $_models = null;
    
    function __construct(&$dbs = null, &$vars = null)
    {
        if (! is_null($dbs) && $this->_dbs === null) {
            $this->_dbs = &$dbs;
        } elseif ($this->_dbs === null) {
            $this->_dbs = new \stdClass();
        }
        if (! is_null($vars) && $this->_vars === null) {
            $this->_vars = &$vars;
        } elseif ($this->_vars === null) {
            $this->_vars = [];
        }
    }
    
    public function setModels(&$models = null)
    {
        if (! is_null($models) && $this->_models === null) {
            $this->_models = &$models;
        }
    }
    
    public function &getModels()
    {
        return $this->_models;
    }
    
    public function &getDbs()
    {
        return $this->_dbs;
    }
    
    public function &getVars()
    {
        return $this->_vars;
    }
    
    public function __get(string $name = '')
    {
        //创建Model实例
        $_modelName = $_modelDirectory = "";
        if (substr_count($name, '_model') === 1) {
            $_modelName = substr($name, 0, strpos($name, '_model'));
            if (substr_count($_modelName, '_') === 1) {
                list($_modelDirectory, $_modelName) = explode("_", $_modelName);
                $_modelDirectory = ucfirst($_modelDirectory);
                $_modelName = ucfirst($_modelName);
            } elseif (substr_count($_modelName, '_') === 0) {
                $_modelName = ucfirst($_modelName);
            } else {
                return null;
            }
            //模型对象存在
            if (isset($this->_models->{$name})) {
                return $this->_models->{$name};
            }
            //需要动态创建模型对象
            else {
                try {
                    $this->_modelname = '\\App\\Model\\'.($_modelDirectory ? $_modelDirectory . '\\' : '') . $_modelName;
                    $this->_models->{$name} = new $this->_modelname();
                } catch (\Throwable $throwable) {
                    $this->_modelname = Helper::getModelClassName($_modelDirectory, $_modelName);
                    $this->_models->{$name} = new $this->_modelname();
                }
                $this->_models->{$name}->setModels($this->_models);
                return $this->_models->{$name};
            }
        }
        
        return null;
    }
}