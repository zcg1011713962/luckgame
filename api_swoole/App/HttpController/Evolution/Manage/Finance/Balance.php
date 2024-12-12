<?php
namespace App\HttpController\Evolution\Manage\Finance;

use EasySwoole\Http\AbstractInterface\Controller;

class Balance extends Controller
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
        /* if (! ($balance = $this->finance_model->getOpenApiAppBalance())) {
            return $this->writeJson(9010, '获取失败', null, true);
        } */
        
        return $this->writeJson(200, '获取成功', '0');
    }
}