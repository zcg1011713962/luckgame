<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Playergamelogs extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account'=> [false, 'str', function($f){ return !empty(Helper::account_format_login($f)); }],
                'gameid'=> [false, 'abs', function($f){ return $f > 0; }],
                'orderby'=> [false, 'str'],
                'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index()
    {
        if (! ($logs = $this->account_model->getPlayerGameLogs(Helper::account_format_login($this->Pars['account']), $this->Pars['gameid'], $this->Pars['orderby'], $this->Pars['page']))) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, '查询成功', $logs);
    }
}