<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use think\facade\Log;
use app\admin\utils\gameUtils;
use app\admin\model\ConfigModel;

class GameModel extends Model
{
	private $key = '';
	private $apiurl = '';
	private $GameServiceKey = '';

	public function __construct(){
		parent::__construct();

		// 读取配置信息
		$config = ConfigModel::getSystemConfig();
		$this->apiurl = $config['GameServiceApi'];
		$this->key = $config['PrivateKey'];
		$this->GameServiceKey = $config['GameServiceKey'];
		// $this->apiurl = Config::get('app.Recharge_API');
	}
	public function getConfig($flag = ''){
		if(empty($flag)){ return false; }
		return Config::get($flag);
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
        curl_setopt($ch , CURLOPT_TIMEOUT , 5);
		$str = curl_exec($ch);//执行访问
		curl_close($ch);//关闭curl释放资源
		return $str;
	}
	
	public function saveGame($data) {

		$params = [
			'gameid' => $data['gameId'] , 'name' => $data['gameName'], 'server' => $data['gamePort'], 'isstart' => 1,
			'port' => $data['gamePort'] , 'version' => isset($data['gameVersion']) ? $data['gameVersion'] : '' , 'type' => $data['gameType'] ,
			'choushuilv' => intval($data['choushuilv']), 'nandulv' => intval($data['nandulv']) , 'isshuigame' => intval($data['waterGame'])
		];
		Db::name('ym_manage.game')->insert($params);

		if (isset($data['waterGame']) && intval($data['waterGame']) > 0) {
			$data['waterLevel'] = gameUtils::waterLevelChange($data['choushuilv']);
			$bigWinInfo = gameUtils::gameLevelChange($data['nandulv']);
			$data['bigWinLevel'] = $bigWinInfo[0];
			$data['bigWinLuck']  = $bigWinInfo[1];
			$params = [
				'nGameID' => $data['gameId'] , 'nGameType' => 0, 'nGamblingUpdateBalanceGold' => 0, 'strGameName' => $data['gameName'] , 'nGamblingWaterLevelGold' => $data['waterLevel'] , 
				'nGamblingBalanceGold' => $data['balance'] , 
                               //  'nGamblingWinPool' => $data['winPool'] ,
                                'nGamblingBigWinLevel' => $data['bigWinLevel'] , 
				'nGamblingBigWinLuck' => $data['bigWinLuck'] , 'expectRTP' => $data['rtp']
			];
			try {
				Db::connect('db_laba')->name('gambling_game_list')->insert($params);
			} catch(\Exception $e) {
				
			}
		}
	}
	// 获取游戏详情
	public function editGame($gameId) {
		$gameInfo = Db::name('ym_manage.game')->where('id', $gameId)->where('delete_at',0)->find();
		if ($gameInfo && $gameInfo['isshuigame'] > 0) {
			$gamblingInfo = Db::name('la_ba.gambling_game_list')->where('nGameID',$gameInfo['gameid'])->find();
			$gameInfo['gamblingInfo'] = $gamblingInfo;
		}
		return $gameInfo;
	}

	// 编辑游戏确认
	public function editGameaffirm($data) {
		$params = [
			'gameid' => $data['gameId'] , 'name' => $data['gameName'], 'server' => $data['gamePort'], 'isstart' => 1,
			'port' => $data['gamePort'] , 'version' => isset($data['gameVersion']) ? $data['gameVersion'] : '' , 'type' => $data['gameType'] ,
			'choushuilv' => intval($data['choushuilv']), 'nandulv' => intval($data['nandulv']) , 'isshuigame' => intval($data['waterGame'])
		];
		Db::name('ym_manage.game')->where('id', $data['id'])->update($params);
		if (isset($data['waterGame']) && intval($data['waterGame']) > 0) {
			$data['waterLevel'] = gameUtils::waterLevelChange($data['choushuilv']);
			$bigWinInfo = gameUtils::gameLevelChange($data['nandulv']);
			$data['bigWinLevel'] = $bigWinInfo[0];
			$data['bigWinLuck']  = $bigWinInfo[1];
			$params = [
				'nGameID' => $data['gameId'] , 'nGameType' => 0, 'nGamblingUpdateBalanceGold' => 0, 'strGameName' => $data['gameName'] , 'nGamblingWaterLevelGold' => $data['waterLevel'] , 
				'nGamblingBalanceGold' => $data['balance'] , 
                                //'nGamblingWinPool' => $data['winPool'] , 
                                'nGamblingBigWinLevel' => $data['bigWinLevel'] , 
				'nGamblingBigWinLuck' => $data['bigWinLuck'] , 'expectRTP' => $data['rtp']
			];
			$gamblingInfo = Db::connect('db_laba')->name('gambling_game_list');
			// 获取上一次的gameid属性
			$gameInfo = $this->editGame($data['id']);
			// 判断水位游戏是否存在
			if (!empty($gameInfo['gamblingInfo']['nGameID'])) {
				$gamblingInfo->where('nGameID', $gameInfo['gamblingInfo']['nGameID'])->update($params);
			} else {
				$gamblingInfo->insert($params);
			}
		}
	}

