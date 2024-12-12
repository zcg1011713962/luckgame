<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use EasySwoole\EasySwoole\Config;

class Login extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //$this->outLog = true;
        
        //检查请求参数
        return $this->colationPars(
            [
                'username'=> [true, 'str', function($f){
                    if (substr_count($f, '.') === 1) {
                        $port = substr($f, 0, strpos($f, '.'));
                        if (is_numeric($port) && is_array($confList = Config::getInstance()->getConf('GAMESERVER.LIST')) && isset($confList[$port])) {
                            $f = substr($f, strpos($f, '.')+1);
                        }
                    }
                    return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false;
                }],
                'pwdmd5'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                'ip' => [true, 'str', function($f) {return true;}]
            ]
        );
    }
    
    public function index()
    {
        //检查账号和密码的匹配
        if (!! ($_agent = $this->account_model->getAgentCheckPwd($this->Pars['username'], $this->Pars['pwdmd5']))) {
            $ip_arr = $this->account_model->getAgentLoginIp($_agent['account_id']);
            if(!empty($ip_arr)) {
                $login_ip = $this->Pars['ip'];
                if(!in_array($login_ip, $ip_arr)) {
                    return $this->writeJson(3006, '不允许在此IP登录', null, true);
                }
            }
            //创建登录信息
            if (($_login = $this->account_model->putAgentLogin($_agent)) !== false) {
                return $this->writeJson(200, $_login);
            } else {
                return $this->writeJson(9091, '系统错误', null, true);
            }
        } else {
            return $this->writeJson(3001, '账号与密码不匹配', null, true);
        }
    }
}