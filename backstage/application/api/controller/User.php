<?php
namespace app\api\controller;
use app\admin\model\UserExchangeModel;
use app\api\controller\Init;
use app\api\controller\Curl;
use think\Db;
use think\facade\Cache;
use think\Loader;
use think\Request;
use app\admin\model\UserModel;
use app\api\model\EncnumModel;

class User extends Init
{			
	/**
	 * ID转token
	 */
	public function id2token(){
		//初始化
		$this->init();
	
		$post = input('post.data');
		$ret = json_decode($post,true);		
		if(empty($ret)){
			return $this->returnError('Post Empty');
		}
		
		//验证 sign
		$sign = $this->makeSignature($ret);
		if( $this->isencrypt && ($ret['sign'] != $sign) ){
			return $this->returnError('Sign check fail');
		}
		
		//验证 uid 		
		$uid = $ret['uid'];
		if(empty($uid)){
			return $this->returnError('uid Empty');
		}
		
		//验证 to
		$to = $ret['to'];
		if(empty($to) || !in_array($to,[2,3,4,5]) ){
			return $this->returnError('to Error');
		}
		
		$user = new UserModel;
		$token = $user->UserInit($uid,$to);
		if(empty($token)){
			return $this->returnError('User not found');
		}
				
		return $this->returnSuccess($token);
	}
	
	/**
	 * 登录 获取用户信息
	 * 登录后 更新token
	 */
	public function userinfo(){
		//初始化
		$this->init();
	
		$post = input('post.data');
		$ret = json_decode($post,true);		
		if(empty($ret)){
			return $this->returnError('Post Empty');
		}
		
		//验证 token
		$token = $ret['token'];
		if(empty($token)){
			return $this->returnError('token Empty');
		}
		
		//验证 sign
		$sign = $this->makeSignature($ret);
		if( $this->isencrypt && ($ret['sign'] != $sign) ){
			return $this->returnError('Sign check fail');
		}
		
		$user = new UserModel;
		$check = $user->checkUser($token,'token');
		if(!$check){
			return $this->returnError('token Error');
		}
		
		$info = $user->getUser($token,'token');
		if(isset($info['id']) && $info['id']){
			//更新token
			$rs = $user->editUser('id',$info['id'],'token','');
			if($rs){
				return $this->returnSuccess($info);
			}else{
				return $this->returnError('Login Token Fail');
			}
		}
		
		return $this->returnError('Login Fail');		
	}
	
	/**
	 * 转移金币
	 */
	public function turnScore()
	{
		//初始化
		$this->init();
	
		$post = input('post.data');
		$ret = json_decode($post,true);
		if(empty($ret)){
			return $this->returnError('Post Empty');
		}
		
		//验证 sign
		$sign = $this->makeSignature($ret);
		if( $this->isencrypt && ($ret['sign'] != $sign) ){
			return $this->returnError('Sign check fail');
		}
		
		//验证 fromtype
		$fromtype = $ret['fromtype'];
		if(empty($fromtype)){
			return $this->returnError('fromtype Empty');
		}
		$obj = new EncnumModel(8);
		$check_fromtype = $obj->decode($fromtype);
		if(!in_array($check_fromtype,[2,3,4,5])){
			return $this->returnError('fromtype Error');
		}
		
		$user = new UserModel;
		
		//验证 id
		$id = $ret['id'];
		if(empty($id)){
			return $this->returnError('id Empty');
		}
		$check = $user->checkUser($id,'id');
		if(empty($check)){
			return $this->returnError('User not found');
		}
		$userinfo = $user->getUser($id,'id');
		if($userinfo['fromtype'] != $check_fromtype){
			return $this->returnError('User From Type Error');
		}
		
		//验证 num
		$num = intval($ret['num']);
		if(empty($num)){
			return $this->returnError('num Empty');
		}
		
		$rs = $user->turnScore($id,$num,$fromtype);
		if($rs){
			return $this->returnSuccess('success');
		}else{
			return $this->returnError('error');
		}
		
	}

