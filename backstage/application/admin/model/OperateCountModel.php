<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;

class OperateCountModel extends Model {

    /**
     * 无限代报表统计
     */
    public function getAgentCountTable($begin_time, $end_time) {

        $result = [
            'data' => [],
            'count' => [],
        ];

        $time = date('Y-m-d');

        while($begin_time <= $end_time) {

            if (empty($result['data'][$begin_time])) {
                $result['data'][$begin_time] = [
                    'taxation_count' => 0,
                    'commission_count_settlement' => 0,
                    'commission_count_notsettlement_yesterday' => 0,
                    'commission_count_notsettlement_today' => 0,
                    'top_agent_total' => 0,
                    'agent_total' => 0,
                    'agent_total_today' => 0,
                    'top_agent_total_today' => 0,
                    'time' => $begin_time,
                ];

            }

            // 当日税收统计(佣金总和)
            $result['data'][$begin_time]['taxation_count'] = $this->getCommissionCount($begin_time, $begin_time ." 23:59:59", 99);
            // 当日已结算佣金
            $result['data'][$begin_time]['commission_count_settlement'] = $this->getCommissionCount($begin_time, $begin_time ." 23:59:59", 1);
            // 昨日未结算佣金
            $result['data'][$begin_time]['commission_count_notsettlement_yesterday'] = $this->getCommissionCount(date('Y-m-d',strtotime($begin_time) - 86400), date('Y-m-d',strtotime($begin_time) - 86400) . " 23:59:59", 0);
            // 当日可结算佣金
            $result['data'][$begin_time]['commission_count_notsettlement_today'] = $this->getCommissionCount($begin_time, $begin_time ." 23:59:59", 0);
            // 顶级代理人数
            $result['data'][$begin_time]['top_agent_total'] = $this->getAgentTotal('', $begin_time. " 23:59:59", 'top');
            // 总代理人数
            $result['data'][$begin_time]['agent_total'] = $this->getAgentTotal('', $begin_time. " 23:59:59", 'agent');
            // 当日新增代理
            $result['data'][$begin_time]['agent_total_today'] = $this->getAgentTotal($begin_time, $begin_time. " 23:59:59", 'agent');
            // 当日新增顶级代理
            $result['data'][$begin_time]['top_agent_total_today'] = $this->getAgentTotal($begin_time, $begin_time. " 23:59:59", 'top');

            $begin_time = date('Y-m-d',strtotime($begin_time) + 86400);
        }

        $result['count']['taxation_count'] = $this->getCommissionCount($time, $time ." 23:59:59", 99);
        $result['count']['commission_count_settlement'] = $this->getCommissionCount($time, $time ." 23:59:59", 1);
        $result['count']['commission_count_settlements'] = $result['count']['commission_count_settlement'];
        $result['count']['commission_count_notsettlement_today'] = $this->getCommissionCount($time, $time ." 23:59:59", 0);
        $result['count']['agent_total_today'] = $this->getAgentTotal($time, $time. " 23:59:59", 'agent');
        $result['count']['top_agent_total_today'] = $this->getAgentTotal($time, $time. " 23:59:59", 'top');

        return $result;

    }

    /**
     * 税收统计（输赢）
     * $type = 0 税收统计
     * $type = 1 输赢统计
     * $type = 2 流水统计
     */
    public function getTaxationCount($begin_time = '', $end_time = '', $type = 0) {
        $sql = Db::table('gameaccount.mark');
        if ($begin_time && $end_time) {
            $sql->where('balanceTime','BETWEEN',[$begin_time, $end_time]);
        }
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
        $sql = Db::table('ym_manage.agent_settlement')->where('p_uid','>',0)->field('SUM(amount) amount');
        if ($begin_time && $end_time) {
            $sql->where('create_at', 'BETWEEN', [$begin_time, $end_time]);
        }
        if ($status != 99) {
            $sql->where('status',$status);
        }
        return $sql->find()['amount'];
    }

