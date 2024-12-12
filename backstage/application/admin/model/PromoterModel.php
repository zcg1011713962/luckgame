<?php
namespace app\admin\model;
use app\agent\model\AdminModel;
use think\Model;
use think\Db;
use app\api\controller\Game as ApiGame;

class PromoterModel extends Model {

    /*
     * 获取顶级代理列表
     * 没有推广ID的均为顶级代理
     */
    public function topAgentList($limit = 30, $agent_id = 0, $uid = 0, $begin_time = '', $end_time = '') {

        $sql = Db::table('gameaccount.newuseraccounts')->where('ChannelType',0)->field('Id, nickname');
        if (!empty($uid)) {
			$sql->where('Id',$uid);
		}
		$result = $sql->paginate($limit)->toArray();

        foreach ($result['data'] as $k => $v) {

            // 当前代理下所有当日注册人数
            $result['data'][$k]['day_register'] = $this->getRegisterTotal($v['Id'], date('Y-m-d'), date('Y-m-d'). " 23:59:59");
            // 充值金额-个人
            $result['data'][$k]['person_recharge_amount'] = $this->getRechargeAmount($v['Id'], $begin_time, $end_time, 'person');
            // 充值金额-团队
            $result['data'][$k]['team_recharge_amount'] = $this->getRechargeAmount($v['Id'], $begin_time, $end_time, 'team');
            // 业绩-个人
            $result['data'][$k]['person_performance'] = $this->getPerformance($v['Id'], $begin_time, $end_time, 'person');
            // 业绩-团队
            $result['data'][$k]['team_performance'] = $this->getPerformance($v['Id'], $begin_time, $end_time, 'team');
            // 有效业绩-个人
            $result['data'][$k]['person_effect_performance'] = $this->getPerformance($v['Id'], $begin_time, $end_time, 'person', 1);
            // 有效业绩-团队
            $result['data'][$k]['team_effect_performance'] = $this->getPerformance($v['Id'], $begin_time, $end_time, 'team', 1);
            // 税金-个人
            $result['data'][$k]['person_taxes'] = $this->getCommission($v['Id'], $begin_time, $end_time, 'person')['amount'];
            // 税金-团队
            $result['data'][$k]['team_taxes'] = $this->getCommission($v['Id'], $begin_time, $end_time, 'team')['amount'];
            // 提现-个人
            $result['data'][$k]['person_outcash'] = $this->outCash($v['Id'], $begin_time, $end_time, 'person');
            // 提现-团队
            $result['data'][$k]['team_outcash'] = $this->outCash($v['Id'], $begin_time, $end_time, 'team');
            // 彩金-个人
            $result['data'][$k]['person_color'] = $this->getColorAmount($v['Id'], $begin_time, $end_time, 'person');
            // 彩金-团队
			$result['data'][$k]['team_color'] = $this->getColorAmount($v['Id'], $begin_time, $end_time, 'team');
            // 平台盈利
            $result['data'][$k]['platform_profit'] = ($result['data'][$k]['person_recharge_amount'] + $result['data'][$k]['team_recharge_amount']) - ($result['data'][$k]['person_outcash'] + $result['data'][$k]['team_outcash']) - ($result['data'][$k]['person_taxes'] + $result['data'][$k]['team_taxes']);
            // 团队人数
            $result['data'][$k]['team_size'] = $this->getRegisterTotal($v['Id']);
        }

        return $result;
    }
    
    /**
     * 获取某天注册人数
     * 指定某一个代理ID(pid)
     * 获取这个代理下所有注册人数
     */
    public function getRegisterTotal($pid, $begin_time = '', $end_time = '', $count = 0, $next_agent = 0) {

        $sql = Db::table('gameaccount.newuseraccounts')->where('ChannelType', $pid)->field('Id');
        if (!empty($begin_time) && !empty($end_time)) {
            $sql->where('AddDate','between', [$begin_time, $end_time]);
        }
        $result = $sql->select();

        foreach ($result as $k => $v) {
            if ($next_agent == 0) {
                $count += $this->getRegisterTotal($v['Id'], $begin_time, $end_time) + 1;
            } elseif($next_agent == 1) {
                $count += 1;
            } elseif ($next_agent == 2) {
                if ($this->getAgentNextIsAgent($v['Id']) > 0) {
                    $count +=  $this->getRegisterTotal($v['Id'], $begin_time, $end_time, $count, $next_agent) + 1;
                }
            }
        }

        return $count;
    }

