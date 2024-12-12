<?php

namespace App\HttpController;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Config;

class IpCheck extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'ip'=> [false, 'str', function($f){ return filter_var($f, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4 | FILTER_FLAG_NO_PRIV_RANGE); }],
                'lan'=> [false, 'str', function($f){ return in_array($f, ['zh','en']); }]
            ],
            false);
    }
    
    public function index()
    {
        //请求IP地址
        $regionStr = Helper::getRegion2($this->Pars['ip'] ?? $this->getIpAddr());
        $myClientIp = $this->getIpAddr();
        $areaCode = '00';
        if (strpos($regionStr, '香港') !== false) {
            $areaCode = '52';
        } elseif (strpos($regionStr, '印尼') !== false || strpos($regionStr, '印度尼西亚') !== false) {
            $areaCode = '62';
        } elseif (strpos($regionStr, '马来') !== false) {
            $areaCode = '60';
        }
        
        //如果是系统参数AREAMONITOR关闭，那么默认为系统参数AREACODE
        if ($areaCode == '00' && ! Config::getInstance()->getConf('AREAMONITOR')) {
            $areaCode = Config::getInstance()->getConf('AREACODE');
        }
        
        //响应提示文字
        $msg = "Game maintenance";
        
        //语言类别
        if (!! ($s = $this->system_model->_getRedisSystemParameters(['game_swl_content', 'game_swl_contenten']))) {
            $lan = $this->Pars['lan'] ?? 'zh';
            $msg = $lan == 'zh' ? $s['game_swl_content'] : $s['game_swl_contenten'];
        }
        
        //响应数据
        $data = ["code"=>200, "state"=> 0, "msg"=> $msg, "areacode"=> $areaCode, 'ip'=>$myClientIp];
        $state = $this->rediscli_model->getDb()->get("maintain_server");
        
        if ($state == 1) {
            $data['state'] = 1;
        } else {
            $data['msg'] = "";
        }
        
        //输出响应
        $this->response()->write(json_encode($data, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
        $this->response()->withHeader('Content-type', 'application/json;charset=utf-8');
        $this->response()->withStatus(200);
    }
}