<?php
namespace app\api\controller;
use app\api\controller\Init;
use app\api\controller\Curl;
use think\Request;
use app\api\model\UserModel;
use app\api\model\EncnumModel;
use app\admin\model\ConfigModel;
use app\admin\model\UserModel as AdminUserModel;
use app\admin\model\PromoterModel;
use think\Db;

class Game extends Init
{
	private $config;

	public function __construct() {
		$this->config = ConfigModel::getSystemConfig();
	}

	//待测试
	public function weixinLogin(){
		
		$url = input('post.url');
		$ret = json_decode($url,true);
		if(empty($ret)){
			return $this->returnError1('URL为空');
		}
		
		//验证 url
		$urlarr = parse_url($url);
		parse_str($urlarr['query'],$data);
		
		$key = $this->config['PrivateKey'];
		if ($data['act'] == "weixinLogin"){
				//注册
				if (!isset($data['goldnum'])) {
					$data['goldnum'] = 0;
				}
				if ($data['accountname'] && $data['pwd'] && $data['time'] && $data['sign']) {

					//验证md5
					$content = $data['act'] . $data['accountname'] . $data['pwd'] . $data['time'] . $key;
					if (md5($content) != $data['sign']){
						return $this->returnError1('参数不正确');						
					}
					
					//密码加密MD5
					$key_login = "89b5b987124d2ec3";
					$content = $data['accountname'] . $data['pwd'] . $key_login;
					$md5_sign = md5($content);


					$key_login = "time@k3lss0x3";
					$content = $data['accountname'] . $data['time'] . $key_login;
					$md5_sign_login = md5($content);

					$userInfo = array();
					$userInfo['accountname'] = $data['accountname'];
					$userInfo['pwd'] = $md5_sign;
					$userInfo['nickname'] = $data['nickname'];
					$userInfo['goldnum'] = $data['goldnum'];
					$userInfo['p'] = $data['pwd'];
					$userInfo['phoneNo'] = !empty($data['phoneNo']) ? $data['phoneNo'] : '';
					$userInfo['email'] = !empty($data['email']) ? $data['email'] : '';
					$userInfo['sex'] = !empty($data['sex']) ? $data['sex'] : '';
					$userInfo['city'] = !empty($data['city']) ? $data['city'] : '';
					$userInfo['province'] = !empty($data['province']) ? $data['province'] : '';
					$userInfo['country'] = !empty($data['country']) ? $data['country'] : '';
					$userInfo['headimgurl'] = $data['headimgurl'];
					$userInfo['language'] = !empty($data['language']) ? $data['language'] : '';
					$userInfo['loginCode'] = $md5_sign_login;
					$userInfo['ChannelType'] = !empty($data['ChannelType']) ? $data['ChannelType'] : '';
					$userInfo['bindUserId'] = !empty($data['bindUserId']) ? $data['bindUserId'] : '';
					$userInfo['did'] = !empty($data['did']) ? $data['did'] : '';
					
					//直接操作数据库
					//accountname,pwd,nickname,goldnum,p,phoneNo,email,sex,city,province,country,headimgurl,language,loginCode,ChannelType,bindUserId,did
					//$sql = 'call weixinCreateUser(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)';
					$sql  = 'call weixinCreateUser(';
						$sql .= '"'.$userInfo['accountname'].'",';
						$sql .= '"'.$userInfo['pwd'].'",';
						$sql .= '"'.$userInfo['nickname'].'",';
						$sql .= '"'.$userInfo['goldnum'].'",';
						$sql .= '"'.$userInfo['p'].'",';
						$sql .= '"'.$userInfo['phoneNo'].'",';
						$sql .= '"'.$userInfo['email'].'",';
						$sql .= '"'.$userInfo['sex'].'",';
						$sql .= '"'.$userInfo['city'].'",';
						$sql .= '"'.$userInfo['province'].'",';
						$sql .= '"'.$userInfo['country'].'",';
						$sql .= '"'.$userInfo['headimgurl'].'",';
						$sql .= '"'.$userInfo['language'].'",';
						$sql .= '"'.$userInfo['loginCode'].'",';
						$sql .= '"'.$userInfo['ChannelType'].'",';
						$sql .= '"'.$userInfo['bindUserId'].'",';
						$sql .= '"'.$userInfo['did'].'"';
					$sql .= ')';
					
					$Rusult = $db->query($sql);			
					if ($Rusult[0]['rcode']){
						//已存在	
						$arr = array(
							'loginCode' => $userInfo['loginCode'],
							'account' => $userInfo['accountname'],
							'id' => $Rusult[0]['rcode']
						);
						return $this->returnSuccess1($arr);
					}else{
						return $this->returnError1('注册失败!');
					}

					
				
				}
		}
		
		
	}

