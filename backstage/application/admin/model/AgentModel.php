<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;
use app\api\controller\Game as ApiGame;

class AgentModel extends Model
{
	private $key = '';
	private $apiurl = '';
	
	public function __construct(){
		parent::__construct();
		
		// 读取配置信息
		$config = ConfigModel::getSystemConfig();
		$this->apiurl = $config['GameServiceApi'];
		$this->key = $config['PrivateKey'];
		// $this->apiurl = Config::get('app.Recharge_API');
	}
	
	private function _request($url, $https=false, $method='get', $data=null)
	{
		$ch = curl_init();
		curl_setopt($ch,CURLOPT_URL,$url); //设置URL
		curl_setopt($ch,CURLOPT_HEADER,false); //不返回网页URL的头信息
		curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);//不直接输出返回一个字符串
		if($https){
			curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);//服务器端的证书不验证
			curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);//客户端证书不验证
		}
		if($method == 'post'){
			curl_setopt($ch, CURLOPT_POST, true); //设置为POST提交方式
			curl_setopt($ch, CURLOPT_POSTFIELDS, $data);//设置提交数据$data
		}
		$str = curl_exec($ch);//执行访问
		curl_close($ch);//关闭curl释放资源
		return $str;
	}
		
	public function getUserInfo($id){
		if(empty($id)){ return false; }	
		return Db::table('gameaccount.newuseraccounts')->alias('u')
					->field('u.*,ui.score')
                    ->leftJoin('gameaccount.userinfo_imp ui','u.Id=ui.userId')
					->where('u.Id',$id)
					->find();
	}
	
	public function getUserInfoByAccount($account){
		if(empty($account)){ return false; }		
		return Db::table('gameaccount.newuseraccounts')->alias('u')
					->field('u.*,i.score')
					->join('ym_manage.agentinfo i','u.Id=i.aid')
					->where('u.Account',$account)
					->find();
	}
	
		
	public function setUserScore($data,$type){
		if(empty($type) || !in_array($type,['1','2']) ){ return false; }
		if(empty($data)){ return false; }
		if(empty($data['username']) || empty($data['uid']) ){ return false; }
		//if(empty($data['score']) || empty($data['addscore']) ){ return false; }
		if( empty($data['addscore']) ){ return false; }
		$addscore = round($data['addscore'], 2);
		$account = trim($data['username']);
		
		if($type == '2'){
			$addscore = 0 - $addscore;
		}
		
		return $this->insertScore($account,$addscore);
	}
			
	private function addRechargeLog($uid,$czfee,$oldfee,$newfee,$logtype){
		$adminid = Cookie::get('admin_user_id');
		$log = array(
			'adminid' => $adminid,
			'userid' => $uid,
			'createtime' => time(),
			'czfee' => $czfee,
			'oldfee' => $oldfee,
			'newfee' => $newfee,
			'type' => $logtype//1 加 0 减
		);
		Db::name('ym_manage.rechargelog')->insert($log);
                $this->query("set autocommit=1");
	}
	
		
	public function insertScore($account,$fee){
		if(empty($account) || empty($fee)){ return false; }
		$account = trim($account);
//		$fee = round(floatval($fee),2) * 100;
		
		$user = $this->getUserInfoByAccount($account);
		if($user){
			
			$act = "scoreedit";			
			$time = strtotime('now');
			$key = $this->key;
			$sign = $act.$account.$fee.$time.$key;
			$md5sign = md5($sign);
			$url=$this->apiurl."/Activity/gameuse?act=".$act."&accountname=".$account."&goldnum=".$fee."&time=".$time."&sign=".$md5sign;
			$res = $this->_request($url);
			//file_put_contents('xxxxx.txt',$res);
			$res = json_decode($res,true);
			if(isset($res) && ($res['status'] == '0')){
				$score = $user['score'] + $fee;
				$logtype = $fee>0 ? 1 : 0;				
				$this->addRechargeLog($user['Id'],abs($fee),$user['score'],$score,$logtype);
				return true;
			}else{
				return json_encode($res);
			}
			
		}
		return false;
	}
	
	public function rechargeLogs($num = 10){
		$list = Db::table('ym_manage.rechargelog')->order('id desc')->paginate($num,false,[
			'var_page' => 'jb',
		]);
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}

	public function rechargeLogsCount(){
		return Db::table('ym_manage.rechargelog')->count();
	}

	// 顶级代理列表
	public function topAgentList($limit = 30, $agent_id = 0, $uid = 0, $begin_time = '', $end_time = '') {

		$sql = Db::table('ym_manage.admin a')
				->join('gameaccount.newuseraccounts u','a.id = u.id')
				->field('a.id, a.username, u.Account')
				->where('top_agent',1);

		if (!empty($agent_id)) {
			$sql->where('a.id',$agent_id);
		}
		if (!empty($uid)) {
			$sql->where('a.id',$uid);
		}

		$result = $sql->paginate($limit)->toArray();

		// 获取当日注册人数
		$todayRegisterUser = $this->todayRegister();

		// 获取注册人数最顶级代理
		$apigame = new ApiGame;
		$topId = [];
		foreach ($todayRegisterUser as $k => $v) {
			$searchRegisterTopNumber = $apigame->agentRecursion($v['Id']);
			$countNumber = count($searchRegisterTopNumber);
			$topIdOnec =$searchRegisterTopNumber[$countNumber-2];
			if (empty($topId[$topIdOnec])) {
				$topId[$topIdOnec] = [
					'id' => $topIdOnec,
					'num' => 0
				];
			}
			$topId[$topIdOnec]['num'] += 1;
		}

		foreach ($result['data'] as $k => $v) {

			// 计算当前代理下注册人数
			$result['data'][$k]['agent_register'] = !empty($topId[$v['id']]['num']) ? $topId[$v['id']]['num'] : 0;

			// 计算充值金额 1. 个人 2. 团队
			$payment_amount_person = $this->getPersonPayment($v['id'], $begin_time, $end_time)['fee'];
			$payment_amount_team = $this->getPersonPaymentTeam($v['id'], $begin_time, $end_time);
			$result['data'][$k]['person_payment_amount'] = $payment_amount_person > 0 ? $payment_amount_person : 0;
			$result['data'][$k]['team_payment_amount'] = $payment_amount_team > 0 ? $payment_amount_team : 0;

			// 提现金额
			$outcash_person = $this->getPersonOutCash($v['id'], $begin_time, $end_time)['money'];
			$outcash_team = $this->getTeamOutCash($v['id'], $begin_time, $end_time);
			$result['data'][$k]['person_out_amount'] =  $outcash_person > 0 ? $outcash_person : 0;
			$result['data'][$k]['team_out_amount'] = $outcash_team;

			// 彩金
			$result['data'][$k]['person_boom'] = 0;
			$result['data'][$k]['team_boom'] = 0;

			// 税金
			$performance_person = $this->getPersonformance($v['id'], $begin_time, $end_time)['tax'];
			$performance_team = $this->getTeamPerformance($v['id'], $begin_time, $end_time);
			$result['data'][$k]['person_taxation'] = $performance_person > 0 ? $performance_person : 0;
			$result['data'][$k]['team_taxation'] = $performance_team;

			// 计算业绩
			$result['data'][$k]['person_performanc'] = $result['data'][$k]['person_taxation'] * 0.3;
			$result['data'][$k]['team_performanc'] = $performance_team * 0.3;

			// 有效业绩
			$performance_person_on = $this->getPersonformance($v['id'],$begin_time,$end_time,0,1)['tax'];
			$performance_team_on = $this->getTeamPerformance($v['id'],$begin_time,$end_time,0,1);
			$result['data'][$k]['person_performanc_true'] = $performance_person_on > 0 ? $performance_person_on * 0.3 : 0;
			$result['data'][$k]['team_performanc_true'] = $performance_team_on * 0.3;

			// 平台盈利
			$result['data'][$k]['platform_profit'] = ($result['data'][$k]['person_payment_amount']  + $result['data'][$k]['team_payment_amount']) - ($result['data'][$k]['person_out_amount'] + $result['data'][$k]['team_out_amount']) - ($result['data'][$k]['person_taxation'] + $result['data'][$k]['team_taxation']);
			$result['data'][$k]['team_number'] = $apigame->getRecursionUserAgentCount($v['id']);

		}

		return $result;
	}

	// 代理列表
	public function AgentList($limit = 30, $agent_id, $level_id, $subordinate_to, $uid, $pid, $commission_no_from, $commission_no_to, $commission_yes_from, $commission_yes_to) {

		$sql = Db::table('ym_manage.admin a')
				->join('gameaccount.newuseraccounts u','a.id = u.id')
				->field('a.id, a.username, u.Account, u.channelType')
				->where('a.isagent',1);

		if (!empty($agent_id)) {
			$sql->where('a.id',$agent_id);
		}
		if (!empty($uid)) {
			$sql->where('a.id',$uid);
		}

		if ($level_id > 0) {
			if ($level_id == 1) {
				$sql->where('a.top_agent',1);
			}
			if ($level_id == 2) {
				$sql->where('a.top_agent',0);
			}
			if ($level_id == 3) {
				$agentArr = $this->getAgentBottomLevel();
				if (count($agentArr) > 0) {
					$sql->where('a.id', 'in', $agentArr);
				}
			}
		}

		if ($subordinate_to > 0) {
			$sql->where('u.channelType','>',1);
		}

		if ($pid > 0) {
			$sql->where('u.channelType',$pid);
		}

		$result = $sql->paginate($limit)->toArray();

		$apigame = new ApiGame;


		foreach ($result['data'] as $k => $v) {
			// 上级ID
			if (empty($v['channelType']) || $v['channelType'] == 0 || $v['channelType'] == 1 || $v['channelType'] == 'abc') {
				$result['data'][$k]['channelType'] = 0;
			}
			$agentList = $apigame->agentRecursion($v['id']);
			$level = 1;
			foreach ($agentList as $key => $val) {
				if ($val > 0) {
					$level += 1;
				}
			}
			$result['data'][$k]['level'] = $level;
			$result['data'][$k]['team_size'] = $apigame->getRecursionUserAgentCount($v['id']);

			//佣金
			$performance = $apigame->getRecursionUserAgentCountInfo($v['id']);
			$result['data'][$k]['no_performance'] = 0;
			$result['data'][$k]['yes_performance'] = 0;
			$result['data'][$k]['history_performance'] = 0;
			foreach ($performance as $key => $val) {
				$result['data'][$k]['no_performance'] += $val['week_person_income'] * 1;
				$result['data'][$k]['yes_performance'] += $val['week_person_performance'] * 1;
				$result['data'][$k]['history_performance'] += $val['week_person_income'] * 1 + $val['week_person_performance'] * 1;
			}

			// 佣金筛选
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
		}

		return $result;
	}

	// 每日数据列表
	public function DayAgentList($limit = 30, $agent_id, $diff_id, $uid, $pid, $commission_no_from, $commission_no_to, $commission_yes_from, $commission_yes_to, $begin_time, $end_time) {
		
		$sql = Db::table('ym_manage.admin a')
		->join('gameaccount.newuseraccounts u','a.id = u.id')
		->field('a.id, a.username, u.Account, u.ChannelType')
		->where('a.isagent',1);

		if ($agent_id > 0) {
			$sql->where('a.id',$agent_id);
		}
		if ($uid > 0) {
			$sql->where('a.id',$uid);
		}
		if ($pid > 0) {
			$sql->where('u.channelType',$pid);
		}

		$result = $sql->paginate($limit)->toArray();

		$apigame = new ApiGame;

		foreach ($result['data'] as $k => $v) {

			// 日期
			$result['data'][$k]['begin_time'] = $begin_time;
			$result['data'][$k]['end_time'] = $end_time;

			// 上级ID
			if (empty($v['channelType']) || $v['channelType'] == 0 || $v['channelType'] == 1 || $v['channelType'] == 'abc') {
				$result['data'][$k]['channelType'] = 0;
			}

			// 个人业绩
			$person_performance = $this->getPersonformance($v['id'], $begin_time, $end_time)['tax'];
			$result['data'][$k]['person_performance'] = $person_performance > 0 ? $person_performance : 0;
			// 个人有效业绩
			$person_performance_true = $this->getPersonformance($v['id'], $begin_time, $end_time, 1)['tax'];
			$result['data'][$k]['person_performance_true'] = $person_performance_true > 0 ? $person_performance_true : 0;

			//佣金
			$performance = $apigame->getRecursionUserAgentCountInfo($v['id'], $begin_time, $end_time);
			$result['data'][$k]['no_performance'] = 0;
			$result['data'][$k]['yes_performance'] = 0;
			$result['data'][$k]['history_performance'] = 0;
			foreach ($performance as $key => $val) {
				$result['data'][$k]['yes_performance'] += $val['week_person_performance'] * 1;
				$result['data'][$k]['history_performance'] += $val['week_person_income'] * 1 + $val['week_person_performance'] * 1;
			}

			// 未领取佣金
			$no_performance = $apigame->getRecursionUserAgentCountInfo($v['id']);
			foreach ($performance as $key => $val) {
				$result['data'][$k]['no_performance'] += $val['week_person_income'] * 1;
			}

			// 佣金筛选
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

			// 团队统计
			$result['data'][$k]['team_info'] = $this->dayTeamCount($v['id'], $begin_time, $end_time);

			// 充提差筛选
			if ($diff_id == 1 && $result['data'][$k]['team_info']['diff_payment'] < 0) {
				unset($result['data'][$k]);
			}
			if ($diff_id == 2 && $result['data'][$k]['team_info']['diff_payment'] > 0) {
				unset($result['data'][$k]);
			}
		}

		return $result;
	}

	// 代理数据详情
	public function AgentInfo($id) {

		$apigame = new ApiGame;

		// 个人信息
		$user_info = Db::table('gameaccount.newuseraccounts')
						->field('Account, ChannelType, nickname, phoneNo, email')
						->where('Id', $id)->find();

		// 个人信息-佣金统计
		$user_info_commission = Db::table('ym_manage.agent_settlement')->where('uid', $id)->field('amount, status')->select();
		$user_info['history_commission'] = 0;
		$user_info['draw_commission'] = 0;
		$user_info['surplus_commission'] = 0;
		foreach ($user_info_commission as $k => $v) {

			if ($v['status'] == 1) {
				$user_info['draw_commission'] += $v['amount'];
			}
			if ($v['status'] == 0) {
				$user_info['surplus_commission'] += $v['amount'];
			}
			$user_info['history_commission'] += $v['amount'];

		}

		$today = [date('Y-m-d'), date('Y-m-d')." 23:59:59"];
		$yesterday = [date('Y-m-d', strtotime("-1 day")), date('Y-m-d', strtotime("-1 day"))." 23:59:59"];
		$preday = [date("Y-m-d H:i:s",mktime(0, 0 , 0,date("m"),date("d")-date("N")+1-7,date("Y"))),date("Y-m-d H:i:s",mktime(23,59,59,date("m"),date("d")-date("N")+7-7,date("Y")))];
		$weekday = [date("Y-m-d H:i:s",mktime(0, 0 , 0,date("m"),date("d")-date("N")+1,date("Y"))),date("Y-m-d H:i:s",mktime(23,59,59,date("m"),date("d")-date("N")+7,date("Y")))];
		$monthday = [date("Y-m-d H:i:s",mktime(0, 0 , 0,date("m"),1,date("Y"))),date("Y-m-d H:i:s",mktime(23,59,59,date("m"),date("t"),date("Y")))];

		$topAgentList = array_reverse($apigame->agentRecursion($id));
		$topAgentId = count($topAgentList) > 1 ? $topAgentList[1] : $id;

		// 业绩数据
		$performance_info = [
			'week_performance' => 0,
			'week_commission' => 0,
			'lask_week_performance' => 0,
			'lask_week_commission' => 0,
			'month_performance' => 0,
			'month_commission' => 0,
			'team_size' => $apigame->getRecursionUserAgentCount($topAgentId),
			'new_today_team_num' => $this->newAddUserNum($id, $today[0], $today[1])['new_add_num'],
			'new_yesterday_team_num' => $this->newAddUserNum($id, $yesterday[0], $yesterday[1])['new_add_num'],
			'sub_size' => $apigame->getRecursionUserAgentCount($id),
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

		$yesterday_info = [
			'team_performance' => 0,
			'team_commission' => 0,
			'agent_performance' => 0,
			'agent_commission' => 0,
			'sub_running_account' => 0,
			'sub_performance' => 0,
			'my_commission' => 0,
		];

		return [
			'user_info' => $user_info,
			'performance_info' => $performance_info,
			'today_info' => $today_info,
			'yesterday_info' => $yesterday_info,
		];
		
	}

	public function newAddUserNum($id, $begin_time = '', $end_time = '', $count = ['new_add_num' => 0]) {
		$baseResult = Db::table('gameaccount.newuseraccounts gn')
						->where('gn.ChannelType', $id)
						->field('gn.Id')
						->select();
		foreach ($baseResult as $k => $v) {
			$newUserInfo = Db::table('gameaccount.newuseraccounts')->where('Id',$v['Id'])->where('AddDate','between', [$begin_time, $end_time])->field('COUNT(1) count')->find();
			$count['new_add_num'] += $newUserInfo['count'];
			return $this->newAddUserNum($v['Id'], $begin_time, $end_time, $count);
		}

		return $count;
	}

	public function dayTeamCount($id, $begin_time = '', $end_time = '', $count = [
		'active_num' => 0,
		'team_performance' => 0,
		'team_performance_true' => 0,
		'new_add_num' => 0,
		'payment_num' => 0,
		'out_payment_num' => 0,
		'diff_payment' => 0,
		'win' => 0,
		'lose' => 0
	]) {

		$baseResult = Db::table('gameaccount.newuseraccounts gn')
						->where('gn.ChannelType', $id)
						->field('gn.Id')
						->select();
		
		foreach ($baseResult as $k => $v) {

			// 获取该用户是否充值过
			$isPay = Db::table('ym_manage.paylog')->where('uid', $v['Id'])->where('status',1)->field('COUNT(1) count')->find();
			// 统计业绩
			$performanceInfo = Db::table('gameaccount.mark')->where('userId', $v['Id'])->where('balanceTime','between', [$begin_time, $end_time])->field('SUM(tax) tax')->find();
			$count['team_performance'] += $performanceInfo['tax'];
			if ($isPay['count'] > 0) {
				$count['team_performance_true'] += $performanceInfo['tax'];
			}
			// 如果统计业绩有值，证明也是活跃用户
			$count['active_num'] += 1;
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
			$count['diff_payment'] = $count['payment_num'] - $count['out_payment_num'];
			// 输赢
			$win_lose = Db::table('gameaccount.mark')->where('userId', $v['Id'])->where('balanceTime','between', [$begin_time, $end_time])->field('winCoin')->select();
			foreach ($win_lose as $key => $val) {
				if($val['winCoin'] <= 0) {
					$count['lose'] += 1;
				} else {
					$count['win'] += 1;
				}
			}

			return $this->dayTeamCount($v['Id'], $begin_time, $end_time, $count);

		}

		return $count;
	}


	public function getAgentBottomLevel($id = 0) {

		$result = Db::table('ym_manage.admin a')
			->join('gameaccount.newuseraccounts na', 'a.id = na.Id')
			->where('a.isagent',1)
			->where('a.top_agent',0)
			->where('na.Id','>',15000)
			->field('a.id, na.channelType pid')
			->select();

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

	// 获取当日注册人数
	public function todayRegister() {
		$begin_time = date('Y-m-d');
		$end_time = date('Y-m-d') . ' 23:59:59';
		$res = Db::table('gameaccount.newuseraccounts')->where('AddDate','between', [$begin_time, $end_time])->field('Id')->select();
		return $res;
	}

	// 获取个人 OR 团队 充值金额
	public function getPersonPayment($id, $begin_time = '', $end_time = '') {
		$sql = Db::table('ym_manage.paylog')->where('uid',$id)->where('status',1)->group('uid')->field('SUM(fee) as fee');
		if ($begin_time && $end_time) {
			$sql->where('paytime','between',[$begin_time, $end_time]);
		}
		return $sql->find();
	}

	public function getPersonPaymentTeam($id, $begin_time = '', $end_time = '', $amount = 0) {

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
			$amount += $v['fee'];
			return $this->getPersonPaymentTeam($v['Id'], $begin_time, $end_time, $amount);
		}

		return $amount;
	}

	// 获取个人业绩
	public function getPersonformance($id, $begin_time = '', $end_time = '', $is_payment = 0) {
		$sql = Db::table('gameaccount.mark')->where('userId',$id)->where('tax','>',0)->group('userId')->field('SUM(tax) as tax');
		if ($begin_time && $end_time) {
			$sql->where('balanceTime','between',[$begin_time, $end_time]);
		}
		if ($is_payment == 0) {
			return $sql->find();
		}
		if ($is_payment == 1) {
			$payment_count = Db::table('ym_manage.paylog')->where('status',1)->where('uid',$id)->field('COUNT(1) count')->find();
			if ($payment_count['count'] > 0) {
				return $sql->find();
			} else {
				return [
					'userId' => $id,
					'tax' => 0
				];
			}
		}
	}

	// 获取团队业绩
	public function getTeamPerformance($id, $begin_time = '', $end_time = '', $amount = 0, $is_payment = 0) {

		$sql = Db::table('gameaccount.newuseraccounts gn')
				->join('gameaccount.mark gm', 'gn.Id = gm.userId')
				->where('gn.channelType', $id)
				->where('gm.tax','>',0)
				->group('gm.userId')
				->field('gn.Id,SUM(gm.tax) as tax, (SELECT COUNT(1) FROM ym_manage.paylog WHERE uid = gn.Id AND status = 1) as is_payment');
		if ($begin_time && $end_time) {
			$sql->where('gm.balanceTime','between',[$begin_time, $end_time]);
		}

		$result = $sql->select();
		foreach ($result as $k => $v) {
			if ($is_payment == 1 && $v['is_payment'] == 0) {
				continue;
			}
			$amount += $v['tax'];
			return $this->getTeamPerformance($v['Id'], $begin_time, $end_time, $amount, $is_payment);
		}
		return $amount;
	}


	// 获取个人提现
	public function getPersonOutCash($id, $begin_time = '', $end_time = '') {
		$sql = Db::table('ym_manage.user_exchange')->where('user_id',$id)->where('status',1)->group('user_id')->field('SUM(money) as money');
		if ($begin_time && $end_time) {
			$sql->where('updated_at','between',[$begin_time, $end_time]);
		}
		return $sql->find();
	}

	// 获取团队提现
	public function getTeamOutCash($id, $begin_time = '', $end_time = '', $amount = 0) {

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
			$amount += $v['money'];
			return $this->getTeamOutCash($v['Id'], $begin_time, $end_time, $amount);
		}

		return $amount;
	}

}
