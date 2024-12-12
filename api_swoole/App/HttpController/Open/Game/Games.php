<?php
namespace App\HttpController\Open\Game;

use EasySwoole\Http\AbstractInterface\Controller;

class Games extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            [],
            true
        );
    }
    
    public function index()
    {
        if (! ($games = $this->account_model->getOpenGameGames())) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, '查询成功', $games);
    }
}