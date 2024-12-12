<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class PlayerPoly extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'account'=> [true, 'str', function($f){ return Helper::account_format_login($f); }],
                        'password'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                        'nickname'=> [true, 'str', function($f){ return Helper::is_string_regular($f) && Helper::strlen_real($f) > 0 && Helper::strlen_real($f) <100; }],
                        'phone'=> [false, 'str', function($f){ return true; }],
                        'remark'=> [false, 'str', function($f){ return true; }],
                        'coin'=> [false, 'str', function($f){ return is_numeric($f) && $f >= 0; }],
                        'ipaddr'=> [false, 'str', function($f){ return !empty($f); }]
                    ],
                    true
                ],
                [
                    Helper::HTTP_PUT,
                    [],
                    true
                ]
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        //创建账号
        if (! ($player = $this->account_model->postPolyPlayer(
            $this->Pars['account'],
            $this->Pars['password'],
            $this->Pars['nickname'],
            $this->Pars['phone'] ?: '',
            $this->Pars['remark'] ?: '',
            $this->Pars['coin'] ?: '0',
            $this->Pars['ipaddr'] ?: ''
        ))) {
            return $this->writeJson(9010, '创建玩家失败', null, true);
        }
        
        return $this->writeJson(200, '创建成功', $player);
    }
    
    public function index_put()
    {
        //仅产生一个新账号PID
        if (! ($playerAccount = $this->account_model->postPlayerPolyAccount())) {
            return $this->writeJson(9010, '获取失败', null, true);
        }
        
        return $this->writeJson(200, '获取成功', ['account'=> $playerAccount]);
    }
}