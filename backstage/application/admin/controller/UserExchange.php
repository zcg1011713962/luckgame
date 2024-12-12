<?php
namespace app\admin\controller;
use app\admin\model\UserExchangeModel;
use app\admin\model\UserModel;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\api\model\UserModel as ApiUserModel;
use app\api\model\GameModel;
use app\api\utils\nutspayUtils;
use app\api\utils\wowpayUtils;
use app\admin\model\ConfigModel;

class UserExchange extends Parents
{
    private $payScale;
	// 初始化支付/提现比例
	public function initialize() {
		$this->payScale = ConfigModel::getPayScale();
	}

    public function lists($status = 0)
    {
        $user = new UserExchangeModel();
		$num = 20;//每页显示数
        $map = input('map' , []);
        if (is_numeric($status)){
            $map['status'] = $status;
        }
        if (!isset($_GET['page'])){
            session('exchange_search_param' , null);
        }
        if ($_POST){
            session('exchange_search_param' , $map);
        }else{
            $map = $map ? $map : session('exchange_search_param');
        }
        $res = $user->getExchangeLog($num , $map);
        $this->assign('list',$res['list']);
        $this->assign('page',$res['page']);
        $count = $user->getExchangeCount($map);
        $this->assign('count',$count);
        $this->assign('map',$map);
        $title = [
            0 => '兑换申请' , 1 => '兑换成功' , 2 => '兑换拒绝'
        ];
        $title = $title[$status];
        $this->assign('title' , $title);
        $this->assign('status',$status);

		return $this->fetch();
    }

    public function changeStatus(){
        $status = input('status');
        $id = input('id');
        if (!$id || !$status) die('缺少参数');
        $find = UserExchangeModel::where('id' , $id)->find();
        if (!$find) die('不存在的数据');
        if ($find['status'] == $status) die('页面过期，请刷新后重试');
        if ($status == 1){
            // print_r($find);die;
            // // 已同意
            // $this->saveStatus($id , $status);
            // echo 1;
            echo json_encode($this->exchangePayout($find, $id, $status));
        }
        if ($status == 2){
            // 已拒绝
            $user = new UserModel;
            $info = $user->getUserInfo($find['user_id']);
            $res = $user->insertScore($info['Account'],$find['money']);
            if ($res === true){
                $this->saveStatus($id , $status);
                echo json_encode(['status' => 0, 'message' => '拒绝成功', 'result' => '']);
            }else{
                $message = json_decode($res,true);
                echo json_encode(['status' => 1, 'message' => '拒绝失败：'.$message['msg'], 'result' => $res]);
            }
        }
    }

    protected function exchangePayout($info, $id, $status) {
        if ($info['pay_type'] == 'kppay') {
            $postData['merchantId'] = Config::get('fastpay.kppay.merchantId');
			$postData['channelId'] = 'QGB';
			$postData['amount'] = (floatval($info['money'])*100/100);
			$postData['orderNo'] = $info['order_number'];
			$postData['email'] = $info['email'];
			$postData['name'] = $info['real_name'];
			$postData['mobile'] = $info['phone'];
			$postData['payType'] = $info['bank_open'];
			$postData['cardNumber'] = '+'.$info['bank_number'];
		    $postData['notifyUrl'] = Config::get('fastpay.kppay.notifyUrl').'?act=payout';
            $postData['sign'] = strtoupper(wowpayUtils::sign(wowpayUtils::ASCII($postData),Config::get('fastpay.kppay.key')));
            $headers = array();
            $headers[]= 'Content-Type: '. 'application/json;charset=UTF-8';
            $res = json_decode(nutspayUtils::httpsPost(Config::get('fastpay.kppay.payout_gateway'),json_encode($postData),$headers),true);
            if ($res['code'] == 1) {
                $insert = array(
                    'uid' => $info['user_id'],
                    'fee' => $postData['amount'],
                    'type' => 99,
                    'osn' => $postData['orderNo'],
                    'createtime' => time(),
                    'paytime' => time(),
                    'status' => 0,
                    'payresmsg' => '',
                    'prepayresmsg' => json_encode($res),
                    'payendtime' => time(),
                    'payscale' => $this->payScale['payment']
                );
                $gameModel->savePayLog($insert);
                $this->saveStatus($id, $status);
                return ['status' => 0, 'message' => '提现成功', 'result' => ''];
            } else {
                return ['status' => 1, 'message' => '提现失败：'. $res['msg'], 'result' => $res];
            }
        }

        if ($info['pay_type'] == 'fastpay') {
            $postData['acc_code'] = $info['bank_open'];
            $postData['acc_name'] = $info['real_name'];
            $postData['acc_no'] = $info['bank_number'];
            $postData['currency'] = Config::get('fastpay.fastpay.currency');
            $postData['mer_no'] = Config::get('fastpay.fastpay.mer_no');
            $postData['method'] = 'fund.apply';
            $postData['order_amount'] = floatval($info['money'])*100/100;
            $postData['order_no'] = $info['order_number'];
            $postData['returnurl'] = Config::get('fastpay.fastpay.returnurl').'?act=payout';
            $postData['sign'] = wowpayUtils::signx(wowpayUtils::ASCII($postData),Config::get('fastpay.fastpay.key'));
            $headers = array();
            $headers[]= 'Content-Type: '. 'application/json;charset=UTF-8';
            $res = json_decode(nutspayUtils::httpsPost(Config::get('fastpay.fastpay.gateway'),json_encode($postData),$headers),true);
            if ($res['status'] == 'success' && $res['status_mes'] == 'success') {
                $insert = array(
                    'uid' => $info['user_id'],
                    'fee' => $postData['order_amount'],
                    'type' => 99,
                    'osn' => $postData['order_no'],
                    'createtime' => time(),
                    'paytime' => 0,
                    'status' => 0,
                    'payresmsg' => '',
                    'prepayresmsg' => json_encode($res),
                    'payendtime' => time(),
                    'payscale' => $this->payScale['cash']
                );
                $gameModel->savePayLog($insert);
                $this->saveStatus($id, $status);
                return ['status' => 0, 'message' => '提现成功', 'result' => ''];
            } else {
                return ['status' => 1, 'message' => '提现失败：'.$res['status_mes'], 'result' => $res];
            }
        }
    }

    protected function saveStatus($id , $status){
        $adminid = Cookie::get('admin_user_id');
        UserExchangeModel::where('id' , $id)->update([
            'status' => $status ,
            'created_uid' => $adminid ,
            'updated_at' => date('Y-m-d H:i:s') ,
        ]);
    }

    public function config(){
        $find = Db::table('ym_manage.config')->where('flag' , 'EXCHANGE_MIN_MONEY')->find();
        $this->assign('find' , $find);
        return $this->fetch();
    }

    public function saveConfig(){
        $minMoney = input('min_money');
        $find = Db::table('ym_manage.config')->where('flag' , 'EXCHANGE_MIN_MONEY')->find();
        if ($find){
            Db::table('ym_manage.config')->where('id' , $find['id'])->update([
                'value' => $minMoney
            ]);
        }else{
            Db::table('ym_manage.config')->insert([
                'name' => '最低兑换金额' ,
                'flag' => 'EXCHANGE_MIN_MONEY' ,
                'value' => $minMoney
            ]);
        }
        echo 1;
    }
}
