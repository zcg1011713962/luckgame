<?php
namespace app\agent\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;
use function Sodium\add;

class UserModel extends Model
{
	private $key = '';
	private $apiurl = '';
	private $config;
	
	public function __construct(){
		parent::__construct();
		$this->config = ConfigModel::getSystemConfig();
		$this->apiurl = $this->config['GameServiceApi'];
		$this->key = $this->config['PrivateKey'];
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
	
	public function getUserList($num = 10, $search = '',$agents_ids = ''){
		if($agents_ids == ''){ return false; }
		
		$dbobj = Db::table('ym_manage.uidglaid')->alias('u')
						->field('u.uid,u.aid,u.createtime,d.username,a.Account,i.score')
						->leftJoin('gameaccount.newuseraccounts a','u.uid=a.Id')
                        ->rightJoin('gameaccount.userinfo_imp i','u.uid=i.userId')
                        ->leftJoin('ym_manage.admin d','u.aid=d.id');
		if( !empty($search['starttime']) && !empty($search['endtime']) ){
			$starttime = strtotime($search['starttime']);
			$endtime = strtotime($search['endtime']);
			$dbobj = $dbobj->where('u.createtime','>=', $starttime)->where('u.createtime','<', $endtime);
		}
		if( !empty($search['searchstr']) ) {
			$dbobj = $dbobj->where('u.uid', $search['searchstr']);
		}
		if( !empty($search['searchaid']) ) {
			$dbobj = $dbobj->where('u.aid', $search['searchaid']);
		}
		$dbobj = $dbobj->where('u.aid','in',$agents_ids);
		$count = $dbobj->count();
		$list = $dbobj->order('u.id desc')->paginate($num);			
		
		$page = $list->render();
		
		return array(
			'list' => $list,
			'count' => $count,
			'page' => $page
		);
	}

    public function getMyUserList($num = 10, $search = '',$agents_ids = ''){
        if (!$search['ChannelType']){
            if($agents_ids == ''){ return false; }
        }

        $dbobj = Db::table('gameaccount.newuseraccounts')->alias('a')
            ->field('a.*,i.score,d.username')
            ->leftJoin('ym_manage.admin d','a.ChannelType=d.id')
            ->rightJoin('gameaccount.userinfo_imp i','a.Id=i.userId');
        if( !empty($search['ChannelType']) ) {
            $dbobj = $dbobj->where('a.ChannelType', $search['ChannelType']);
        }
        if (!empty($search['searchstr'])){
            $dbobj = $dbobj->where('a.Id', $search['searchstr']);
        }
        $count = $dbobj->count();
        $list = $dbobj->order('a.id desc')->paginate($num);

        $page = $list->render();

        return array(
            'list' => $list,
            'count' => $count,
            'page' => $page
        );
    }
	
	public function getUserCount($search = ''){
		if(!empty($search)){
			return Db::table('gameaccount.newuseraccounts')
						->where('Id|Account','eq',$search)
						->count();
		}else{
			return Db::table('gameaccount.newuseraccounts')->count();
		}
	}
	
	public function getUserInfo($id){
		if(empty($id)){ return false; }		
		return Db::table('gameaccount.newuseraccounts')->alias('u')
					->join('gameaccount.userinfo_imp i','u.Id=i.userId')
					->find($id);
	}
	
	public function getUserInfoByAccount($account){
		if(empty($account)){ return false; }		
		return Db::table('gameaccount.newuseraccounts')->alias('u')
					->leftJoin('gameaccount.userinfo_imp i','u.Id=i.userId')
					->where('u.Account',$account)
					->find();
	}
	
	public function setUserPwd($data){
		if(empty($data)){ return false; }
		if(empty($data['username']) || empty($data['uid']) ){ return false; }
		if(empty($data['newpass']) || empty($data['repass']) ){ return false; }
		if($data['newpass'] != $data['repass']){ return false; }
		
		$user = Db::table('gameaccount.newuseraccounts')
					->where('Id',$data['uid'])
					->where('Account',$data['username'])
					->find();
		
		if($user){
			// return Db::name('gameaccount.newuseraccounts')
			// 			->where('Id', $user['Id'])
			// 			->data(['p' => $data['repass'],'Password' => md5($data['repass'])])
			// 			->update();
			
			$act = "pwdreset";
			$time = strtotime('now');
			$key = $this->key;
			$account = trim($user['Account']);
			$pwd = $data['newpass'];
			$sign = $act.$account.$pwd.$time.$key;
			$md5sign = md5($sign);
			$url= $this->apiurl."/Activity/gameuse?act=".$act."&accountname=".$account."&pwd=".$pwd."&time=".$time."&sign=".$md5sign;
			$res = $this->_request($url);
			
			$res = json_decode($res,true);
			if(isset($res) && ($res['status'] == '0')){				
				return true;
			}
			
		}
		
		return false;
	}
	
	public function setUserScore($data,$type,$agent=false){
		if(empty($type) || !in_array($type,['1','2']) ){ return false; }
		if(empty($data)){ return false; }
		if(empty($data['username']) || empty($data['uid']) ){ return false; }
		if(empty($data['addscore']) ){ return false; }
        if (strpos($data['addscore'] , '-') !== false || strpos($data['addscore'] , '+') !== false){
            die('金币数量不正确');
        }
		$addscore = round($data['addscore'], 0);
		$account = trim($data['username']);

		if($type == 2){
            // 不是代理，则计算金币是否充足
            if (!$agent){
                // 检查用户的金币是否足
                $info = $this->getUserInfo($data['uid']);
                if ($info['score'] < $addscore){
                    die('用户可用数不足');
                }
            }
			$addscore = 0 - $addscore;
		}
		return $this->insertScore($account,$addscore);
		
		die;
		//下面代码废弃
		$user = Db::table('gameaccount.newuseraccounts')
					->where('Id',$data['uid'])
					->where('Account',$data['username'])
					->find();
					
		if($user){
			if($user['score'] != $data['score']){
				return false;
			}
			if($type == '1'){
				$score = $user['score'] + $addscore;
				$logtype = 1;
				$totalRecharge = $user['totalRecharge'] + $addscore;
			}elseif($type == '2'){
				$score = $user['score'] - $addscore;
				$logtype = 0;
				$totalRecharge = $user['totalRecharge'];
			}else{
				return false;
			}
			
			$res = Db::name('gameaccount.newuseraccounts')
						->where('Id', $user['Id'])
						->data(['score' => $score, 'totalRecharge' => $totalRecharge])
						->update();
			if($res){				
				$this->addRechargeLog($user['Id'],$addscore,$user['score'],$score,$logtype);
				return true;
			}else{
				return false;
			}
		}
		
		return false;
	}
			
	private function addRechargeLog($uid,$czfee,$oldfee,$newfee,$logtype){
		$adminid = Cookie::get('agent_user_id');
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
	}
	
	public function setUserVip($data){
		if(empty($data)){ return false; }
		if(empty($data['i'])){ return false; }
		if(!isset($data['t'])){ return false; }
		
		$user = Db::table('gameaccount.newuseraccounts')
					->where('Id',$data['i'])
					->find();					
		if($user){
			
			$res = Db::name('gameaccount.newuseraccounts')
						->where('Id', $user['Id'])
						->data(['is_vip' => $data['t']])
						->update();
			if($res){
				return true;
			}
		}
		
		return false;
	}
	
	public function setUserFeng($data){
		if(empty($data)){ return false; }
		if(empty($data['i'])){ return false; }
		if(!isset($data['t'])){ return false; }
		
		$user = Db::table('gameaccount.newuseraccounts')
					->where('Id',$data['i'])
					->find();
		if($user){
			Db::name('gameaccount.newuseraccounts')
						->where('Id', $user['Id'])
						->data([ 'iscanlogin' => $data['t'] ])
						->update();
						
			$act = "disabled";
			$time = strtotime('now');
			$key = $this->key;
			$account = trim($user['Account']);
			$state = $data['t'];//$state 1启用 0禁用
			$sign = $act.$account.$state.$time.$key;
			$md5sign = md5($sign);
			$url=$this->apiurl."/Activity/gameuse?act=".$act."&accountname=".$account."&state=".$state."&time=".$time."&sign=".$md5sign;
			$res = $this->_request($url);
			
			$res = json_decode($res,true);
			if(isset($res) && ($res['status'] == '0')){				
				return true;
			}
		}
		
		return false;
	}
	
	public function insertScore($account,$fee){
		if(empty($account) || empty($fee)){ return false; }
		$account = trim($account);
//		$fee = intval($fee) * 100;
		
		$user = $this->getUserInfoByAccount($account);
		if($user){
			
			$act = "scoreedit";			
			$time = strtotime('now');
			$key = $this->key;
			$sign = $act.$account.$fee.$time.$key;
			$md5sign = md5($sign);
			$url=$this->apiurl."/Activity/gameuse?act=".$act."&accountname=".$account."&goldnum=".$fee."&time=".$time."&sign=".$md5sign;
			$res = $this->_request($url);
			
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
		$list = Db::table('ym_manage.rechargelog')->order('id desc')->paginate($num);
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	public function rechargeLogsCount(){
		return Db::table('ym_manage.rechargelog')->count();
	}
	
	public function rechargeLogs1($num = 10){
		$list = Db::table('ym_manage.fkrechargelog')->order('id desc')->paginate($num);
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	public function rechargeLogsCount1(){
		return Db::table('ym_manage.fkrechargelog')->count();
	}
	
	public function setUserDiamond($data,$type){
		if(empty($type) || !in_array($type,['1','2']) ){ return false; }
		if(empty($data)){ return false; }
		if(empty($data['username']) || empty($data['uid']) ){ return false; }
		if( empty($data['addscore']) ){ return false; }
		$addscore = round($data['addscore'], 0);
		//$account = trim($data['username']);
		$account = $data['username'];
		
		if($type == '2'){
			$addscore = 0 - $addscore;
		}
		
		return $this->insertDiamond($account,$addscore);
		
		
	}
	public function insertDiamond($account,$fee){
		if(empty($account) || empty($fee)){ return false; }
		$account = trim($account);
		$fee = intval($fee) * 1;
		
		$user = $this->getUserInfoByAccount($account);
		if($user){
			
			$act = "diamondedit";			
			$time = strtotime('now');
			$key = $this->key;
			$sign = $act.$account.$fee.$time.$key;
			$md5sign = md5($sign);
			$url=$this->apiurl."/Activity/gameuse?act=".$act."&accountname=".$account."&goldnum=".$fee."&time=".$time."&sign=".$md5sign;
			$res = $this->_request($url);
			
			$res = json_decode($res,true);
			if(isset($res) && ($res['status'] == '0')){
				$score = $user['diamond'] + $fee;
				$logtype = $fee>0 ? 1 : 0;				
				$this->addFKRechargeLog($user['Id'],abs($fee),$user['diamond'],$score,$logtype);
				return true;
			}else{
				return json_encode($res);
			}
			
		}
		return false;
	}
	private function addFKRechargeLog($uid,$czfee,$oldfee,$newfee,$logtype){
		$adminid = Cookie::get('agent_user_id');
		$log = array(
			'adminid' => $adminid,
			'userid' => $uid,
			'createtime' => time(),
			'czfee' => $czfee,
			'oldfee' => $oldfee,
			'newfee' => $newfee,
			'type' => $logtype//1 加 0 减
		);
		Db::name('ym_manage.fkrechargelog')->insert($log);
	}

	public function getRealNum($account){		
		$act = "scorequery";
		$time = strtotime('now');
		$key = $this->key;				
		$sign = $act.$account.$time.$key;
		$md5sign = md5($sign);
		$_url = $this->apiurl;
		$url = $_url."/Activity/gameuse?act=".$act."&accountname=".$account."&time=".$time."&sign=".$md5sign;
		$res = $this->_request($url);
		
		$res = json_decode($res,true);
		if(isset($res) && ($res['status'] == '0')){
			return $res['data']['score'];
		}else{
			return false;
		}
	}
	
}