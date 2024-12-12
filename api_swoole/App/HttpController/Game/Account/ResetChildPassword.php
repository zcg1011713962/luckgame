<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;
/**
*BB推广员系统 推广员直接充值下级的密码
*/
class ResetChildPassword extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account_id'=> [true, 'str', function($f){ return true; }]
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! $this->account_model->putReChildPlayerPassword($this->Pars['account_id'])) {
            return $this->writeJson(9010, '设置失败', null, true);
        }
        
        return $this->writeJson(200, '设置成功');
    }
}