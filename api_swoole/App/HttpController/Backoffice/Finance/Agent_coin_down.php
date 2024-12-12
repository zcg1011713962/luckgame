<?php
namespace App\HttpController\Backoffice\Finance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Agent_coin_down extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            Helper::HTTP_POST,
            [
                'username'=> array(true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }),
                'coin'=> array(true, 'str', function($f){ return is_numeric($f) && Helper::format_money($f) >0; }),
                'ipaddr'=> array(false, 'str', function($f){ return !empty($f); })
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! $this->finance_model->postAgentCoinDown($this->Pars['username'], Helper::format_money($this->Pars['coin']), $this->Pars['ipaddr'] ?: '')) {
            return $this->writeJson(9010, '下分失败', null, true);
        }
        
        return $this->writeJson(200, '下分成功', ['username'=> $this->Pars['username'], 'msg'=> '操作成功']);
    }
}