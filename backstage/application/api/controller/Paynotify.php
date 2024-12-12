<?php

namespace app\api\controller;

use app\admin\logic\WalletLogic;
use app\admin\model\WalletModel;
use think\Exception;
use think\facade\Log;
use app\api\model\PayOrderModel;
use app\api\utils\betcatpayUtils;
use app\api\utils\fatpagUtils;

/**
 * 支付异步回调通知
 */
class PayNotify extends Init
{

    private $payUtil = null;

    public function __construct()
    {
        parent::__construct();
        $this->payment_secretKey = getenv("SECRET_BETCAT_PAYMENT");
        $this->payout_secretKey = getenv("SECRET_BETCAT_PAYOUT");
        $this->fatpag_secretkey = getenv("SECRET_FATPAG");
        $this->fatpag_mchId = getenv("MCHID_FATPAG");
    }

    public function paymentBetcat()
    {
        $params = request()->param();
        $secretKey = $this->payment_secretKey;
        Log::info("payment betcatpay notify: " . json_encode($params));
        $sign = $params["sign"];
        unset($params["sign"]);
        $this->getPayUtil();
        $res_sign = $this->payUtil->createSign($secretKey, $params);
        //签名错误
        if ($sign != $res_sign) {
            return "fail";
        } else {
            //支付订单操作
            $record = array("order_status" => $params["orderStatus"],
                            "pay_order_no" => $params["orderNo"],
                            "mer_order_no" => $params["merOrderNo"],
                            "order_type"   => 0,
                            "channel_type" => "betcatpay",
                            "order_id"     => md5("betcatpay" . $params["merOrderNo"])
            );
            if ($params["orderStatus"] == 2 || $params["orderStatus"] == 3) {
                $record["pay_time"] = date("Y-m-d H:i:s", $params["updateTime"] / 1000);
            }

            $model = new PayOrderModel;
            $model->updateOrder($record);

            if ($params["orderStatus"] == 2 || $params["orderStatus"] == 3) {
                $record_detail = $model->getOrder($record["order_id"]);
                if ($record_detail != null) {
                    $this->payUtil->httpGet($record_detail["notify_url"]);
                }
            }
            return "ok";
        }

    }

    public function payoutBetcat()
    {
        $params = request()->param();
        $secretKey = $this->payout_secretKey;
        Log::info("payout betcatpay notify: " . json_encode($params));
        $sign = $params["sign"];
        unset($params["sign"]);
        $this->getPayUtil();
        $res_sign = $this->payUtil->createSign($secretKey, $params);
        //签名错误
        if ($sign != $res_sign) {
            return "fail";
        } else {
            //支付订单操作
            $record = array("order_status" => $params["orderStatus"],
                            "pay_order_no" => $params["orderNo"],
                            "mer_order_no" => $params["merOrderNo"],
                            "order_type"   => 1,
                            "channel_type" => "betcatpay",
                            "order_id"     => md5("betcatpay" . $params["mer_order_no"])
            );
            if ($params["orderStatus"] == 2 || $params["orderStatus"] == 3) {
                $record["pay_time"] = date("Y-m-d H:i:s", $params["updateTime"] / 1000);
            }
            $model = new PayOrderModel;
            $model->updateOrder($record);
            if ($params["orderStatus"] == 2 || $params["orderStatus"] == 3) {
                $record_detail = $model->getOrder($record["order_id"]);
                if ($record_detail != null) {
                    $this->payUtil->httpGet($record_detail["notify_url"]);
                }
            }
            return "ok";
        }

    }