    /**
     * 获取某个代理下是否还有代理
     */
    public function getAgentNextIsAgent($id) {
        return Db::table('gameaccount.newuseraccounts')->where('ChannelType', $id)->count();
    }

    /**
     * 获取顶级代理人
     */
    public function getTopAgentList($uid, $data = [], $count = 0) {

        // 获取游戏代理方式 ...
		$game_agent = Db::table('gameaccount.newuseraccounts')->field('ChannelType as uid')->where('Id',"{$uid}")->where('ChannelType','<>','abc')->where('ChannelType','>',0)->find();

		$pid = 0;

		if (!empty($game_agent)) {
			$pid = $game_agent['uid'];
		}

        // 合并代理用户 ...
		$data[$count] = $pid;

		if (!empty($data[$count])) {
			return $this->getTopAgentList($data[$count],$data,($count+1));
		}

		return $data;
    }


    /**
     * 获取彩金金额
     * person OR team
     * 根据不同值获取不同结果
     */
    public function getColorAmount($id, $begin_time = '', $end_time = '', $type = 'person') {

        if ($type == 'person') {
            $sql = Db::table('ym_manage.paylog')->where('uid',$id)->where('status',1)->where('type','in',[4,5,6,7,8])->group('uid')->field('SUM(fee) as fee');
            if ($begin_time && $end_time) {
                $sql->where('paytime','between',[strtotime($begin_time), strtotime($end_time)]);
            }
            $result = $sql->find();
            return $result['fee'] ? $result['fee'] : 0;
        }

        if ($type == 'team') {
            $amount = 0;
            $sql = Db::table('gameaccount.newuseraccounts gn')
				    ->join('ym_manage.paylog ympay', 'gn.Id = ympay.uid')
				    ->where('gn.channelType', $id)
				    ->where('ympay.status',1)
                    ->where('ympay.type','in',[4,5,6,7,8])
				    ->group('ympay.uid')
				    ->field('gn.Id,SUM(ympay.fee) as fee');
            if ($begin_time && $end_time) {
                $sql->where('paytime','between',[strtotime($begin_time), strtotime($end_time)]);
            }
            $result = $sql->select();

            foreach ($result as $k => $v) {
                $amount += $this->getColorAmount($v['Id'], $begin_time, $end_time, $type) + $v['fee'];
            }

            return $amount;
        }
    }

    /**
     * 获取充值金额
     * person OR team
     * 根据不同值获取不同结果
     */
    public function getRechargeAmount($id, $begin_time = '', $end_time = '', $type = 'person') {

        if ($type == 'person') {
            $sql = Db::table('ym_manage.paylog')->where('uid',$id)->where('status',1)->group('uid')->field('SUM(fee) as fee');
            if ($begin_time && $end_time) {
                $sql->where('paytime','between',[$begin_time, $end_time]);
            }
            $result = $sql->find();
            if($result == null || !isset($result["fee"])){
               return 0;
             }
             return $result["fee"];
            //return $result['fee'] ? $result['fee'] : 0;
        }

        if ($type == 'team') {
            $amount = 0;
            $sql = Db::table('gameaccount.newuseraccounts gn')
				    ->join('ym_manage.paylog ympay', 'gn.Id = ympay.uid')
				    ->where('gn.channelType', $id)
				    ->where('ympay.status',1)
				    ->group('ympay.uid')
				    ->field('gn.Id,SUM(ympay.fee) as fee');
            if ($begin_time && $end_time) {
                $sql->where('paytime','between',[$begin_time, $end_time]);
            }
            $result = $sql->select();

            foreach ($result as $k => $v) {
                $amount += $this->getRechargeAmount($v['Id'], $begin_time, $end_time, $type) + $v['fee'];
            }

            return $amount;
        }
    }