	public function deleteGame($id) {
		// 如果删除了一个游戏 状态也改变为 已关闭
		return Db::name('ym_manage.game')->where('id',$id)->update(['delete_at' => time(),'isstart' => 0]);
	}

	public function getGameListPorts($ports) {
		return Db::table('ym_manage.game')->field('port,name')->where(['port' => $ports])->select();
	}

	public function getList($params){
		$subsql = Db::table('gameaccount.mark')->field('gameId, serverId, SUM(useCoin) useCoinTotal')
            ->group('gameId,serverId')
            ->buildSql();
		$info = Db::table('ym_manage.game g')->where('g.delete_at',0)
            ->leftJoin([$subsql => 'gm'], 'g.gameid = gm.gameId AND g.server = gm.serverId');
		if (!empty($params['gameCategoryId']) && $params['gameCategoryId'] > 0) {
			$info->where('g.type', $params['gameCategoryId']);
		}
		if (!empty($params['keyWord'])) {
			$info->where('g.name','LIKE',"%{$params['keyWord']}%");
		}
		$info = $info->order('port asc')->select();

		// 保存fish数据，避免循环读取fish
		$fish = [];
		// 保存 fish -> catch_chance 数据， 避免循环读取catch_chance
		$catch_chance = [];
		// 追加 fish 功能
		foreach ($info as $k => $v) {
			$info[$k]['isFish'] = 0;
			$info[$k]['line'] = 0;
			$info[$k]['pool'] = 0;
			$info[$k]['chance'] = 0;
			if (!empty($v['fish'])) {
				$info[$k]['isFish'] = 1;

				// 读取fish数据
				if (empty($fish[$v['fish']])) {
					$fish[$v['fish']] = Db::table($v['fish'].'.control_pool')->select();
					$catch_chance[$v['fish']] = Db::table($v['fish'].'.catch_chance')->select();
				}

				// 直接追加fish数据
				foreach ($fish[$v['fish']] as $key => $val) {
					if ($v['port'] == $val['serveId']) {
						$info[$k]['line'] = $val['line'];
						$info[$k]['pool'] = $val['pool'];
						continue;
					}
				}
				
				// 追加 catch_chance 数据
				foreach ($catch_chance[$v['fish']] as $key => $val) {
					if ($v['port'] == $val['serveId']) {
						$info[$k]['chance'] = $val['chance'] * 100;
						continue;
					}
				}
			}
		}

        $redis_ip = $this->getConfig('app.redis_ip');
        $redis_port = $this->getConfig('app.redis_port');
        $redis_auth = $this->getConfig('app.redis_auth');
        //发布订阅
        $redis = new \Redis();
        $redis->connect($redis_ip, $redis_port);
        $redis_auth && $redis->auth($redis_auth);
        $redisData = $redis->get('gameRTP');
        $redisData = $redisData ? json_decode($redisData , true) : [];
        $checkFields=array("nGamblingWinPool"=>0,"nGamblingWaterLevelGold"=>0,"nGamblingBalanceGold"=>0,"expectRTP"=>0,"nGamblingBigWinLevel"=>"0,0,1","nandu"=>"");
        foreach($info as $k => $v){
            $redisKey = 'game' . $v['port'];
            $redisInfo = [];
            if (isset($redisData[$redisKey])){
                $redisInfo = $redisData[$redisKey];
            }
            $info[$k]['currentRTP'] = 0;
            if ($redisInfo){
                $info[$k]['currentRTP'] = $redisInfo['curRTP'] ? $redisInfo['curRTP'] : 0;
            }
			if($v['isshuigame'] == '1'){
				$slotset = Db::connect('db_laba')->table('gambling_game_list')->where('nGameID',$v['gameid'])->find();
                              
                                foreach($checkFields as $field=>$val)
                                if(!isset($slotset[$field])){
                                   $slotset[$field]=$val;
                                }
                                
				$info[$k]['slotset'] = serialize($slotset);
                                
				if($slotset){
					$info[$k]['shuiwei'] = $slotset['nGamblingWaterLevelGold'];
					$info[$k]['kucun'] = $slotset['nGamblingBalanceGold'];
					$info[$k]['jiangchi'] = $slotset['nGamblingWinPool'];
					$info[$k]['expectRTP'] = $slotset['expectRTP'];

					if($slotset['nGamblingBigWinLevel'] == '0,0,1000'){ $nandu = 1; }
					if($slotset['nGamblingBigWinLevel'] == '0,0,800'){ $nandu = 2; }
					if($slotset['nGamblingBigWinLevel'] == '0,0,700'){ $nandu = 3; }
					if($slotset['nGamblingBigWinLevel'] == '0,0,600'){ $nandu = 4; }
					if($slotset['nGamblingBigWinLevel'] == '0,0,400'){ $nandu = 5; }
					if($slotset['nGamblingBigWinLevel'] == '0,0,300'){ $nandu = 6; }
					if($slotset['nGamblingBigWinLevel'] == '0,0,200'){ $nandu = 7; }
					if($slotset['nGamblingBigWinLevel'] == '0,0,100'){ $nandu = 8; }
					if($slotset['nGamblingBigWinLevel'] == '0,0,50'){ $nandu = 9; }
					if($slotset['nGamblingBigWinLevel'] == '0,0,1'){ $nandu = 10; }
					$info[$k]['nandu'] = $nandu;
				}
			}
		}
		foreach ($info as $k => $v) {
			$info[$k]['newCurrentRTP'] = 0;
			if ($v['isshuigame'] == '1' && !empty($v['useCoinTotal']) && !empty($v['kucun'])) {
				// （投注总额-系统盈利）/投注总额*100=RTP(小数点后2位)
				$info[$k]['newCurrentRTP'] = round(($v['useCoinTotal'] - $v['kucun']) / $v['useCoinTotal'] * 100,2);
			}
		}
		return $info;
	}
		
