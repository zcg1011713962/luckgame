<?php

namespace App\HttpController;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Config;

class Index extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'lan'=> [false, 'str', function($f){ return in_array($f, ['zh','en','vtm']); }],
                'appVer' => [false, 'str']
            ],
            false);
    }
    
    public function index()
    {
        //请求IP地址
        $clientIp = $this->getIpAddr();
        $regionStr = Helper::getRegion2($clientIp);
//        $regionStr = '220.255.1.166'; //新加坡

        $areaCode = '00';
        if (strpos($regionStr, '香港') !== false) {
            $areaCode = '52';
        } elseif (strpos($regionStr, '印尼') !== false || strpos($regionStr, '印度尼西亚') !== false) {
            $areaCode = '62';
        } elseif (strpos($regionStr, '马来') !== false || strpos($regionStr, '新加') !== false || strpos($regionStr, '文莱') !== false) {
            $areaCode = '60';
        } elseif (strpos($regionStr, '泰国') !== false || strpos($regionStr, '曼谷') !== false) {
            $areaCode = '66';
        } elseif (strpos($regionStr, '越南') !== false || strpos($regionStr, '河内') !== false) {
            $areaCode = '84';
        } elseif (strpos($regionStr, '缅甸') !== false || strpos($regionStr, '缅甸') !== false) {
            $areaCode = '91';
//        } elseif (strpos($regionStr, '中国') !== false) {
//            $areaCode = '86';
        }
        //mm 103.231.93.42
        //vn 123.24.222.87
        //th 195.190.133.255
        
        //如果是系统参数AREAMONITOR关闭，那么默认为系统参数AREACODE
        if ($areaCode == '00' && ! Config::getInstance()->getConf('AREAMONITOR')) {
            $areaCode = Config::getInstance()->getConf('AREACODE');
        }

        if (Config::getInstance()->getConf('IS_DEBUG') || $this->rediscli_model->getDb()->get("IS_DEBUG")) {
            $areaCode = '60';
        }

        //响应提示文字
        $msg = "Game maintenance";
        
        //语言类别
        if (!! ($s = $this->system_model->_getRedisSystemParameters(['game_swl_content', 'game_swl_contenten','game_swl_ip']))) {
            $lan = $this->Pars['lan'] ?? 'zh';
            $msg = $lan == 'zh' ? $s['game_swl_content'] : $s['game_swl_contenten'];
        }
        
        //响应数据
        $data = ["code"=>200, "state"=> 0, "msg"=> $msg, "areacode"=> $areaCode];
        $state = $this->rediscli_model->getDb()->get("maintain_server");
        
        if ($state == 1) {
            $whiteIpList = $s['game_swl_ip']; //白名单ip列表
            if (!empty($whiteIpList)) {
                $ip_arr = explode(',', $whiteIpList);
                if (in_array($clientIp, $ip_arr)) {
                    $data['state'] = 0;
                } else {
                    $data['state'] = 1;
                }
            } else {
                $data['state'] = 1;
            }
        } else {
            $data['msg'] = "";
        }
        $data['la'] = "buhao"; //IOS不要热更
        $la = $this->rediscli_model->getDb()->get("ios_hotupdate");
        if ($la == 'hao') {
            $data['la'] = "hao"; //ISO要热更新
        }
        $ios_ver = $this->rediscli_model->getDb()->get("ios_examine_version");
        if ($this->Pars['appVer'] == $ios_ver) {
            $data['la'] = "buhao"; //IOS提审版本不要热更
        }
        
        //输出响应
        $this->response()->write(json_encode($data, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
        $this->response()->withHeader('Content-type', 'application/json;charset=utf-8');
        $this->response()->withStatus(200);
    }
}