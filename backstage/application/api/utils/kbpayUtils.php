<?php
namespace app\api\utils;

class kbpayUtils {
    public static function post_form($url, $data) {
        //初使化init方法
        $ch = curl_init();
        //指定URL
        curl_setopt($ch, CURLOPT_URL, $url);
        //设定请求后返回结果
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        //声明使用POST方式来进行发送
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'POST');
        //发送的数据
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($data));
        //忽略证书
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
        //不需要响应的header头信息
        curl_setopt($ch, CURLOPT_HEADER, false);
        //设置请求的header头信息
        curl_setopt($ch, CURLOPT_HTTPHEADER, array(
           "Content-Type: application/x-www-form-urlencoded",   
        ));
        //设置超时时间
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);
        //发送请求
        $response = curl_exec($ch);
		$err = curl_error($ch);
        //关闭curl
        curl_close($ch);
        if ($err) {
            return $err;
          }
        return $response;
     }
}