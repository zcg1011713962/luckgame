<?php
namespace app\api\controller;
use app\api\controller\Init;
use app\api\controller\Curl;
use think\facade\Request;
use think\facade\Config;
use think\Db;
use think\cache\driver\Redis;
use app\api\model\BlockpayModel;
use app\api\model\GameModel;
use app\admin\model\ConfigModel;

class Blockpay extends Init {

    private $payScale;

	// 初始化支付/提现比例
	public function __construct() {
		$this->payScale = ConfigModel::getPayScale();
	}

    // 充值回调
    public function blockPayNotify() {

         /**
         * $params 
         *      ['hash'] => '用户地址'
         *      ['amount'] => '充值金额'
         *      ['user_email'] => '用户邮箱'
         *      ['pay_address'] => '充值地址'
         *      ['accept_address'] => '接受地址'
         */
        $params = json_decode(file_get_contents('php://input'),true);

        // 支付实例
        $BlockPayModel = new BlockpayModel;

        // 查询是否有此账户信息
        $users = $BlockPayModel->searchUser('email',$params['hash']);
        if (empty($users['Id'])) {
            // 未查到该用户
            return $this->returnError('User not found');
        }

        // 写入日志...
        $BlockPayModel->addPayLog($users['Id'], $params);

        // 调用服务端加金币 
        $gameModel = new GameModel;
        $result = $gameModel->insertScore($users['Account'], $params['amount'], '');
        return $this->returnSuccess($result);
    }

    // 充值记录查询
    public function searchPaymentLog() {
        $params = Request::param();
        $BlockPayModel = new BlockpayModel;
        $result = $BlockPayModel->searchPaymentLog($params['uid']);
        return $this->returnSuccess($result);
    }

    // 提现申请
    public function outCash() {

        $params = json_decode(file_get_contents('php://input'),true);
        $BlockPayModel = new BlockpayModel;
        // 查询是否有此账户信息
        $users = $BlockPayModel->searchUser('Account',$params['phone']);
        if (empty($users['Id'])) {
            // 未查到该用户
            return $this->returnError('User not found');
        }
        $data = [];
        $data['order_number'] = 'BLOCK_'.$users['Id'].time().str_pad(mt_rand(1, 99999999999), 10, '0', STR_PAD_LEFT);
        $data['user_id'] = $users['Id'];
        $data['bank_number'] = $params['address'];
        $data['money'] = $params['cncAmount'];
        $data['created_at'] = date('Y-m-d H:i:s');
        $data['bank_open']  = $params['cncAmount'] * $this->payScale['cash'];
        $data['status'] = 0;
        $result = $BlockPayModel->insertUserExchange($data);
        return $this->returnSuccess($result);

    }
}