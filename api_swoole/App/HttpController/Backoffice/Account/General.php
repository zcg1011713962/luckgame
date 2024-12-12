<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class General extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'prefix_username'=> [false, 'str', function($f){ return preg_match('/^[a-zA-Z]{1,5}$/i',$f) ? true : false; }],
                        'username'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }],
                        'password'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                       'nickname'=> [false, 'str', function($f){ return Helper::strlen_real($f) >0 && Helper::strlen_real($f) <100; }],
//                        'nickname'=> [true, 'str', function($f){ return Helper::is_string_regular($f) && Helper::strlen_real($f) >0 && Helper::strlen_real($f) <100; }],
                        'phone'=> [false, 'str', function($f){ return true; }],
                        'remark'=> [false, 'str', function($f){ return true; }],
                        'coin'=> [false, 'str', function($f){ return is_numeric($f) && $f >= 0; }],
                        'ipaddr'=> [false, 'str', function($f){ return !empty($f); }],
                        'region_id'=> [false, 'int', function($f){ return is_numeric($f); }]
                    ],
                    true
                ],
                [
                    Helper::HTTP_PUT,
                    [
                        'username'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }],
                        'password'=> [false, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                        'nickname'=> [false, 'str', function($f){ return Helper::strlen_real($f) >0 && Helper::strlen_real($f) <100; }],
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
        $nickname = isset($this->Pars['nickname']) ? $this->Pars['nickname'] : '';
        // file_put_contents("/tmp/file.log", json_encode($this->Pars)."\r\n", FILE_APPEND);
        if (! ($general = $this->account_model->postAgent(
            $this->Pars['username'],
            $this->Pars['password'],
            $nickname,
            $this->Pars['phone'] ?: '',
            $this->Pars['remark'] ?: '',
            $this->Pars['coin'] ?: '0',
            $this->Pars['ipaddr'] ?: '',
            $this->Pars['prefix_username'] ?: '',
            $this->Pars['region_id'] ?: 0
        ))) {
            return $this->writeJson(9010, '创建代理失败', null, true);
        }
        
        return $this->writeJson(200, '创建成功', $general);
    }
    
    public function index_put()
    {
        if (! ($general = $this->account_model->putAgent($this->Pars['username'], $this->Pars))) {
            return $this->writeJson(9010, '设置代理失败', null, true);
        }
        
        return $this->writeJson(200, '设置成功', ['username'=> $this->Pars['username'], 'msg'=> '设置成功']);
    }
}