    /**
     * 获取佣金 OR 有效业绩
     * 取决于 是否有首充
     * person OR team
     * 根据不同值获取不同结果
     * return [
     *  'amount',
     *  'every_statement',
     *  'status',
     * ]
     */
    public function getCommission($id, $begin_time = '', $end_time = '', $type = 'person', $effect_performance = 0, $count = [
        'amount' => 0,
        'amount_0' => 0,
        'amount_1' => 0,
    ]) {
        if ($type == 'person') {
            $sql = Db::table('ym_manage.agent_settlement agent')
                    ->where('agent.uid', $id)
                    ->leftJoin('ym_manage.paylog ympay', 'agent.uid = ympay.uid')
                    ->group('agent.uid, agent.status, ympay.status')
                    ->field('SUM(agent.amount) as amount, agent.status as agent_status, ympay.status as ympay_status ');
            if ($begin_time && $end_time) {
                $sql->where('agent.create_at', 'between', [$begin_time, $end_time]);
            }
            $result = $sql->select();
            foreach ($result as $k => $v) {
                if ($effect_performance == 1 && $v['ympay_status'] == 1) {
                    $count['amount'] += $v['amount'];
                    $count['amount_'.$v['agent_status']] += $v['amount'];
                }
                if ($effect_performance == 0) {
                    $count['amount'] += $v['amount'];
                    $count['amount_'.$v['agent_status']] += $v['amount'];
                }
            }
        }

        if ($type == 'team') {
            $sql = Db::table('gameaccount.newuseraccounts gn')
                ->join('ym_manage.agent_settlement agent', 'gn.Id = agent.uid')
                ->leftJoin('ym_manage.paylog ympay', 'agent.uid = ympay.uid')
                ->where('gn.channelType', $id)
                ->group('agent.uid, agent.status, ympay_status')
                ->field('gn.Id, agent.p_uid, SUM(agent.amount) as amount, agent.status as agent_status, ympay.status as ympay_status ');
            if ($begin_time && $end_time) {
                $sql->where('agent.create_at', 'between', [$begin_time, $end_time]);
            }
            $result = $sql->select();
            foreach ($result as $k => $v) {
                if ($v['p_uid'] > 0) {
                    if ($effect_performance == 1 && $v['ympay_status'] == 1) {
                        $count['amount'] += $v['amount'];
                        $count['amount_'.$v['agent_status']] += $v['amount'];
                    }
                    if ($effect_performance == 0) {
                        $count['amount'] += $v['amount'];
                        $count['amount_'.$v['agent_status']] += $v['amount'];
                    }
                }

                return $this->getCommission($v['Id'], $begin_time, $end_time, $type, $effect_performance, $count);
            }
        }

        return $count;
    }

   /**
     * 获取业绩 OR 有效业绩
     * 取决于 是否有首充
     * person OR team
     * 根据不同值获取不同结果
     * return [
     *  'amount',
     *  'every_statement',
     *  'status',
     * ]
     */
    public function getPerformance($id, $begin_time = '', $end_time = '', $type = 'person', $effect_performance = 0, $tax = 0, $next_agent = 0) {
        if ($type == 'person') {
            $sql = Db::table('ym_manage.agent_settlement agent')
                    ->where('agent.uid', $id)->where('agent.p_uid',0)
                    ->leftJoin('ym_manage.paylog ympay', 'agent.uid = ympay.uid')
                    ->field('SUM(every_statement) as every_statement');
            if ($begin_time && $end_time) {
                $sql->where('agent.create_at', 'between', [$begin_time, $end_time]);
            }
            $result = $sql->find();
            $tax = $result['every_statement'] ? $result['every_statement'] : 0;
            return $tax;
        }
        if ($type == 'team') {
            $sql = Db::table('gameaccount.newuseraccounts gn')
                ->join('ym_manage.agent_settlement agent', 'gn.Id = agent.uid')
                ->leftJoin('ym_manage.paylog ympay', 'agent.uid = ympay.uid')
                ->where('gn.channelType', $id)
                ->group('gn.Id, agent.p_uid')
                ->field('gn.Id, agent.p_uid, SUM(agent.every_statement) every_statement,  ympay.status as ympay_status');
            if ($begin_time && $end_time) {
                $sql->where('agent.create_at', 'between', [$begin_time, $end_time]);
            }
            $result = $sql->select();
            foreach ($result as $k => $v) {
                if ($v['p_uid'] == 0) {
                    if ($effect_performance == 1 && $v['ympay_status'] == 1) {
                        $tax += $v['every_statement'];
                    }
                    if ($effect_performance == 0) {
                        $tax += $v['every_statement'];
                    }
                }
                if ($next_agent == 0) {
                    return $this->getPerformance($v['Id'], $begin_time, $end_time, $type, $effect_performance, $tax, $next_agent);
                }
            }
        }
        return $tax;
    }

