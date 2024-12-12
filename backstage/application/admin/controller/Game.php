<?php
namespace app\admin\controller;
use think\Controller;
use think\Db;
use think\facade\Request;
use app\admin\controller\Parents;
use app\admin\model\GameModel;
use app\admin\model\ConfigModel;
use app\admin\validate\gameValidate;

class Game extends Parents
{
	// 添加游戏
	public function saveGame() {
		$params = request()->post();
		$validate = new gameValidate;
		if (!$validate->scene('add')->check($params)) {
			return $this->_error($validate->getError());
        }
		$game = new GameModel;
		$result = $game->saveGame($params);
		if (!empty($result)) {
			return $this->_error($result);
		}
		return $this->_success('','添加游戏成功');
	}

	// 删除游戏
	public function deleteGame() {
		$params = request()->post();
		$validate = new gameValidate;
		if (!$validate->scene('deleteAndEdit')->check($params)) {
			return $this->_error($validate->getError());
		}
		$game = new GameModel;
		$game->deleteGame($params['gameId']);
		return $this->_success('','删除游戏成功');
	}

	// 编辑游戏
	public function editGame() {
		$params = request()->get();
		$validate = new gameValidate;
		if (!$validate->scene('deleteAndEdit')->check($params)) {
			return $this->_error($validate->getError());
		}
		$game = new GameModel;
		$gameInfo = $game->editGame($params['gameId']);

		$this->assign('gameInfo',$gameInfo);
		return $this->fetch();
	}

	// 编辑游戏确认
	public function editGameaffirm() {
		$params = request()->post();
		$validate = new gameValidate;
		if (!$validate->scene('edit')->check($params)) {
			return $this->_error($validate->getError());
        }
		$game = new GameModel;
		$result = $game->editGameaffirm($params);
		if (!empty($result)) {
			return $this->_error($result);
		}
		return $this->_success('','修改游戏成功');
	}
	
	public function addGame() {
		return $this->fetch();
	}

    public function lists()
    {
		$params = request()->get();
		$params['gameCategoryId'] = isset($params['gameCategoryId']) ? intval($params['gameCategoryId']) : 0;
		$params['keyWord'] = isset($params['keyWord']) ? $params['keyWord'] : '';
		$game = new GameModel;
		$list = $game->getList($params);
		//print_r($list);die;
		$this->assign('list',$list);
		
		$count = $game->getCount($params);
		$this->assign('count',$count);

		//$fish = $game->getBuYuPool();
		//$this->assign('fish',$fish);

		$this->assign('gameCategoryId',$params['gameCategoryId']);
		$this->assign('keyWord',$params['keyWord']);

        return $this->fetch();
    }
	
