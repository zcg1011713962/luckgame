<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Ban extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            Helper::HTTP_PUT,
            [
                'username'=> [false, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }],
                'account'=> [false, 'str', function($f){ return !empty(Helper::account_format_login($f)); }]
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_put()
    {
        if (! ($ban = $this->account_model->banAccount($this->Pars['username'] ?? '', Helper::account_format_login($this->Pars['account'])))) {
            return $this->writeJson(9010, '操作失败', null, true);
        }
        
        return $this->writeJson(200, '操作成功', ['account'=> $this->Pars['username'] ?: Helper::account_format_display($this->Pars['account']), 'msg'=> '操作成功']);
    }
}