<?php

namespace App\HttpController\Backoffice;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Auth extends Controller
{
    public function index()
    {
        // TODO: Implement index() method.
    }

    public function generals()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'page'=> array(TRUE, 'abs', function($f){ return preg_match('/^[0-9]{10000}$/', $f); })
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->account_model->getAuths($this->Pars['page'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function general_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'username'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }],
                        'auth'=> [true, 'str', function($f){ return !empty($f); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (! $this->account_model->postAuth($this->Pars['username'], $this->Pars['auth'])) {
                return $this->writeJson(9010, '设置权限失败', null, true);
            }
            
            return $this->writeJson(200, '设置成功');
        }
    }

    public function general_delete()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_DELETE,
                    [
                        'id'=> [true, 'int', function($f){ return $f > 0; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (! $this->account_model->deleteAuth($this->Pars['id'])) {
                return $this->writeJson(9010, '删除权限失败', null, true);
            }
            
            return $this->writeJson(200, '删除成功');
        }
    }
}