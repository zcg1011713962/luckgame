<?php
namespace App\HttpController\Game\System;
/**
 * google 支付回调验证 
 * 服务器端验证(省掉去google服务器验证)
 */
use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;

class Google extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'data'=> [true, 'str', function($f){ return !empty($f); }]
            ]
        );
    }
    
    public function index()
    {
        //post
        //$post = '{"data":{"orderId":"GPA.3322-9390-5286-51952","packageName":"com.nineyou.wydlm","productId":"wydlm_gp_01","purchaseTime":1529896147041,"purchaseState":0,"developerPayload":"inapp:wydlm_gp_01:e6f494c5-4842-4303-9709-92e0e43e6744:OrderId:201806251108370798798749","purchaseToken":"dmhhdcgphngnmopmlfbomhab.AO-J1OxQ8KL09TCUOTFdaEU3-lJW2auOeNiUUYZb9pk5ttvCsBEzYqYE_rIv-h7LLEaGsDJhW6Li9Z9QKyM0wnlI_YucXJ_rIRllkEOaI8l1Uqxstsu-u9g"},"sign":"jMk6jk37wWsJESAVl\/JY\/BS5H11mcC4Rw5N/OKt7APC3NacyC0vzESD5+XtAvAP0T5nv\/hAIBM5ZfB8en4fxGIMvwIv3AUPasttR9vOaXDwZcmT+8wg\/IqNt5B\/9NeWr9hzhKhSF7MDW6qTsQxcK7AP4qsJBB7Vp0xNyQ3L+VA8W5osUBnWEI0gBD7hNvecv92ni3JHiMiQPAYUqD\/Lg8C2y7SiA1Fy1lWm7NYcQq5AGmX2A16KqYVID2t6yB1kmC3v95r00jm7rjJqL9Se03n4bBHbNOQ3B58r37yks23X9eNh96UEAbSfu5w3egP\/s0\/KKs9juIwGJOwRwMV7R5A=="}';
        //$post = file_get_contents("php://input");
        $post = $this->Pars['data'];
        file_put_contents('/tmp/post.log', $post."\r\n", FILE_APPEND);
        if (empty($post)) {
            return $this->writeJson(500, '参数不能为空', null, true);
        }
        $post = json_decode($post, true);
        //$post['data'] = '{"orderId":"GPA.3366-0264-7791-46663","packageName":"com.nineyou.wydlm","productId":"wydlm_gp_02","purchaseTime":1529911032145,"purchaseState":0,"developerPayload":"inapp:wydlm_gp_02:259b68cb-1c15-49e3-b5bd-818ef484b879:OrderId:201806251517078006970427","purchaseToken":"jokkgfjikcfjhadeinbipefk.AO-J1Oxv9Rj2QR7yHShGSz5MQ0-BmeoRovx5I2YdjPPiu6r2iZx5wdiSLGq6o8Bg2MuIMN5P_RkMg_UvJrRHX7D8bnU41QPDC75q3Uu3jCrEeKlVF7X8sd0"}';
        //$post['sign'] = 'yAEZwKSWb8kcy9KnAH29rGbRFY4w4RhDgsvRgL8iufJwq29ndJvgG1AIRrwnJenAQIg/3+ujFpAoL+nsW5ANEiJaj97xNZQTo3lumB3Z90zBh4neEcKfDMbL2LgbZsgC1+AU5sSReCZxMkBgrROrRahSiv/b0XA8Ju5c6u5BcCmYsgLpACuHVmZclkf04bKyVuFU/WA4Tw+U1dfqzYhjLxG9CALVdCwjApW+RDBzwFLmpONQ9TgDHItaC2CRr4JNg/zbU9QNzmFM0wBNegqEQtj9Q2LCXT8Exv5OIl9ZfrH47O2S8B2u8YnpIct6gZ3ylrvqXsKvkqmwUw/UOsB+8Q==';
        $inappPurchaseData = isset($post['data']) ? $post['data'] : '';
        $inappDataSignature = isset($post['sign']) ? $post['sign'] : '';

        $inappDataSignature = str_replace("_", "+", $inappDataSignature);
        if (empty($inappPurchaseData) || empty($inappDataSignature)) {
            return $this->writeJson(500, '参数缺失data或sign', null, true);
        }
        $tmp = [];
        $tmp['orderId'] =$inappPurchaseData['orderId'];
        $tmp['packageName'] =$inappPurchaseData['packageName'];
        $tmp['productId'] =$inappPurchaseData['productId'];
        $tmp['purchaseTime'] =$inappPurchaseData['purchaseTime'];
        $tmp['purchaseState'] =$inappPurchaseData['purchaseState'];
        $tmp['developerPayload'] =$inappPurchaseData['developerPayload'];
        $tmp['purchaseToken'] =$inappPurchaseData['purchaseToken'];
        $inappPurchaseData = json_encode($tmp);

        //new 一起打拉米
        $cfgInstance = \EasySwoole\EasySwoole\Config::getInstance();
        $googlePublicKey = $cfgInstance->getConf('GOOGLE_PUBLICKEY');
        if(!$googlePublicKey) {
            $googlePublicKey = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsicC1EA8cD23JwpcGo9PIOTZbS+Y5AxbYHgL9dxydI7ZMZGCGHBxZLV8mlv1uIYCmtD3G2JzRYH5YJ/vBLowwkD5lgdbAwLDzJRaGCAcUwcc78jnhawLEqQHBypg+EkpqMEM38VmpjX6TJ4IX6AAA69WsHEyXqNB4BLRQ6ouwD1gxEouPXu/nbni4v5TPLW1FVShJhwZJ16RkiiTAek7aFllvQsyLQM/bRRtGU3rmm/722aZ7DC1opvxl5F2H6h1tgtrIFtABESK6leAUjkChvCjALHGZHCK+Plc5ZUcCsMhj5NXcZ4MI5c0v+WoQRytGAVbxY93PQPryfpdeR02ywIDAQAB';
        }
        
        $publicKey = "-----BEGIN PUBLIC KEY-----". PHP_EOL .
            chunk_split($googlePublicKey, 64, PHP_EOL) .
            "-----END PUBLIC KEY-----";

        $publicKeyHandle = openssl_get_publickey($publicKey);
        $result = openssl_verify($inappPurchaseData, base64_decode($inappDataSignature), $publicKeyHandle, OPENSSL_ALGO_SHA1);
        if (1 !== $result) {
            return $this->writeJson(500, '签名验证失败', null, true);
        }
        return $this->writeJson(200, ['msg'=>'succ']);
    }
}