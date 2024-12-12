<?php

namespace App\HttpController\Backoffice;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Platform extends Controller
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
                        'keywords' => [false, 'str'],
                        'page'=> array(TRUE, 'abs', function($f){ return preg_match('/^[0-9]{10000}$/', $f); })
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->platform_model->getPlatforms($this->Pars['keywords'], $this->Pars['page'])) === false) {
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
                        'name'=> [true, 'str', function($f) { return true; } ],
                        'api_whitelist'=> [true, 'str', function($f) { return true; } ],
                        'agent_username'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }],
                        'agent_password'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }],
                        'remark'=> [false, 'str', function($f) { return !empty($f); } ]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->platform_model->postPlatform($this->Pars['name'], $this->Pars['api_whitelist'], $this->Pars['agent_username'], $this->Pars['agent_password'], $this->Pars['remark'])) === false) {
                return $this->writeJson(9010, '新增平台失败', null, true);
            }
            return $this->writeJson(200, '新增平台成功');
        }
    }

    public function general_put()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_PUT,
                    [
                        'id'=> [true, 'int', function($f) { return $f > 0; } ],
                        'name'=> [false, 'str', function($f) { return true; } ],
                        'api_whitelist'=> [false, 'str', function($f) { return true; } ],
                        'remark'=> [false, 'str', function($f) { return !empty($f); } ]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->platform_model->putPlatform($this->Pars['id'], $this->Pars['name'], $this->Pars['api_whitelist'], $this->Pars['remark'])) === false) {
                return $this->writeJson(9010, '编辑平台失败', null, true);
            }
            return $this->writeJson(200, '编辑平台成功');
        }
    }

    public function general()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'id' => [true, 'int', function($f) { return $f > 0; } ]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($info = $this->platform_model->getPlatform($this->Pars['id'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, '查询成功', $info);
        }
    }

    public function api_password()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'id' => [true, 'int', function($f) { return $f > 0; } ]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($apiPassword = $this->platform_model->getApiPassword($this->Pars['id'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, '查询成功', $apiPassword);
        }
    }

    public function recharge_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'appid'=> [true, 'int', function($f) { return $f > 0; } ],
                        'coin'=> [true, 'str', function($f) { return is_numeric($f); } ],
                        'ipaddr'=> [false, 'str', function($f){ return !empty($f); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if ($this->platform_model->recharge($this->Pars['appid'], $this->Pars['coin'], $this->Pars['ipaddr']) === false) {
                return $this->writeJson(9010, '充值失败', null, true);
            }
            return $this->writeJson(200, '充值成功');
        }
    }
}