    /**
     * 获取提现金额
     * person OR team
     * 根据不同值返回不同结果
     */
    public function outCash($id, $begin_time = '', $end_time = '', $type = 'person', $amount = 0) {
        if ($type == 'person') {
            $sql = Db::table('ym_manage.user_exchange')->where('user_id',$id)->where('status',1)->group('user_id')->field('SUM(money) as money');
            if ($begin_time && $end_time) {
                $sql->where('updated_at','between',[$begin_time, $end_time]);
            }
            $result = $sql->find();
            if($result == null){
              return 0;
            }
            return $result['money'] ? $result['money'] : 0;
        }
        if ($type == 'team') {
            $sql = Db::table('gameaccount.newuseraccounts gn')
            ->join('ym_manage.user_exchange ue', 'gn.Id = ue.user_id')
            ->where('gn.channelType', $id)
            ->where('ue.status',1)
            ->group('ue.user_id')
            ->field('gn.Id,SUM(ue.money) as money');
            if ($begin_time && $end_time) {
                $sql->where('updated_at','between',[$begin_time, $end_time]);
            }
            $result = $sql->select();

            foreach ($result as $k => $v) {
               $amount += $this->outCash($v['Id'], $begin_time, $end_time, $type) + $v['money'];
            }
        }

        return $amount;
    }

    /**
     * 代理列表
     */
    public function AgentList($limit = 30, $agent_id, $level_id, $uid, $pid, $commission_no_from, $commission_no_to, $commission_yes_from, $commission_yes_to) {
        
        $sql = Db::table('gameaccount.newuseraccounts gn')
            ->join('ym_manage.agentinfo ue', 'gn.Id = ue.uid', 'left')
            ->field('Id, nickname, channelType, ue.name, ue.aid')->where('Id','>',15000);

        // 顶级代理
        if ($level_id == 0) {
            $sql->where('ChannelType',0);
        }
        // 非顶级代理
        if ($level_id == 1) {
            $sql->where('ChannelType','>',0);
        }
        // 最底层代理
        if ($level_id == 2) {
            $agentArr = $this->getAgentBottomLevel();
            if (count($agentArr) > 0) {
                $sql->where('Id', 'in', $agentArr);
            }
        }

        if (!empty($uid)) {
			$sql->where('Id',$uid);
		}
        if ($pid > 0) {
			$sql->where('channelType',$pid);
		}

		$result = $sql->paginate($limit)->toArray();

        $model = new AdminModel;
        foreach ($result['data'] as $k => $v) {
            // 上级ID
            $result['data'][$k]['channelType'] = intval($v['channelType']);
            // 当前代理层级
            $result['data'][$k]['level'] = $this->getAgentLevel($v['Id']) + 1;
            // 团队人数
            $result['data'][$k]['team_size'] = $this->getRegisterTotal($v['Id']);
            // 当天佣金
            $today_performance =  $this->getCommission($v['Id'], date('Y-m-d'), date('Y-m-d') .' 23:59:59');
            // 未领佣金-当天
            $result['data'][$k]['no_performance'] = $today_performance['amount_0'];
            // 已领佣金-当天
            $result['data'][$k]['yes_performance'] = $today_performance['amount_1'];
            // 历史佣金
            $result['data'][$k]['history_performance'] = $this->getCommission($v['Id'])['amount'];

            // 佣金筛选规则
            if ($commission_no_from > 0 && $result['data'][$k]['no_performance'] < $commission_no_from) {
				unset($result['data'][$k]);
			}
			if ($commission_no_to > 0 && $result['data'][$k]['no_performance'] > $commission_no_to) {
				unset($result['data'][$k]);
			}
			if ($commission_yes_from > 0 && $result['data'][$k]['yes_performance'] < $commission_yes_from) {
				unset($result['data'][$k]);
			}
			if ($commission_yes_to > 0 && $result['data'][$k]['yes_performance'] > $commission_yes_to) {
				unset($result['data'][$k]);
			}

            // 代理推广链接和推广二维码
            $url = '';
            $pic = '';
            if ($v['aid']) {
                $url = $model->getConfig('app.SystemUrl').'/index/index/register?id='.$v['aid'];//进入游戏链接地址
                $name = 'agent_'.$v['aid'].'_new.png';//生成二维码文件名前缀
                $path = 'qrcode';// Public目录下文件夹名称
                //$pic = create_qrcode($url,$name,$path);
            }
            //$result['data'][$k]['url'] = $url;
            //$result['data'][$k]['qrcode'] = $pic;
        }

        return $result;
    }

    /**
     * 获取最底层代理
     */

