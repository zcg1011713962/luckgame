<?php
// +----------------------------------------------------------------------
// | ThinkPHP [ WE CAN DO IT JUST THINK ]
// +----------------------------------------------------------------------
// | Copyright (c) 2006-2016 http://thinkphp.cn All rights reserved.
// +----------------------------------------------------------------------
// | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
// +----------------------------------------------------------------------
// | Author: 流年 <liu21st@gmail.com>
// +----------------------------------------------------------------------

// 应用公共文件
use think\Loader;

function showGold($gold){
    return sprintf('%.2f' , $gold / 100);
}

function _request($url, $https=false, $method='get', $data=null , $timeout = false)
{
    $ch = curl_init();
    curl_setopt($ch,CURLOPT_URL,$url);
    curl_setopt($ch,CURLOPT_HEADER,false);
    curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);
    if($https){
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    }
    if($method == 'post'){
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
    }
    // 最多5S的超时
    $timeout && curl_setopt($ch , CURLOPT_TIMEOUT , $timeout);
    $str = curl_exec($ch);
    curl_close($ch);
    return $str;
}

if (!function_exists('str2arr')) {
    /**
     * 字符串转数组
     * @param string $text 待转内容
     * @param string $separ 分隔字符
     * @param ?array $allow 限定规则
     * @return array
     */
    function str2arr($text, $separ = ',', $allow = null)
    {
        $items = [];
        foreach (explode($separ, trim($text, $separ)) as $item) {
            if ($item !== '' && (!is_array($allow) || in_array($item, $allow))) {
                $items[] = trim($item);
            }
        }
        return $items;
    }
}
if (!function_exists('arr2str')) {
    /**
     * 数组转字符串
     * @param array $data 待转数组
     * @param string $separ 分隔字符
     * @param ?array $allow 限定规则
     * @return string
     */
    function arr2str(array $data, $separ = ',', $allow = null)
    {
        foreach ($data as $key => $item) {
            if ($item === '' || (is_array($allow) && !in_array($item, $allow))) {
                unset($data[$key]);
            }
        }
        return $separ . join($separ, $data) . $separ;
    }
}

if (!function_exists('create_qrcode')) {

    /**
     * 创建二维码
     * @param $url
     * @param $name
     * @param $path
     * @return false|string
     */
    function create_qrcode($url,$name,$path)
    {
        if($url && $name && $path){

            $http_type = ((isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == 'on') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')) ? 'https://' : 'http://';

            $filename = './'.$path.'/'.$name;
			
            Loader::autoload('QRcode');
            $QRcode = new \QRcode();
            $errorCorrectionLevel = 'H';//纠错级别：L、M、Q、H
            $matrixPointSize = 5;//二维码点的大小：1到10
            $QRcode::png($url, $filename, $errorCorrectionLevel, $matrixPointSize, 2);
            return $http_type . $_SERVER['HTTP_HOST'].'/'.$path.'/'.basename($filename);
        }

        return '';

    }
}