<?php
namespace App\HttpController\Backoffice\Finance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Player_coin extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account'=> [false, 'str', function($f){ return !empty(Helper::account_format_login($f)); }],
                'times'=> [false, 'str', function($f){ return is_array($_ts = explode(".", $f)) && count($_ts) === 2 && is_numeric($_ts[0]) && is_numeric($_ts[1]) && $_ts[1] > $_ts[0]; }]
            ],
            true
        );
    }
    
    public function index()
    {
        if (! ($list = $this->finance_model->getPlayerCoin(Helper::account_format_login($this->Pars['account']), $this->Pars['times']))) {
            return $this->writeJson(9010, '获取失败', null, true);
        }
        
        return $this->writeJson(200, '获取成功', $list);
    }
}