	public function addTax() {

		$param = request()->post();

		if (empty($param['uid']) || empty($param['amount']) || empty($param['mark_id'])) {
			return $this->returnError1('参数不正确'); 
		}

		// 计算所有代理，无限层级分类，但只计算六级
		$agentList = $this->agentRecursion($param['uid']);
		array_unshift($agentList, $param['uid']);
		array_pop($agentList);

		// 数组表示
		//Array (
		//	[0] => 17096 自身(玩家)
		//	[1] => 17067 六级代理
		//	[2] => 17066 五级代理
		//	[3] => 17065 四级代理
		//	[4] => 17064 三级代理
		//	[5] => 17057 二级代理
		//	[6] => 16110 一级代理
		// )

		// 代理结算金币
		$agentListArr = [];
		foreach ($agentList as $k => $v) {

			if ($k > 6) { // 如果大于六级 退出循环
				break;
			}
			if ($k == 0) {// 如果是玩家自身 循环下一次
				$agentListArr[$k] = [
					'id' => $v,
					'amount' => $param['amount']
				];
				continue;
			}

			$agentListArr[$k] = [
				'id' => $v,
				'amount' => sprintf("%.2f",substr(sprintf("%.3f", $agentListArr[$k-1]['amount'] * 0.3), 0, -1))
			];
		}

		// 最终结构
		// Array (
		// 	[0] => Array
		// 		(
		// 			[id] => 17096
		// 			[amount] => 25
		// 		)
		// 	[1] => Array
		// 		(
		// 			[id] => 17067
		// 			[amount] => 7.50
		// 		)
		// 	[2] => Array
		// 		(
		// 			[id] => 17066
		// 			[amount] => 2.25
		// 		)
		// 	[3] => Array
		// 		(
		// 			[id] => 17065
		// 			[amount] => 0.67
		// 		)
		// 	[4] => Array
		// 		(
		// 			[id] => 17064
		// 			[amount] => 0.20
		// 		)
		// 	[5] => Array
		// 		(
		// 			[id] => 17057
		// 			[amount] => 0.06
		// 		)
		// 	[6] => Array
		// 		(
		// 			[id] => 16110
		// 			[amount] => 0.01
		// 		)
		// 	)

		// 如果没有代理
		if (count($agentListArr) == 1) {
			return $this->returnError1('无法查到上级代理ID');
		}

		// 每局结算写入数据库，每日凌晨01:00 结算
		$insertData = [];
		foreach ($agentListArr as $k => $v) {
			if ($k > 6) {
				break;
			}
			$insertData[] = [
				'mark_id' => $param['mark_id'],
				'uid' => $v['id'],
				'p_uid' => ($k > 0 ? $agentListArr[$k-1]['id'] : 0),
				'amount' => $v['amount'],
				'create_at' => date('Y-m-d H:i:s'),
				'every_statement' => $param['amount']
			];
		}

		Db::table('ym_manage.agent_settlement')->insertAll($insertData);

		// 对代理商增加金币
		// $adminUserModel = new AdminUserModel;
		// $account = $adminUserModel->getUserInfo($user_list[0]);

		// if (empty($account)) {
		// 	return $this->returnError1('无法查到上级代理Account'); 
		// }

		// $addScoreStat = $adminUserModel->insertScore($account['Account'], intval($param['amount']));
		// if (!$addScoreStat) {
		// 	return $this->returnError1('代理用户充值金币失败'); 
		// }

		return $this->returnSuccess1();
	}

