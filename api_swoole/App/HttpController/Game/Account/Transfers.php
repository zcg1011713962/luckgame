<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
/**
*BB推广员系统 获取玩家上下级转账记录列表
*/
class Transfers extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'times'=> [false, 'str', function($f){ return is_array($_ts = explode(".", $f)) && count($_ts) === 2 && is_numeric($_ts[0]) && is_numeric($_ts[1]) && $_ts[1] > $_ts[0]; }],
                'orderby'=> [false, 'str'],
                'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/', $f) ? true : false; }],
                'limit'=> [false, 'abs', function($f){ return preg_match('/^[0-9]{2,100}$/', $f) ? true : false; }],
                'type'=> [false, 'str', function($f){ return in_array($f, ['normal', 'relation']); }]
            ],
            true
        );
    }
    
    public function index()
    {
        if (! ($list = $this->finance_model->getPlayerTransfer($this->Pars['times'] ?? '', $this->Pars['orderby'] ?? '', $this->Pars['page'], $this->Pars['limit'] ?? 0, $this->Pars['type'] ?? 'normal'))) {
            return $this->writeJson(3003, '查询失败', null, true);
        }
        
        return $this->writeJson(200, $list);
    }
}