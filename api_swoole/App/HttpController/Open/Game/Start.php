<?php
namespace App\HttpController\Open\Game;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Start extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            Helper::HTTP_POST,
            [
                'gameid'=> [true, 'str', function($f){ return !empty($f); }],
                'account'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9_\-\.]{1,32}$/i', $f) ? true : false; }]
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
        
        if (! ($_start = $this->account_model->getOpenGameUri($this->Pars['gameid'], $account, $this->getIpAddr()))) {
            return $this->writeJson(9091, '启动失败', null, true);
        }
        
        return $this->writeJson(200, '启动成功', ['uri'=> $_start]);
    }
}