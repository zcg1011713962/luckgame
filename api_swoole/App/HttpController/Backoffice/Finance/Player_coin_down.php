<?php
namespace App\HttpController\Backoffice\Finance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Player_coin_down extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            Helper::HTTP_POST,
            [
                'account'=> [true, 'str', function($f){ return !empty(Helper::account_format_login($f)); }],
                'coin'=> [true, 'str', function($f){ return is_numeric($f) && Helper::format_money($f) >0; }],
                'ipaddr'=> array(false, 'str', function($f){ return !empty($f); })
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! $this->finance_model->postPlayerCoinDown(Helper::account_format_login($this->Pars['account']), Helper::format_money($this->Pars['coin']), $this->Pars['ipaddr'] ?: '')) {
            return $this->writeJson(9010, '下分失败', null, true);
        }
        
        return $this->writeJson(200, '下分成功', ['account'=> $this->Pars['account'], 'msg'=> '操作成功']);
    }
}