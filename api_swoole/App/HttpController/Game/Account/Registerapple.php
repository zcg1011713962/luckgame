<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

/**
 * 注册苹果账号
 *
 */
class Registerapple extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->outLog = true;
        
        //检查请求参数
        return $this->colationPars(
            [
                'username'=> [true, 'str', function($f){ return true; }], 
                'pwdmd5'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                'ip'=> [true, 'str', function($f){ return Helper::checkIp($f); }],
                'clientuuid'=> [true, 'str', function($f){ return !empty($f); }],
                'id_token'=> [true, 'str', function($f){ return !empty($f) ? true : false;}],
                'nickname'=> [true, 'str', function($f){ return true; }], 
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! $this->thirdparty_model->check_apple_code($this->Pars['username'], $this->Pars['id_token'])) {
            return $this->writeJson(9010, 'token签名不对', null, true);
        }

        $_account = $this->account_model->postRegisterYKPlayer($this->Pars, 1025, 'apple'); //跟注册游戏的方式一样
        if (empty($_account)) {
            return $this->writeJson(9010, '注册失败', null, true);
        }
        //创建登录信息
        if (!! ($_login = $this->account_model->putPlayerLogin($_account))) {
            return $this->writeJson(200, $_login);
        } 
        return $this->writeJson(200, '注册成功登录失败', $_account);
    }
}