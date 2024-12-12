<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Login extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account'=> [true, 'str', function($f){ return !empty(Helper::account_format_login($f)) || Helper::isPlayerUsername($f); }],
                'pwdmd5'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                'ip'=> [true, 'str', function($f){ return Helper::checkIp($f); }],
                'clientuuid'=> [true, 'str', function($f){ return !empty($f); }]
            ]
        );
    }
    
    public function index()
    {
        //检查账号和密码的匹配
        if (
            !! ($_account = $this->account_model->getPlayerCheckPwd($this->Pars['account'], $this->Pars['pwdmd5'], $this->Pars['ip'], $this->Pars['clientuuid'] ?? ''))
            && !! ($_account['account_ip'] = $this->Pars['ip'])
            && !! ($_account['account_clientuuid'] = $this->Pars['clientuuid'])
        ) {
            //创建登录信息
            if (!! ($_login = $this->account_model->putPlayerLogin($_account))) {
                return $this->writeJson(200, $_login);
            } else {
                return $this->writeJson(9091, '系统错误', null, true);
            }
        } else {
            return $this->writeJson(3001, '账号与密码不匹配', null, true);
        }
    }
}