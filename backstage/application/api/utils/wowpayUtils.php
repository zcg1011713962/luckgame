<?php
namespace app\api\utils;

class wowpayUtils {

    public static function http_post($url, $data) {
        $options = array(    
            'http' => array(    
                'method' => 'POST',    
                'header' => 'Content-type:application/x-www-form-urlencoded',
                'header' => 'Content-Encoding : gzip',
                'content' => $data,    
                'timeout' => 15 * 60 
            )    
        );         
        $context = stream_context_create($options);
        $result = file_get_contents($url, false, $context);  
        return $result;        
    }

    public static function http_post_res($url, $data) {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);  
        curl_setopt($ch, CURLOPT_POST, 1);  
        curl_setopt($ch, CURLOPT_POSTFIELDS, $data);  
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);  
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);  
        curl_setopt($ch, CURLOPT_AUTOREFERER, 1);  
        curl_setopt($ch, CURLOPT_MAXREDIRS, 4);  
        curl_setopt($ch, CURLOPT_ENCODING, "");
        curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 5.1; zh-CN) AppleWebKit/535.12 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/535.12");  
        curl_setopt($ch, CURLOPT_TIMEOUT, 15);  
        $output = curl_exec($ch);  
        curl_close($ch);
        return $output;
    }

    public static function wowPaySubmit($url, $data, $headers) {
        $ch = curl_init();    
        curl_setopt($ch,CURLOPT_URL,$url); //支付请求地址
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HEADER, false);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($data));  
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        $response=curl_exec($ch);
        curl_close($ch);
        return $response;
    }

    public static function convToGBK($str) {
        if( mb_detect_encoding($str,"UTF-8, ISO-8859-1, GBK")!="UTF-8" ) {
            return  iconv("utf-8","gbk",$str);
        } else {
            return $str;
        }
    }

    public static function sign($signSource,$key) {
        if (!empty($key)) {
             $signSource = $signSource."&key=".$key;
        }
        return     md5($signSource);
    }

    public static function signx($signSource, $key) {
        if (!empty($key)) {
            $signSource = $signSource.$key;
        }
       return md5($signSource);
    }

    public static function validateSignByKey($signSource, $key, $retsign) {
        if (!empty($key)) {
             $signSource = $signSource."&key=".$key;
        }
        $signkey = md5($signSource);
        if($signkey == $retsign){
            return true;
        }
        return false;
    }

    public static function ASCII($params = array()){
        if(!empty($params)){
           $p =  ksort($params);
           if($p){
               $str = '';
               foreach ($params as $k=>$val){
                   $str .= $k .'=' . $val . '&';
               }
               $strs = rtrim($str, '&');
               return $strs;
           }
        }
        return '参数错误';
    }
}