    public function paymentFatpag()
    {
        $params = request()->param();
        $secretKey = $this->fatpag_secretkey;
        Log::info("payment fatpag notify: " . json_encode($params));
        $sign = $params["sign"];
        unset($params["sign"]);
        $pay = new fatpagUtils;
        $pay->setSignKey($secretKey);
        $ret_sign = $pay->PaySign($params);
        if ($sign == $ret_sign) {
            //支付订单操作
            $record = array("order_status" => $params["status"],
                            "mer_order_no" => $params["orderNo"],
                            "order_type"   => 0,
                            "channel_type" => "fatpag",
                            "order_id"     => md5("fatpag" . $params["orderNo"])
            );
            $record["pay_time"] = date("Y-m-d H:i:s", $params["paySuccTime"] / 1000);
            $model = new PayOrderModel;
            $model->updateOrder($record);

            if ($params["status"] == 2) {
                $record_detail = $model->getOrder($record["order_id"]);
                if ($record_detail != null) {
                    $this->payUtil->httpGet($record_detail["notify_url"]);
                }
            }

            return "success";
        } else {
            return "fail";
        }
    }

    public function payoutFatpag()
    {
        $params = request()->param();
        $secretKey = $this->fatpag_secretkey;
        Log::info("payout fatpag notify: " . json_encode($params));
        $sign = $params["sign"];
        unset($params["sign"]);
        $msg = $params["msg"];
        unset($params["msg"]);
        $pay = new fatpagUtils;
        $pay->setSignKey($secretKey);
        $ret_sign = $pay->PaySign($params);
        if ($sign == $ret_sign) {
            //代付单操作
            $record = array("order_status" => $params["status"],
                            "mer_order_no" => $params["mchTransNo"],
                            "order_type"   => 1,
                            "channel_type" => "fatpag",
                            "order_id"     => md5("fatpag" . $params["mchTransNo"])
            );
            if (!empty($msg)) {
                $record["msg"] = $msg;
            }
            $record["pay_time"] = date("Y-m-d H:i:s", $params["transSuccTime"] / 1000);
            $model = new PayOrderModel;
            $model->updateOrder($record);

            if ($params["status"] == 2) {
                $record_detail = $model->getOrder($record["order_id"]);
                if ($record_detail != null) {
                    $this->payUtil->httpGet($record_detail["notify_url"]);
                }
            }
            return "success";
        } else {
            return "fail";
        }
    }

    public function payoutApnapay()
    {
        $params = request()->param();
        Log::info("payout inpay notify: " . json_encode($params));

        $model = new WalletModel;
        $payOrderModel = new PayOrderModel;
        $info = $model->getPayInfo(['a.orderId' => $params["merOrderNo"], 'b.pay_order_no' => $params["orderNo"]]);
        if (empty($info)) {
            return "支付回调获取订单信息异常";
        }

        if ($info['pay_status'] == 2 && $info['order_status'] == 2) {
            return "ok";
        }

        try {
            $model->startTrans();

            //更新支付流水
            $record = [
                "order_status" => $params["status"],
                "pay_order_no" => $params["orderNo"],
                "mer_order_no" => $params["merOrderNo"],
                "order_type"   => 1,
                "channel_type" => "apnapay",
                "order_id"     => md5("apnapay" . $params["merOrderNo"]),
            ];
            if (!empty($params["payTime"])) {
                $record["pay_time"] = date("Y-m-d H:i:s", $params["payTime"] / 1000);
            }
            $res = $payOrderModel->updateOrder($record);
            if (empty($res)) {
                return new Exception("支付回调修改支付流水状态异常");
            }

            //更新提现订单
            $res = $model->updateWithdrawOrder($info["id"], ['pay_status' => $params["status"]]);
            if ($res === false) {
                return new Exception("支付回调修改订单状态异常");
            }

            //支付回调成功/失败通知
            if ($params["status"] != 1) {
                $res = (new WalletLogic())->httpGet($info["callbackUrl"]);
                Log::info("payout inpay notify curl: " . json_encode($res));
            }

            $model->commit();
            return "ok";
        } catch (Exception $e) {
            $model->rollback();
            Log::error("payout inpay notify error: " . $e->getMessage());
            return "支付回调异常";
        }
    }

    private function getPayUtil()
    {
        if (empty($this->payUtil)) {
            $this->payUtil = new betcatPayUtils;
        }
        return $this->payUtil;
    }


}
