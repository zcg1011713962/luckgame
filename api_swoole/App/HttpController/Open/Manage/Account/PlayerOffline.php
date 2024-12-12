<?php
namespace App\HttpController\Open\Manage\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class PlayerOffline extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            [
                'account'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9_\-\.]{1,32}$/i', $f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_put()
    {
        //权限+账号检测
        if (! ($account = $this->account_model->getOpenApiPlayerPID($this->Pars['account']))) {
            return $this->writeJson(1002, '账号不存在', null, true);
        }
        
        //踢下线60秒，并禁止登陆
        $this->Pars['ban_time'] = time() + 60;
        if (! ($player = $this->account_model->putPlayer($account, $this->Pars, ['ban_time']))) {
            return $this->writeJson(9010, '操作失败', null, true);
        }
        
        return $this->writeJson(200, '操作成功', ['account'=> $this->Pars['account'], 'online'=> 0]);
    }
}