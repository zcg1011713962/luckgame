<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;

class Logout extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(true);
    }
    
    public function index()
    {
        if (!! ($_logout = $this->account_model->putAgentLogout())) {
            return $this->writeJson(200, $_logout);
        } else {
            return $this->writeJson(9091, '系统错误', null, true);
        }
    }
}