	public function getCount($params = []) {
		$where = [];
		if (isset($params['gameCategoryId']) && $params['gameCategoryId'] > 0) {
			$where[] = ['type', '=', $params['gameCategoryId']];
		}
		if (isset($params['keyWord']) && !empty($params['keyWord'])) {
			$where[] = ['name', 'LIKE', "%{$params['keyWord']}%"];
		}
		return Db::table('ym_manage.game')->where('delete_at',0)->where($where)->count();		
	}
	
	public function setStart($data){
		if(empty($data)){ return false; }
		if(empty($data['i'])){ return false; }
		if(!isset($data['t'])){ return false; }
		
		$game = Db::table('ym_manage.game')
					->where('id',$data['i'])
					->find();
		if($game){
			if($data['t'] == '0'){
				$this->closeGame($game['port']);
			}
			return Db::name('ym_manage.game')
						->where('id', $game['id'])
						->data([ 'isstart' => $data['t'] ])
						->update();
		}
		
		return false;
	}

	public function closeGame($port=''){
		//if(empty($port)){ return false; }
		$act = "closeServer";	
		$url = $this->apiurl."/gmManage?act=".$act.'&port='.$port;
		//echo $url.'<br/>';
		$arr = array('port'=>$port,'act'=>$act);
		$arr = json_encode($arr);
		//var_dump($arr);die;
		$res = $this->_request($url,false,'post',$arr);
		//var_dump($res);
		return $res;
	}

    public function updateGameData($port='' , $dataKey = '' , $data = ''){
        $act = "updateGameData";
        $arr = array('port'=>$port,'act'=>$act , 'key' => $this->GameServiceKey , 'dataKey' => $dataKey , 'data' => $data);
        $url = $this->apiurl."/gmManage?act=".$act.'&port='.$port . '&key=' . $arr['key'] . '&dataKey=' . $dataKey . '&data=' . $data;
        $arr = json_encode($arr);
        //var_dump($arr);die;
        $res = $this->_request($url,false,'post',$arr);
        //var_dump($res);
        return $res;
    }

	public function notifyGameEmail($act, $type, $userid) {
		$arr = array('act'=>$act , 'key' => $this->GameServiceKey , 'type' => $type , 'userid' => $userid);
		$url = $this->apiurl ."/gmManage";
        $this->_request($url,false,'post', json_encode($arr));
	}
	
	public function getInfo($id){
		return Db::table('ym_manage.game')->find($id);		
	}
	
