<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

/**
 * 注册玩家账号
 *
 */
class Register extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->outLog = true;
        
        //检查请求参数
        return $this->colationPars(
            [
                'username'=> [true, 'str', function($f){ return Helper::isPlayerUsername($f); }],
                'pwdmd5'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                'email'=> [false, 'str', function($f){ return Helper::isEmail($f); }],
                'pcode'=> [true, 'str', function($f){ return preg_match('/^[0-9]{8}$/i', $f) ? true : false; }],
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! ($newUser = $this->account_model->postRegisterPlayer($this->Pars))) {
            return $this->writeJson(9010, '注册失败', null, true);
        }
        
        return $this->writeJson(200, '注册成功', $newUser);
    }
}