<?php
/**
 * 华为支付
 */
namespace App\HttpController\Game\System;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;

class Huawei extends Controller
{
    const CLIENT_SECRET = "d17ab5eca8973f3699c91fe9af561ad1446e62ee839a8d1242ab6775cb132f02"; // your app secret
    const CLIENT_ID = "105816525"; //your appId
    const TOKEN_URL = "https://oauth-login.cloud.huawei.com/oauth2/v3/token"; //token url to get the authorization
    private $accessToken = null;

    const TOC_SITE_URL = "https://orders-dre.iap.hicloud.com";
    const TOBTOC_SITE_URL = "https://subscr-at-dre.iap.dbankcloud.com";

    const VERIFY_TOKEN_URL = "/applications/purchases/tokens/verify";
    const CANCELLED_LIST_PURCHASE_URL = "/applications/v2/purchases/cancelledList";
    const CONFIRM_PURCHASE_URL = "/applications/v2/purchases/confirm";

    protected function onRequest($action, $method) :? bool
    {
        $this->outLog = true;

        return true;
    }

    private function log($str) {
        file_put_contents("/tmp/huawei.log", date('Y-m-d H:i:s').' '. $str."\r\n", FILE_APPEND);
    }

    /**
     * Gets App Level AccessToken.
     *
     * @return string the App Level AccessToken
     */
    public function getAppAT() {
        // $this->log('getAppAT access_token0: ' . $this->accessToken);
        // if($this->accessToken != null && $this->accessToken != ''){
        //     $this->log('getAppAT access_token1: ' . $this->accessToken);
        //     return $this->accessToken;
        // }
        $accessToken = $this->rediscli_model->getDb()->get("huawei_token");
        if (!empty($accessToken)) {
            // $this->accessToken = $accessToken;
            $this->log('getAppAT access_token2: ' . $accessToken);
            return $accessToken;
        }


        $grant_type = "client_credentials";
        $dataArray= array("grant_type"=>$grant_type,"client_id"=>self::CLIENT_ID,"client_secret"=>self::CLIENT_SECRET);
        $data=http_build_query($dataArray, '', '&');
        $header = array("Content-Type: application/x-www-form-urlencoded; charset=UTF-8");
        try{
            $this->log('getAppAT post data: ' . $data . ' url:'.self::TOKEN_URL);
            $ret = $this->doPost(self::TOKEN_URL, $data,  30, 30, $header);

            $this->log('getAppAT doPost after: ' . json_encode($ret) );

            $result = $ret[0];
            $status_code = $ret[1];
            if($status_code != '200'){
                echo "get token error! the oauth server response=",$result;
                $this->log('getAppAT status_code: ' . $status_code);
                return null;
            }
            $array = json_decode($result,true);
            $accessToken = $array["access_token"];
            $this->rediscli_model->getDb()->set("huawei_token", $accessToken, 1800); //缓存半小时

            $this->log('getAppAT access_token after set');
        } catch (Exception $e){
            echo $e->getMessage();
            $this->log('getAppAT access_token Exception:' . $e->getMessage());
        }
        return $accessToken;
    }

    /**
     * Http post function. when the AppAT is out of time, get AppAT and try again.
     *
     * @param $httpUrl string the http url
     * @param $data string the data
     * @param $connectTimeout int the connect timeout
     * @param $readTimeout int the read timeout
     * @param $headers array the headers
     * @return string the result
     */
    public function  httpPost($httpUrl, $data, $connectTimeout, $readTimeout,$headers) {
        $ret = $this->doPost($httpUrl, $data, $connectTimeout, $readTimeout,$headers);
        $result = $ret[0];
        $status_code = $ret[1];
        //when statusCode is 401, means AT is expired
        if($status_code == '401'){
            //refresh Access Token
            // $this->accessToken = '';
            $appAt =$this->getAppAT();
            $this->log('httpPost 401 access_token: ' . json_encode($appAt));
            $headers = $this->buildAuthorization($appAt);
            $ret = $this->doPost($httpUrl, $data, $connectTimeout, $readTimeout,$headers);
            $result = $ret[0];
        }
        return $result;
    }

    /**
     * Http post function.
     *
     * @param $httpUrl string the http url
     * @param $data string the data
     * @param $connectTimeout int the connect timeout
     * @param $readTimeout int the read timeout
     * @param $headers array the headers
     * @return array the result and status code
     */
    private function doPost($httpUrl, $data, $connectTimeout, $readTimeout,$headers) {
        $options = array(
            CURLOPT_POST => 1,
            CURLOPT_URL => $httpUrl,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_RETURNTRANSFER => 1,
            CURLOPT_CONNECTTIMEOUT => $connectTimeout,
            CURLOPT_TIMEOUT => $readTimeout,
            CURLOPT_POSTFIELDS => $data,
            CURLOPT_SSL_VERIFYPEER => 0 //disable HTTPS protocol to verify SSL security certificate
        );
        $ch = curl_init();
        curl_setopt_array($ch, $options);
        $result = curl_exec($ch);

        $this->log('url: '. $httpUrl);
        $this->log('data: ' . json_encode($data));
        $this->log('result: '.json_encode($result));

        $status_code = curl_getinfo($ch,CURLINFO_HTTP_CODE);
        if (curl_error($ch)) {
            var_dump($ch);
            $result = false;
        }
        curl_close($ch);
        return [$result,$status_code];
    }

