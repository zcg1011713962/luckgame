<?php
namespace App\HttpController\Open\Manage\Finance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class PlayerCoinUp extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //$this->outLog = true;
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            Helper::HTTP_POST,
            [
                'account'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9_\-\.]{1,32}$/i', $f) ? true : false; }],
                'coin'=> array(true, 'str', function($f){ return is_numeric($f) && Helper::format_money($f) >0; })
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        //权限+账号检测
        if (! ($account = $this->account_model->getOpenApiPlayerPID($this->Pars['account']))) {
            return $this->writeJson(1002, '账号不存在', null, true);
        }
        
        if (! $this->finance_model->postPlayerCoinUp($account, Helper::format_money($this->Pars['coin']), $this->getIpAddr())) {
            return $this->writeJson(9010, '上分失败', null, true);
        }
        
        return $this->writeJson(200, '上分成功', []);
    }
}