    public function getAgentBottomLevel() {

        $result = Db::table('gameaccount.newuseraccounts')->field('Id id, channelType pid')->where('channelType','>',0)->where('Id','>',15000)->select();

		$ids = [];
		$pids = [];

		if (count($result) == 0) {
			return [];
		}

		foreach ($result as $k => $v) {

			$ids[$v['id']] = [
				'ids' => $v['id'],
				'pids' => $v['pid']
			];

			$pids[$v['pid']] = [
				'ids' => $v['id'],
				'pids' => $v['pid']
			];
		}

		$doubleLinkedListResult = [];
		foreach ($ids as $k => $v) {
			$doubleLinkedListResult[] = $this->bottomLevelReducer($ids, $pids, $v);
		}

		$agentArr = [];
		foreach ($doubleLinkedListResult as $k => $v) {
			$agentArr[$v['ids']] = 0;
		}

		return array_keys($agentArr);
	 }

	public function bottomLevelReducer($ids, $pids, $curr) {

		if (!empty($pids[$curr['ids']])) {
			return $this->bottomLevelReducer($ids, $pids, $pids[$curr['ids']]);
		}
		return $curr;
	}

    /**
     * 代理级别
     */
    public function getAgentLevel($id, $type = 'level', $data = [], $count = 0) {

		$game_agent = Db::table('gameaccount.newuseraccounts')->field('ChannelType as uid')->where('Id',$id)->where('ChannelType','>',0)->find();

		$pid = 0;

		if (!empty($game_agent)) {
			$pid = $game_agent['uid'];
		}

        // 合并代理用户 ...
		$data[$count] = $pid;

		if (!empty($data[$count])) {
			return $this->getAgentLevel($data[$count], $type, $data, ($count+1));
		}

        if ($type == 'level') {
            return $count;
        }

		return $data;
    }

    // 每日代理列表
    public function DayAgentList($limit = 30, $diff_id, $uid, $pid, $commission_no_from, $commission_no_to, $commission_yes_from, $commission_yes_to, $begin_time, $end_time) {
        
        $sql = Db::table('gameaccount.newuseraccounts')->field('Id, nickname, channelType');

        if (!empty($uid) || !empty($pid)) {
            if (!empty($uid)) {
                $sql->where('Id',$uid);
            }
            if (!empty($pid)) {
                $sql->where('channelType',$pid);
            }
        } else {
            $sql->where('channelType','>',0);
        }

        $result = $sql->paginate($limit)->toArray();

        foreach ($result['data'] as $k => $v) {

            // 日期
            $result['data'][$k]['begin_time'] = $begin_time;
			$result['data'][$k]['end_time'] = $end_time;
            // 上级ID
            $result['data'][$k]['channelType'] = intval($v['channelType']);
            // 业绩-个人
            $result['data'][$k]['person_performance'] = $this->getPerformance($v['Id'], $begin_time, $end_time, 'person');
            // 有效业绩-个人
            $result['data'][$k]['person_effect_performance'] = $this->getPerformance($v['Id'], $begin_time, $end_time, 'person', 1);
            // 当天佣金
            $today_performance =  $this->getCommission($v['Id'], $begin_time, $end_time);
            // 未领佣金-当天
            $result['data'][$k]['no_performance'] = $today_performance['amount_0'];
            // 已领佣金-当天
            $result['data'][$k]['yes_performance'] = $today_performance['amount_1'];

            // 佣金筛选
			if ($commission_no_from > 0 && $result['data'][$k]['no_performance'] < $commission_no_from) {
				unset($result['data'][$k]);
                continue;
			}
			if ($commission_no_to > 0 && $result['data'][$k]['no_performance'] > $commission_no_to) {
				unset($result['data'][$k]);
                continue;
			}
			if ($commission_yes_from > 0 && $result['data'][$k]['yes_performance'] < $commission_yes_from) {
				unset($result['data'][$k]);
                continue;
			}
			if ($commission_yes_to > 0 && $result['data'][$k]['yes_performance'] > $commission_yes_to) {
				unset($result['data'][$k]);
                continue;
			}

            // 团队统计
			$result['data'][$k]['team_info'] = $this->dayTeamCount($v['Id'], $begin_time, $end_time);

            // 充提差筛选
			if ($diff_id == 1 && $result['data'][$k]['team_info']['diff_payment'] < 0) {
				unset($result['data'][$k]);
                continue;
			}
			if ($diff_id == 2 && $result['data'][$k]['team_info']['diff_payment'] > 0) {
				unset($result['data'][$k]);
                continue;
			}
        }

        return $result;
    }

