<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;

class Clinotice extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(true);
    }
    
    public function index()
    {
        $clinotice = $this->system_model->getRedisCliNotice();
        $clinotice = str_replace('&nbsp;', ' ', $clinotice);
        
        return $this->writeJson(200, ['clinotice'=> $clinotice]);
    }
}