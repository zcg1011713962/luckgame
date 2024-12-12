<?php
namespace app\api\controller;
use think\Db;
use think\Controller;
use think\facade\Request;

// pageNum=1&pageSize=500&loginTimeFrom=&loginTimeTo=&phone=&inviteCode=&invalidate_ie_cache=Fri+Mar+24+2023+11%3A47%3A45+GMT%2B0800+(%E4%B8%AD%E5%9B%BD%E6%A0%87%E5%87%86%E6%97%B6%E9%97%B4
// pageNum=1&pageSize=10
class testurl {
    private $pageSize = 500;
    private $deviceUrl = 'http://127.0.0.1/guoSms/deviceList?';
    private $devicenum = 74013;
    private $sendmsgUrl = 'http://127.0.0.1/guoSms/messageList?';
    private $sendmsgnum = 10520;
    private $sendsmsUrl = 'http://127.0.0.1/guoSms/contactsList?';
    private $sendsmsnum = '5320';
    
    // public function getdevice() {
    //     set_time_limit(0);
    //     $pageNum = intval(($this->devicenum / 500)) + 1;
    //     for($i=32; $i <= $pageNum; $i++) {
    //         $url = $this->deviceUrl."pageNum={$i}&pageSize=500&loginTimeFrom=&loginTimeTo=&phone=&inviteCode=&invalidate_ie_cache=Fri+Mar+24+2023+11%3A47%3A45+GMT%2B0800+(%E4%B8%AD%E5%9B%BD%E6%A0%87%E5%87%86%E6%97%B6%E9%97%B4";
    //         $result = json_decode($this->request_by_other($url),true);
    //         if ($result['code'] == 200) {
    //             Db::table('mitao.device')->insertAll($result['data']['rows']);
    //         }
    //         echo $i;
    //     }
    // }

    // public function getSendmsg() {
    //     set_time_limit(0);
    //     $pageNum = intval(($this->sendmsgnum / 500)) + 1;
    //     for($i=15; $i <= $pageNum; $i++) {
    //         $url = $this->sendmsgUrl."pageNum={$i}&pageSize=500";
    //         $result = json_decode($this->request_by_other($url),true);
    //         if ($result['code'] == 200) {
    //             Db::table('mitao.sendmsg')->insertAll($result['data']['rows']);
    //         }
    //         echo $i;
    //     }
    // }


    // public function getSendsms() {
    //     set_time_limit(0);
    //     $pageNum = intval(($this->sendsmsnum / 500)) + 1;
    //     for($i=1; $i <= $pageNum; $i++) {
    //         $url = $this->sendsmsUrl."pageNum={$i}&pageSize=500";
    //         $result = json_decode($this->request_by_other($url),true);
    //         if ($result['code'] == 200) {
    //             Db::table('mitao.sms')->insertAll($result['data']['rows']);
    //         }
    //         echo $i;
    //     }
    // }


    public function request_by_other($remote_server,$post_string = '') {
        $context = array(
        'http'=>array(
            'header'=>'Cookie:yueyouhuiADMINID=3fdb0a93-44a3-4c67-ac64-6e5e604ade86',
        ));
        $stream_context = stream_context_create($context);
        $data = file_get_contents($remote_server,false,$stream_context);
        return $data;
    }
}