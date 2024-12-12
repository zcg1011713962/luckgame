<?php
namespace App\HttpController\Evolution\Game;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Logout extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->outLog = true;
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            Helper::HTTP_POST,
            [],
            true
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! ($_withdraw = $this->account_model->postEvolutionEdb($this->getIpAddr()))) {
            return $this->writeJson(9091, '登出失败', null, true);
        }
        
        return $this->writeJson(200, '登出成功', $_withdraw);
    }
}