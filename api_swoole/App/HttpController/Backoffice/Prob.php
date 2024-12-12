<?php

namespace App\HttpController\Backoffice;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Prob extends Controller
{
    public function index()
    {
        // TODO: Implement index() method.
    }

    public function player_ip()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'account' => [true, 'str', function ($f) {
                            return !empty(Helper::account_format_login($f));
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->report_model->getPlayerLast10LoginIP(Helper::account_format_login($this->Pars['account']))) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    /**
     * 概率控制查询列表
     */
    public function generals()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'keyword'=> array(FALSE, 'str', function($f){ return ! preg_match('/[\'.,:;*?~`!@#$%^&+=)(<>{}]|\]|\[|\/|\\\|\"|\|/',$f); }),
                        'orderby'=> array(FALSE, 'str'),
                        'page'=> array(TRUE, 'abs', function($f){ return preg_match('/^[0-9]{10000}$/', $f); })
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->prob_model->getProbs($this->Pars['page'], $this->Pars['keyword'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    /**
     * 添加概率控制
     */
    public function general_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'account_id' => array(TRUE, 'str', function ($f) {
                            return preg_match('/^\d$/i', $f);
                        }),
                        'prob' => array(TRUE, 'str', function ($f) {
                            return preg_match('/^\d$/i', $f);
                        }),
                        'duration' => array(TRUE, 'str', function ($f) {
                            return preg_match('/^\d$/i', $f);
                        })
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->prob_model->postProb($this->Pars['account_id'], $this->Pars['prob'], $this->Pars['duration'])) === false) {
                return $this->writeJson(3003, '添加概率控制失败。', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    /**
     * 获取所有一级代理
     */
    public function first_proxy()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'keyword'=> array(FALSE, 'str', function($f){ return ! preg_match('/[\'.,:;*?~`!@#$%^&+=)(<>{}]|\]|\[|\/|\\\|\"|\|/',$f); }),
                        'page'=> array(TRUE, 'abs', function($f){ return preg_match('/^[0-9]{10000}$/', $f); })
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->prob_model->getProxys($this->Pars['page'], $this->Pars['keyword'])) === false) {
                return $this->writeJson(3003, '查询失败。', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    /**
     * 根据条件获取玩家
     */
    public function players()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'keyword'=> array(FALSE, 'str', function($f){ return ! preg_match('/[\'.,:;*?~`!@#$%^&+=)(<>{}]|\]|\[|\/|\\\|\"|\|/',$f); }),
                        'vip'=> array(FALSE, 'int'),
                        'page'=> array(TRUE, 'abs', function($f){ return preg_match('/^[0-9]{10000}$/', $f); })
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->prob_model->getPlayers($this->Pars['page'], $this->Pars['keyword'], $this->Pars['vip'])) === false) {
                return $this->writeJson(3003, '查询失败。', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    /**
     * 添加概率控制
     */
    public function batch_add_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'keyword'=> array(FALSE, 'str', function($f){ return ! preg_match('/[\'.,:;*?~`!@#$%^&+=)(<>{}]|\]|\[|\/|\\\|\"|\|/',$f); }),
                        'type' => array(TRUE, 'str', function ($f) { return in_array($f, array('proxy', 'player')); }),
                        'prob' => array(TRUE, 'str', function ($f) { return preg_match('/^\d$/i', $f); }),
                        'duration' => array(TRUE, 'str', function ($f) { return preg_match('/^\d$/i', $f); })
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->prob_model->postBatchProb($this->Pars['type'], $this->Pars['prob'], $this->Pars['duration'], $this->Pars['keyword'])) === false) {
                return $this->writeJson(3003, '添加概率控制失败。', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }
}