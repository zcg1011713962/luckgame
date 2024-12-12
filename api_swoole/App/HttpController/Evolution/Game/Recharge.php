<?php
namespace App\HttpController\Evolution\Game;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;
//往evo充值
class Recharge extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->outLog = true;
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            Helper::HTTP_POST,
            [
                'game_identification'=> [true, 'abs', function($f){ return $f > 0 && abs($f) == $f; }],
                'coin'=> [true, 'str', function($f){ return true; }]
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! ($_start = $this->account_model->recharge2Evolution($this->Pars['game_identification'], $this->Pars['coin'], $this->getIpAddr()))) {
            return $this->writeJson(9091, '启动失败', null, true);
        }
        
        return $this->writeJson(200, '启动成功', $_start);
    }
}