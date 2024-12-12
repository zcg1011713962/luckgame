<?php

namespace App\HttpController\Backoffice;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Config;

class System extends Controller
{
    public function index()
    {
        // TODO: Implement index() method.
    }
    
    public function test111()
    {
        return $this->writeJson(200, ['msg'=> 'success']);
    }
    
    public function import_account_post()
    {
        $this->outLog = true;
        
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'parstrings'=> [true, 'str', function($f){ return !empty($f); }]
                    ],
                    false
                ]
             ]);
        
        if ($auth) {
            $this->system_model->_importAccount($this->Pars['parstrings'] ?? '');
            
            return $this->writeJson(200, ['msg'=> 'success']);
        }
    }
    
    public function import_account2_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'agent_id'=> [true, 'abs', function($f){ return $f > 0 && $f == abs($f); }],
                        'initcoin'=> [true, 'abs', function($f){ return $f > 0 && $f == abs($f); }],
                        'p'=> [false, 'str', function($f){ return in_array($f, ['bb','poly']); }]
                    ],
                    false
                ]
            ]);
        
        if ($auth) {
            
            if (! isset($this->Pars['p']) || $this->Pars['p'] == 'poly') {
                if (! $this->system_model->_import2Account($this->Pars['agent_id'], $this->Pars['initcoin'])) {
                    return $this->writeJson(3003, '失败', null, true);
                }
            } else {
                if (! $this->system_model->_import3Account($this->Pars['agent_id'], $this->Pars['initcoin'])) {
                    return $this->writeJson(3003, '失败', null, true);
                }
            }
            
            return $this->writeJson(200, '成功');
        }
    }

    /**
     * 重置BB的密码
     * @return bool
     */
    public function rest_account2_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'agent_id'=> [true, 'abs', function($f){ return $f > 0 && $f == abs($f); }],
                        'initcoin'=> [true, 'abs', function($f){ return $f > 0 && $f == abs($f); }],
                        'p'=> [false, 'str', function($f){ return in_array($f, ['bb','poly']); }],
                        'pwd'=> [false, 'str', function($f){ return !empty($f); }],
                    ],
                    false
                ]
            ]);

        if ($auth) {
            $pwd = $this->Pars['pwd'];
            if(empty($pwd) || $pwd!= 'Aa1111') {
                $pwd = '123456';
            }
            if (! $this->system_model->_reset3Account($this->Pars['agent_id'], $this->Pars['initcoin'], $pwd)) {
                return $this->writeJson(3003, '失败', null, true);
            }
            return $this->writeJson(200, '成功');
        }
    }

    /**
     * API日志
     * 添加
     * 代理接口
     */
    public function log_agent_api_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'account_agent'=> [true, 'abs', function($f){ return is_numeric($f) && $f > 0; }],
                        'account_id'=> [true, 'abs', function($f){ return is_numeric($f) && $f > 0; }],
                        'account_vid'=> [false, 'abs', function($f){ return is_numeric($f); }],
                        'ip'=> [true, 'str', function($f){ return !empty($f); }],
                        'os'=> [false, 'str', function($f){ return !empty($f); }],
                        'browser'=> [false, 'str', function($f){ return !empty($f); }],
                        't'=> [false, 'str', function($f){ return !empty($f); }],
                        't2'=> [false, 'str', function($f){ return !empty($f); }],
                        'detail'=> [false, 'str', function($f){ return !empty($f); }],
                        'detail2'=> [false, 'str', function($f){ return !empty($f); }],
                        'request'=> [false, 'str', function($f){ return !empty($f); }],
                        'response'=> [false, 'str', function($f){ return !empty($f); }],
                        'create_time'=> [true, 'abs', function($f){ return is_numeric($f) && $f > 0; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (!$this->system_model->postAgentApiLogs($this->Pars)) {
                return $this->writeJson(3003, '添加失败。', null, true);
            }

            return $this->writeJson(200, $this->Pars);
        }
    }

    /**
     * API日志
     * 查询记录
     * 代理接口
     */
    public function log_agent_api()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'lan'=> [false, 'abs', function($f){ return in_array($f, ['1','2']); }],
                        'agent'=> [false, 'abs', function($f){ return $f>0 && $f<4; }],
                        'username'=> [false, 'str', function($f){ return !empty($f); }],
                        'nickname'=> [false, 'str', function($f){ return !empty($f); }],
                        'accountid'=> [false, 'abs', function($f){ return $f>0; }],
                        'ip'=> [false, 'str', function($f){ return !empty($f) && filter_var($f, FILTER_VALIDATE_IP); }],
                        'os'=> [false, 'str', function($f){ return !empty($f); }],
                        'browser'=> [false, 'str', function($f){ return !empty($f); }],
                        't'=> [false, 'str', function($f){ return !empty($f); }],
                        'detail'=> [false, 'str', function($f){ return !empty($f); }],
                        'time'=> [false, 'abs', function($f){ return $f>0; }],
                        'time2'=> [false, 'abs', function($f){ return $f>0; }],
                        'orderby'=> [false, 'str'],
                        'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->getAgentApiLogs($this->Pars)) === false) {
                return $this->writeJson(3003, '查询失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 系统参数设置
     */
    public function setting_put()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_PUT,
                    [
                        'pars'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9\+\/]{30,9999}$/i', $f) ? true : false; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->putSystemPars($this->Pars['pars'])) === false) {
                return $this->writeJson(3003, '操作失败。', null, true);
            }

            return $this->writeJson(200, ['msg'=> '操作成功']);
        }
    }

    /**
     * 系统参数获取
     */
    public function setting()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($data = $this->system_model->getSystemPars()) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $data);
        }
    }

    /**
     * 添加客户端公告
     */
    public function notice_client_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'content'=> [true, 'str', function($f){ return true; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->postNoticeClient($this->Pars['content'])) === false) {
                return $this->writeJson(3003, '添加客户端公告失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 编辑客户端公告
     */
    public function notice_client_put()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_PUT,
                    [
                        'id'=> [true, 'int', function($f){ return preg_match('/^[0-9]+$/i',$f) ? true : false; }],
                        'content'=> [true, 'str', function($f){ return true; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->putNoticeClient($this->Pars['id'], $this->Pars['content'])) === false) {
                return $this->writeJson(3003, '编辑客户端公告失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 获取客户端详情
     */
    public function notice_client()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($data = $this->system_model->getNoticeClient()) === false) {
                return $this->writeJson(3003, '获取客户端详情失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 添加跑马灯
     */
    public function marquee_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'start_time' => [true, 'str', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }],
                        'counts' => [true, 'str', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }],
                        'interval' => [true, 'str', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }],
                        'content'=> [true, 'str', function($f){ return true; }],
                        'contenten'=> [true, 'str', function($f){ return true; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->postMarquee($this->Pars['start_time'], $this->Pars['counts'], $this->Pars['interval'], $this->Pars['content'], $this->Pars['contenten'])) === false) {
                return $this->writeJson(3003, '添加跑马灯失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 编辑跑马灯
     */
    public function marquee_put()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_PUT,
                    [
                        'id'=> [true, 'str', function($f){ return preg_match('/^[0-9]+$/i',$f) ? true : false; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->putMarquee($this->Pars['id'])) === false) {
                return $this->writeJson(3003, '编辑跑马灯失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 获取跑马灯详情
     */
    public function marquee()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'id'=> [true, 'str', function($f){ return preg_match('/^[0-9]+$/i',$f) ? true : false; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->getMarquee($this->Pars['id'])) === false) {
                return $this->writeJson(3003, '获取跑马灯详情失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 获取跑马灯列表
     */
    public function marquees()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }],
                        'status'=> [true, 'str', function($f){ return in_array($f, array('all', 'open', 'cancel')); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->getMarquees($this->Pars['page'], $this->Pars['status'])) === false) {
                return $this->writeJson(3003, '获取跑马灯列表失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * Bigbang开奖
     */
    public function bigbang_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'account'=> [true, 'str', function($f){ return !empty(Helper::account_format_login($f)); }],
                        'coin' => [true, 'str', function($f){ return $f >= 10 && $f <= 10000; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->postBigbang($this->Pars['account'], $this->Pars['coin'])) === false) {
                return $this->writeJson(3003, '添加Bigbang开奖失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * Bigbang开奖列表
     */
    public function bigbangs()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'times'=> [false, 'str', function($f){ return is_array($_ts = explode(".", $f)) && count($_ts) === 2 && is_numeric($_ts[0]) && is_numeric($_ts[1]) && $_ts[1] > $_ts[0]; }],
                        'account'=> [false, 'str'],
                        'orderby'=> [false, 'str'],
                        'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{10000}$/', $f); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->getBigbangs($this->Pars['page'], 10, $this->Pars['times'], $this->Pars['account'], $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '获取Bigbang开奖列表失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * jackpot开奖列表
     */
    public function jackpots()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'times'=> [false, 'str', function($f){ return is_array($_ts = explode(".", $f)) && count($_ts) === 2 && is_numeric($_ts[0]) && is_numeric($_ts[1]) && $_ts[1] > $_ts[0]; }],
                        'account'=> [false, 'str'],
                        'orderby'=> [false, 'str'],
                        'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{10000}$/', $f); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->getJackpots($this->Pars['page'], 10, $this->Pars['times'], $this->Pars['account'], $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '获取jackpot开奖列表失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 救济红包列表
     */
    public function redbags()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'times'=> [false, 'str', function($f){ return is_array($_ts = explode(".", $f)) && count($_ts) === 2 && is_numeric($_ts[0]) && is_numeric($_ts[1]) && $_ts[1] > $_ts[0]; }],
                        'account'=> [false, 'str'],
                        'orderby'=> [false, 'str'],
                        'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{10000}$/', $f); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->getRedbags($this->Pars['page'], 10, $this->Pars['times'], $this->Pars['account'], $this->Pars['orderby'])) === false) {
                return $this->writeJson(3003, '获取redbags列表失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 游戏列表
     */
    public function games()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'lang'=> [false, 'int', function($f){ return in_array($f, [1,2]); }],
                        'uniq'=> [false, 'int', function($f){ return in_array($f, [0,1]); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->getGames($this->Pars['lang'], $this->Pars['uniq'])) === false) {
                return $this->writeJson(3003, '获取游戏列表失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 根据游戏ID获取概率配置json
     */
    public function prob()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'id'=> [true, 'int', function($f){ return preg_match('/^[0-9]*$/', $f); }],
                        'type' => [true, 'int', function($f){ return in_array($f, [1,2,3,4,5]); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->getProbByGameId($this->Pars['id'], $this->Pars['type'])) === false) {
                return $this->writeJson(3003, '获取概率失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 修改概率配置
     */
    public function prob_put()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_PUT,
                    [
                        'id'=> [true, 'int', function($f){ return preg_match('/^[0-9]*$/', $f); }],
                        'type' => [true, 'int', function($f){ return in_array($f, [1,2,3,4,5]); }],
                        'prob' => [true, 'str', function($f){ return !is_null(json_decode($f)); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->putProb($this->Pars['id'], $this->Pars['type'], $this->Pars['prob'])) === false) {
                return $this->writeJson(3003, '修改概率配置失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 修改游戏状态
     */
    public function game_status_put()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_PUT,
                    [
                        'id'=> [true, 'int', function($f){ return preg_match('/^[0-9]*$/', $f); }],
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->putGameStatus($this->Pars['id'])) === false) {
                return $this->writeJson(3003, '修改游戏状态失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * redis
     * 余额
     * 彩池 poolnormal
     * 重置为0
     * 抹掉
     */
    public function redis_balance_poolnormal_flush_put()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($data = $this->system_model->_redisBalancePoolnormalFlush()) === false) {
                return $this->writeJson(3003, '重置彩池失败。', null, true);
            }

            return $this->writeJson(200, ['result'=> $data ? 'success' : 'fail']);
        }
    }

    /**
     * redis
     * 余额
     * JP池 pooljp
     * 重置为0
     * 抹掉
     */
    public function redis_balance_pooljp_flush_put()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($data = $this->system_model->_redisBalancePooljpFlush()) === false) {
                return $this->writeJson(3003, '重置JP池失败。', null, true);
            }

            return $this->writeJson(200, ['result'=> $data ? 'success' : 'fail']);
        }
    }

    /**
     * redis
     * 余额
     * Tax池 pooltax
     * 重置为0
     * 抹掉
     */
    public function redis_balance_pooltax_flush_put()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($data = $this->system_model->_redisBalancePooltaxFlush()) === false) {
                return $this->writeJson(3003, '重置Tax池失败。', null, true);
            }

            return $this->writeJson(200, ['result'=> $data ? 'success' : 'fail']);
        }
    }

    /**
     * 获取游戏服务器列表（状态）
     */
    public function gameserverlist()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            $_r = $this->curl_model->getGameServerList();
            return $this->writeJson(200, $_r ?: []);
        }
    }

    /**
     * 修改游戏服务器状态
     */
    public function gameserverlist_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'servername'=> [true, 'str', function($f){ return !empty($f) && strlen($f) > 0; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            $_r = $this->curl_model->pushGameServerList($this->Pars['servername']);
            return $this->writeJson(200, ['result'=> $_r ? 'success' : 'fail']);
        }
    }

    /**
     * 税池清空列表
     */
    public function tax_empty_log()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{10000}$/', $f); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->system_model->emptyTaxLog($this->Pars['page'], 20)) === false) {
                return $this->writeJson(3003, '获取税池清空列表失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    /**
     * 修改小游戏标签
     */
    public function game_tag_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'ids'=> [true, 'str', function($f){ return !empty($f) && strlen($f) > 0; }],
                        'tag' => [true, 'int', function($f){ return preg_match('/^[0-9]{10000}$/', $f); }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            $_r = $this->curl_model->pushGameTag($this->Pars['ids'], $this->Pars['tag']);
            return $this->writeJson(200, ['result'=> $_r ? 'success' : 'fail']);
        }
    }

    /**
     * 获取多人游戏设置
     */
    public function multgamesetting()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'username'=> [true, 'str'],
                        'game_id' => [true, 'int', function($f){ return $f > 0; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            $_r = $this->system_model->getMultgamesetting($this->Pars['username'], $this->Pars['game_id']);
            if ($_r) {
                return $this->writeJson(200, $_r ?: []);
            }
            return $this->writeJson(3003, '获取失败', null, true);
        }
    }

    /**
     * 修改多人游戏设置
     */
    public function multgamesetting_put()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_PUT,
                    [
                        'username'=> [true, 'str'],
                        'game_id' => [true, 'int', function($f){ return $f > 0; }],
                        'setting' => [true, 'str']
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            $_r = $this->system_model->setMultgamesetting($this->Pars['username'], $this->Pars['game_id'], $this->Pars['setting']);
            if ($_r) {
                return $this->writeJson(200, '操作成功');
            }
            return $this->writeJson(3003, '操作成功', null, true);
        }
    }

    /**
     * 获取多人游戏
     */
    public function multgame()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            $_r = $this->curl_model->getMultgame();
            if ($_r) {
                return $this->writeJson(200, $_r ?: []);
            }
            return $this->writeJson(3003, '获取失败', null, true);
        }
    }

    /**
     * 获取地区列表
     */
    public function regions()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            $_r = $this->system_model->getRegions();
            if ($_r) {
                return $this->writeJson(200, $_r ?: []);
            }
            return $this->writeJson(3003, '获取失败', null, true);
        }
    }

    /**
     * 添加代理设置
     */
    public function account_setting_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'red_envelope_switch'=> [true, 'int', function($f){ return is_numeric($f); }],
                        'red_envelope_max'=> [true, 'str', function($f){ return $f > 0; }],
                        'red_envelope_min'=> [true, 'str', function($f){ return $f > 0; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            $data = [
                'red_envelope_switch' => $this->Pars['red_envelope_switch'],
                'red_envelope_max' => $this->Pars['red_envelope_max'],
                'red_envelope_min' => $this->Pars['red_envelope_min']
            ];
            if ($this->system_model->postAccountSetting($data) === false) {
                return $this->writeJson(3003, '操作失败', null, true);
            }

            return $this->writeJson(200, '操作成功');
        }
    }

    /**
     * 获取多人游戏
     */
    public function account_setting()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            $data = $this->system_model->getAccountSetting();
            return $this->writeJson(200, $data);
        }
    }

    /**
     * 修改游戏排序
     */
    public function game_sort_put()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_PUT,
                    [
                        'id'=> [true, 'int', function($f){ return preg_match('/^[0-9]*$/', $f); }],
                        'type'=> [true, 'int', function($f){ return preg_match('/^[0-9]*$/', $f); }],
                        'ord'=> [true, 'int', function($f){ return preg_match('/^[0-9]*$/', $f); }],
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->curl_model->putGameSort($this->Pars['id'], $this->Pars['type'], $this->Pars['ord'])) === false) {
                return $this->writeJson(3003, '修改游戏排序失败。', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }
}