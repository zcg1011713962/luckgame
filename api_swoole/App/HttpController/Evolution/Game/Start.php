<?php
namespace App\HttpController\Evolution\Game;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Start extends Controller
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
                'coin'=> [true, 'str', function($f){ return true; }],
                'evoaccount'=> [false, 'str', function($f){ return true; }], //对方平台账号 bb
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        $evoaccount = isset($this->Pars['evoaccount']) ? trim($this->Pars['evoaccount']) : '';
        if (! ($_start = $this->account_model->getEvolutionGameUri($this->Pars['game_identification'], $this->Pars['coin'], $this->getIpAddr(), $evoaccount))) {
            return $this->writeJson(9091, '启动失败', null, true);
        }
        
        return $this->writeJson(200, '启动成功', $_start);
    }
}