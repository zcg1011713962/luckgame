<?php
namespace App\HttpController\Open\Manage\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class PlayerDetail extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            [
                'account'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9_\-\.]{1,32}$/i', $f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index()
    {
        //权限+账号检测
        if (! ($account = $this->account_model->getOpenApiPlayerPID($this->Pars['account']))) {
            return $this->writeJson(1002, '账号不存在', null, true);
        }
        
        if (! ($player = $this->account_model->getPlayer($account, 0, true, true, false))) {
            return $this->writeJson(1002, '查询失败', null, true);
        }
        
        //构建返回
        $rPlayer['account'] = (string)$player['account_appuid'];
        $rPlayer['coin'] = (string)$player['account_coin'];
        $rPlayer['ban'] = $this->account_model->checkAccountBan($player['account_id']) ? 1 : 0;
        $rPlayer['online'] = (int)$this->curl_model->getOnlinePlayerOne($player['account_id']);
        $rPlayer['create_time'] = (string)$player['account_create_time'];
        $rPlayer['lastlogin_time'] = (string)$player['account_login_time'];
        
        return $this->writeJson(200, '查询成功', $rPlayer);
    }
}