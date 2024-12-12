<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;
use app\admin\model\PromoterModel;

class MemberModel extends Model {

    /**
     * 获取会员列表
     */
    public function MemberList($limit, $agent_id, $where_column, $column_value, $role, $status, $channel_id, $login_begin_time, $login_end_time, $reg_begin_time, $reg_end_time, $gold_where_id, $gold_begin_value, $gold_end_value) {
        
        $sql = Db::table('gameaccount.newuseraccounts gn')
                ->leftJoin ('gameaccount.logintemp gl', 'gn.Id = gl.loginid')
                ->leftJoin('gameaccount.userinfo_imp gu', 'gn.Id = gu.userId')
                ->where('Id','>','15000')
                ->field('Id,nickname,Account,channelType,AddDate,phoneNo,email,account_using,loginDate,gu.score');
                // 条件筛选
        if (!empty($where_column) && !empty($column_value)) {
            $sql->where($where_column,'like',"%{$column_value}%");
        }
        if (!empty($role)) {
            if ($role == 1) {
                $sql->where('channelType','<>','abc');
            }
            if ($role == 2) {
                $sql->where('channelType','abc');
            }
        }
        if (!empty($status)) {
            if ($status == 1) {
                $sql->where('account_using',1);
            }
            if ($status == 2) {
                $sql->where('account_using',0);
            }
        }
        if (!empty($login_begin_time) && !empty($login_end_time)) {
            $sql->where('loginDate','BETWEEN', [$login_begin_time, $login_end_time]);
        }
        if (!empty($reg_begin_time) && !empty($reg_end_time)) {
            $sql->where('AddDate','BETWEEN', [$reg_begin_time, $reg_end_time]);
        }

        $result = $sql->paginate($limit)->toArray();
        $promoterModel = new PromoterModel;

        // 特定条件查找
        foreach ($result['data'] as $k => $v) {
            // 角色
            if ($v['channelType'] == 'abc') {
                $result['data'][$k]['role'] = '游客';
            } else {
                $result['data'][$k]['role'] = '正式';
            }
            // 账号状态
            if ($v['account_using'] == 0) {
                $result['data'][$k]['account_status'] = '已封禁';
            }
            if ($v['account_using'] == 1) {
                $result['data'][$k]['account_status'] = '已开启';
            }
            // 层级
            $result['data'][$k]['level'] = $promoterModel->getAgentLevel($v['Id']) + 1;
            // 彩金
            $result['data'][$k]['color_gold'] = $promoterModel->color_gold($v['Id']);
            // 历史充值
            $result['data'][$k]['count_payment'] = $promoterModel->getRechargeAmount($v['Id']);
            // 历史提现
            $result['data'][$k]['count_outcash'] = $promoterModel->outCash($v['Id']);
            // 历史流水
            $result['data'][$k]['count_wincoin'] = Db::table('gameaccount.mark')->where('userId', $v['Id'])->where('winCoin',0)->field('SUM(winCoin) winCoin')->find()['winCoin'];
            // 历史佣金
            $result['data'][$k]['count_commission'] = $promoterModel->getCommission($v['Id'])['amount'];
            // 历史充提
            $result['data'][$k]['count_paydiff'] = $result['data'][$k]['count_payment'] - $result['data'][$k]['count_outcash'];

            // 条件查找
            if (!empty($gold_where_id)) {
                if (!empty($gold_begin_value)) {
                    if ($result['data'][$k][$gold_where_id] < $gold_begin_value) {
                        unset($result['data'][$k]);
                        continue;
                    }
                }
                if (!empty($gold_end_value)) {
                    if ($result['data'][$k][$gold_where_id] > $gold_end_value) {
                        unset($result['data'][$k]);
                        continue;
                    }
                }
            }
        }
        return $result;
    }

