<?php

namespace App\HttpController\Backoffice;

use App\Utility\Helper;
use EasySwoole\Http\AbstractInterface\Controller;

class Stat extends Controller
{
    public function index()
    {
        // TODO: Implement index() method.
    }

    public function welcome()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($data = $this->stat_model->getWelcome()) === FALSE) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    public function stat_sysexclusive_bygameid()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'time2' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (! ($data = $this->stat_model->getStatSysExclusiveByGameid($this->Pars['time'], $this->Pars['time2']))) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 报表
     * 系统管理员专用的报表
     * 大玩家
     */
    public function stat_sysexclusive_superplayer()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'time2' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getStatSysExclusiveSuperPlayer($this->Pars['time'], $this->Pars['time2'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 报表
     * 系统管理员专用的报表
     * 大赢家
     */
    public function stat_sysexclusive_superwiner()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'time2' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getStatSysExclusiveSuperWiner($this->Pars['time'], $this->Pars['time2'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 报表
     * 日
     * 系统赢钱
     */
    public function stat_daily_syswin()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time' => [false, 'str'],
                        'time2' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getStatDailySyswin($this->Pars['time'], $this->Pars['time2'], $this->Pars['page'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 报表
     * 实时
     * 玩家在线数
     */
    public function stat_online_player()
    {
        $auth = $this->colationPars(true);
        
        if ($auth) {
            $_online = $this->curl_model->getStatServerOnlineTotal();
            return $this->writeJson(200, ['online' => $_online]);
        }
    }

    /**
     * 报表
     * 30分钟
     * 玩家在线数
     */
    public function stat_30min_online_player()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'time2' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getStat30minOnlinePlayer($this->Pars['time'], $this->Pars['time2'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 报表
     * 30分钟
     * 玩家余额
     */
    public function stat_30min_coin_player()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'time2' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getStat30minCoinPlayer($this->Pars['time'], $this->Pars['time2'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 报表
     * 5分钟
     * 普通池（彩池）存量
     */
    public function stat_5min_pool_normal()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'time2' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getStat5minPoolNormal($this->Pars['time'], $this->Pars['time2'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 报表
     * 5分钟
     * JP池存量
     */
    public function stat_5min_pool_jp()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'time2' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getStat5minPoolJp($this->Pars['time'], $this->Pars['time2'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 报表
     * 5分钟
     * Tax池存量
     */
    public function stat_5min_pool_tax()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'time2' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getStat5minPoolTax($this->Pars['time'], $this->Pars['time2'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 报表
     * 实时
     * 分游戏玩家在线数
     */
    public function stat_game_online_player()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'gameid' => [true, 'str', function ($f) { return !empty($f); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            $_online = $this->curl_model->getStatServerGameOnline($this->Pars['gameid']);
            return $this->writeJson(200, $_online);
        }
    }

    /**
     * 报表
     * 5分钟
     * 分游戏玩家在线数
     */
    public function stat_5min_game_online_player()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'time2' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getStat5minGameOnlinePlayer($this->Pars['time'], $this->Pars['time2'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 玩家查账
     */
    public function players()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [true, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'end_time' => [true, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'account' => [true, 'str', function ($f) {
                            return !empty(Helper::account_format_login($f));
                        }],
                        'orderby' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getPlayerCoinByDay(Helper::account_format_login($this->Pars['account']), $this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 代理查账
     */
    public function agents()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'end_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'username' => [false, 'str', function ($f) {
                            return preg_match('/^[a-zA-Z0-9]{5,30}$/i', $f) ? true : false;
                        }],
                        'orderby' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getAgentCoinByDate($this->Pars['username'], $this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 代理查账明细
     */
    public function agents_detail()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'end_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'username' => [false, 'str', function ($f) {
                            return preg_match('/^[a-zA-Z0-9]{5,30}$/i', $f) ? true : false;
                        }],
                        'orderby' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getAgentCoinDetailByDay($this->Pars['username'], $this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 总代报表
     */
    public function general_agent_report()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'end_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'username' => [false, 'str', function ($f) {
                            return preg_match('/^[a-zA-Z0-9]{5,30}$/i', $f) ? true : false;
                        }],
                        'field' => [false, 'str'],
                        'order' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->generalAgentReport($this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['field'], $this->Pars['order'], $this->Pars['username'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 游戏记录
     */
    public function game_records()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'end_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'account' => [true, 'str', function ($f) {
                            return !empty(Helper::account_format_login($f));
                        }],
                        'min_coin' => [false, 'str', function ($f) {
                            return is_numeric($f);
                        }],
                        'max_coin' => [false, 'str', function ($f) {
                            return is_numeric($f);
                        }],
                        'orderby' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->gameRecord(Helper::account_format_login($this->Pars['account']), $this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['min_coin'], $this->Pars['max_coin'], $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    public function level_search()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'account_id' => [false, 'int'],
                        'start_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'end_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->levelSearch($this->Pars['account_id'], $this->Pars['start_time'], $this->Pars['end_time'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    public function level_search_detail()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'end_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'account_id' => [false, 'int'],
                        'orderby' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->levelSearchDetail($this->Pars['account_id'], $this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * Bigbang累计开奖
     */
    public function bigbang()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($data = $this->stat_model->getBigBangAcc()) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 游戏配置分数数据
     */
    public function game_setting_coin_data()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($data = $this->stat_model->historyCoin()) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 游戏配置实时数据
     */
    public function game_setting_cur_data()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($data = $this->stat_model->curPondData()) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    // 玩家游戏记录列表
    ////////////////////////////////////////////貌似可以删除
    public function player_game_log()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'account_id' => [false, 'int'],
                        'game_id' => [false, 'int'],
                        'start_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'end_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'orderby' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getPlayerGameLog($this->Pars['account_id'], $this->Pars['game_id'], $this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    // 代理列表
    public function agent_list()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'keywords' => [false, 'str'],
                        'orderby' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getAgentList($this->Pars['keywords'], $this->Pars['page'], 10, 0, 0, $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    // 代理上下分记录列表
    public function agent_score_log()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'keywords' => [false, 'str'],
                        'orderby' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getAgentScoreLog($this->Pars['keywords'], $this->Pars['page'], 10, 0, 0, $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    // 获取抽水
    public function commission()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'end_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getCommission($this->Pars['start_time'], $this->Pars['end_time'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, '', $data);
        }
    }

    /**
     * 总代报表明细
     */
    public function general_agent_report_detail()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'end_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'account_id' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->generalAgentReportDetail($this->Pars['page'], 10, $this->Pars['account_id'], $this->Pars['start_time'], $this->Pars['end_time'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * bigbang查询
     */
    public function bigbang_list()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'end_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'account_id' => [false, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }],
                        'field' => [false, 'str'],
                        'order' => [false, 'str']
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getBigbangList($this->Pars['page'], 10, $this->Pars['account_id'], $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['field'], $this->Pars['order'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * bigbang查询
     */
    public function bigbang_detail()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'end_time' => [false, 'str', function ($f) {
                            return preg_match("/^([0-9]{4})-([0-9]{2})-([0-9]{2})$/", $f);
                        }],
                        'account_id' => [false, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }],
                        'field' => [false, 'str'],
                        'order' => [false, 'str']
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getBigbangDetail($this->Pars['page'], 10, $this->Pars['account_id'], $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['field'], $this->Pars['order'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 代理总账
     */
    public function agent_total_report()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'id' => [false, 'str'],
                        'start_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'end_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'page' => [true, 'abs', function ($f) { return preg_match('/^[0-9]{10000}$/', $f); }],
                        'username' => [false, 'str', function ($f) { return true; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getAgentTotalReport($this->Pars['page'], 20, $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['username'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 玩家总账
     */
    public function player_total_report()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'end_time'   => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'page'       => [true, 'abs', function ($f) { return preg_match('/^[0-9]{10000}$/', $f); }],
                        'username'   => [false, 'string'],
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getPlayerTotalReport($this->Pars['username'], $this->Pars['page'], 1000, $this->Pars['start_time'], $this->Pars['end_time'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 对账
     */
    public function check_accounts()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->checkAccountList($this->Pars['page'], 20)) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 游戏记录
     */
    public function game_records_poly()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'end_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'account' => [true, 'str', function ($f) { return !empty(Helper::account_format_login($f)); }],
                        'orderby' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) { return preg_match('/^[0-9]{10000}$/', $f); }],
                        'type' => [true, 'abs', function ($f) { return preg_match('/^[0-9]{1}$/', $f); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->gameRecordPoly(Helper::account_format_login($this->Pars['account']), $this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['orderby'],$this->Pars['type'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 游戏记录
     */
    public function game_record_detail()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'log_id' => [true, 'int', function ($f) { return $f > 0; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->gameRecordDetail($this->Pars['log_id'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 新手策略详细列表
     */
    public function new_strategy_list()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->newStrategyList($this->Pars['page'], 10)) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

     /**
     * 新手策略打点数据
     */
    public function new_strategy_count()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->newStrategyCountList($this->Pars['page'], 10)) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    public function red_envelope_record()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'keywords' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getRedEnvelopeRecord($this->Pars['keywords'], $this->Pars['page'], 10)) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    //总代给游戏内玩家发红包列表
    public function red_packet_record()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'keywords' => [false, 'str'],
                        'start_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'end_time' => [false, 'int', function ($f) { return strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getRedPacketRecord($this->Pars['keywords'], $this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    //总代给游戏内玩家发红包设定
    public function red_packet_setting_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'content' => [false, 'str'],
                        'coin' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->setRedPacket($this->Pars['content'], $this->Pars['coin'])) === false) {
                return $this->writeJson(3003, '发红包失败', null, true);
            }
            return $this->writeJson(200, '发红包成功', ['msg'=> '操作成功']);
        }
    }

    /**
     * 推广员一级玩家列表
     */
    public function user_list()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'account_id' => [true, 'int', function($f) { return $f > 0; }],
                        'keywords' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getPlayerCoinByDay(Helper::account_format_login($this->Pars['account_id']), $this->Pars['keywords'], $this->Pars['page'], 10)) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 单个玩家分别对五级代理的分成记录
     */
    public function divide_record()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'account' => [true, 'str'],
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getDivideRecord($this->Pars['account'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 玩家总流水
     */
    public function total_flows()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'account' => [true, 'str'],
                        'start_time' => [true, 'int'],
                        'end_time' => [true, 'int'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getTotalFlows($this->Pars['account'], $this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['page'], 10)) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 转账记录
     */
    public function transfer()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'username' => [false, 'str'],
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10000}$/', $f);
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getTransfer($this->Pars['username'], $this->Pars['page'], 10)) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 游戏统计
     */
    public function game_stat()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'field' => [true, 'str'],
                        'order' => [true, 'str'],
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->stat_model->getGameStat($this->Pars['field'], $this->Pars['order'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }
    
    public function game_stat2()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time_min_start' => [true, 'str'],
                        'time_min_end' => [true, 'str'],
                        'field' => [true, 'str'],
                        'order' => [true, 'str']
                    ],
                    true
                ]
            ]
            );
        
        if ($auth) {
            if (! ($data = $this->stat_model->getGameStat2($this->Pars['time_min_start'], $this->Pars['time_min_end'], $this->Pars['field'], $this->Pars['order']))) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            
            return $this->writeJson(200, $data);
        }
    }
    
    public function game_stat3()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'time_min_start' => [true, 'str'],
                        'time_min_end' => [true, 'str'],
                        'min' => [true, 'str', function($f){ return in_array($f, ['30', '60', '1440']); }]
                    ],
                    true
                ]
            ]
            );
        
        if ($auth) {
            if (! ($data = $this->stat_model->getGameStat3($this->Pars['time_min_start'], $this->Pars['time_min_end'], $this->Pars['min']))) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            
            return $this->writeJson(200, $data);
        }
    }
}