    public function dayTeamCount($id, $begin_time = '', $end_time = '', $count = [
		'active_num' => 0,
		'team_performance' => 0,
		'team_performance_true' => 0,
		'new_add_num' => 0,
		'payment_num' => 0,
		'out_payment_num' => 0,
		'diff_payment' => 0,
		'winLose' => 0,
	]) {

		$baseResult = Db::table('gameaccount.newuseraccounts gn')
						->where('gn.ChannelType', $id)
						->field('gn.Id')
						->select();
		
		foreach ($baseResult as $k => $v) {

			// 获取该用户是否充值过
			$isPay = Db::table('ym_manage.paylog')->where('uid', $v['Id'])->where('status',1)->field('COUNT(1) count')->find();
			// 统计业绩
            $count['team_performance'] += $this->getPerformance($v['Id'], $begin_time, $end_time, 'person');
            $count['team_performance_true'] += $this->getPerformance($v['Id'], $begin_time, $end_time, 'person', 1);
            if ($count['team_performance'] > 0) {
                $count['active_num'] += 1;
            }
			// 新增用户
			$newUserInfo = Db::table('gameaccount.newuseraccounts')->where('Id',$v['Id'])->where('AddDate','between', [$begin_time, $end_time])->field('COUNT(1) count')->find();
			$count['new_add_num'] += $newUserInfo['count'];
			// 充值
			$paymentInfo = Db::table('ym_manage.paylog')->where('uid', $v['Id'])->where('status',1)->where('type',3)->where('paytime','between', [$begin_time, $end_time])->field('SUM(fee) fee')->find();
			$count['payment_num'] += $paymentInfo['fee'];
			// 提现
			$outPaymentInfo = Db::table('ym_manage.user_exchange')->where('user_id', $v['Id'])->where('status',1)->where('created_at','between', [$begin_time, $end_time])->field('SUM(money) money')->find();
			$count['out_payment_num'] += $outPaymentInfo['money'];
			// 充提差
			$count['diff_payment'] += $count['payment_num'] - $count['out_payment_num'];
			// 输赢
			$count['winLose'] += Db::table('gameaccount.mark')->where('userId', $v['Id'])->where('balanceTime','between', [$begin_time, $end_time])->field('SUM(winCoin) winCoin')->find()['winCoin'];

			return $this->dayTeamCount($v['Id'], $begin_time, $end_time, $count);

		}

		return $count;
	}


