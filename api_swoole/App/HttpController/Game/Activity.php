<?php
namespace App\HttpController\Game;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Activity extends Controller
{
    public function index()
    {
        // TODO: Implement index() method.
    }

    public function lucky_redbag()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'account_id'=> [true, 'int', function($f){ return $f > 0; }]
                    ],
                    false
                ]
            ]
        );

        if ($auth) {
            if (($rs = $this->activity_model->getLuckyRedbag($this->Pars['account_id'])) === false) {
                return $this->writeJson(3003, '获取失败', null, true);
            }
            return $this->writeJson(200, $rs);
        }
    }

    public function open_lucky_redbag()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'redbag_id'=> [true, 'int', function($f){ return $f > 0; }],
                        'account_id'=> [true, 'int', function($f){ return $f > 0; }]
                    ],
                    false
                ]
            ]
        );

        if ($auth) {
            if (($rs = $this->activity_model->openLuckyRedbag($this->Pars['account_id'], $this->Pars['redbag_id'])) === false) {
                return $this->writeJson(3003, '开启失败', null, true);
            }
            return $this->writeJson(200, $rs);
        }
    }

    public function rainy_redbag()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'account_id'=> [true, 'int', function($f){ return $f > 0; }]
                    ],
                    false
                ]
            ]
        );

        if ($auth) {
            if (($rs = $this->activity_model->getRainyRedbag($this->Pars['account_id'])) === false) {
                return $this->writeJson(3003, '获取失败', null, true);
            }
            return $this->writeJson(200, $rs);
        }
    }

    public function lucky_box()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'account_id'=> [true, 'int', function($f){ return $f > 0; }]
                    ],
                    false
                ]
            ]
        );

        if ($auth) {
            if (($rs = $this->activity_model->getLuckyBox($this->Pars['account_id'])) === false) {
                return $this->writeJson(3003, '获取失败', null, true);
            }
            return $this->writeJson(200, $rs);
        }
    }
}