    /**
     * 会员详情
     */
    public function getInfo($id) {

        $data = [];
        $promoterModel = new PromoterModel;
		$today = [date('Y-m-d'), date('Y-m-d')." 23:59:59"];
        $topAgentId = $promoterModel->getTopAgentList(17069);
        if (count($topAgentId) <= 1) {
            $topAgentId = 0;
        } else {
            $topAgentId = $topAgentId[count($topAgentId)-2];
        }

        // 个人信息
        $data['info'] = Db::table('gameaccount.newuseraccounts gn')
                            ->leftJoin ('gameaccount.logintemp gl', 'gn.Id = gl.loginid')
                            ->leftJoin('gameaccount.userinfo_imp gu', 'gn.Id = gu.userId')
                            ->where('Id',$id)
                            ->field('Id,nickname,Account,channelType,AddDate,phoneNo,email,account_using,loginDate,gu.score')
                            ->find();
        $data['info']['status'] = $data['info']['account_using'] == 0 ? '封禁' : '启用';
        $data['info']['role'] = $data['info']['channelType'] == 'abc' ? '游客' : '正式';
        $data['info']['level'] = $promoterModel->getAgentLevel($id) + 1;
        $data['info']['payment_onec'] = Db::table('ym_manage.paylog')->where('uid',$id)->where('type',3)->where('status',1)->field('FROM_UNIXTIME(paytime) paytime')->find()['paytime'];

        // 金币信息
        $data['gold'] = [];
        $data['gold']['score'] = $data['info']['score'];
        $data['gold']['day_payment'] = $promoterModel->getRechargeAmount($id, $today[0], $today[1]);
        $data['gold']['count_payment'] = $promoterModel->getRechargeAmount($id);
        $data['gold']['day_color'] = 0;
        $data['gold']['count_color'] = 0;
        $data['gold']['day_outcash'] = $promoterModel->outCash($id, $today[0], $today[1]);
        $data['gold']['count_outcash'] = $promoterModel->outCash($id, $today[0], $today[1]);
        $data['gold']['day_outcash_number'] = Db::table('ym_manage.user_exchange')->where('user_id',$id)->where('status',1)->where('updated_at','between',$today)->count();
        $data['gold']['day_wincoin'] = Db::table('gameaccount.mark')->where('userId', $id)->where('balanceTime','between', $today)->field('SUM(winCoin) winCoin')->find()['winCoin'];
        $data['gold']['count_wincoin'] = Db::table('gameaccount.mark')->where('userId', $id)->field('SUM(winCoin) winCoin')->find()['winCoin'];
        $data['gold']['day_performance'] = $promoterModel->getPerformance($id, $today[0], $today[1]);
        $data['gold']['count_performance'] = $promoterModel->getPerformance($id);
        $data['gold']['day_water'] = Db::table('gameaccount.mark')->where('userId', $id)->where('winCoin',0)->where('balanceTime','between', $today)->field('SUM(winCoin) winCoin')->find()['winCoin'];
        $data['gold']['count_water'] = Db::table('gameaccount.mark')->where('userId', $id)->where('winCoin',0)->field('SUM(winCoin) winCoin')->find()['winCoin'];
        $data['gold']['day_paydiff'] = $data['gold']['day_payment'] - $data['gold']['day_outcash'];
        $data['gold']['count_paydiff'] = $data['gold']['count_payment'] - $data['gold']['count_outcash'];
        $data['gold']['day_payment_once'] = Db::table('ym_manage.paylog')->where('uid',$id)->where('type',3)->where('status',1)->where('paytime','between', [strtotime($today[0]), strtotime($today[1])])->field('fee')->find()['fee'];
        $data['gold']['reg_day_payment_once'] = Db::table('ym_manage.paylog')->where('uid',$id)->where('type',3)->where('status',1)->where('paytime','between', [strtotime(date('Y-m-d',strtotime($data['info']['AddDate']))), strtotime(date('Y-m-d',strtotime($data['info']['AddDate']))) + 86399])->field('fee')->find()['fee'];

        // 注册信息
        $data['register'] = [];
        $data['register']['prev_login_time'] = $data['info']['loginDate'];
        $data['register']['register_time'] = $data['info']['AddDate'];
        $data['register']['device'] = '';
        $data['register']['channelName'] = '代理';
        $data['register']['pid'] = $data['info']['channelType'];
        $data['register']['topid'] = $topAgentId;
        $data['register']['note'] = '';

        // 代理信息
        $data['agent'] = [];
        $data['agent']['day_team_add'] = $promoterModel->getRegisterTotal($id, $today[0], $today[1]);
        $data['agent']['team_size'] = $promoterModel->getRegisterTotal($id);
        $data['agent']['day_team_direct_add'] = $promoterModel->getRegisterTotal($id, $today[0], $today[1], 0, 1);
        $data['agent']['team_size_direct'] = $promoterModel->getRegisterTotal($id, '', '', 0, 1);
        $data['agent']['day_team_performance'] = $promoterModel->getPerformance($id, $today[0], $today[1], 'team');
        $data['agent']['day_team_performance_true'] = $promoterModel->getPerformance($id, $today[0], $today[1], 'team', 1);
        $data['agent']['day_direct_performance'] = $promoterModel->getPerformance($id, $today[0], $today[1], 'team', 0, 0, 1);
        $data['agent']['day_direct_performance_true'] = $promoterModel->getPerformance($id, $today[0], $today[1], 'team', 1, 0, 1);
        $data['agent']['day_commission'] = $promoterModel->getCommission($id, $today[0], $today[1], 'team')['amount'];
        $data['agent']['count_commission'] = $promoterModel->getCommission($id, '', '', 'team')['amount'];

        return $data;
    }

