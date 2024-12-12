<?php

namespace app\agent\model;

use app\admin\model\ConfigModel;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;

/**
 * 代理运营数据统计
 */
class AgentStatisModel extends Model
{

    private $adminid;
    private $config;
    public function __construct(){
        parent::__construct();
        $this->adminid = $this->getAgId();
        $this->config = ConfigModel::getSystemConfig();
    }

    /**
     * 代理ID
     * @return mixed
     */
    public function getAgId(){
        return Cookie::get('agent_user_id');
    }

    /**
     * 获取自己及下级代理的代理ID
     * @return string
     */
    public function getSubAgId()
    {
        //上级代理
        $agents_ids = $a1 = $this->getAgId();
        $a23 = (new AdminModel())->get3ji_ids();
        if ($a23) {
            $agents_ids = trim($a1.','.$a23, ',');
        }
        return $agents_ids;
    }

    public function getConfig($msg = 'app.GameLoginUrl'){
        $configArr = explode('.',$msg);
        // 如果系统有当前配置项，走系统配置项
        if (!empty($this->config[$configArr[1]])) {
            return $this->config[$configArr[1]];
        }
        // 否则走配置文件
        return Config::get($msg);
    }

    /**
     * 代理运营数据统计
     * @param $begin_time
     * @param $end_time
     * @return array[]
     */
    public function getOperationStatisData($begin_time, $end_time)
    {
        $result = [
            'data' => [],
        ];

        while($begin_time <= $end_time) {

            if (empty($result['data'][$begin_time])) {
                $result['data'][$begin_time] = [];
            }

            $result['data'][$begin_time]['time'] = $begin_time;
            // 宝箱金额
            $result['data'][$begin_time]['box_amount'] = $this->getBoxAmount($begin_time, $begin_time. " 23:59:59") ?: 0;
            // 注册人数
            $result['data'][$begin_time]['new_have'] = $this->getNewHave($begin_time, $begin_time. " 23:59:59") ?: 0;
            // 复充人数
            $result['data'][$begin_time]['two_payment'] = $this->getTwoPaymentTotal($begin_time, $begin_time. " 23:59:59")['count'] ?: 0;
            // 充值人数
            $reuslt['data'][$begin_time]['payment_total'] = $this->getPaymentTotal($begin_time, $begin_time ." 23:59:59")['count'] ?: 0;
            // 充值金额
            $result['data'][$begin_time]['payment_amount'] = $this->getPaymentTotal($begin_time, $begin_time. " 23:59:59")['amount'] ?: 0;
            // 有效充值金额（扣除支付点位）
            $result['data'][$begin_time]['new_payment_gold'] = $result['data'][$begin_time]['payment_amount'] - $this->getPaymentDecTotal($begin_time, $begin_time ." 23:59:59")['amount'] ?: 0;
            // 流水佣金（拉人抽成）
            $result['data'][$begin_time]['commission_total'] = $this->getCommissionCount($begin_time, $begin_time. " 23:59:59") ?: 0;
            // 平台余额
            $result['data'][$begin_time]['balance_amount'] = 0;
            // 游戏输赢
            $result['data'][$begin_time]['win_or_close_total'] = $this->getTaxationCount($begin_time, $begin_time. " 23:59:59", 1) ?: 0;
            // 流水（投注记录）
            $result['data'][$begin_time]['usecoin'] = $this->getTaxationCount($begin_time, $begin_time. " 23:59:59", 2) ?: 0;
            // 提现金额
            $reuslt['data'][$begin_time]['cash_amount'] = $this->getCashTotal($begin_time, $begin_time. " 23:59:59")['money'] ?: 0;
            // 提现人数
            $result['data'][$begin_time]['cash_total'] = $this->getCashTotal($begin_time, $begin_time. " 23:59:59")['count'] ?: 0;
            // 充提差
            $result['data'][$begin_time]['diff_pay'] = $result['data'][$begin_time]['payment_amount'] - $reuslt['data'][$begin_time]['cash_amount'] ?: 0;

            $begin_time = date('Y-m-d',strtotime($begin_time) + 86400);
        }

        return $result;
    }

    /**
     * 宝箱金额
     * @param $begin_time
     * @param $end_time
     * @return mixed
     * @throws \think\db\exception\DataNotFoundException
     * @throws \think\db\exception\ModelNotFoundException
     * @throws \think\exception\DbException
     */
    public function getBoxAmount($begin_time, $end_time)
    {
        $userIdArr = $this->getAgentUserIdArr();
        $sql = Db::table('ym_manage.recharge_give_log')->where('user_id','in',$userIdArr)->field('sum(give) count');
        if ($begin_time && $end_time) {
            $sql->where('createtime', 'BETWEEN', [$begin_time, $end_time]);
        }
        return $sql->find()['count'];
    }

