<?php
namespace App\HttpController\Game\System;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;

class Redbagsetting extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        return true;
    }
    
    public function index()
    {
        if (($pars = $this->system_model->getSystemPars('pool_rb_isopen|pool_rb_limitup|pool_rb_limitdown|pool_rb_coinless|pool_rb_7daycoindiff')) === false) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, $pars);
    }
}