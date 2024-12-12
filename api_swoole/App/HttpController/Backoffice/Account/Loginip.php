<?php
namespace App\HttpController\Backoffice\Account;

use App\Utility\Helper;
use EasySwoole\Http\AbstractInterface\Controller;
use EasySwoole\EasySwoole\Config;

class Loginip extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //$this->outLog = true;

        //检查请求参数
        return $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'username'=> [true, 'str', function($f){
                            if (substr_count($f, '.') === 1) {
                                $port = substr($f, 0, strpos($f, '.'));
                                if (is_numeric($port) && is_array($confList = Config::getInstance()->getConf('GAMESERVER.LIST')) && isset($confList[$port])) {
                                    $f = substr($f, strpos($f, '.')+1);
                                }
                            }
                            return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false;
                        }],
                        'act'=> [true, 'str', function($f){ return (in_array($f, ['addip','delip','editip','save'])) ? true : false; }],
                        'ip'=> [true, 'str', function($f){ return true; }],
                        'sip'=> [true, 'str', function($f){ return true; }]
                    ],
                    true
                ],
                [
                    Helper::HTTP_GET,
                    [
                        'username'=> [false, 'str', function($f){ return !empty($f); }],
                    ],
                    true
                ],
                [
                    Helper::HTTP_PUT,
                    [
                        'username'=> [false, 'str', function($f){ return !empty($f); }],
                        'act'=> [true, 'str', function($f){ return (in_array($f, ['save'])) ? true : false; }],
                        'state'=> [true, 'int', function($f){ return (in_array($f, [1, 2])) ? true : false; }],
                    ],
                    true
                ]
            ]
        );
    }

    public function index() {
        //获取登录ip数据
        if (($data = $this->account_model->getLoginIP($this->Pars['username'])) !== false) {
            return $this->writeJson(200, $data);
        }
        return $this->writeJson(9091, '获取数据失败', null, true);
    }

    public function index_put()
    {
        if($this->Pars['act'] == 'save') {
        //更改状态
            if (($_login = $this->account_model->saveLoginIPStatus($this->Pars['username'], $this->Pars['state'])) !== false) {
                return $this->writeJson(200, $_login);
            } else {
                return $this->writeJson(9091, '系统错误', null, true);
            }
        }
    }

    public function index_post()
    {
        if($this->Pars['act'] == 'addip') {
            //添加ip
            if (($_login = $this->account_model->addLoginIP($this->Pars['username'], $this->Pars['ip'])) !== false) {
                return $this->writeJson(200, $_login);
            } else {
                return $this->writeJson(9091, '系统错误', null, true);
            }

        } elseif($this->Pars['act'] == 'delip') {
            //删除ip
            if (($_login = $this->account_model->delLoginIP($this->Pars['username'], $this->Pars['ip'])) !== false) {
                return $this->writeJson(200, $_login);
            } else {
                return $this->writeJson(9091, '系统错误', null, true);
            }
        } elseif($this->Pars['act'] == 'editip') {
            //编辑
            if (($_login = $this->account_model->putLoginIP($this->Pars['username'], $this->Pars['ip'], $this->Pars['sip'])) !== false) {
                return $this->writeJson(200, $_login);
            } else {
                return $this->writeJson(9091, '系统错误', null, true);
            }
        }   else {
            return $this->writeJson(9091, '非法操作', null, true);
        }
    }
}