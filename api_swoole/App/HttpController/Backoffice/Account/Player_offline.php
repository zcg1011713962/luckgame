<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Player_offline extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account'=> [true, 'str', function($f){ return !empty(Helper::account_format_login($f)); }]
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_put()
    {
        //踢下线60秒，并禁止登陆
        $this->Pars['ban_time'] = time()+10;/* 60秒改成10秒 */
        
        if (! ($player = $this->account_model->putPlayer(Helper::account_format_login($this->Pars['account']), $this->Pars, ['ban_time']))) {
            return $this->writeJson(9010, '操作失败', null, true);
        }
        
        return $this->writeJson(200, '操作成功', ['account'=> $this->Pars['account'], 'msg'=> '操作成功']);
    }
}