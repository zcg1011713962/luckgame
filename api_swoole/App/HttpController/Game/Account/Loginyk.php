<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;
/**
* 游客登录
*/
class Loginyk extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account'=> [true, 'str', function($f){ return !empty($f); }],
                'pwdmd5'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                'ip'=> [true, 'str', function($f){ return Helper::checkIp($f); }],
                'clientuuid'=> [true, 'str', function($f){ return !empty($f); }]
            ]
        );
    }
    
    public function index()
    {
        //检查账号和密码的匹配
        $_login = $this->account_model->getYKPlayerCheckPwd($this->Pars['account'], $this->Pars['pwdmd5'], $this->Pars['ip'], $this->Pars['clientuuid'] ?? '');
        if(empty($_login)) {
            return $this->writeJson(9091, '账号与密码不匹配', null, true);
        } else {
            if ($_login) {
                return $this->writeJson(200, $_login);
            } else {
                return $this->writeJson(9091, '系统错误', null, true);
            }
        }
        
    }
}