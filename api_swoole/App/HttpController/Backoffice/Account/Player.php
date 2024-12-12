<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Player extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'playertotal'=> [true, 'abs', function($f){ return [$f > 0 && $f < 1001, '参数：%s 玩家数量限制为1~1000']; }],
                        'password'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                        'nickname'=> [true, 'str', function($f){ return Helper::is_string_regular($f) && Helper::strlen_real($f) > 0 && Helper::strlen_real($f) <100; }]
                    ],
                    true
                ],
                [
                    Helper::HTTP_PUT,
                    [
                        'account'=> [true, 'str', function($f){ return !empty(Helper::account_format_login($f)); }],
                        'password'=> [false, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                        'nickname'=> [false, 'str', function($f){ return Helper::is_string_regular($f) && Helper::strlen_real($f) >0 && Helper::strlen_real($f) <100; }],
                        'remark'=> [false, 'str', function($f){ return true; }],
                        'phone'=> [false, 'str', function($f){ return true; }]
                    ],
                    true
                ]
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! ($player = $this->account_model->postPlayers($this->Pars['playertotal'], $this->Pars['password'], $this->Pars['nickname']))) {
            return $this->writeJson(9010, '创建玩家失败', null, true);
        }
        
        return $this->writeJson(200, '创建成功', $player);
    }
    
    public function index_put()
    {
        if (! ($player = $this->account_model->putPlayer(Helper::account_format_login($this->Pars['account']), $this->Pars))) {
            return $this->writeJson(9010, '设置玩家失败', null, true);
        }
        
        return $this->writeJson(200, '设置成功', ['account'=> $this->Pars['account'], 'msg'=> '设置成功']);
    }
}