	public function setCSlv($data){
		if(empty($data)){ return false; }
		if(empty($data['lv'])){ return false; }
		if(empty($data['id'])){ return false; }
		
		$game = Db::table('ym_manage.game')
					->where('id',$data['id'])
					->find();
		if($game){
			
			switch ($data['lv']) {
				case 1:
				  $shuiwei = 0;
				  break;  
				case 11:
				  $shuiwei = 1;
				  break;
				case 12:
				  $shuiwei = 2;
				  break;
				case 13:
				  $shuiwei = 3;
				  break;
				case 14:
				  $shuiwei = 4;
				  break;
				case 2:
				  $shuiwei = 5;
				  break;
				case 3:
				  $shuiwei = 10;
				  break;
				case 4:
				  $shuiwei = 15;
				  break;
				case 5:
				  $shuiwei = 20;
				  break;
				case 6:
				  $shuiwei = 25;
				  break;
				case 7:
				  $shuiwei = 30;
				  break;
				case 8:
				  $shuiwei = 35;
				  break;
				case 9:
				  $shuiwei = 40;
				  break;
				case 10:
				  $shuiwei = 50;
				  break;
				default:
				  $shuiwei = null;
			}
			if($shuiwei === null){
				return false;
			}else{
				$res = Db::connect('db_laba')->name('gambling_game_list')
							->where('nGameID', $game['gameid'])
							->data([ 'nGamblingWaterLevelGold' => $shuiwei ])
							->update();
				if($res){
					$redis_ip = $this->getConfig('app.redis_ip');
					$redis_port = $this->getConfig('app.redis_port');
					$redis_auth = $this->getConfig('app.redis_auth');
					//发布订阅					
					$redis = new \Redis();
					$redis->connect($redis_ip, $redis_port);
					$redis->auth($redis_auth); 
					$str = '{"swval":"'.$shuiwei.'","gameid":"'.$game['gameid'].'","serverId":"'.$game['port'].'","type":"1"}';
					//Log::write($str,'nxp');
					$rs = $redis->publish('EditLabaSet', $str);
					//Log::write($rs,'nxp');
					$redis->close();
                    $this->updateGameData($game['port'] , 'nGamblingWaterLevelGold' , $shuiwei);
				}
			}
			return Db::name('ym_manage.game')
						->where('id', $game['id'])
						->data([ 'choushuilv' => $data['lv'] ])
						->update();
		}
		
		return false;
	}

	public function setNandu($data){
		if(empty($data)){ return false; }
		if(empty($data['lv'])){ return false; }
		if(empty($data['id'])){ return false; }
		
		$game = Db::table('ym_manage.game')
					->where('id',$data['id'])
					->find();
		if($game){

			switch ($data['lv']) {
				case '1':
					$BigWinlevel = '0,0,1000';
					$BigWinluck = '0,0,100';
				  	break;  
				case '2':
					$BigWinlevel = '0,0,800';
					$BigWinluck = '0,0,90';
				  	break;
				case '3':
					$BigWinlevel = '0,0,700';
					$BigWinluck = '0,0,80';
				  	break;
				case '4':
					$BigWinlevel = '0,0,600';
					$BigWinluck = '0,0,70';
				 	break;
				case '5':
					$BigWinlevel = '0,0,400';
					$BigWinluck = '0,0,60';
				  	break;
				case '6':
					$BigWinlevel = '0,0,300';
					$BigWinluck = '0,0,50';
				  break;
				case '7':
					$BigWinlevel = '0,0,200';
					$BigWinluck = '0,0,40';
				  	break;
				case '8':
					$BigWinlevel = '0,0,100';
					$BigWinluck = '0,0,30';
				  	break;
				case '9':
					$BigWinlevel = '0,0,50';
					$BigWinluck = '0,0,20';
				  	break;
				case '10':
					$BigWinlevel = '0,0,1';
					$BigWinluck = '0,0,10';
				  	break;
				default:
				  	return false;
			}
			// Log::write($data,'nxp');
			// Log::write($BigWinlevel,'nxp');
			// Log::write($BigWinluck,'nxp');
			
			$res = Db::connect('db_laba')->name('gambling_game_list')
						->where('nGameID', $game['gameid'])
						->data([ 'nGamblingBigWinLevel' => $BigWinlevel, 'nGamblingBigWinLuck' => $BigWinluck ])
						->update();
			if($res){
				$redis_ip = $this->getConfig('app.redis_ip');
				$redis_port = $this->getConfig('app.redis_port');
				$redis_auth = $this->getConfig('app.redis_auth');
				//发布订阅					
				$redis = new \Redis();
				$redis->connect($redis_ip, $redis_port);
				$redis->auth($redis_auth); 
				$str = '{"BigWinlevel":"'.$BigWinlevel.'","BigWinluck":"'.$BigWinluck.'","gameid":"'.$game['gameid'].'","serverId":"'.$game['port'].'","type":"2"}';
				//Log::write($str,'nxp');
				$rs = $redis->publish('EditLabaSet', $str);
				//Log::write($rs,'nxp');
				$redis->close();
                $this->updateGameData($game['port'] , 'nGamblingBigWinLevel' , $BigWinlevel);
                $this->updateGameData($game['port'] , 'nGamblingBigWinLuck ' , $BigWinluck);
			}
			
			return Db::name('ym_manage.game')
						->where('id', $game['id'])
						->data([ 'nandulv' => $data['lv'] ])
						->update();
		}
		
		return false;
	}
		
	public function setKucun($data){
		if(empty($data)){ return false; }
		if(empty($data['kucun'])){ return false; }
		if(empty($data['id'])){ return false; }
		
		$kucun = $data['kucun'];
		
		$game = Db::table('ym_manage.game')
					->where('id',$data['id'])
					->find();
		if($game){
			
			$res = Db::connect('db_laba')->name('gambling_game_list')
						->where('nGameID', $game['gameid'])
						->data([ 'nGamblingBalanceGold' => $kucun ])
						->update();
			if($res){
				//发布订阅
				$url = '/redis_pub/editKucun.php?gameid='.$game['gameid'].'&kucun='.$kucun;
				$this->_request($url);
                $this->updateGameData($game['port'] , 'nGamblingBalanceGold' , $kucun);
				return true;
			}
			
		}
		
		return false;
	}
	
