<?php
namespace app\agent\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use app\admin\model\GameModel as AdminGameModel;
use app\agent\model\AdminModel;

class GameModel extends Model
{
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
	
	public function getList(){
		$info = Db::table('ym_manage.game')->order('port asc')->select();
		foreach($info as $k => $v){
			if($v['type'] == '2'){
				$slotset = Db::table('la_ba.gambling_game_list')->where('nGameID',$v['gameid'])->find();
				$info[$k]['slotset'] = serialize($slotset);
				if($slotset){
					$info[$k]['shuiwei'] = $slotset['nGamblingWaterLevelGold'];
					$info[$k]['kucun'] = $slotset['nGamblingBalanceGold'];
					$info[$k]['jiangchi'] = $slotset['nGamblingWinPool'];
				}
			}
		}
		return $info;
	}
	
	public function getCount(){
		return Db::table('ym_manage.game')->count();		
	}
	
	public function setStart($data){
		if(empty($data)){ return false; }
		if(empty($data['i'])){ return false; }
		if(!isset($data['t'])){ return false; }
		
		$game = Db::table('ym_manage.game')
					->where('id',$data['i'])
					->find();
		if($game){
			return Db::name('ym_manage.game')
						->where('id', $game['id'])
						->data([ 'isstart' => $data['t'] ])
						->update();
		}
		
		return false;
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
				$res = Db::name('la_ba.gambling_game_list')
							->where('nGameID', $game['gameid'])
							->data([ 'nGamblingWaterLevelGold' => $shuiwei ])
							->update();
				if($res){
					//发布订阅
					$url = '/redis_pub/editCSlv.php?gameid='.$game['gameid'].'&shuiwei='.$shuiwei;
					$this->_request($url);
				}
			}
			return Db::name('ym_manage.game')
						->where('id', $game['id'])
						->data([ 'choushuilv' => $data['lv'] ])
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
			
			$res = Db::name('la_ba.gambling_game_list')
						->where('nGameID', $game['gameid'])
						->data([ 'nGamblingBalanceGold' => $kucun ])
						->update();
			if($res){
				//发布订阅
				$url = '/redis_pub/editKucun.php?gameid='.$game['gameid'].'&kucun='.$kucun;
				$this->_request($url);
				return true;
			}
			
		}
		
		return false;
	}
	
	public function getOnlineNum($id){
		if(empty($id)){ return false; }
		$nums = Db::table('ym_manage.game_onlinenum')
					->where('gid',$id)
					->order('createtime desc')
					->limit(10)
					->select();
		
		$key = array();
		$value = array();
		foreach($nums as $k=>$v){
			$key[] = strval(date('m-d H:i:s',$v['createtime']));
			$value[] = $v['num'];
		}
		$key = array_reverse($key);
		$value = array_reverse($value);
		return array('key'=>$key,'value'=>implode(',',$value));
	}

	public function getOnlineNums() {
		
		// 获取当前代理ID
		$adminModel = new AdminModel;
		$admin = $adminModel->getAdminInfo();
		
		// 获取当前代理下级ID
		$user_ids = Db::table('gameaccount.newuseraccounts')->field('Id')->where('ChannelType',$admin['id'])->select();
		$user_list = [];
		foreach ($user_ids as $k => $v) {
			$user_list[$v['Id']] = ['Id' => $v['Id']];
		}
		
		// 通过 admin/Model/Game 获取在线人数
		$adminGameModel = new AdminGameModel;
		$result = $adminGameModel->getOnlineList();
		
		// 数据整理
		$gameId = [];
		$onLineNum = 0;
		foreach ($result as $k => $v) {
			// 机器人除外
			if ($v['_userId'] >= 15000) {
				// 只统计代理下级玩家
				if (!empty($user_list[$v['_userId']])) {
					// 统计玩家在线数量
					$onLineNum += 1;
					// 在线玩家追加数据
					$user_list[$v['_userId']]['GameId'] = $v['GameId'];
					$user_list[$v['_userId']]['gameName'] = '大厅';
					$user_list[$v['_userId']]['score'] = $v['_score'];
					$user_list[$v['_userId']]['account'] = $v['_account'];
					// 获取游戏名称
					if ($v['GameId'] > 0) {
						$gameId[$v['GameId']] = 1;
					}
				}
			}
		}
		
		foreach ($user_list as $k => $v) {
			if (empty($v['account'])) {
				unset($user_list[$k]);
			}
		}
		
		
		$gameList = $adminGameModel->getGameListPorts(array_keys($gameId));
		// 结果输出
		foreach ($gameList as $k => $v) {
			foreach ($user_list as $key => $val) {
				if ($v['port'] == $val['GameId']) {
					$user_list[$key]['gameName'] = $v['name'];
				}
			}
		}
		
		return ['count' => $onLineNum, 'user_list' => $user_list];
	}
	
}