	// 定时结算佣金
	public function sendTax() {

		$time = strtotime(date('Y-m-d'). '01:00:00');
		$begin_time = date('Y-m-d H:i:s', $time - 86400);
		$end_time = date('Y-m-d H:i:s', $time);

		$result = Db::table('ym_manage.agent_settlement')
			->where('p_uid','>',0)
			->where('status',0)
			->where('create_at','between',[$begin_time, $end_time])
			->group('uid')
			->field('uid, SUM(amount) as amount')
			->select();

		$adminUserModel = new AdminUserModel;

		// 循环增加金币
		foreach ($result as $k => $v) {
			$account = $adminUserModel->getUserInfo($v['uid']);
			$adminUserModel->insertScore($account['Account'], $v['amount']);
		}

		// 批量设置已结算状态
		Db::table('ym_manage.agent_settlement')
			->where('p_uid','>',0)
			->where('status',0)
			->where('create_at','between',[$begin_time, $end_time])
			->update(['status' => 1]);
		
		return $this->returnSuccess1();
	}

	// 代理级别递归计算
	public function agentRecursion($uid, $data = [], $count = 0) {

		// 获取游戏代理方式 ...
		$game_agent = Db::table('gameaccount.newuseraccounts')->field('ChannelType as uid')->where('Id',"{$uid}")->where('ChannelType','<>','abc')->where('ChannelType','>',0)->find();
		// 获取注册代理方式 ...
		$admin_agent = Db::table('ym_manage.uidglaid')->field('aid as uid')->where('uid',"{$uid}")->find();

		$pid = 0;

		if (!empty($game_agent)) {
			$pid = $game_agent['uid'];
		}

		if (!empty($admin_agent)) {
			$pid = $admin_agent['uid'];
		}

        // 合并代理用户 ...
		$data[$count] = $pid;

		if (!empty($data[$count])) {
			return $this->agentRecursion($data[$count],$data,($count+1));
		}

		return $data;

	} 


	// 每日统计 -- 代理列表
	public function dayAgentListCount() {
		$id = request()->post('id');
		$limit = empty(request()->post('limit')) ? '' : request()->post('limit');
		if (empty($id)) {
			return $this->returnError1('参数不正确'); 
		}
		$result = $this->getAgentListDay($limit, $id);
		return $this->returnSuccess1($result);
	}

	public function getAgentList($limit = 30, $puid = 0, $begin_time = '', $end_time = '') {
		$sql =  Db::table('ym_manage.agent_settlement agent')->order('agent.create_at','desc');
		if (!empty($begin_time)) {
			$sql->where('agent.create_at','>=',$begin_time);
		}
		if (!empty($end_time)) {
			$sql->where('agent.create_at','<=',$end_time);
		}
		if (!empty($puid)) {
			$sql->where('agent.p_uid', $puid);
		}
		return $sql->paginate($limit)->toArray();
	}

	public function getAgentListDay($limit = 30, $uid = 0) {
		$subQuery = Db::table('ym_manage.agent_settlement agent')->where('agent.uid',$uid)->field('agent.*,DATE(agent.create_at) date_format')->buildSql();
		return Db::table($subQuery . ' T1 ')->group('T1.date_format')->order('T1.date_format','desc')->field('SUM(T1.amount) AS amount,SUM(T1.every_statement) AS every_statement,T1.`status`,T1.date_format')->paginate($limit)->toArray();
	}

	public function getPersonAgentAmountCount($id) {
		$result = Db::table('ym_manage.agent_settlement')->where('uid',$id)->where('p_uid','>',0)->field('SUM(amount) as amount, status')->group('status')->select();
		$agentIncome = 0;
		$agentPerformance = 0;
		$agentAmountCount = 0;
		foreach ($result as $k => $v) {
			if ($v['status'] == 0) {
				$agentPerformance += $v['amount'];
			}
			if ($v['status'] == 1) {
				$agentIncome += $v['amount'];
			}
			$agentAmountCount += $v['amount'];
		}
		return ['agentIncome' => $agentIncome, 'agentPerformance' => $agentPerformance, 'agentAmountCount' => $agentAmountCount];
	}

	public function getRecursionUserAgentCount($id, $count = 0, $type = 'each') {

		$ids = Db::table('gameaccount.newuseraccounts')->field('Id')->where('ChannelType',"{$id}")->select();
		$count += count($ids);

		if ($type !== 'each') {
			return $count;
		}

		if (count($ids) > 0) {
			foreach ($ids as $k => $v) {
				$count += $this->getRecursionUserAgentCount($v['Id']);
			}
		}
		return $count;
	}