	public function setJiangchi($data){
		if(empty($data)){ return false; }
		if(empty($data['id'])){ return false; }
		
		$jiangchi = $data['jiangchi'];
		
		$game = Db::table('ym_manage.game')
					->where('id',$data['id'])
					->find();
		if($game){
			if ($data['status'] == 0) {
				$res = Db::connect('la_ba')->name('gambling_game_list')->where('nGameID', $game['gameid'])->inc('nGamblingWinPool', $jiangchi)->dec('nGamblingBalanceGold', $jiangchi)->update();
			}
			if ($data['status'] == 1) {
				$res = Db::connect('la_ba')->name('gambling_game_list')->where('nGameID', $game['gameid'])->dec('nGamblingWinPool', $jiangchi)->inc('nGamblingBalanceGold', $jiangchi)->update();
			}
			Db::table('laba_gambling_game_log')->insert([
				'game_id' => $game['gameid'],
				'server_id' => $game['server'],
				'status' => $data['status'],
				'money' => $jiangchi
			]);
			/*$res = Db::connect('db_laba')->name('gambling_game_list')
						->where('nGameID', $game['gameid'])
						->data([ 'nGamblingWinPool' => $jiangchi ])
						->update();*/
			if($res){
				//发布订阅
				$url = '/redis_pub/editJiangchi.php?gameid='.$game['gameid'].'&jiangchi='.$jiangchi;
				$this->_request($url);
                $this->updateGameData($game['port'] , 'nGamblingWinPool' , $jiangchi);
				return true;
			}
			
		}
		
		return false;
	}

	public function getOnlineList() {
		$arr = ['key'=>$this->GameServiceKey,'act'=>'GetuserListOnline'];
		return json_decode($this->_request($this->apiurl.'/gmManage',false,'post',json_encode($arr)),true) ?: [];
	}
	
	public function getOnlineNum($id){

		// 获取游戏在线人数老方法
		// if(empty($id)){ return false; }
		// $nums = Db::table('ym_manage.game_onlinenum')
		// 			->where('gid',$id)
		// 			->order('createtime desc')
		// 			->limit(10)
		// 			->select();
		
		// $key = array();
		// $value = array();
		// foreach($nums as $k=>$v){
		// 	$key[] = strval(date('m-d H:i:s',$v['createtime']));
		// 	$value[] = $v['num'];
		// }
		// $key = array_reverse($key);
		// $value = array_reverse($value);
		// return array('key'=>$key,'value'=>implode(',',$value));

		// 获取游戏在线人数新方法
		// 获取当前游戏详情
		$gameInfo = $this->editGame($id);
		$result = $this->getOnlineList();
//		var_dump($result);die;
		// 保存当前游戏玩家在线人数
		$gameOnlineNum = 0;
		$gameOnLineNumAll = 0;
		foreach ($result as $k => $v) {
			if ($v['_userId'] >= 15000){
				$gameOnLineNumAll += 1;
			}
			// 去除在大厅玩家
			if ($v['GameId'] == 0) {
				continue;
			}
            if ($gameInfo) {
                if ($v['GameId'] == $gameInfo['server'] || $v['GameId'] == $gameInfo['port']) {
                    $gameOnlineNum += 1;
                }
            }
		}
		return ['gamename' => isset($gameInfo['name']) ? $gameInfo['name'] : '','onlinenum' => $gameOnlineNum, 'gameOnLineNumAll' => $gameOnLineNumAll];
	}
	
	public function getGongGaoList(){
		$info = Db::connect('db_gameaccount')->table('server_log')->where('status','1')->order('id desc')->select();
		return $info;
	}

	public function totalLoginNum() {
		$begin_time = date('Y-m-d',time());
		$end_time   = date('Y-m-d H:i:s',strtotime($begin_time) + 86399);
		return Db::connect('db_gameaccount')->name('logintemp')->field('COUNT(1) as count')->where([
			['loginDate','>=',$begin_time],
			['loginDate','<=',$end_time]
		])->count();
	}

	public function totalBetNum() {
		$begin_time = date('Y-m-d',time());
		$end_time   = date('Y-m-d H:i:s',strtotime($begin_time) + 86399);
		return Db::table('gameaccount.score_changelog')->field('COUNT(1) as count')->where([
			['userid','>','15000'],
			['change_time','>=',$begin_time],
			['change_time','<=',$end_time],
			['change_type','BETWEEN','100,20000']
		])->group('userid')->count();
	}

