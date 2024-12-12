<?php

namespace app\admin\controller;

use app\admin\logic\WalletLogic;
use app\api\controller\InPay;
use app\admin\model\WalletModel;
use think\Exception;
use think\facade\Log;

class Wallet extends Parents
{

    public function withdrawlist()
    {
        return $this->fetch();
    }

    public function rechargelist()
    {
        return $this->fetch();
    }

    /**
     * 提现审核
     * @throws \think\exception\PDOException
     */
    public function modifywithdraworder()
    {
        $param = request()->param();
        if (empty($param["id"]) || empty($param["action"])) {
            $this->error("参数错误", "/admin/wallet/modifywithdraworder");
        }
        $status = 0;
        $pay_status = 0;
        if ($param["action"] == "reject") {
            $status = 2;
        } else if ($param["action"] == "pass" || $param["action"] == "pass_pay") {
            $status = 1;
        }
        $model = new  WalletModel;
        $record = $model->getWithdrawInfo($param["id"]);
        if (empty($record)) {
            $this->error("订单不存在", "/admin/wallet/modifywithdraworder");
        }
        if($record["status"] != 0){
            $this->error("该订单已审核，不可重复操作", "/admin/wallet/modifywithdraworder");
        }

        try {
            //开启事务
            $model->startTrans();

            $record["status"] = $status;
            $model->updateWithdrawOrder($param["id"], $record);

            if ($status == 1) {
                $creatParam = [
                    "amount"      => $record["amount"],
                    "merOrderNo"  => $record["orderId"],
                    "accountNo"   => $record["account"],
                    "accountName" => $record["name"],
                    "accountIfsc" => $record["ifsc"],
                ];
                $data = (new WalletLogic())->createPayoutOrder($creatParam);
                !empty($data) && $pay_status = 1;

                //事务提交
                $model->commit();

                //校验代付是否成功
                $queryParam = ["merOrderNo" => $record["orderId"]];
                $data = (new WalletLogic())->queryPayoutOrder($queryParam);
                if ($data["code"] == 0) {
                    $pay_status = $data["data"]["status"] ?? -1;
                }
                $record["pay_status"] = $pay_status;
                $model->updateWithdrawOrder($param["id"], $record);
            } else {
                //事务提交
                $model->commit();
            }

            //发送客户端通知
            if ($pay_status == -1 || $status == 2) {
                $ret = (new WalletLogic())->httpGet($record["callbackUrl"]);
                Log::info($ret);
            }

            $this->success("success");
        } catch (Exception $e) {
            //事务回滚
            $model->rollback();
            $this->error($e->getMessage() ?? "操作失败", "/admin/wallet/modifywithdraworder");
        }

    }

    public function getrechargelist()
    {
        $param = request()->param();
        if (isset($param["status"])) {
            if($param["status"] == 0){
                $param["status"] = "0,1";
            } elseif ($param["status"] == 1) {
                $param["status"] = "-99,-98";
            } elseif ($param["status"] == 2) {
                $param["status"] = "2";
            } else {
                unset($param["status"]);
            }
        }
        $limit = 30;
        if (isset($param["limit"])) {
            $limit = $param["limit"];
            unset($param["limit"]);
        }
        $model = new  WalletModel;
        $ret = $model->getRechargeList($limit, $param);
        $static_total = $model->getRechargeStatistics($param);
        return ["code" => 0, "count" => $ret["total"], "amount" => $static_total["amount"], "data" => $ret["data"], "msg" => "ok"];
    }

    public function getwithdrawlist()
    {
        $param = request()->param();
        $model = new  WalletModel;
        $limit = 30;
        if (isset($param["limit"])) {
            $limit = $param["limit"];
            unset($param["limit"]);
        }
        if (isset($param["status"]) && ($param["status"] < 0 || $param["status"] > 2)) {
            unset($param["status"]);
        }
        if (isset($param["pay_status"]) && ($param["pay_status"] > 4 || $param["pay_status"] < -1)) {
            unset($param["pay_status"]);
        }
        $ret = $model->getWithdrawList($limit, $param);
        $static_total = $model->getWithdrawStatistics($param);
        return ["code" => 0, "count" => $ret["total"], "amount" => $static_total["amount"], "data" => $ret["data"], "msg" => "ok"];
    }
}