    // 代理数据详情
	public function AgentInfo($id) {

		$apigame = new ApiGame;

		// 个人信息
		$user_info = Db::table('gameaccount.newuseraccounts')
						->field('Account, ChannelType, nickname, phoneNo, email, Id')
						->where('Id', $id)->find();

		// 个人信息-佣金统计
		$user_info_commission = $this->getCommission($id,'','','person');
		$user_info['history_commission'] = $user_info_commission['amount'];
		$user_info['draw_commission'] = $user_info_commission['amount_1'];
		$user_info['surplus_commission'] = $user_info_commission['amount_0'];

        // 今日时间
		$today = [date('Y-m-d'), date('Y-m-d')." 23:59:59"];
        // 昨日时间
		$yesterday = [date('Y-m-d', strtotime("-1 day")), date('Y-m-d', strtotime("-1 day"))." 23:59:59"];
		// 上周
        $preday = [date("Y-m-d H:i:s",mktime(0, 0 , 0,date("m"),date("d")-date("N")+1-7,date("Y"))),date("Y-m-d H:i:s",mktime(23,59,59,date("m"),date("d")-date("N")+7-7,date("Y")))];
		// 这周
        $weekday = [date("Y-m-d H:i:s",mktime(0, 0 , 0,date("m"),date("d")-date("N")+1,date("Y"))),date("Y-m-d H:i:s",mktime(23,59,59,date("m"),date("d")-date("N")+7,date("Y")))];
		// 这月
        $monthday = [date("Y-m-d H:i:s",mktime(0, 0 , 0,date("m"),1,date("Y"))),date("Y-m-d H:i:s",mktime(23,59,59,date("m"),date("t"),date("Y")))];

		// 业绩数据
		$performance_info = [
			'week_performance' => 0,
			'week_commission' => 0,
			'lask_week_performance' => 0,
			'lask_week_commission' => 0,
			'month_performance' => 0,
			'month_commission' => 0,
			'team_size' => $this->getRegisterTotal($id),
			'new_today_team_num' => $this->getRegisterTotal($id, $today[0], $today[1]),
			'new_yesterday_team_num' => $this->getRegisterTotal($id, $yesterday[0], $yesterday[1]),
			'sub_size' => $apigame->getRecursionUserAgentCount($id,0,'count'),
			'parent_name' => Db::table('gameaccount.newuseraccounts')->where('Id', $user_info['ChannelType'])->field('Account')->find()['Account'],
		];

		$week_performance = $apigame->getRecursionUserAgentCountInfo($id, $weekday[0], $weekday[1]);
		if (count($week_performance) > 0) {
			foreach ($week_performance as $k => $v) {
				$performance_info['week_performance'] += $v['week_team_income'] * 1 + $v['week_team_performance'] * 1;
				$performance_info['week_commission'] += $v['week_person_income'] * 1 + $v['week_person_performance'] * 1;
			}
		}
		$pre_performance = $apigame->getRecursionUserAgentCountInfo($id, $preday[0], $preday[1]);
		if (count($pre_performance) > 0) {
			foreach ($pre_performance as $k => $v) {
				$performance_info['lask_week_performance'] += $v['week_team_income'] * 1 + $v['week_team_performance'] * 1;
				$performance_info['lask_week_commission'] += $v['week_person_income'] * 1 + $v['week_person_performance'] * 1;
			}
		}
		$month_performance = $apigame->getRecursionUserAgentCountInfo($id, $monthday[0], $monthday[1]);
		if (count($month_performance) > 0) {
			foreach ($month_performance as $k => $v) {
				$performance_info['month_performance'] += $v['week_team_income'] * 1 + $v['week_team_performance'] * 1;
				$performance_info['month_commission'] += $v['week_person_income'] * 1 + $v['week_person_performance'] * 1;
			}
		}

		// 昨日 - 今日 数据
		$today_info = [
			'team_performance' => 0,
			'team_commission' => 0,
			'agent_performance' => 0,
			'agent_commission' => 0,
			'sub_running_account' => 0,
			'sub_performance' => 0,
			'my_commission' => 0,
		];

        // 团队业绩
        $today_info['team_performance'] = $this->getPerformance($id, $today[0], $today[1], 'team');
        $today_info['team_commission'] = $this->getCommission($id, $today[0], $today[1], 'team')['amount'];
        // 代理业绩
        $today['agent_performance'] = $this->getPerformance($id, $today[0], $today[1], 'person');
        $today['agent_commission'] = $this->getCommission($id, $today[0], $today[1], 'person')['amount'];
        // 直营流水
        $today['sub_running_account'] = $this->getSerail($id);
        // 直营业绩
        $today['sub_performance'] = $this->getPerformance($id, $today[0], $today[1], 'team', 0, 1);
        // 我的佣金
        $today_info['my_commission'] =  $today['agent_commission'];

		$yesterday_info = [
			'team_performance' => 0,
			'team_commission' => 0,
			'agent_performance' => 0,
			'agent_commission' => 0,
			'sub_running_account' => 0,
			'sub_performance' => 0,
			'my_commission' => 0,
		];

         // 团队业绩
         $today_info['team_performance'] = $this->getPerformance($id, $yesterday[0], $yesterday[1], 'team');
         $today_info['team_commission'] = $this->getCommission($id, $yesterday[0], $yesterday[1], 'team')['amount'];
         // 代理业绩
         $today['agent_performance'] = $this->getPerformance($id, $yesterday[0], $yesterday[1], 'person');
         $today['agent_commission'] = $this->getCommission($id, $yesterday[0], $yesterday[1], 'person')['amount'];
         // 直营流水
         $today['sub_running_account'] = $this->getSerail($id);
         // 直营业绩
         $today['sub_performance'] = $this->getPerformance($id, $yesterday[0], $yesterday[1], 'team', 0, 1);
         // 我的佣金
         $today_info['my_commission'] =  $today['agent_commission'];

		return [
			'user_info' => $user_info,
			'performance_info' => $performance_info,
			'today_info' => $today_info,
			'yesterday_info' => $yesterday_info,
		];
		
	}

    public function getSerail($id, $type='prev') {
        // 获取直营流水
        if ($type == 'prev') {
           $result = Db::table('gameaccount.newuseraccounts gn')
                        ->join('gameaccount.mark gm','gn.Id = gm.userId')
                        ->where('gn.channelType',$id)
                        ->field('SUM(winCoin) winCoin')->find();
            $result = $result['winCoin'];
        }

        return $result;
    }