	public function totalPayNum() {
		$begin_time = date('Y-m-d',time());
		$end_time   = date('Y-m-d H:i:s',strtotime($begin_time) + 86399);
		return Db::table('gameaccount.score_changelog')->field('COUNT(1) as count')->where([
			['userid','>','15000'],
			['change_time','>=',$begin_time],
			['change_time','<=',$end_time],
			['change_type','=',0]
		])->group('userid')->count();
	}
        


	public function totalPayPrice () {
		$begin_time = date('Y-m-d',time());
		$end_time   = date('Y-m-d H:i:s',strtotime($begin_time) + 86399);
		$result = Db::table('gameaccount.score_changelog')->field('SUM(score_change) as count')->where([
			['userid','>','15000'],
			['change_time','>=',$begin_time],
			['change_time','<=',$end_time],
			['change_type','=',0],
			['score_change','>',0]
		])->find('count');
		return intval($result['count']);
	}
       
	public function totalWeekBetNum() {
               $now_time=time();
               $week=date('N',$now_time);
               $begin_day=$week -1;
               $end_day=7-$week;
               $begin_time=date("Y-m-d",strtotime("- $begin_day  day",$now_time));
               $end_time=date("Y-m-d 23:59:59",strtotime("+$end_day day",$now_time));
                 
		return Db::table('gameaccount.score_changelog')->field('COUNT(1) as count')->where([
			['userid','>','15000'],
			['change_time','>=',$begin_time],
			['change_time','<=',$end_time],
			['change_type','BETWEEN','100,20000']
		])->group('userid')->count();
	}
	public function totalWeekPayNum() {
               $now_time=time();
               $week=date('N',$now_time);
               $begin_day=$week -1;
               $end_day=7-$week;
               $begin_time=date("Y-m-d",strtotime("- $begin_day  day",$now_time));
               $end_time=date("Y-m-d 23:59:59",strtotime("+$end_day day",$now_time));
		return Db::table('gameaccount.score_changelog')->field('COUNT(1) as count')->where([
			['userid','>','15000'],
			['change_time','>=',$begin_time],
			['change_time','<=',$end_time],
			['change_type','=',0]
		])->group('userid')->count();
	}
	
        public function totalWeekPayPrice () {
                $now_time=time();
                $week=date('N',$now_time);
                $begin_day=$week -1;
                $end_day=7-$week;
                $begin_time=date("Y-m-d",strtotime("- $begin_day  day",$now_time));
                $end_time=date("Y-m-d 23:59:59",strtotime("+$end_day day",$now_time));
		$result = Db::table('gameaccount.score_changelog')->field('SUM(score_change) as count')->where([
			['userid','>','15000'],
			['change_time','>=',$begin_time],
			['change_time','<=',$end_time],
			['change_type','=',0],
			['score_change','>',0]
		])->find('count');
		return intval($result['count']);
	}

	
	public function getGongGaoCount(){
		return Db::connect('db_gameaccount')->table('server_log')->where('status','1')->count();		
	}
	public function getGongGaoInfo($id){
		if(empty($id)){ return false; }
		return Db::connect('db_gameaccount')->table('server_log')->where('id',$id)->find();
	}
	
	public function doAddGongGao($data){
		if(empty($data)){ return false; }
		if(empty($data['gonggao'])){ die('公告不能为空'); }
		if( strlen($data['gonggao']) > 200 ){ die('公告至多200个字符'); }
		
		$time = time();
		$arr = array(
			'txt' => $data['gonggao'],
			'status' => 1,
			'createtime' => $time,
			'updatetime' => $time
		);
		$res = Db::connect('db_gameaccount')->table('server_log')->insertGetId($arr);
		if($res){
			$rs = $this->sendgonggao();
			if($rs){
				return true;
			}
		}
		return false;
	}
	
	public function doEditGongGao($data){
		if(empty($data)){ return false; }
		if(empty($data['gonggao'])){ die('公告不能为空'); }
		if( strlen($data['gonggao']) > 200 ){ die('公告至多200个字符'); }
		if(empty($data['ggid'])){ die('公告ID有误'); }
		
		$time = time();
		$arr = array(
			'txt' => $data['gonggao'],
			'updatetime' => $time
		);
		$res = Db::connect('db_gameaccount')->table('server_log')->where('id',$data['ggid'])->update($arr);
		if($res){
			$rs = $this->sendgonggao();
			if($rs){
				return true;
			}
		}
		return false;
	}
	
	public function doGongGaoDel($data){
		if(empty($data)){ return false; }
		if(empty($data['id'])){ die('公告ID有误'); }
		$res = Db::connect('db_gameaccount')->table('server_log')->where('id',$data['id'])->delete();
		if($res){
			$rs = $this->sendgonggao();
			if($rs){
				return true;
			}
		}
		return false;
	}
	
