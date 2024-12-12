<?php
namespace App\HttpController\Game\System;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;

class Disbigbang extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        return true;
    }
    
    public function index()
    {
        if(($pars = $this->system_model->getSystemPars('bb_disbaseline|bb_valdown_parl|bb_valdown_time|bb_wave_val')) === false) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, $pars);
    }
}