    /**
     * 代理人数
     */
    public function getAgentTotal($begin_time = '', $end_time = '', $agent_type = 'top') {
        $sql = Db::table('gameaccount.newuseraccounts')->field("COUNT(1) count");
        if ($begin_time) {
            $sql->where('addDate', '>=', $begin_time);
        }
        if ($end_time) {
            $sql->where('addDate', '<=', $end_time);
        }
        if ($agent_type == 'top') {
            $sql->where('channelType',0);
        }
        if ($agent_type == 'agent') {
            $sql->where('channelType','>',0);
        }
        return $sql->find()['count'];
    }

    /**
     * 新注册账号
     */
    public function getAccount($begin_time = '', $end_time = '') {
        $sql = Db::table('gameaccount.newuseraccounts')->where('Id','>',15000)->field('COUNT(1) count');
        if ($begin_time && $end_time) {
            $sql->where('AddDate', 'BETWEEN', [$begin_time, $end_time]);
        }
        return $sql->find()['count'];
    }

    /**
     * 新增参与数
     * 有进行过投注的人数
     */
    public function getNewHave($begin_time = '', $end_time = '') {
        $sql = Db::table('gameaccount.newuseraccounts gn')
                ->join('gameaccount.mark gm', 'gn.Id = gm.userId')
                ->field('COUNT(1) count');
        if ($begin_time && $end_time) {
            $sql->where('balanceTime', 'BETWEEN', [$begin_time, $end_time]);
        }
        return $sql->find()['count'];
    }

    /**
     * 新增充值数
     * 有进行过充值的人数
     */
    public function getNewPayment($begin_time = '', $end_time = '') {
        $sql = Db::table('gameaccount.newuseraccounts gn')
                ->join('ym_manage.paylog yp', 'gn.Id = yp.uid')
                ->where('status',1)->where('type',3)
                ->field('COUNT(1) count');
        if ($begin_time && $end_time) {
            $sql->where('paytime', 'BETWEEN', [strtotime($begin_time), strtotime($end_time)]);
        }
        return $sql->find()['count'];
    }

    /**
     * 新增充值金额
     * return [count,amount]
     */
    public function getPaymentTotal($begin_time = '', $end_time = '') {
        $sql = Db::table('ym_manage.paylog')->where('status',1)->where('type',3)->field('COUNT(1) count, SUM(fee) fee');
        if ($begin_time && $end_time) {
            $sql->where('paytime', 'BETWEEN', [strtotime($begin_time), strtotime($end_time)]);
        }
        $result = $sql->find();
        return ['count' => $result['count'], 'amount' => $result['fee']];

    }

    /**
     * 新增提现人数
     * return [count, money]
     */
    public function getCashTotal($begin_time = '', $end_time = '') {
        $sql = Db::table('ym_manage.user_exchange')->where('status',1)->field('COUNT(1) count, SUM(money) money');
        if ($begin_time && $end_time) {
            $sql->where('created_at', 'BETWEEN', [$begin_time, $end_time]);
        }
        $result = $sql->find();
        return ['count' => $result['count'], 'money' => $result['money']];
    }

    /**
     * 有效总金币
     */
    public function getGlodTotal($begin_time = '', $end_time = '') {
        // return Db::table('gameaccount.userinfo_imp')->where('userId','>',15000)->field('SUM(score) score')->find()['score'];
        $subQuery = Db::table('gameaccount.score_changelog')->order('change_time','desc')->field('userid, score_current');
        if ($begin_time && $end_time) {
            $subQuery->where('change_time','BETWEEN', [$begin_time, $end_time]);
        }
        $subQuery = $subQuery->buildSql();

        $subQueryT1 = Db::table($subQuery." T1")->field('T1.*')->group('T1.userid')->buildSql();
        return Db::table($subQueryT1." T2")->field('SUM(T2.score_current) amount')->find()['amount'];
    }