    /**
     * build IAP Authorization
     *
     * @param $appAT string the AppAT
     * @return array the header
     */
    public function buildAuthorization($appAT) {
        $oriString = "APPAT:".$appAT;
        $authHead = "Basic ".base64_encode(utf8_encode($oriString))."";
        $headers = ["Authorization:".$authHead,"Content-Type: application/json; charset=UTF-8"];
        return $headers;
    }

    public function getRootUrl($accountFlag) {
        if ($accountFlag != null && $accountFlag == 1) {
            return self::TOBTOC_SITE_URL;
        }
        return self::TOC_SITE_URL;
    }

    /**
     * 验证支付的token
     * @param $purchaseToken
     * @param $productId
     * @param $accountFlag
     * @return string|void
     */
    public function verifyToken($purchaseToken, $productId, $accountFlag) {
        // fetch the App Level AccessToken
        $appAT = $this->getAppAT();
        $this->log('verifyToken appAT: ' . $appAT);
        if ($appAT == null) {
            return;
        }
        // construct the Authorization in Header
        $headers = $this->buildAuthorization($appAT);
        // pack the request body
        $body = ["purchaseToken" => $purchaseToken, "productId" => $productId];
        $msgBody = json_encode($body);

        $this->log('headers: ' . json_encode($headers));
        $this->log('url: ' . $this->getRootUrl($accountFlag).self::VERIFY_TOKEN_URL);
        $this->log('msgBody: ' . $msgBody);
        $response = $this->httpPost($this->getRootUrl($accountFlag).self::VERIFY_TOKEN_URL, $msgBody, 30, 30, $headers);

        $this->log('response: ' . json_encode($response));
        return $response;
    }

    /**
     * 去华为服务器验证支付的正确性及状态
     * 返回json给客户端
     * {"purchaseTokenData":"{\"autoRenewing\":false,\"orderId\":\"20200926144518531ac231adb1.102932647\",\"packageName\":\"com.slots.rummy.casino.games.free.huawei\",\"applicationId\":102932647,\"kind\":0,\"productId\":\"a5\",\"productName\":\"STORE PACK\",\"purchaseTime\":1601102765000,\"purchaseTimeMillis\":1601102765000,\"purchaseState\":0,\"developerPayload\":\"202009261445132764365995\",\"purchaseToken\":\"00000174c9295cd5c1b0d13e3d6e7b4d668b81396ab5f1b6c544a0e39010cbe7ac2a2ea054bba426x434e.1.102932647\",\"consumptionState\":0,\"confirmed\":0,\"purchaseType\":0,\"currency\":\"CNY\",\"price\":3496,\"country\":\"CN\",\"payOrderId\":\"sandbox202009260246052521ED890\",\"payType\":\"31\"}",
     * "dataSignature":"kZ1UGPdGW4yACReZaD4j62oeRv+kD2G4iiTw9wSnwtBm9YJh/NFRovRtB1Hm5jGxdL4oaF+RfOqsW9piv7c8gtIrsoqk0wT8nP357xyyrBh7t/DwZsWih55kXPMFYzkkG63e3W+vAEDMxFmKcppDjECVuzitlnpFz+arOLaG5VUOSOamvBOgMv9P4NcJE6b75OGw/4lsk2UqVEcaQmEwNgJUYILAs1uiaPtU9M1TK/7H1G2bj8KjTnn1iIMlyxbZS5tmIqZka++u4OAR1yKscS1tLjvtSqwdEDUvngLNUZ79q0ytaPlC2tBvBR2RCboWJ/sEjGWxb+7gGfKHirgpOqu6beaAspkDInJbNrqg9SSN6N6pQEhBFGnZ7/EvvbsFK6VZ0oOmom9ZBAz4hbou9MBRiZeIcyTsyK97HFNAwFnbxaY0WqKS7UTpAerC7Wghntf2syGkG59ZYmR96JpG/z5e+drUkyYNm8qG9h92WpolMOu/4P+2MaHwJzhvqGGu",
     * "responseCode":"0"}
     * responseCode 返回码： 0 支付成功， 其他 失败
     */
    public function index()
    {
        $purchaseToken = $this->request()->getRequestParam('purchaseToken'); //支付的token
        $productId = $this->request()->getRequestParam('productId'); //商品id

        $this->log("\r\n-----------------------" . "\r\n" . 'args: ' . json_encode(['token'=>$purchaseToken, 'productId'=>$productId]));
       $result = $this->verifyToken($purchaseToken, $productId, 0);

        $this->log('result: ' . json_encode($result));
        return $this->writeJson(200, '', $result);
    }

    public function onException(\Throwable $throwable): void
    {
        var_dump($throwable);
    }
}