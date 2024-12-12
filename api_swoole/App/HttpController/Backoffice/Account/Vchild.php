<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Vchild extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'username'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }],
                        'password'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                        'nickname'=> [true, 'str', function($f){ return Helper::is_string_regular($f) && Helper::strlen_real($f) >0 && Helper::strlen_real($f) <100; }],
                        'pergids'=> [true, 'str', function($f){ return !empty($f); }]
                    ],
                    true
                ],
                [
                    Helper::HTTP_PUT,
                    [
                        'username'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }],
                        'password'=> [false, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                        'nickname'=> [false, 'str', function($f){ return Helper::is_string_regular($f) && Helper::strlen_real($f) >0 && Helper::strlen_real($f) <100; }],
                        'pergids'=> [false, 'str', function($f){ return !empty($f); }]
                    ],
                    true
                ]
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! ($vchild = $this->account_model->postVchild($this->Pars['username'], $this->Pars['password'], $this->Pars['nickname'], $this->Pars['pergids']))) {
            return $this->writeJson(9010, '创建子账号失败', null, true);
        }
        
        return $this->writeJson(200, '创建成功', $vchild);
    }
    
    public function index_put()
    {
        if (! ($vchild = $this->account_model->putVchild($this->Pars['username'], $this->Pars))) {
            return $this->writeJson(9010, '设置子账号失败', null, true);
        }
        
        return $this->writeJson(200, '设置成功', ['username'=> $this->Pars['username'], 'msg'=> '设置成功']);
    }
}