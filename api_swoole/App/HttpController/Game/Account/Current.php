<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;

class Current extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(true);
    }
    
    public function index()
    {
        if (! ($player = $this->account_model->getCurPlayer())) {
            return $this->writeJson(9091, '获取失败', null, true);
        }
        
        return $this->writeJson(200, $player);
    }
}