    /**
     * 兑换
     * @return void
     * @author: Colin<amcolin@126.com>
     * @datetime: 2022/11/9 10:15
     */
    public function exchange(){
        //初始化
        $this->init();
        $ret = input();
        if(empty($ret)){
            return $this->returnError('Post Empty');
        }
        // {"bank_number":"test","name":"test name","open":"test open","money":"100","id":1}
        $number = isset($ret['bank_number']) ? $ret['bank_number'] : '';
        $name = isset($ret['name']) ? $ret['name'] : '';
        $open = isset($ret['open']) ? $ret['open'] : '';
        $money = isset($ret['money']) ? $ret['money'] : '';
        if (!$number) return $this->returnError('number is null');
        if (!$name) return $this->returnError('name is null');
        if (!$open) return $this->returnError('open is null');
        if (!$money) return $this->returnError('money is null');
        //验证 id
        $id = $ret['id'];
        if(empty($id)){
            return $this->returnError('id Empty');
        }
        $find = Db::table('ym_manage.config')->where('flag' , 'EXCHANGE_MIN_MONEY')->find();
        if (!$find) return $this->returnError('not found config');
        if ($money < $find['value']) return $this->returnError('不满足最低金额要求');
        // 写入数据
        Db::table('ym_manage.user_exchange')->insert([
            'user_id' => $id ,
            'order_number' => date('YmdHis') . time() . mt_rand(1000,9999) ,
            'bank_number' => $number ,
            'real_name' => $name ,
            'bank_open' => $open ,
            'money' => $money ,
            'status' => 0 ,
            'created_at' => date('Y-m-d H:i:s') ,
        ]);
        return $this->returnSuccess('success');
    }

    /**
     * 兑换
     * @return void
     * @author: Colin<amcolin@126.com>
     * @datetime: 2022/11/9 10:15
     */
    public function cdKey(){
        //初始化
        $this->init();
        $ret = input();
        if(empty($ret)){
            return $this->returnError('Post Empty');
        }
        // {"bank_number":"test","name":"test name","open":"test open","money":"100","id":1}
        $code = isset($ret['code']) ? $ret['code'] : '';
        if (!$code) return $this->returnError('code is null');
        //验证 id
        $id = $ret['id'];
        if(empty($id)){
            return $this->returnError('id Empty');
        }
        $userFind = Db::table('gameaccount.newuseraccounts')->where(['Id' => $id])->find();
        if (!$userFind){
            return $this->returnError('用户不存在');
        }
//        $find = Db::table('ym_manage.config')->where('flag' , 'EXCHANGE_MIN_MONEY')->find();
//        if (!$find) return $this->returnError('not found config');
//        if ($money < $find['value']) return $this->returnError('不满足最低金额要求');
        Db::startTrans();
        $refMoney = '100000';
        // 检查号码是否存在
        $find = Db::table('ym_manage.cdkey')->where(['number' => $code])->lock(true)->find();
        if (!$find){
            Db::rollback();
            return $this->returnError('兑换码不存在');
        }
        if ($find['status'] == 1){
            Db::rollback();
            return $this->returnError('兑换码已使用');
        }
        $change = Db::table('ym_manage.cdkey')->where(['id' => $find['id']])->data([
            'status' => 1 ,
            'use_id' => $id ,
        ])->update();
        if (!$change){
            Db::rollback();
            return $this->returnError('使用失败');
        }
        $userModel = new UserModel();
        $status = $userModel->insertScore($userFind['Account'] , $refMoney);
        if (!$status){
            Db::rollback();
            return $this->returnError('使用兑换码失败');
        }
        Db::commit();
        return $this->returnSuccess('success');
    }

