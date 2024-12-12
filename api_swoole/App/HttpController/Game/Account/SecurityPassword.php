<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

/**
 * 修改安全密码
 *
 * BB专用 推广员系统
 * GET请求：检查玩家的支付密码是否正确
 * POST请求：修改支付密码
 */
class SecurityPassword extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'pwdmd5'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }]
                    ],
                    true
                ],
                [
                    Helper::HTTP_POST,
                    [
                        'oldpassword'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                        'newpassword'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }]
                    ],
                    true
                ]
            ]
        );
    }
    
    public function index() {
        if (! $this->account_model->getPlayerSecurityPassword($this->Pars['pwdmd5'])) {
            return $this->writeJson(9010, '失败', null, true);
        }
        
        return $this->writeJson(200, '成功');
    }
    
    public function index_post()
    {
        if (! $this->account_model->putPlayerSecurityPassword($this->Pars['oldpassword'], $this->Pars['newpassword'])) {
            return $this->writeJson(9010, '设置密码失败', null, true);
        }
        
        return $this->writeJson(200, '设置密码成功');
    }
}