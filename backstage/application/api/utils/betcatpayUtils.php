<?php

namespace app\api\utils;

use app\api\utils\betcatpaySignUtil;

/**
 * http请求类
 */
class betcatpayUtils
{
    const SIGN = "sign";
    const EXT  = "extra";
    const KEY  = "key";

    public function httpGet($url, $params = null)
    {
        if ($params != null) {
            $url .= "?";
            foreach ($params as $key => $val) {
                $url .= "$key=$val&";
            }
        }
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_ENCODING, "");
        curl_setopt($ch, CURLOPT_MAXREDIRS, 10);
        curl_setopt($ch, CURLOPT_TIMEOUT, 60);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
        $res = curl_exec($ch);
        $header = array(
            'CURL_ERROR'   => curl_error($ch),
            'HTTP_CODE'    => curl_getinfo($ch, CURLINFO_HTTP_CODE),
            'LAST_URL'     => curl_getinfo($ch, CURLINFO_EFFECTIVE_URL),
            'CONTENT_TYPE' => curl_getinfo($ch, CURLINFO_CONTENT_TYPE),
        );

        curl_close($ch);
        return array("header" => $header, "body" => $res);

    }

    public function httpPost($url, $params)
    {
        $headers = array('Content-Type: application/json');
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_ENCODING, "");
        curl_setopt($ch, CURLOPT_MAXREDIRS, 10);
        curl_setopt($ch, CURLOPT_TIMEOUT, 60);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($params));
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        $res = curl_exec($ch);
        $header = array(
            'CURL_ERROR'   => curl_error($ch),
            'HTTP_CODE'    => curl_getinfo($ch, CURLINFO_HTTP_CODE),
            'LAST_URL'     => curl_getinfo($ch, CURLINFO_EFFECTIVE_URL),
            'CONTENT_TYPE' => curl_getinfo($ch, CURLINFO_CONTENT_TYPE),
        );

        curl_close($ch);
        return array("header" => $header, "body" => $res);
    }

    public function createSign($appSecret, $map)
    {
        return BetcatpaySignUtil::create($appSecret, $map);
    }

}