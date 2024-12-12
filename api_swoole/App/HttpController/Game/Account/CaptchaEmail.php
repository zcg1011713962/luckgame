<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

/**
 * 发送邮件验证码
 *
 */
class CaptchaEmail extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'username'=> [true, 'str', function($f){ return Helper::isPlayerUsername($f); }],
                'email'=> [true, 'str', function($f){ return Helper::isEmail($f); }]
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! $this->account_model->postCaptchaEmail($this->Pars['username'], $this->Pars['email'])) {
            return $this->writeJson(9010, '发送失败', null, true);
        }
        
        return $this->writeJson(200, '发送成功');
    }
}