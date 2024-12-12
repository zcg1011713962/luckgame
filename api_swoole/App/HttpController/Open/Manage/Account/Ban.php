<?php
namespace App\HttpController\Open\Manage\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Ban extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            Helper::HTTP_PUT,
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
        
        if (! ($ban = $this->account_model->banAccount('', $account))) {
            return $this->writeJson(9010, '操作失败', null, true);
        }
        
        return $this->writeJson(200, '操作成功', ['account'=> $this->Pars['account'], 'ban'=> $this->vars['ApiErr']['ErrData']['ban']]);
    }
}