    protected function getHost(){
        $http_type = ((isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == 'on') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')) ? 'https://' : 'http://';
        //echo $http_type . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'];
        $url = $http_type . $_SERVER['HTTP_HOST'];
        return $url;
    }

    /**
     * http://ht.com/qr/123
     * http://ht.com/index.php/index/index/genQrcode/uid/123
     */
    public function genQrcode($uid = '' , &$url = '')
    {
        if($uid){
            $host = self::getHost();
            $url = $host .'/index/index/register?id='.$uid;
            $filename = './qrcode/extend_'.$uid.'.png';

            Loader::autoload('QRcode');
            $QRcode = new \QRcode();
            $errorCorrectionLevel = 'H';//纠错级别：L、M、Q、H
            $matrixPointSize = 10;//二维码点的大小：1到10
            $QRcode::png($url, $filename, $errorCorrectionLevel, $matrixPointSize, 2);
            //echo '<img src="/qrcode/'.basename($filename).'" />';

            return $host.'/qrcode/'.basename($filename);
        }else{
            return 'uid not found';
        }
    }

    /**
     * 我的推广
     * @author: Colin<amcolin@126.com>
     * @datetime: 2023/2/15 13:57
     */
    public function extension(){
        list($id , $ret , $userFind) = $this->getUserInfo();
        $path = $this->genQrcode($id , $url);
        // 直属人员
        $directlyCount = Db::table('ym_manage.account_invites')->where([
            'invite_uid' => $id ,
        ])->count();
        $totalProfit = Db::table('ym_manage.account_invite_sends')->where([
            'uid' => $id ,
        ])->sum('gold');
        $data = [
            'id' => $id ,
            'url' => $url ,
            'qrcode' => $path ,
            'directly_number' => $directlyCount ?: 0 ,
            'total_profit' => $totalProfit ?: 0 ,
        ];
        return $this->returnSuccess($data);
    }

    /**
     * 推广统计页面
     * @return false|string
     * @author: Colin<amcolin@126.com>
     * @datetime: 2023/2/15 14:25
     */
    public function extensionStat(){
        list($id , $ret , $userFind) = $this->getUserInfo();
        // 直属人员
        $directlyCount = Db::table('ym_manage.account_invites')->where([
            'invite_uid' => $id ,
        ])->count();
        $availableCount = Db::table('ym_manage.account_invites')->where([
            'invite_uid' => $id ,
        ])->count();
        $totalProfit = Db::table('ym_manage.account_invite_sends')->where([
            'uid' => $id ,
            'status' => 0 ,
        ])->sum('gold');
        return $this->returnSuccess([
            'available' => $availableCount ?: 0 ,
            'directly_number' => $directlyCount ?: 0 ,
            'second_number' => 0 , // 二级
            'total_profit' => $totalProfit ?: 0 ,
        ]);
    }

    /**
     * 推广奖励领取
     * @author: Colin<amcolin@126.com>
     * @datetime: 2023/2/15 14:27
     */
    public function extensionReward(){
        list($id , $ret , $userFind) = $this->getUserInfo();
        $cacheName = 'reward_' . $id;
        $cacheValue = Cache::get($cacheName);
        $maxExpire = 5;
        if ($cacheValue){
            return $this->returnError('请过5秒后试试');
        }
        Cache::set($cacheName , 1 , $maxExpire);
        $list = Db::table('ym_manage.account_invite_sends')->where([
            'uid' => $id ,
            'status' => 0 ,
        ])->select();
        foreach ($list as $val){
            // 更新成处理中
            $map = ['id' => $val['id']];
            $data = ['updated_at' => date('Y-m-d H:i:s')];
            $data['status'] = 1;
            Db::table('ym_manage.account_invite_sends')->where($map)->update($data);
            $account = Db::table('gameaccount.newuseraccounts')->where($map)->find();
            if ($account){
                // 处理
                $userModel = new UserModel();
                $status = $userModel->insertScore($account['Account'] , $val['number']);
                if ($status){
                    // 处理成功
                    $data['status'] = 2;
                }else{
                    // 失败
                    $data['status'] = 3;
                }
            }else{
                // 失败
                $data['status'] = 3;
            }
            Db::table('ym_manage.account_invite_sends')->where('id' , $val['id'])->update($data);
        }
        return $this->returnSuccess('领取成功');
    }

    protected function getUserInfo(){
        $this->init();
        $ret = input();
        if(empty($ret)){
            return $this->returnError('Post Empty');
        }
        // {"bank_number":"test","name":"test name","open":"test open","money":"100","id":1}
        $id = $ret['id'];
        if(empty($id)){
            return $this->returnError('id Empty');
        }
        $userFind = Db::table('gameaccount.newuseraccounts')->where(['Id' => $id])->find();
        if (!$userFind){
            return $this->returnError('用户不存在');
        }
        return [$id , $ret , $userFind];
    }
	
}
