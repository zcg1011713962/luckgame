<?php

namespace app\admin\logic;

use app\api\model\PayOrderModel;
use think\Exception;
use think\facade\Log;
use think\Model;

class WalletLogic extends Model
{

    private string $createPayoutOrderUrl;
    private string $queryPayoutOrderUrl;
    private string $appToken;
    private string $environment;
    private string $notifyUrl;

    public function __construct()
    {
        parent::__construct();

        $this->createPayoutOrderUrl = getenv("INPAY_PAYOUT_HOST") . "pay/createPayoutOrder";
        $this->queryPayoutOrderUrl = getenv("INPAY_PAYOUT_HOST") . "pay/queryPayout";
        $this->appToken = getenv("INPAY_PAYOUT_APP_TOKEN");
        $this->environment = getenv("INPAY_PAYOUT_ENVIRONMENT");
        $this->notifyUrl = getenv("INPAY_PAYOUT_NOTIFY_URL");
    }


    /**
     * 创建代付订单
     * @return false|string
     * @throws Exception
     */
    public function createPayoutOrder($params)
    {
        if (empty($params["amount"]) || empty($params["merOrderNo"])
            || empty($params["accountNo"])
            || empty($params["accountName"])
            || empty($params["accountIfsc"])
        ) {
            throw new Exception("创建代付订单参数错误 " . json_encode($params));
        }

        $param = [
            "amount"      => $params["amount"],
            "merOrderNo"  => $params["merOrderNo"],
            "accountNo"   => $params["accountNo"],
            "accountName" => $params["accountName"],
            "accountIfsc" => $params["accountIfsc"],
            "app_token"   => $this->appToken,
            "environment" => $this->environment,
            "notifyUrl"   => $this->notifyUrl,
        ];
        $data = $this->httpPost($this->createPayoutOrderUrl, $param);
        Log::info("create payout order info: " . $data["body"]);
        $result = json_decode($data["body"], true);

        $model = new PayOrderModel;
        $record = [
            "order_id"        => md5("apnapay" . $param["merOrderNo"]),
            "mer_order_no"    => $param["merOrderNo"],
            "amount"          => $param["amount"],
            'currency'        => "CNY",
            "order_type"      => 1,
            "order_status"    => 1,
            "request_detail"  => json_encode($param),
            "response_detail" => $data["body"],
            "channel_type"    => $result["data"]['channel'] ?? "apnapay",
            "uid"             => $params["uid"] ?? 0,
            "notify_url"      => $param["notifyUrl"] ?? '',
        ];

        if ($result["code"] != 0) {
            throw new Exception("创建代付订单失败 code:" . $result['code'] . " msg:" . $result["msg"]);
        }

        $record["pay_order_no"] = $result["data"]["orderNo"];
        $record['pay_time'] = date("Y-m-d H:i:s", time());
        $res = $model->addPayOrder($record);
        if ($res === false) {
            throw new Exception("添加支付流水异常");
        }

        return $result["data"];
    }

    /**
     * 查询代付订单
     * @return false|string
     */
    public function queryPayoutOrder($param)
    {
        if (empty($param["merOrderNo"])) {
            throw new Exception("查询代付订单参数错误 " . json_encode($param));
        }
        $param['app_token'] = $this->appToken;
        $param["environment"] = $this->environment;
        $data = $this->httpPost($this->queryPayoutOrderUrl, $param);
        Log::info("query payout order info: " . $data["body"]);
        $result = json_decode($data["body"], true);
        return $result;
    }

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
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "GET");
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
}
