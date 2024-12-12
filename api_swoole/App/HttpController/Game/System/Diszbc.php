<?php
namespace App\HttpController\Game\System;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;

class Diszbc extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        return true;
    }
    
    public function index()
    {
        if (($pars = $this->system_model->getSystemPars('pool_zbc_disbaseline|pool_zbc_diswave|pool_zbc_disinterval|pool_zbc_disdownpar')) === false) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, $pars);
    }
}