	public function getUserAgentCount() {

		$id = request()->post('id');
		$data = [];
		// 获取团队总人数
		$data['teamNumber'] = $this->getRecursionUserAgentCount($id);
		// 获取直属总人数
		$data['subordinateNumber'] = $this->getRecursionUserAgentCount($id,0,'one');
		// 获取当前代理收益
		$data = array_merge($data, $this->getPersonAgentAmountCount($id));
		// 获取当前代理URL
		$data['agentUrl'] = $this->config['SystemUrl'].'/index/index/register?id='. $id;

		return $this->returnSuccess1($data);
	}

	public function getUserAgentInfo() {
		$id = request()->post('id');
		$promoterModel = new PromoterModel;
		return $this->returnSuccess1($promoterModel->getApiUserAgentInfo($id));
	}

	public function getRecursionUserAgentCountInfo($id, $start_time = '', $end_time = '', $agentInfoArr = []) {

		if ($id == 0) {
			return $agentInfoArr;
		}

		$sql = Db::table('ym_manage.agent_settlement agent')
		->join('gameaccount.newuseraccounts gn', 'agent.uid = gn.Id')
		->where('agent.uid',$id)
		->group('agent.uid,agent.status')
		->field('agent.id,SUM(agent.amount) as amount, SUM(agent.every_statement) as every_statement, gn.nickname, agent.status, agent.uid, agent.p_uid')
		->order('agent.create_at','desc');

		if (!empty($start_time) && !empty($end_time)) {
			$sql->where('agent.create_at','between',[$start_time, $end_time]);
		}

		$result = $sql->select();

		$taskAgentArr = [];
		foreach ($result as $k => $v) {
			$taskAgentArr[$v['p_uid']] = 1;
			if (empty($agentInfoArr[$v['uid']])) {
				$agentInfoArr[$v['uid']] = [
					'uid' => $v['uid'],
					'nickname' => $v['nickname'],
					'week_team_income' => 0,
					'week_team_performance' => 0,
					'week_person_income' => 0,
					'week_person_performance' => 0,
					'count_team_size' => 0
				];
			}
			if ($v['status'] == 0) {
				$agentInfoArr[$v['uid']]['week_team_income'] += $v['every_statement'];
				$agentInfoArr[$v['uid']]['week_person_income'] += $v['amount'];
			}

			if ($v['status'] == 1) {
				$agentInfoArr[$v['uid']]['week_team_performance'] += $v['every_statement'];
				$agentInfoArr[$v['uid']]['week_person_performance'] += $v['amount'];
			}
		}

		if (count($result) > 0) {
			$agentInfoArr[$id]['count_team_size'] = count($taskAgentArr);
		}


		foreach ($taskAgentArr as $k => $v) {
			return $this->getRecursionUserAgentCountInfo($k, $start_time, $end_time, $agentInfoArr);
		}

		return $agentInfoArr;
		
	}

	public function getWeekCount() {

		$id = request()->post('id');
		
		// 当前周时间范围
		$weekday = [date("Y-m-d",mktime(0, 0 , 0,date("m"),date("d")-date("N")+1,date("Y"))),date("Y-m-d",mktime(23,59,59,date("m"),date("d")-date("N")+7,date("Y")))];
		// 自身数据
		$current = $this->getWeekCountRecursion($id, 'direct');
		// 直营数据
		$direct = $this->getWeekCountRecursion($id, 'team', 1);
		// 团队数据
		$team = $this->getWeekCountRecursion($id, 'team');
		// 组合数据
		$result = [
			'topList' => [
				'my_commission' => 0,
				'team_performance' => 0,
				'direct_performance' => 0,
			],
			'teamList' => []
		];
		// 取数组第0条当做顶部数据
		if (!empty($current) && !empty($current[$weekday[0].'-'.$weekday[1]])) {
			$topList = array_slice($current,0,1);
			$topList = array_shift($topList);
			$result['topList']['my_commission'] = $topList['amount'] * 1;
			$result['topList']['direct_performance'] = $topList['every_statement'] * 1;
			if (!empty($team) > 0) {
				$result['topList']['team_performance'] = $team[$topList['begin_time'].'-'.$topList['end_time']]['every_statement'] * 1;
			}
		}
		// 底部数据
		$countArr = 0;
		foreach ($current as $k => $v) {
			if ($countArr == 0) {
				// 团队佣金
				$current[$k]['income_team'] = 0;
				// 直营团队佣金
				$current[$k]['income_directAgent'] = 0;
				// 团队业绩
				$current[$k]['performance_team'] = 0;
				// 直营团队业绩
				$current[$k]['performance_directTeam'] = 0;
			}
			if (!empty($team)) {
				$current[$k]['income_team'] += $team[$v['begin_time'].'-'.$v['end_time']]['amount'] * 1;
				$current[$k]['performance_team'] += $team[$v['begin_time'].'-'.$v['end_time']]['every_statement'] * 1;
			}
			if (!empty($direct)) {
				$current[$k]['income_directAgent'] += $direct[$v['begin_time'].'-'.$v['end_time']]['amount'] * 1;
				$current[$k]['performance_directTeam'] = $direct[$v['begin_time'].'-'.$v['end_time']]['every_statement'] * 1;
			}
			
			//$current[$k]['income_team'] += $team[$v['begin_time'].'-'.$v['end_time']]['amount'];
			//$current[$k]['income_directAgent'] += $direct[$v['begin_time'].'-'.$v['end_time']]['amount'];
			//$current[$k]['performance_team'] += $team[$v['begin_time'].'-'.$v['end_time']]['every_statement'];
			//$current[$k]['performance_directTeam'] = $direct[$v['begin_time'].'-'.$v['end_time']]['every_statement'];

			$countArr++;
		}
		
		$result['teamList'] = $current;
	
		return $this->returnSuccess1($result);
	}

