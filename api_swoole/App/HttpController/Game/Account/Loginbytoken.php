<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Loginbytoken extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //$this->outLog = true;
        
        //检查请求参数
        return $this->colationPars(
            [
                'ip'=> [true, 'str', function($f){ return !empty($f); }],
                'gameid'=> [false, 'str', function($f){ return $f > 0; }],
                'signstr'=> [false, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }]
            ], 
            true
        );
    }
    
    public function index()
    {
        if (! ($_login = $this->account_model->putPlayerLoginByToken($this->Pars['ip'], $this->Pars['gameid'] ?? '', $this->Pars['signstr'] ?? ''))) {
            return $this->writeJson(3003, '登录失败', null, true);
        }
        
        return $this->writeJson(200, $_login);
    }
}