	private function sendgonggao(){
		//return true;
		$act = "updateServerLog";
		$time = strtotime('now');
		$key = $this->key;
		
		$sign = $act.$time.$key;
		$md5sign = md5($sign);
		$url= $this->apiurl."/Activity/gameuse?act=".$act."&time=".$time."&sign=".$md5sign;
		//Log::write($url,'nxpc');
		$res = $this->_request($url);
		//Log::write($res,'nxpc');

		$res = json_decode($res,true);
		if(isset($res) && ($res['status'] == '0')){				
			return true;
		}else{
			return false;
		}
	}

	public function getBuYuPool(){
		//$fish = Db::table('fish.control_pool')->select();
		$arr = array();
		//foreach($fish as $v){
	        //		$arr[$v['serveId']] = $v;
	 	//}
		return $arr;
	}

	public function getBuYuPoolOne($port,$name){
		if(empty($port)){ return false; }
		$fishTable = $name.'.control_pool';
		$fish = Db::table($fishTable)->where('serveId',$port)->find();
		return $fish;
	}
	
	public function getBuYuChanceOne($port, $name) {
		if(empty($port)){ return false; }
		$fishTable = $name.'.catch_chance';
		$fish = Db::table($fishTable)->where('serveId',$port)->find();
		return $fish;
	}

	public function setbuyuline($data){
		if(empty($data)){ return false; }
		if(empty($data['line'])){ return false; }
		if(empty($data['id'])){ return false; }

		// 实时水位控制
		// $configs = ConfigModel::getSystemConfig();
        // $arr = array('port'=>$data['id'] ,'act'=>'updateGameData' , 'key' => $configs['GameServiceKey'] , 'dataKey' => 'line' , 'data' => $data['line']);
		// $url = $configs['GameServiceApi']."/gmManage";
        // $res = $this->_request($url,false,'post',json_encode($arr));

		// 修改数据库水位控制
		$fishTable = $data['name'].'.control_pool';
		$rs = Db::table($fishTable)->where('serveId',$data['id'])->data('line',$data['line'])->update();
		return $rs;
	}
	
	public function setbuyuchance($data) {
		if(empty($data)){ return false; }
		if(empty($data['chance'])){ return false; }
		if(empty($data['id'])){ return false; }

		$fishTable = $data['name'].'.catch_chance';
		$rs = Db::table($fishTable)->where('serveId',$data['id'])->data('chance',intval($data['chance'])/100)->update();
		return $rs;
	}

    public function setExpectRTP($data){
        if(empty($data)){ return false; }
        if(empty($data['expectRTP'])){ return false; }
        if(empty($data['game_id'])){ return false; }
        if(empty($data['id'])){ return false; }
        $game = Db::table('ym_manage.game')
            ->where('id',$data['id'])
            ->find();
        if($game) {
            Db::connect('db_laba')->table('gambling_game_list')->where('nGameID', $data['game_id'])->data('expectRTP', $data['expectRTP'])->update();
            $this->updateGameData($game['port'] , 'expectRTP' , $data['expectRTP']);
            return true;
        }
        return false;
    }

	public function setbuyupool($data){
		if(empty($data)){ return false; }
		if(empty($data['pool'])){ return false; }
		if(empty($data['id'])){ return false; }

		// 奖池实时控制
		// $configs = ConfigModel::getSystemConfig();
        // $arr = array('port'=>$data['id'] ,'act'=>'updateGameData' , 'key' => $configs['GameServiceKey'] , 'dataKey' => 'pool' , 'data' => $data['pool']);
		// $url = $configs['GameServiceApi']."/gmManage";
        // $res = $this->_request($url,false,'post',json_encode($arr));

		// 数据库奖池控制 
		$fishTable = $data['name'].'.control_pool';
		$rs = Db::table($fishTable)->where('serveId',$data['id'])->data('pool',$data['pool'])->update();
		return $rs;
	}

	public function getBuYuUser(){
		return Db::table('fish.control_user')->select();
	}

	public function doAddbuyuuser($data){
		$rs = Db::table('fish.control_user')->data($data)->insert();
		if($rs){
			$redis_ip = $this->getConfig('app.redis_ip');
			$redis_port = $this->getConfig('app.redis_port');
			$redis_auth = $this->getConfig('app.redis_auth');
			//发布订阅					
			$redis = new \Redis();
			$redis->connect($redis_ip, $redis_port);
			$redis->auth($redis_auth); 
			//type 1水位 3奖池 4用户
			$str = '{"uid":"'.$data['uid'].'","gameid":"0","serverId":"0","type":"4"}';
			//Log::write($str,'nxp');
			$rs = $redis->publish('EditLabaSet', $str);
			//Log::write($rs,'nxp');
			$redis->close();
		}
		return $rs;
	}

	public function checkbuyuuser($uid){
		return Db::table('fish.control_user')->where('uid',$uid)->find();
	}

