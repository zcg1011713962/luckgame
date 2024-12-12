<?php

namespace App\HttpController\Backoffice;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

/**
 * 运营活动
 */

class Activity extends Controller
{
    public function index()
    {
        // TODO: Implement index() method.
    }

    public function value_setting()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($list = $this->activity_model->getValueSettings()) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function value_setting_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'key'=> [true, 'str'],
                        'value'=> [true, 'str']
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->activity_model->postValueSettings($this->Pars['key'], $this->Pars['value'])) === false) {
                return $this->writeJson(3003, '添加失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function lucky_redbag()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($list = $this->activity_model->getLuckyRedbags()) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function lucky_redbag_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'data'=> [true, 'str', function($f){ return true; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->activity_model->postLuckyRedbag($this->Pars['data'])) === false) {
                return $this->writeJson(3003, '添加失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function rainy_redbag()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($list = $this->activity_model->getRainyRedbags()) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function rainy_redbag_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'data'=> [true, 'str', function($f){ return true; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->activity_model->postRainyRedbag($this->Pars['data'])) === false) {
                return $this->writeJson(3003, '添加失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function rainy_redbag_setting_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'send_time'=> [true, 'str', function($f){ return true; }],
                        'prob' => [true, 'str', function($f) { return is_numeric($f); }],
                        'total' => [true, 'str', function($f) { return is_numeric($f); }],
                        'end_time' => [true, 'int', function($f) { return is_numeric($f); }],
                        'remark' => [false, 'str']
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            $data = [
                'send_time' => $this->Pars['send_time'],
                'prob' => $this->Pars['prob'],
                'total' => $this->Pars['total'],
                'end_time' => $this->Pars['end_time']
            ];
            $this->Pars['remark'] && $data['remark'] = $this->Pars['remark'];
            if (($rs = $this->activity_model->postRainyRedbagSetting($data)) === false) {
                return $this->writeJson(3003, '设置失败', null, true);
            }
            return $this->writeJson(200, '设置成功');
        }
    }

    public function rainy_redbag_setting()
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
            if (($data = $this->activity_model->getRainyRedbagSettings($this->Pars['page'], 10)) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    public function rainy_redbag_setting_put()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_PUT,
                    [
                        'id' => [true, 'int', function($f) { return $f > 0; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->activity_model->putRainyRedbagSettings($this->Pars['id'])) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    public function add_jackpot_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'coin'=> [true, 'str', function($f){ return is_numeric($f) && Helper::format_money($f) >0; }],
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->activity_model->addJackpot($this->Pars['coin'])) === false) {
                return $this->writeJson(3003, '充值失败', null, true);
            }

            return $this->writeJson(200, '充值成功');
        }
    }

    public function activity_jackpot()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($rs = $this->activity_model->getActivityJackpot()) === false) {
                return $this->writeJson(3003, '获取失败', null, true);
            }
            return $this->writeJson(200, '', $rs);
        }
    }

    public function lucky_redbag_setting()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($rs = $this->activity_model->getLuckyRedbagSetting()) === false) {
                return $this->writeJson(3003, '获取失败', null, true);
            }
            return $this->writeJson(200, '', $rs);
        }
    }

    public function lucky_redbag_setting_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'share_nums'=> [true, 'str'],
                        'switch'=> [true, 'str', function($f){ return in_array($f, [0, 1]); }],
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($data = $this->activity_model->postLuckyRedbagSetting($this->Pars['share_nums'], $this->Pars['switch'])) === false) {
                return $this->writeJson(3003, '设置失败', null, true);
            }

            return $this->writeJson(200, '设置成功');
        }
    }

    public function growth_value()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($list = $this->activity_model->getGrowthValues()) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function growth_value_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'data'=> [true, 'str', function($f){ return true; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->activity_model->postGrowthValue($this->Pars['data'])) === false) {
                return $this->writeJson(3003, '添加失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function lucky_box()
    {
        $auth = $this->colationPars(true);

        if ($auth) {
            if (($list = $this->activity_model->getLuckyBoxs()) === false) {
                return $this->writeJson(3003, '查询失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function lucky_box_post()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_POST,
                    [
                        'data'=> [true, 'str', function($f){ return true; }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (($list = $this->activity_model->postLuckyBox($this->Pars['data'])) === false) {
                return $this->writeJson(3003, '添加失败', null, true);
            }
            return $this->writeJson(200, $list);
        }
    }

    public function stat_lucky_redbag()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false;
                        }],
                        'start_time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'end_time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (! ($data = $this->activity_model->getStatLuckyRedbag($this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time']))) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    public function stat_rainy_redbag()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false;
                        }],
                        'start_time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'end_time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (! ($data = $this->activity_model->getStatRainyRedbag($this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time']))) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }

    public function stat_lucky_box()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'page' => [true, 'abs', function ($f) {
                            return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false;
                        }],
                        'start_time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }],
                        'end_time' => [TRUE, 'abs', function ($f) {
                            return preg_match('/^[0-9]{10,15}$/i', $f) ? true : false;
                        }]
                    ],
                    true
                ]
            ]
        );

        if ($auth) {
            if (! ($data = $this->activity_model->getStatLuckyBox($this->Pars['page'], 10, $this->Pars['start_time'], $this->Pars['end_time']))) {
                return $this->writeJson(3003, '查询失败', null, true);
            }

            return $this->writeJson(200, $data);
        }
    }
}