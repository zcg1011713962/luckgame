<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Auth extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }]
                    ],
                    true
                ],
                [
                    Helper::HTTP_PUT,
                    [
                        'username'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }],
                        'auth'=> [true, 'str', function($f){ return !empty($f); }]
                    ],
                    true
                ]
            ]
        );
    }
    
    public function index()
    {
        if (! ($list = $this->account_model->getAuth($this->Pars['username'], $this->Pars['auth']))) {
            return $this->writeJson(9010, '设置权限失败', null, true);
        }
        
        return $this->writeJson(200, '设置成功');
    }
    
    public function index_put()
    {
        if (! ($auth = $this->account_model->putAuth($this->Pars['username'], $this->Pars['auth']))) {
            return $this->writeJson(9010, '设置权限失败', null, true);
        }
        
        return $this->writeJson(200, '设置成功');
    }
}