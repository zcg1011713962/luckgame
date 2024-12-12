<?php
namespace App\HttpController\Game\System;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;

class Dispoolmega extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        return true;
    }
    
    public function index()
    {
        if (($pars = $this->system_model->getSystemPars('pool_mega_disbaseline|pool_mega_diswave|pool_mega_disinterval|pool_mega_disdownpar')) === false) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, $pars);
    }
}