    /**
     * 平台综合报表
     */
    public function getPlatformIntergrationCountTable($begin_time, $end_time) {

        $result = [
            'data' => [],
        ];

        $time = date('Y-m-d');

        while($begin_time <= $end_time) {

            if (empty($result['data'][$begin_time])) {
                $result['data'][$begin_time] = [];
            }

            $result['data'][$begin_time]['agent_name'] = '代理';
            $result['data'][$begin_time]['time'] = $begin_time;
            // 新账号
            $result['data'][$begin_time]['new_account'] = $this->getAccount($begin_time, $begin_time. " 23:59:59");
            // 新增参与数
            $result['data'][$begin_time]['new_have'] = $this->getNewHave($begin_time, $begin_time. " 23:59:59");
            // 新增充值
            $result['data'][$begin_time]['new_payment'] = $this->getNewPayment($begin_time, $begin_time ." 23:59:59");
            // 新增充币
            $result['data'][$begin_time]['new_payment_gold'] = $this->getPaymentTotal($begin_time, $begin_time ." 23:59:59")['amount'];
            // 活动参与人数
            $result['data'][$begin_time]['activity_have'] = $result['data'][$begin_time]['new_account'];
            // 充值人数
            $reuslt['data'][$begin_time]['payment_total'] = $this->getPaymentTotal($begin_time, $begin_time ." 23:59:59")['count'];
            // 彩金人数
            $result['data'][$begin_time]['color_total'] = $this->colorGoldTotal($begin_time, $begin_time. " 23:59:59")['count'];
            // 提现人数
            $result['data'][$begin_time]['cash_total'] = $this->getCashTotal($begin_time, $begin_time. " 23:59:59")['count'];
            // 佣金数
            $result['data'][$begin_time]['commission_total'] = $this->getCommissionCount($begin_time, $begin_time. " 23:59:59");
            // 彩金金额
            $result['data'][$begin_time]['color_amount'] = $this->colorGoldTotal($begin_time, $begin_time. " 23:59:59")['amount'];
            // 结算佣金
            $result['data'][$begin_time]['commission_count_settlement'] =  $this->getCommissionCount($begin_time, $begin_time ." 23:59:59", 1);
            // 输赢
            $result['data'][$begin_time]['win_or_close_total'] = $this->getTaxationCount($begin_time, $begin_time. " 23:59:59", 1);
            // 流水
            $result['data'][$begin_time]['usecoin'] = $this->getTaxationCount($begin_time, $begin_time. " 23:59:59", 2);
            // 充值金额
            $result['data'][$begin_time]['payment_amount'] = $this->getPaymentTotal($begin_time, $begin_time. " 23:59:59")['amount'];
            // 提现金额
            $reuslt['data'][$begin_time]['cash_amount'] = $this->getCashTotal($begin_time, $begin_time. " 23:59:59")['money'];
            // 充提差
            $result['data'][$begin_time]['diff_pay'] = $result['data'][$begin_time]['payment_amount'] - $reuslt['data'][$begin_time]['cash_amount'];

            $begin_time = date('Y-m-d',strtotime($begin_time) + 86400);
        }

        return $result;
    }

    /**
     * 彩金统计
     */
    public function colorGoldTotal($begin_time = '', $end_time = '') {
        $sql = Db::table('ym_manage.paylog')->where('type','in',[4,5,6,7,8])->where('status',1)->field('COUNT(1) count, SUM(fee) fee');
        if ($begin_time && $end_time) {
            $sql->where('paytime','BETWEEN',[strtotime($begin_time), strtotime($end_time)]);
        }
        $result = $sql->find();
        return ['count' => $result['count'], 'amount' => $result['fee']];
    }

