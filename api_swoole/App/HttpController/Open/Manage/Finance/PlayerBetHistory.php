<?php
namespace App\HttpController\Open\Manage\Finance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class PlayerBetHistory extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            [
                'account'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9_\-\.]{1,32}$/i', $f) ? true : false; }],
                'start_time'=> [true, 'abs', function($f){ return is_numeric($f) && $f > 0 && $f == strtotime(date("Y-m-d H:i:s", $f)); }],
                'end_time'=> [true, 'abs', function($f){ return is_numeric($f) && $f > 0 && $f == strtotime(date("Y-m-d H:i:s", $f)); }],
                'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/', $f) ? true : false; }]
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
        
        $this->Pars['account'] = $account;
        if (! ($list = $this->finance_model->getOpenApiPlayerBets($this->Pars['page'], $this->Pars))) {
            return $this->writeJson(9010, '获取失败', null, true);
        }
        
        return $this->writeJson(200, '获取成功', $list);
    }
}