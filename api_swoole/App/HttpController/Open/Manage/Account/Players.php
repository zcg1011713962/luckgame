<?php
namespace App\HttpController\Open\Manage\Account;

use EasySwoole\Http\AbstractInterface\Controller;

class Players extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            [
                'page'=> [true, 'abs', function($f){ return preg_match('/^[1-9]{1,10000}$/i', $f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index()
    {
        if (! ($players = $this->account_model->getPlayers('', '', $this->Pars['page']))) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, '查询成功', $players);
    }
}