<?php
namespace App\HttpController\Evolution\Game;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Order extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->outLog = true;
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            Helper::HTTP_POST,
            [
                'result'=> [true, 'abs', function($f){ return $f > 0 && abs($f) == $f; }], //1或2
                'transid'=> [true, 'str', function($f){ return true; }]
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! ($result = $this->account_model->confirmEvolutionBackMount($this->Pars['transid'], $this->Pars['result']))) {
            return $this->writeJson(9091, '请求失败', null, true);
        }
        
        return $this->writeJson(200, '请求成功', $result);
    }
}