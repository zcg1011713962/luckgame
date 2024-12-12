<?php
namespace App\HttpController\Game\System;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;

class Disslc extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        return true;
    }
    
    public function index()
    {
        if (($pars = $this->system_model->getSystemPars('pool_slc_disbaseline|pool_slc_diswave|pool_slc_disinterval|pool_slc_disdownpar')) === false) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, $pars);
    }
}