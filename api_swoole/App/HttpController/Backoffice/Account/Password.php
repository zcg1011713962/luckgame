<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;

class Password extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'oldpassword'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                'newpassword'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_put()
    {
        if (! $this->account_model->putAgentPassword($this->Pars['oldpassword'], $this->Pars['newpassword'])) {
            return $this->writeJson(9010, '设置密码失败', null, true);
        }
        
        return $this->writeJson(200, '设置密码成功');
    }
}