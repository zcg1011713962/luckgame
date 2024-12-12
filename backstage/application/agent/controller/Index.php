<?php
namespace app\agent\controller;
use app\admin\model\OperateCountModel;
use app\agent\model\AgentStatisModel;
use think\Controller;
use app\agent\controller\Parents;
use app\agent\model\AdminModel;
use app\agent\model\UserModel;
use app\agent\model\GameModel;
use app\agent\model\MarkModel;
use think\Db;
use think\facade\Cookie;
use think\Loader;

class Index extends Parents
{
    public function index()
    {
		$model = new AdminModel;
		$admin = $model->getAdminInfo();
		$this->assign('username',$admin['username']);
		
		$ht_name = $model->getConfig('app.HT_NAME');
		$this->assign('ht_name',$ht_name);
        $agentFind = Db::table('ym_manage.agentinfo')->where(['aid' => $admin['id']])->find();
        $level = '';
        if ($agentFind){
            $level = $agentFind['level'];
        }
        $this->assign('agent_level' , $level);
        return $this->fetch();
    }
	
	public function welcome()
	{
		$model = new AdminModel;
		$admin = $model->getAdminInfo();
		$this->assign('agentinfo',$admin);

		$gameModel = new GameModel;
		$onlinecount = $gameModel->getOnlineNums();
		$this->assign('onlinecount',$onlinecount['count']);
		
		$detail = $model->getAgentDetail($admin['id']);
		$this->assign('agentdetail',$detail);
		
		//获取实际金币房卡数值
		$aid = $model->getAgId();
		$agentinfo = $model->getAgentDetail($aid);
		if(empty($agentinfo['uid'])){ $this->error('转出代理 未绑定UID'); }
		$user = new UserModel;
		$info = $user->getUserInfo($agentinfo['uid']);
		$realnumres = $info ? $model->getRealNum($info['Account']) : ['score' => 0 , 'diamond' => 0];
//		if(!$realnumres){
//			die('用户未找到');
//		}
		$realnum = [];
		$realnum['score'] = $realnumres ? $realnumres['score'] : 0;
		$realnum['diamond'] = $realnumres ? $realnumres['diamond'] : 0;
		$this->assign('realnum',$realnum);
		
		$agentid = $model->getAgId();//代理ID
		$url = $model->getConfig('app.SystemUrl').'/index/index/register?id='.$agentid;//进入游戏链接地址
		$name = 'agent_'.$agentid.'_new.png';//生成二维码文件名前缀
		$path = 'qrcode';// Public目录下文件夹名称
		$pic = $this->genQrcode($url,$name,$path);
		$this->assign('pic',$pic);
		$this->assign('url',$url);

		//getWebInfo
		$url = $_SERVER['SERVER_NAME'].''.url('api/testClientShow',['uid'=>$aid]);
		$clientShow = $this->_request($url,true);
		$clientShow = json_decode($clientShow, true);
		if($clientShow && $clientShow['status'] == '1'){
			$clientShow = $clientShow['data'];
			$this->assign('isShow',1);
			$this->assign('clientShow',$clientShow);
		}else{
			$this->assign('isShow',0);
		}

		// 获取当前代理ID全部税收总计
		$tax_total = MarkModel::countTax($agentid);
		$this->assign('tax_total',$tax_total['tax_total']);
		
	    return $this->fetch();
	}
	
	/**
	 * http://127.0.0.1/qr/123
	 * http://127.0.0.1/index.php/index/index/genQrcode/uid/123
	 */
	private function genQrcode($url,$name,$path)
	{
		if($url && $name && $path){
			
			$http_type = ((isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == 'on') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')) ? 'https://' : 'http://';
			//echo $http_type . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'];
			
			$filename = './'.$path.'/'.$name;
			
			Loader::autoload('QRcode');
			$QRcode = new \QRcode();
			$errorCorrectionLevel = 'H';//纠错级别：L、M、Q、H
			$matrixPointSize = 10;//二维码点的大小：1到10
			$QRcode::png($url, $filename, $errorCorrectionLevel, $matrixPointSize, 2);    
			//echo '<img src="/qrcode/'.basename($filename).'" />';  
			
			return $http_type . $_SERVER['HTTP_HOST'].'/'.$path.'/'.basename($filename);
		}
		
		return false;
	    
	}

    /**
     * 代理运营统计
     * @return void
     */
    public function operationStatis()
    {
        return $this->fetch();
    }

    /**
     * 运营统计数据
     * @return array
     */
    public function operationStatisInfo()
    {
        $params = request()->param();
        $begin_time = isset($params['begin_time']) && !empty($params['begin_time']) ? date('Y-m-d',strtotime($params['begin_time'])) : date('Y-m-d');
        $end_time = isset($params['end_time']) && !empty($params['end_time']) ? date('Y-m-d',strtotime($params['end_time'])) : date('Y-m-d');
        $operateCountModel = new AgentStatisModel();
        $result = $operateCountModel->getOperationStatisData($begin_time, $end_time);
        return ['code' => 0, 'data' => $result['data'], 'total' => count($result['data']), 'msg' => 'ok'];
    }
	
}