    /**
     * 平台运营总览
     */
    public function getPlatformOperateTotal($begin_time, $end_time) {
        $result = [
            'data' => [],
            'count' => [],
        ];

        $time = date('Y-m-d');

        while($begin_time <= $end_time) {

            if (empty($result['data'][$begin_time])) {
                $result['data'][$begin_time] = [];
            }

            $result['data'][$begin_time]['time'] = $begin_time;

            // 总金币
            $result['data'][$begin_time]['gold_total'] = $this->getGlodTotal($begin_time, $begin_time . "23:59:59");
            // 充值金额
            $result['data'][$begin_time]['payment_amount'] = $this->getPaymentTotal($begin_time, $begin_time. " 23:59:59")['amount'];
            // 提现金额
            $reuslt['data'][$begin_time]['cash_amount'] = $this->getCashTotal($begin_time, $begin_time. " 23:59:59")['money'];
            // 充提差
            $result['data'][$begin_time]['diff_pay'] = $result['data'][$begin_time]['payment_amount'] - $reuslt['data'][$begin_time]['cash_amount'];
            // 流水
            $result['data'][$begin_time]['usecoin'] = $this->getTaxationCount($begin_time, $begin_time. " 23:59:59", 2);
            // 税收统计
            $result['data'][$begin_time]['tax'] = $this->getTaxationCount($begin_time, $begin_time. " 23:59:59");
            // 平台盈利
            $result['data'][$begin_time]['platform_total'] = $result['data'][$begin_time]['diff_pay'] - $result['data'][$begin_time]['tax'];

            $begin_time = date('Y-m-d',strtotime($begin_time) + 86400);
        }

         // 总金币
         $result['count']['gold_total'] = $this->getGlodTotal($time, $time . "23:59:59");
         // 充值金额
         $result['count']['payment_amount'] = $this->getPaymentTotal($time, $time. " 23:59:59")['amount'];
         // 提现金额
         $reuslt['count']['cash_amount'] = $this->getCashTotal($time, $time. " 23:59:59")['money'];
         // 充提差
         $result['count']['diff_pay'] = $result['count']['payment_amount'] - $reuslt['count']['cash_amount'];
         // 流水
         $result['count']['usecoin'] = $this->getTaxationCount($time, $time. " 23:59:59", 2);
         // 税收统计
         $result['count']['tax'] = $this->getTaxationCount($time, $time. " 23:59:59");
         // 平台盈利
         $result['count']['platform_total'] = $result['count']['diff_pay'] - $result['count']['tax'];

        return $result;
    }

    /**
     * 游戏总表
     */
    public function getGameTotal($begin_time, $end_time, $game_id) {

        $result = [
            'data' => [],
            'count' => [],
        ];

        $time = date('Y-m-d');

        while($begin_time <= $end_time) {

            if (empty($result['data'][$begin_time])) {
                $result['data'][$begin_time] = [];
            }

            $markResult = $this->getMarkTotal($begin_time, $begin_time. " 23:59:59", $game_id);

            $result['data'][$begin_time]['rtp'] = $markResult['rtp'];
            $result['data'][$begin_time]['wincoin'] = $markResult['winCoin'];
            $result['data'][$begin_time]['useCoin'] = $markResult['useCoin'];
            $result['data'][$begin_time]['time'] = $begin_time;

            $begin_time = date('Y-m-d',strtotime($begin_time) + 86400);
        }

        $markResultDay = $this->getMarkTotal($time, $time. " 23:59:59", $game_id);
        $result['count']['rtp'] = $markResultDay['rtp'];
        $result['count']['wincoin'] = $markResultDay['winCoin'];
        $result['count']['useCoin'] = $markResultDay['useCoin'];

        return $result;
    }

    /**
     * mark表统计
     */
    public function getMarkTotal($begin_time, $end_time, $game_id) {
        $sql = Db::table('gameaccount.mark')->field('SUM(winCoin) winCoin, SUM(useCoin) useCoin');
        if ($begin_time && $end_time) {
            $sql->where('balanceTime', 'BETWEEN', [$begin_time, $end_time]);
        }
        if (!empty($game_id)) {
            $sql->where('gameId', $game_id);
        }
        $result = $sql->find();
        foreach ($result as $k => $v) {
            $result[$k] = empty($v) ? 0 : $v;
        }
        $rtp = $result['useCoin'] > 0 ? round($result['winCoin'] / $result['useCoin'],2) : 0;
        return [ 'rtp' => $rtp .'%' , 'winCoin' => $result['winCoin'], 'useCoin' => $result['useCoin']];
    }

    /**
     * 活动彩金统计
     */
    public function getColorTotal($begin_time, $end_time) {
        $sql = Db::table('ym_manage.paylog')
                ->where('type','in',[4,5,6,7,8])
                ->where('status',1)
                ->group('type')
                ->field('COUNT(1) count, SUM(fee) fee, type')
                ->field("(CASE type WHEN 4 THEN '认证赠送' WHEN 5 THEN '首充赠送' WHEN 6 THEN '每日首充' WHEN 7 THEN '邀请奖励' WHEN 8 THEN '每日领奖' ELSE '' END) activity_name");
        if ($begin_time && $end_time) {
            $sql->where('paytime','BETWEEN',[strtotime($begin_time), strtotime($end_time)]);
        }
        $result = $sql->select();

        return ['data' => $result, 'count' => count($result)];
    }
}