<?php
namespace App\HttpController\Backoffice\Finance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Agent_coins extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'username'=> array(false, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }),
                'times'=> array(false, 'str', function($f){ return is_array($_ts = explode(".", $f)) && count($_ts) === 2 && is_numeric($_ts[0]) && is_numeric($_ts[1]) && $_ts[1] > $_ts[0]; }),
                'orderby'=> array(false, 'str'),
                'page'=> array(true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; })
            ],
            true
        );
    }
    
    public function index()
    {
        if (! ($list = $this->finance_model->getAgentCoins($this->Pars['page'], $this->Pars))) {
            return $this->writeJson(9010, '获取失败', null, true);
        }
        
        return $this->writeJson(200, '获取成功', $list);
    }
}