    public function getApiUserAgentInfo($id) {

        // 今日时间
		$today = [date('Y-m-d'), date('Y-m-d')." 23:59:59"];
        // 昨日时间
		$yesterday = [date('Y-m-d', strtotime("-1 day")), date('Y-m-d', strtotime("-1 day"))." 23:59:59"];
		// 这周
        $weekday = [date("Y-m-d H:i:s",mktime(0, 0 , 0,date("m"),date("d")-date("N")+1,date("Y"))),date("Y-m-d H:i:s",mktime(23,59,59,date("m"),date("d")-date("N")+7,date("Y")))];

        // 指定下一级列表
        $result = Db::table('gameaccount.newuseraccounts')->where('channelType',$id)->field('Id as uid,nickname')->select();
        $count = 0;
        // 循环数据
        foreach ($result as $k => $v) {
            if ($count == 0) {
                // (周)团队业绩
                $result[$k]['week_team_performance'] = 0;
                // (周)个人业绩
                $result[$k]['week_person_performance'] = 0;
                // (日)团队业绩
                $result[$k]['today_team_performance'] = 0;
                // (日)个人业绩
                $result[$k]['today_person_performance'] = 0;
                // 团队人数
                $result[$k]['count_team_size'] = 0;
                // 今日新增注册人数
                $result[$k]['today_add_size'] = 0;
                // 昨日团队业绩
                $result[$k]['old_team_performance'] = 0;
            }
            $count++;
            // 周
            $result[$k]['week_team_performance'] = $this->getPerformance($v['uid'],$weekday[0], $weekday[1], 'team');
            $result[$k]['week_person_performance'] = $this->getPerformance($v['uid'],$weekday[0], $weekday[1], 'person');
            // 日
            $result[$k]['today_team_performance'] = $this->getPerformance($v['uid'],$today[0], $today[1], 'team');
            $result[$k]['today_person_performance'] = $this->getPerformance($v['uid'],$today[0], $today[1], 'person');
            // 昨日
            $result[$k]['old_team_performance'] = $this->getPerformance($v['uid'],$yesterday[0], $yesterday[1], 'team');
            // 团队人数
            $result[$k]['count_team_size'] = $this->getRegisterTotal($v['uid']);
            // 今日新增
            $result[$k]['today_add_size'] = $this->getRegisterTotal($v['uid'], $today[0], $today[1]);
        }

        return $result;
        
    }

    public function getApiAgentSystem($id) {

        $data = [
            'affiliation_size' => 0,
			'team_size' => 0,
			'affiliation_agent' => 0,
			'team_performance' => 0,
			'promotion_performance' => 0,
			'yesterday_commission' => 0,
			'today_commission' => 0,
			'claimed_commission' => 0,
			'current_claimable_commission' => 0
        ];

        // 今日时间
		$today = [date('Y-m-d'), date('Y-m-d')." 23:59:59"];
        // 昨日时间
		$yesterday = [date('Y-m-d', strtotime("-1 day")), date('Y-m-d', strtotime("-1 day"))." 23:59:59"];

        // 团队总人数
        $data['team_size'] = $this->getRegisterTotal($id);
        // 团队今日新增人数
        $data['team_size_new'] = $this->getRegisterTotal($id, $today[0], $today[1]);
        // 直属团队人数
        $data['affiliation_size'] = $this->getRegisterTotal($id, '', '', 0, 1);
        // 直属团队今日新增人数
        $data['affiliation_size_new'] = $this->getRegisterTotal($id, $today[0], $today[1], 0, 1);
        // 直属代理人数
        $data['affiliation_agent'] = $this->getRegisterTotal($id, '', '', 0, 2);
        // 直属代理人数今日新增
        $data['affiliation_agent_new'] = $this->getRegisterTotal($id, $today[0], $today[1], 0, 2);
        // 今日团队业绩
        $data['team_performance'] = $this->getPerformance($id,$today[0], $today[1], 'team');
        // 今日彩金业绩
        $data['promotion_performance'] = 0;
        // 昨日佣金
        $data['yesterday_commission'] = $this->getCommission($id, $yesterday[0], $yesterday[1])['amount'];
        // 已提现佣金
        $data['claimed_commission'] = $this->getCommission($id)['amount_1'];
        // 今日佣金
        $data['today_commission'] = $this->getCommission($id, $today[0], $today[1])['amount'];
        // 当前可以提现的佣金
        $data['current_claimable_commission'] = $this->getCommission($id)['amount_0'];

        return $data;
    }

    // 获取系统赠送彩金
    public function color_gold($user_id = 0, $begin_time = '', $end_time = '') {
        $sql = Db::table('ym_manage.paylog')->where('type','in',[4,5,6,7,8])->where('status',1)->field('SUM(fee) fee');
        if ($begin_time && $end_time) {
            $sql->where('paytime','between',[strtotime($begin_time), strtotime($end_time)]);
        }
        if (!empty($user_id)) {
            $sql->where('uid', $user_id);
        }
        return $sql->find()['fee'];
    }
}