	public function doStart(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['i'])){ die('用户参数有误'); }
		if(!isset($data['t'])){ die('封禁参数有误'); }
		
		$user = new GameModel;
		$res = $user->setStart($data);
		if($res){
			echo 'success';
		}else{
			echo '修改密码失败';
		}		
	}

	public function closeAllGame(){
		$user = new GameModel;
		$user->closeGame();
		echo '已执行';
	}
		
	public function editchoushuilv(){
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Game\editchoushuilv'); }
				
		$game = new GameModel;
		$info = $game->getInfo($id);
		$this->assign('info',$info);
		
		return $this->fetch();			
	}

	public function doEditCSlv(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['lv']) || empty($data['id'])){ die('参数有误'); }
		
		$game = new GameModel;
		$res = $game->setCSlv($data);
		if($res){
			echo 'success';
		}else{
			echo '修改失败';
		}
	}

	public function editnandu(){
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Game\editnandu'); }
				
		$game = new GameModel;
		$info = $game->getInfo($id);
		$this->assign('info',$info);
		
		return $this->fetch();			
	}
	
	public function doEditNandu(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['lv']) || empty($data['id'])){ die('参数有误'); }
		
		$game = new GameModel;
		$res = $game->setNandu($data);
		if($res){
			echo 'success';
		}else{
			echo '修改失败';
		}
	}
	
	public function editkucun(){
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Game\editkucun'); }
				
		$game = new GameModel;
		$info = $game->getInfo($id);
		$this->assign('info',$info);
		
		return $this->fetch();			
	}
	
	public function doEditKucun(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['kucun']) || empty($data['id'])){ die('参数有误'); }
		
		$game = new GameModel;
		$res = $game->setKucun($data);
		if($res){
			echo 'success';
		}else{
			echo '修改库存失败';
		}
	}
	
	public function editpool(){
		$id = request()->param('id');
		$game_id = request()->param('game_id');
		$server_id = request()->param('server_id');
		if(empty($id)){ $this->error('参数有误','admin\Game\editpool'); }
				
		$game = new GameModel;
		$info = $game->getInfo($id);
		$this->assign('info',$info);
		$this->assign('game_id',$game_id);
		$this->assign('server_id',$server_id);
		
		return $this->fetch();			
	}
	
	public function doEditPool(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['id'])){ die('参数有误'); }
		
		$game = new GameModel;
		$res = $game->setJiangchi($data);
		if($res){
			echo 'success';
		}else{
			echo '修改奖池失败';
		}
	}
	
	public function onlinenum()
	{
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Game\onlinenum'); }
		
		$game = new GameModel;
		$info = $game->getInfo($id);
		$this->assign('info',$info);
		
		$onlineInfo = $game->getOnlineNum($id);
		
		// $key = '';
		// foreach($nums['key'] as $v){
		// 	$key .= "'".$v."',";
		// }
		// $key = trim($key,',');
		// $this->assign('key',$key);
		
		// $value = $nums['value'];		
		// $this->assign('value',$value);

		$this->assign('onlineInfo',$onlineInfo);
	    return $this->fetch();
	}
	
	
	public function gonggao()
	{
		$game = new GameModel;
		
		$list = $game->getGongGaoList();
		$this->assign('list',$list);
		
		$count = $game->getGongGaoCount();
		$this->assign('count',$count);
	
	    return $this->fetch();
	}
	public function addGongGao()
	{
	    return $this->fetch('addgonggao');
	}
	
	public function doAddGongGao(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['gonggao'])){ die('公告不能为空'); }
		if( strlen($data['gonggao']) > 200 ){ die('公告至多200个字符'); }
		
		$user = new GameModel;
		$res = $user->doAddGongGao($data);
		if($res){
			echo 'success';
		}else{
			echo '新增公告失败';
		}		
	}
	public function editGongGao()
	{
		$id = Request::param('id');		
		if(empty($id)){ die('参数有误'); }
		
		$user = new GameModel;
		$info = $user->getGongGaoInfo($id);
		$this->assign('info',$info);
		
	    return $this->fetch('editgonggao');
	}
	public function doEditGongGao(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['gonggao'])){ die('公告不能为空'); }
		if( strlen($data['gonggao']) > 200 ){ die('公告至多200个字符'); }
		if(empty($data['ggid'])){ die('公告ID有误'); }
		
		$user = new GameModel;
		$res = $user->doEditGongGao($data);
		if($res){
			echo 'success';
		}else{
			echo '公告修改失败';
		}		
	}
	
	public function doGongGaoDel(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		if(empty($data['id'])){ die('参数有误'); }
		
		$user = new GameModel;
		$res = $user->doGongGaoDel($data);
		if($res){
			echo 'success';
		}else{
			echo '公告删除失败';
		}		
	}

	public function txts()
    {
		$config = new ConfigModel;

		$txt1 = request()->has('txt1','post');
		if($txt1){
			$content = request()->post('txt1');
			$config->setConfig('MANAGER_WECHAT_NUMBER',$content);
		}

		$txt1 = $config->getConfig('MANAGER_WECHAT_NUMBER');
		$this->assign('txt1',$txt1);

        return $this->fetch();
	}

    public function expectrtp(){
        $id = request()->param('id');
        if(empty($id)){ $this->error('参数有误'); }

        $info = Db::table('ym_manage.game')->findOrFail($id);
        $slotset = Db::connect('db_laba')->table('gambling_game_list')->where('nGameID',$info['gameid'])->find();
        $info['expectRTP'] = $slotset['expectRTP'];
        $this->assign('info',$info);

        return $this->fetch();
    }

    public function doEditExpectRTP(){
        $data = request()->post();
        if(empty($data)){ die('参数有误'); }

        if(empty($data['expectRTP'])){ die('参数有误'); }
        if(empty($data['game_id'])){ die('参数有误'); }
        $game = new GameModel;
        $res = $game->setExpectRTP($data);
        if($res){
            echo 'success';
        }else{
            echo '修改失败';
        }
    }
	
	public function editbuyuline(){
		$port = request()->param('port');
		$name = request()->param('name');
		if(empty($port)){ $this->error('参数有误'); }
				
		$game = new GameModel;
		$info = $game->getBuYuPoolOne($port,$name);
		$this->assign('info',$info);
		$this->assign('name',$name);
		
		return $this->fetch();			
	}

	public function doEditbuyuline(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['line'])){ die('参数有误'); }
		if(empty($data['id'])){ die('参数有误'); }
		
		$game = new GameModel;
		$res = $game->setbuyuline($data);
		if($res){
			echo 'success';
		}else{
			echo '修改失败';
		}
	}

	public function editbuyupool(){
		$port = request()->param('port');
		$name = request()->param('name');
		if(empty($port)){ $this->error('参数有误'); }
				
		$game = new GameModel;
		$info = $game->getBuYuPoolOne($port,$name);
		$this->assign('info',$info);
		$this->assign('name',$name);
		
		return $this->fetch();			
	}

	public function doEditbuyupool(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['pool'])){ die('参数有误'); }
		if(empty($data['id'])){ die('参数有误'); }
		
		$game = new GameModel;
		$res = $game->setbuyupool($data);
		if($res){
			echo 'success';
		}else{
			echo '修改失败';
		}
	}
	
	public function editbuyuchance() {

		$port = request()->param('port');
		$name = request()->param('name');

		if(empty($port)){ $this->error('参数有误'); }
		$game = new GameModel;
		$info = $game->getBuYuChanceOne($port,$name);
		$this->assign('info',$info);
		$this->assign('name',$name);
		
		return $this->fetch();
	}

	public function doEditbuyuchance() {
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['chance'])){ die('参数有误'); }
		if(empty($data['id'])){ die('参数有误'); }
		
		$game = new GameModel;
		$res = $game->setbuyuchance($data);
		if($res){
			echo 'success';
		}else{
			echo '修改失败';
		}
	}

	public function buyuuser()
    {
		$game = new GameModel;
		
		$list = $game->getBuYuUser();
		$this->assign('list',$list);

        return $this->fetch();
	}
	
	public function addbuyuuser(){		
		return $this->fetch();			
	}

	public function doAddbuyuuser(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['uid'])){ die('参数有误'); }
		if(empty($data['chance'])){ die('参数有误'); }
		
		$game = new GameModel;
		$check = $game->checkbuyuuser($data['uid']);
		if($check){ echo '用户已设置';die; }

		$res = $game->doAddbuyuuser($data);
		if($res){
			echo 'success';
		}else{
			echo '新增失败';
		}
	}

	public function editbuyuuser(){
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误'); }
				
		$game = new GameModel;
		$info = $game->checkbuyuuser($id);
		$this->assign('info',$info);
		
		return $this->fetch();			
	}

	public function doEditbuyuuser(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['uid'])){ die('参数有误'); }
		if(empty($data['chance'])){ die('参数有误'); }

		$game = new GameModel;
		$res = $game->doEditbuyuuser($data);
		if($res){
			echo 'success';
		}else{
			echo '修改失败';
		}
	}

	public function doDelbuyuuser(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		if(empty($data['id'])){ die('参数有误'); }
		
		$user = new GameModel;
		$res = $user->doDelbuyuuser($data);
		if($res){
			echo 'success';
		}else{
			echo '删除失败';
		}		
	}
	
	public function editnandu_qiangcow(){
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误'); }
				
		$game = new GameModel;
		$info = $game->getInfo($id);
		$this->assign('info',$info);
		
		return $this->fetch();			
	}
	
	public function doEditNandu_qiangcow(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['lv']) || empty($data['id'])){ die('参数有误'); }
		
		$game = new GameModel;
		$res = $game->setNandu_qiangcow($data);
		if($res){
			echo 'success';
		}else{
			echo '修改失败';
		}
	}


    public function playerControl()
    {
        $game = new GameModel;

        $list = $game->getPlayerControl();
        $this->assign('list',$list);

        return $this->fetch();
    }

    public function addPlayerControl(){
        return $this->fetch();
    }

    public function doAddPlayerControl(){
        $data = request()->post();
        if(empty($data)){ die('参数有误'); }

        if(empty($data['userId'])){ die('参数有误'); }
        if(empty($data['coinCtrl'])){ die('参数有误'); }

        $game = new GameModel;
        $check = $game->checkPlayerControl($data['userId']);
        if($check){ echo '用户已设置';die; }

        $res = $game->doAddPlayerControl($data);
        if($res){
            echo 'success';
        }else{
            echo '新增失败';
        }
    }

    public function editPlayerControl(){
        $id = request()->param('id');
        if(empty($id)){ $this->error('参数有误'); }

        $game = new GameModel;
        $info = $game->checkPlayerControl($id);
        $this->assign('info',$info);

        return $this->fetch();
    }

    public function doEditPlayerControl(){
        $data = request()->post();
        if(empty($data)){ die('参数有误'); }

        if(empty($data['userId'])){ die('参数有误'); }
        if(empty($data['coinCtrl'])){ die('参数有误'); }

        $game = new GameModel;
        $res = $game->doEditPlayerControl($data);
        if($res){
            echo 'success';
        }else{
            echo '修改失败';
        }
    }

    public function doDelPlayerControl(){
        $data = request()->post();
        if(empty($data)){ die('参数有误'); }
        if(empty($data['id'])){ die('参数有误'); }

        $user = new GameModel;
        $res = $user->doDelPlayerControl($data);
        if($res){
            echo 'success';
        }else{
            echo '删除失败';
        }
    }
	
	public function att() {
		return $this->fetch();
	}

	public function ApiAtt() {
		$limit = request()->param('limit');
		$page  = request()->param('page');
		$game = new GameModel;
		$list = $game->getAtt($page, $limit);
		return ['code' => 0, 'count' => $list['total'], 'data' => $list['data'], 'msg' => 'ok'];
	}

	public function editAtt() {
		$params = request()->param();
		$configs = ConfigModel::getSystemConfig();
        $arr = array('id' => $params['id'] ,'port'=>$params['gameport'], 'roomid' => $params['roomid'] ,'act'=>'updateGameData' , 'key' => $configs['GameServiceKey'] , 'dataKey' => $params['key'] , 'data' => $params['value']);
		$url = $configs['GameServiceApi']."/gmManage";
        $res = $this->__request($url,false,'post',json_encode($arr));
		return $this->_success();
	}

	private function __request($url, $https=false, $method='get', $data=null)
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
}
