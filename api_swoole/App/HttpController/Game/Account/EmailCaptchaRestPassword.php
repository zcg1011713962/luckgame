<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

/**
 * 通过邮件验证码重置密码
 *
 */
class EmailCaptchaRestPassword extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'username'=> [true, 'str', function($f){ return Helper::isPlayerUsername($f); }],
                'email'=> [true, 'str', function($f){ return Helper::isEmail($f); }],
                'captcha'=> [true, 'str', function($f){ return preg_match('/^[0-9]{6}$/i', $f) ? true : false; }],
                'pwdmd5'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }]
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! $this->account_model->postPlayerEmailCaptchaRestPassword($this->Pars)) {
            return $this->writeJson(9010, '重置密码失败', null, true);
        }
        
        return $this->writeJson(200, '重置密码成功');
    }
}