	public function doEditbuyuuser($data){
		//sreturn json_encode($data);
		$rs = Db::table('fish.control_user')->where('uid', intval($data['uid']) )->data([ 'chance' => floatval($data['chance']) ])->update();
		if($rs){
			$redis_ip = $this->getConfig('app.redis_ip');
			$redis_port = $this->getConfig('app.redis_port');
			$redis_auth = $this->getConfig('app.redis_auth');
			//发布订阅					
			$redis = new \Redis();
			$redis->connect($redis_ip, $redis_port);
			$redis->auth($redis_auth); 
			//type 1水位 3奖池 4用户
			$str = '{"uid":"'.$data['uid'].'","gameid":"0","serverId":"0","type":"4"}';
			//Log::write($redis_ip.'-'.$redis_port.'-'.$redis_auth,'nxp');
			//Log::write($str,'nxp');
			$rs = $redis->publish('EditLabaSet', $str);
			//Log::write($rs,'nxp');
			$redis->close();
		}
		return $rs;
	}

	public function doDelbuyuuser($data){
		//return json_encode($data);
		$rs = Db::table('fish.control_user')->where('uid', intval($data['id']) )->delete();
		if($rs){
			$redis_ip = $this->getConfig('app.redis_ip');
			$redis_port = $this->getConfig('app.redis_port');
			$redis_auth = $this->getConfig('app.redis_auth');
			//发布订阅					
			$redis = new \Redis();
			$redis->connect($redis_ip, $redis_port);
			$redis->auth($redis_auth); 
			//type 1水位 3奖池 4用户
			$str = '{"uid":"'.$data['id'].'","gameid":"0","serverId":"0","type":"4"}';
			//Log::write($str,'nxp');
			$rs = $redis->publish('EditLabaSet', $str);
			//Log::write($rs,'nxp');
			$redis->close();
		}
		return $rs;
	}

	public function setNandu_qiangcow($data){
		if(empty($data)){ return false; }
		if(empty($data['lv'])){ return false; }
		if(empty($data['id'])){ return false; }
		
		$game = Db::table('ym_manage.game')
					->where('id',$data['id'])
					->find();
		if($game){
			$res = Db::table('ym_manage.game')
						->where('id', $game['id'])
						->data( 'nandulv' , $data['lv'] )						
						->update();

			if($res){
				Db::connect('db_laba')->name('la_ba.gambling_game_list')
						->where('nGameID', $game['port'])
						->data([ 'nGameType' => $data['lv'] ])
						->update();

				$redis_ip = $this->getConfig('app.redis_ip');
				$redis_port = $this->getConfig('app.redis_port');
				$redis_auth = $this->getConfig('app.redis_auth');
				//发布订阅					
				$redis = new \Redis();
				$redis->connect($redis_ip, $redis_port);
				$redis->auth($redis_auth); 
				$str = '{"nandu":"'.$data['lv'].'","gameid":"'.$game['gameid'].'","serverId":"'.$game['port'].'","type":"10"}';
				Log::write($str,'setNandu_qiangcow');
				$rs = $redis->publish('EditLabaSet', $str);
				Log::write($rs,'setNandu_qiangcow');
				$redis->close();
			}
			
			return true;
			
		}
		
		return false;
	}

    public function getPlayerControl(){
        return Db::table('gameaccount.usermoneyctrl')->select();
    }

    public function doAddPlayerControl($data){
        $rs = Db::table('gameaccount.usermoneyctrl')->data($data)->insert();
        return $rs;
    }

    public function checkPlayerControl($uid){
        return Db::table('gameaccount.usermoneyctrl')->where('userId',$uid)->find();
    }

    public function doEditPlayerControl($data){
        //return json_encode($data);
        $rs = Db::table('gameaccount.usermoneyctrl')->where('userId', intval($data['userId']) )->data([ 'coinCtrl' => floatval($data['coinCtrl']) ])->update();
        return $rs;
    }

    public function doDelPlayerControl($data){
        //return json_encode($data);
        $rs = Db::table('gameaccount.usermoneyctrl')->where('userId', intval($data['id']) )->delete();
        return $rs;
    }
	
	public function getAtt($page = 1, $limit = 10) {
		$rs = Db::table('game_attarc.roominfo')->order(['gameport' => 'asc', 'roomid' => 'asc'])->paginate($limit)->toArray();
		foreach ($rs['data'] as $k => $v) {
			$formatJson = json_decode($v['gameInfo'],true);
			foreach ($formatJson as $key => $val) {
				if($key == 'wroomState') {
					if ($val == 0) {
						$rs['data'][$k]['wroomStateFormat'] = '无人';
					}
					if ($val == 1) {
						$rs['data'][$k]['wroomStateFormat'] = '有人';
					}
					if ($val == 2) {
						$rs['data'][$k]['wroomStateFormat'] = '保留';
					}
				}
				$rs['data'][$k][$key] = $val;
			}
			// $rs['data'][$k]['formatJson'] = json_decode($v['gameInfo'],true);
		}
		return $rs;
	}
	
	
}