	public function getWeekCountRecursion($id, $type = 'direct', $next_agent = 0, $team = []) {
		if ($type == 'direct') {
			$data = Db::table('ym_manage.agent_settlement agent')
						->where('agent.uid', $id)
						->where('agent.p_uid','>',0)
						->group('weeknum')
						->order('weeknum DESC')
						->field([
							'SUM(agent.amount) AS amount',
							'SUM(agent.every_statement) AS every_statement',
							'date_format(agent.create_at, "%v") AS weeknum',
							'date_sub(date_format(agent.create_at, "%Y-%m-%d"),INTERVAL WEEKDAY(date_format(agent.create_at, "%Y-%m-%d")) + 0 DAY) begin_time',
							'date_sub(date_format(agent.create_at, "%Y-%m-%d"),INTERVAL WEEKDAY(date_format(agent.create_at, "%Y-%m-%d")) - 6 DAY) end_time'
						])->select();
			$new_data = [];
			foreach ($data as $k => $v) {
				$new_data[$v['begin_time'].'-'.$v['end_time']] = $v;
			}
			return $new_data;
		}
		if ($type == 'team') {
			$result = Db::table('gameaccount.newuseraccounts')->where('channelType',$id)->field('Id')->select();
			if (count($result) == 0) {
				return $team;
			}
			foreach ($result as $k => $v) {
				$data = $this->getWeekCountRecursion($v['Id']);
				foreach ($data as $key => $val) {
					if (empty($team[$val['begin_time'].'-'.$val['end_time']])) {
						$team[$val['begin_time'].'-'.$val['end_time']] = [];
						$team[$val['begin_time'].'-'.$val['end_time']]['amount'] = 0;
						$team[$val['begin_time'].'-'.$val['end_time']]['every_statement'] = 0;
					}
					$team[$val['begin_time'].'-'.$val['end_time']]['amount'] += $val['amount'];
					$team[$val['begin_time'].'-'.$val['end_time']]['every_statement'] += $val['every_statement'];
				}
				if ($next_agent == 0) {
					return $this->getWeekCountRecursion($v['Id'], $type, $next_agent, $team);
				}
			}

			return $team;
		}
	}

	public function getAgentSystem() {
		$id = request()->post('id');
		$promoterModel = new PromoterModel;
		return $this->returnSuccess1($promoterModel->getApiAgentSystem($id));
	}

	public function getWeekday () {
		$time = time();
		$week_day_num = date('w',$time);
		if ($week_day_num == 0) {
			$sdate = date('Y-m-d', strtotime("-6 day", $time));
			$edate = date('Y-m-d', $time);
		} else {
			$sdate = date('Y-m-d', strtotime("-". ($week_day_num - 1). "day", $time));
			$edate = date('Y-m-d', strtotime("+". (7 - $week_day_num). "day", $time));
		}

		return [$sdate, $edate];
	}

}