    /**
     * 支付日志
     */
    public function MemberPayList($limit, $agent_id, $pay_type, $uid, $pay_sn, $order_begin_time, $order_end_time) {

        $sql = Db::table('ym_manage.paylog')
                ->join('gameaccount.score_changelog gsc', "ym_manage.paylog.osn = gsc.pay_sn AND gsc.pay_sn <> ''")
                ->where('status',1)
                ->field('uid,fee,osn,FROM_UNIXTIME(paytime) paytime')
                ->field("(CASE type WHEN 3 THEN '充值到账' WHEN 99 THEN '提现' WHEN 4 THEN '认证赠送' WHEN 5 THEN '首充赠送' WHEN 6 THEN '每日首充' WHEN 7 THEN '邀请奖金' WHEN 8 THEN '每日领奖' WHEN 9 THEN '佣金' WHEN 10 THEN '人工送点' WHEN 11 THEN '人工扣点' ELSE '' END) AS pay_type_format")
                ->field('gsc.score_current')
                ->order('paytime','desc');

        if (!empty($uid)) {
            $sql->where('uid',$uid);
        }
        if (!empty($pay_sn)) {
            $sql->where('osn',$pay_sn);
        }
        if ($order_begin_time && $order_end_time) {
            $sql->where('paytime','BETWEEN', [strtotime($order_begin_time), strtotime($order_end_time)]);
        }
        if (!empty($pay_type)) {
            if ($pay_type == 1) {
                $sql->where('type',3);
            }
            if ($pay_type == 2) {
                $sql->where('type',99);
            }
            if ($pay_type == 3) {
                $sql->where('type',4);
            }
            if ($pay_type == 4) {
                $sql->where('type',5);
            }
            if ($pay_type == 5) {
                $sql->where('type',6);
            }
            if ($pay_type == 6) {
                $sql->where('type',7);
            }
            if ($pay_type == 7) {
                $sql->where('type',8);
            }
            if ($pay_type == 8) {
                $sql->where('type',9);
            }
            if ($pay_type == 9) {
                $sql->where('type',10);
            }
            if ($pay_type == 10) {
                $sql->where('type',11);
            }
        }

        $result = $sql->paginate($limit)->toArray();
        return $result;

    }

    /**
     * 获取游戏列表
     */
    public function getGameList($column_name) {
        return Db::table('ym_manage.game')->where('delete_at',0)->field($column_name)->select();
    }

    /**
     * 获取投注记录
     */
    public function MemberBettingList($limit, $agent_id, $game_id, $uid, $mark_id, $mark_begin_time, $mark_end_time) {

		# m.bfUserCoin,(m.bfUserCoin + m.winCoin) AS afUserCoin
        $sql = Db::table('gameaccount.mark m')
                ->join('ym_manage.game g', ['m.gameId = g.gameid', 'm.serverId = g.port'])
                ->order('m.balanceTime','DESC')
                ->field('m.id,m.balanceTime,m.userId,m.useCoin,m.winCoin,m.tax,m.gameId,m.mark, g.name');

        if (!empty($game_id)) {
            $sql->where('m.gameId',$game_id);
        }
        if (!empty($uid)) {
            $sql->where('m.userId',$uid);
        }
        if (!empty($mark_id)) {
            $sql->where('m.id',$mark_id);
        }
        if ($mark_begin_time && $mark_end_time) {
            $sql->where('m.balanceTime','BETWEEN',[$mark_begin_time, $mark_end_time]);
        }

        $result = $sql->paginate($limit)->toArray();
        return $result;
    }
}
