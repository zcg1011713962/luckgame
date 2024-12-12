<?php

namespace App\HttpController\Backoffice;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Report extends Controller
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
                        'account'=> [true, 'str', function($f){ return !empty(Helper::account_format_login($f)); }]
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

    public function bet_nums()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [true, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }],
                        'end_time' => [true, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->report_model->getGameBetNumsList($this->Pars['start_time'], $this->Pars['end_time'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    //获取游戏对库存变化的列表
    public function mainpool()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [true, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }],
                        'end_time' => [true, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->report_model->getMainpoolList($this->Pars['start_time'], $this->Pars['end_time'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function player_win()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'account'=> [false, 'str'],
                        'is_control'=> [false, 'int'],
                        'start_time' => [false, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }],
                        'end_time' => [false, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }],
                        'page'=> [false, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }],
                        'order_by'=> [false, 'str']
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->report_model->getPlayerWin($this->Pars['account'], $this->Pars['is_control'], $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['page'], 10, $this->Pars['order_by'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function all_players()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'keywords'=> [false, 'str'],
                        'page'=> [false, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }],
                        'order_by'=> [false, 'str']
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->report_model->getAllPlayers($this->Pars['keywords'], $this->Pars['page'], 20, $this->Pars['order_by'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function player_details()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'keywords'=> [false, 'str'],
                        'start_time' => [false, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }],
                        'end_time' => [false, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }],
                        'page'=> [false, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->report_model->getPlayerDetails($this->Pars['keywords'], $this->Pars['page'], 20, $this->Pars['start_time'], $this->Pars['end_time'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function today_mainpool()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [true, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }],
                        'end_time' => [true, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }]
                    ],
                    true
                ]
            ]);
        
        if ($auth) {
            if (($list = $this->report_model->getMainpool(0, $this->Pars['start_time'], $this->Pars['end_time'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    //本地子库存
    public function all_selfsubmainpool()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [true, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }],
                        'end_time' => [true, 'int', function($f) { return strtotime(date('Y-m-d H:i:s', $f)) == $f; }]
                    ],
                    true
                ]
            ]);
        
        if ($auth) {
            $list = $this->report_model->getSelfSubMainPool();
            if ($list === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }
}