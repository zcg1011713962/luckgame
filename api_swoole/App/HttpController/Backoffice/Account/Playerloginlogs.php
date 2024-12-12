<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;

class Playerloginlogs extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account_id_or_pid'=> [false, 'str', function($f){ return !empty($f); }],
                'time'=> [false, 'abs', function($f){ return $f>0; }],
                'time2'=> [false, 'abs', function($f){ return $f>0; }],
                'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index()
    {
        if (! ($logs = $this->account_model->getPlayerLoginLogs($this->Pars['account_id_or_pid'], $this->Pars['time'], $this->Pars['time2'], $this->Pars['page']))) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, '查询成功', $logs);
    }
}