<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Player_detail extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account'=> [true, 'str', function($f){ return !empty(Helper::account_format_login($f)); }]
            ],
            true
        );
    }
    
    public function index()
    {
        if (! ($player = $this->account_model->getPlayer(Helper::account_format_login($this->Pars['account']), 0, true, true, false))) {
            return $this->writeJson(1002, '查询失败', null, true);
        }
        
        $player['account_online'] = (string)$this->curl_model->getOnlinePlayerOne($player['account_id']);
        
        return $this->writeJson(200, '查询成功', $player);
    }
}