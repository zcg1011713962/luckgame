<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Vchild_switch extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'username'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true: false; }],
                'switch'=> [true, 'abs', function($f){ return preg_match('/^[0-1]{1}$/i', $f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_put()
    {
        if (! ($vchild = $this->account_model->putVchild($this->Pars['username'], $this->Pars))) {
            return $this->writeJson(9010, ($this->Pars['switch'] ? '开启' : '禁用').'子账号失败', null, true);
        }
        
        return $this->writeJson(200, '设置成功', ['username'=> $this->Pars['username'], 'msg'=> '设置成功']);
    }
}