    /**
     * 注册人数
     * @param $begin_time
     * @param $end_time
     * @return mixed
     * @throws \think\db\exception\DataNotFoundException
     * @throws \think\db\exception\ModelNotFoundException
     * @throws \think\exception\DbException
     */
    public function getNewHave($begin_time, $end_time)
    {
        $userIdArr = $this->getSubAgId();
        $dbobj = Db::table('ym_manage.uidglaid');
        if ($begin_time && $end_time) {
            $starttime = strtotime($begin_time);
            $endtime = strtotime($end_time);
            $dbobj = $dbobj->where('createtime','>=', $starttime)->where('createtime','<', $endtime);
        }
        $dbobj = $dbobj->where('aid','in', $userIdArr);
        $count = $dbobj->count();
        return $count;
    }

    /**
     * 充值数量
     * @return array
     * return [count,amount]
     */
    public function getPaymentTotal($begin_time, $end_time)
    {
        $userIdArr = $this->getAgentUserIdArr();
        $sql = Db::table('ym_manage.paylog')->where('status',1)->where('type',3)->field('COUNT(1) count, SUM(fee) fee');
        if ($begin_time && $end_time) {
            $sql->where('paytime', 'BETWEEN', [strtotime($begin_time), strtotime($end_time)]);
        }
        $sql->where('uid', 'in', $userIdArr);
        $result = $sql->find();
        return ['count' => $result['count'], 'amount' => $result['fee']];
    }

    /**
     * 获取代理下所有用户
     * @return array
     */
    public function getAgentUserIdArr()
    {
        return [];
    }

    /**
     * 新增提现数量
     * return [count, money]
     */
    public function getCashTotal($begin_time = '', $end_time = '') {
        $userIdArr = $this->getAgentUserIdArr();
        $sql = Db::table('ym_manage.user_exchange')->where('status',1)->field('COUNT(1) count, SUM(money) money');
        if ($begin_time && $end_time) {
            $sql->where('created_at', 'BETWEEN', [$begin_time, $end_time]);
        }
        $sql->where('user_id', 'in', $userIdArr);
        $result = $sql->find();
        return ['count' => $result['count'], 'money' => $result['money']];
    }

    /**
     * 税收统计（输赢）
     * $type = 0 税收统计
     * $type = 1 输赢统计
     * $type = 2 流水统计
     */
    public function getTaxationCount($begin_time = '', $end_time = '', $type = 0) {
        $userIdArr = $this->getAgentUserIdArr();

        $sql = Db::table('gameaccount.mark');
        if ($begin_time && $end_time) {
            $sql->where('balanceTime','BETWEEN',[$begin_time, $end_time]);
        }
        $sql->where('userId', 'in', $userIdArr);

        if ($type == 0) {
            $sql->where('tax','>',0);
            $sql->field('SUM(tax) tax');
            return $sql->find()['tax'];
        }
        if ($type == 1) {
            $sql->field('SUM(winCoin) wincoin');
            return $sql->find()['wincoin'];
        }
        if ($type == 2) {
            $sql->field('SUM(useCoin) usecoin');
            return $sql->find()['usecoin'];
        }
    }

    /**
     * 佣金统计
     * $status 0 未结算 1 已结算 99 全部
     */
    public function getCommissionCount($begin_time = '', $end_time = '', $status = 99) {

        $userIdArr = $this->getAgentUserIdArr();

        $sql = Db::table('ym_manage.agent_settlement')->where('p_uid','>',0)->field('SUM(amount) amount');
        if ($begin_time && $end_time) {
            $sql->where('create_at', 'BETWEEN', [$begin_time, $end_time]);
        }
        if ($status != 99) {
            $sql->where('status',$status);
        }
        $sql->where('uid', 'in', $userIdArr);
        return $sql->find()['amount'];
    }

    /**
     * 重复充值数量
     * @return array
     * return [count,amount]
     */
    public function getTwoPaymentTotal($begin_time, $end_time)
    {
        $userIdArr = $this->getAgentUserIdArr();
        $sql = Db::table('ym_manage.paylog')->where('status',1)->where('type',3)->group('uid')->field('COUNT(1) count, SUM(fee) fee');
        if ($begin_time && $end_time) {
            $sql->where('paytime', 'BETWEEN', [strtotime($begin_time), strtotime($end_time)]);
        }
        $sql->where('uid', 'in', $userIdArr);
        $sqlN = $sql;
        $count = $sql->count();
        $amount = $sqlN->sum('fee');
        return ['count' => $count, 'amount' => $amount];
    }

    /**
     * 充值扣点金额
     * @return array
     * return [count,amount]
     */
    public function getPaymentDecTotal($begin_time, $end_time)
    {
        $userIdArr = $this->getAgentUserIdArr();
        $sql = Db::table('ym_manage.rechargelog')->where('type',0)->field('COUNT(1) count, SUM(czfee) fee');
        if ($begin_time && $end_time) {
            $sql->where('createtime', 'BETWEEN', [strtotime($begin_time), strtotime($end_time)]);
        }
        $sql->where('userid', 'in', $userIdArr);
        $result = $sql->find();
        return ['count' => $result['count'], 'amount' => $result['fee']];
    }

}