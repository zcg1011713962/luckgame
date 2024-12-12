<?php
namespace App\HttpController\Open\Manage\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;
use EasySwoole\Utility\Random;

class Player extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        $this->vars['isOpenApi'] = true;
        
        //检查请求参数
        return $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'account'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9_\-\.]{1,32}$/i', $f) ? true : false; }]
                    ],
                    true
                ]
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! ($_player = $this->account_model->postPlayers('1', md5(Random::character(6)), '', $this->Pars['account']))) {
            return $this->writeJson(9010, '创建失败', null, true);
        }
        
        //获取新账号
        $_player = $this->account_model->getPlayer($_player[0], 0, false, true, false);
        
        //构建返回
        //APP方平台内玩家账号ID
        $player['account'] = (string)$_player['account_appuid'];
        //创建时间戳
        $player['create_time'] = (string)$_player['account_create_time'];
        
        return $this->writeJson(200, '创建成功', $player);
    }
}