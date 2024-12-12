<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;

class PasswordX extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'username'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }],
                'oldpassword'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                'newpassword'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }]
            ],
            false
        );
    }
    
    public function index() {}
    
    public function index_put()
    {
        if (! $this->account_model->putAgentPasswordX($this->Pars['username'], $this->Pars['oldpassword'], $this->Pars['newpassword'])) {
            return $this->writeJson(9010, '设置密码失败', null, true);
        }
        
        return $this->writeJson(200, '设置密码成功');
    }
}