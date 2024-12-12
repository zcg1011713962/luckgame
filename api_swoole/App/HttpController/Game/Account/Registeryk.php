<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

/**
 * 注册游客玩家账号
 *
 */
class Registeryk extends Controller
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
                'clientuuid'=> [true, 'str', function($f){ return !empty($f); }]
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        $_account = $this->account_model->postRegisterYKPlayer($this->Pars);
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