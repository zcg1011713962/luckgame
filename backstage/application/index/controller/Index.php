<?php
namespace app\index\controller;
use think\Controller;
use think\Db;
use think\facade\Log;
use think\Loader;
use UCloud\Core\Logger\DisabledLogger;
use UCloud\USMS\USMSClient;
use UCloud\USMS\Apis\SendUSMSMessageRequest;
use UCloud\Core\Exception\UCloudException;
use app\admin\model\ConfigModel;
use think\facade\Cache;

class Index extends Controller
{

    private $config;

	public function __construct() {
        parent::__construct();
		$this->config = ConfigModel::getSystemConfig();
	}

    public $gameConfig = [
        ['number' => 3 , 'gold' => 30] ,
        ['number' => 6 , 'gold' => 60] ,
        ['number' => 10 , 'gold' => 100] ,
        ['number' => 20 , 'gold' => 200] ,
        ['number' => 30 , 'gold' => 300] ,
        ['number' => 50 , 'gold' => 500] ,
        ['number' => 80 , 'gold' => 800] ,
    ];

    public $quArray = [55];

    public function index()
    {
        //echo url('index/hello');
		return $this->fetch();
	}
	
	/**
	 * /index.php/index/index/hello.html
	 */
    public function hello($name = '111111')
    {
        return 'hello,' . $name;
    }

    protected function getHost(){
        $http_type = ((isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == 'on') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')) ? 'https://' : 'http://';
        //echo $http_type . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'];
        $url = $http_type . $_SERVER['HTTP_HOST'];
        return $url;
    }
	
	public function genQrcode($uid = '')
	{
		if($uid){
            $host = self::getHost();
			$url = $host .'?uid='.$uid;
			$filename = './qrcode/test_'.$uid.'.png';
			
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

    public function register(){
        $quArray = $this->quArray;
        if ($this->request->isPost()){
            $type =  $this->request->post('type' , 'mobile');
            $isMobile = $type == 'mobile';
            $isAccount = $type == 'account';
            $parentId = $this->request->get('id');
            $qu = $this->request->post('qu');
            $mobile = $this->request->post('mobile');
            $verify = $this->request->post('verify');
            $account_verify = $this->request->post('account_verify');
            $password = $this->request->post('password');
            $confirmPass = $this->request->post('confirm_password');
            $account = $this->request->post('account');
            if ($isMobile && !$mobile){
                $this->error('手机号不能为空');
            }
            if (!$password) {
                $this->error('密码不能为空');
            }
            if ($isAccount && !$account_verify){
                $this->error('验证码不能为空');
            }
            /*if ($isMobile && !$verify){
                $this->error('验证码不能为空');
            }*/
            if ($isAccount && $password != $confirmPass){
                $this->error('两次输入不一致');
            }
            if ($isAccount){
                if (mb_strlen($account , 'utf8') > 16){
                    $this->error('账号16字符以下');
                }
                if (!(preg_match('/[0-9]+[a-zA-Z]+/' , $account) || preg_match('/[a-zA-Z]+[0-9]+/' , $account))){
                    $this->error('账号必须字母+数字组合');
                }
            }
            /*if (
                ($isMobile && $verify != session('regcode')) ||
                ($isAccount && !captcha_check($account_verify))
            ){
                $this->error('验证码不正确');
            }*/
			if ($isMobile && !in_array($qu, $quArray)) {
				$this->error('区号不正确');
			}
            if ($isMobile){
                $account = $mobile;
                $nickname = preg_replace('/^(\d{3})\d+(\d{4})$/' , '$1xxxx$2' , $account);
            }
            if ($isAccount){
                $nickname = $account;
            }
            $time = time();
            $createdUid = $parentId;
            $sign = 'register' . $account . $password . $time . $this->config['PrivateKey'];
            $sign = md5($sign);
            $url = $this->config['GameServiceApi'] ."/ml_api?act=register&accountname=" . $account . "&nickname=" . $nickname . "&pwd=" . $password . "&time=" . $time . "&agc=" . $createdUid . "&sign=" . $sign;
            $res = _request($url , false , 'get' , null , 2);
            $res = json_decode($res , true);
            if ($res){
                if ($res['status'] != 0){
                    $this->error($res['msg']);
                }
                $currentId = $res['userid'];
                Db::startTrans();
                if ($parentId > 0){
                    $find = Db::table('ym_manage.account_invites')->where([
                        'invite_uid' => $parentId ,
                        'invitee_uid' => $currentId ,
                    ])->lock(true)->find();
                    if (!$find){
                        Db::table('ym_manage.account_invites')->insert([
                            'invite_uid' => $parentId ,
                            'invitee_uid' => $currentId ,
                            'created_at' => date('Y-m-d H:i:s') ,
                        ]);
                    }
                    // 记录这个代理名下
                    $uidFind = Db::table('ym_manage.uidglaid')->where([
                        'aid' => $parentId ,
                        'uid' => $currentId ,
                    ])->find();
                    if(!$uidFind){
                        Db::table('ym_manage.uidglaid')->insert([
                            'aid' => $parentId ,
                            'uid' => $currentId ,
                            'createtime' => time() ,
                        ]);
                    }
                    // 一共邀请了多少人
                    $count = Db::table('ym_manage.account_invites')->where(['invite_uid' => $parentId])->lock(true)->count();
                    $findItem = [];
                    foreach ($this->gameConfig as $val){
                        if ($count >= $val['number']){
                            $findItem = $val;
                        }
                    }
                    if ($findItem){
                        $send = Db::table('ym_manage.account_invite_sends')->where([
                            'uid' => $parentId ,
                            'number' => $findItem['number'] ,
                        ])->lock(true)->find();
                        if (!$send){
                            $date = date('Y-m-d H:i:s');
                            Db::table('ym_manage.account_invite_sends')->insert([
                                'uid' => $parentId ,
                                'number' => $findItem['number'] ,
                                'gold' => $findItem['gold'] ,
                                'status' => 0 ,
                                'created_at' => $date ,
                                'updated_at' => $date ,
                            ]);
                        }
                    }
                }
                Db::commit();
                $this->success('注册成功');
            }else{
                $this->error('注册失败！');
            }
        }
        // print_r($quArray);die;
		$this->assign('gameLoginUrl',$this->config['GameLoginUrl']);
        $this->assign('qu' , $quArray);
        return $this->fetch('newregister');
    }

    public function register_sendmsg(){
        $quArray = $this->quArray;
        if ($this->request->isPost()){
            $type =  $this->request->post('type' , 'mobile');
            $isMobile = $type == 'mobile';
            $isAccount = $type == 'account';
            $parentId = $this->request->get('id');
            $qu = $this->request->post('qu');
            $mobile = $this->request->post('mobile');
            $verify = $this->request->post('verify');
            $password = $this->request->post('password');
            if ($isMobile && !$mobile){
                $this->error('手机号不能为空');
            }
            if (!$password) {
                $this->error('密码不能为空');
            }
            if ($isMobile && !$verify){
                $this->error('验证码不能为空');
            }
            if (empty(Cache::get($mobile))) {
                $this->error('请重新获取验证码');
            } else {
                if ($verify != Cache::get($mobile)) {
                    $this->error('验证码不正确');
                }
            }
            if ($isMobile){
                $account = $mobile;
                $nickname = preg_replace('/^(\d{3})\d+(\d{4})$/' , '$1xxxx$2' , $account);
            }
            $time = time();
            $createdUid = 0;
            $sign = 'register' . $account . $password . $time . $this->config['PrivateKey'];
            $sign = md5($sign);
            $url = $this->config['GameServiceApi'] ."/ml_api?act=register&accountname=" . $account . "&nickname=" . $nickname . "&pwd=" . $password . "&time=" . $time . "&agc=" . $createdUid . "&sign=" . $sign;
            $res = _request($url , false , 'get' , null , 2);
            $res = json_decode($res , true);
            if ($res){
                if ($res['status'] != 0){
                    $this->error($res['msg']);
                }
                $currentId = $res['userid'];
                Db::startTrans();
                if ($parentId > 0){
                    $find = Db::table('ym_manage.account_invites')->where([
                        'invite_uid' => $parentId ,
                        'invitee_uid' => $currentId ,
                    ])->lock(true)->find();
                    if (!$find){
                        Db::table('ym_manage.account_invites')->insert([
                            'invite_uid' => $parentId ,
                            'invitee_uid' => $currentId ,
                            'created_at' => date('Y-m-d H:i:s') ,
                        ]);
                    }
                    // 记录这个代理名下
                    $uidFind = Db::table('ym_manage.uidglaid')->where([
                        'aid' => $parentId ,
                        'uid' => $currentId ,
                    ])->find();
                    if(!$uidFind){
                        Db::table('ym_manage.uidglaid')->insert([
                            'aid' => $parentId ,
                            'uid' => $currentId ,
                            'createtime' => time() ,
                        ]);
                    }
                    // 一共邀请了多少人
                    $count = Db::table('ym_manage.account_invites')->where(['invite_uid' => $parentId])->lock(true)->count();
                    $findItem = [];
                    foreach ($this->gameConfig as $val){
                        if ($count >= $val['number']){
                            $findItem = $val;
                        }
                    }
                    if ($findItem){
                        $send = Db::table('ym_manage.account_invite_sends')->where([
                            'uid' => $parentId ,
                            'number' => $findItem['number'] ,
                        ])->lock(true)->find();
                        if (!$send){
                            $date = date('Y-m-d H:i:s');
                            Db::table('ym_manage.account_invite_sends')->insert([
                                'uid' => $parentId ,
                                'number' => $findItem['number'] ,
                                'gold' => $findItem['gold'] ,
                                'status' => 0 ,
                                'created_at' => $date ,
                                'updated_at' => $date ,
                            ]);
                        }
                    }
                }
                Db::commit();
                $this->success('注册成功');
            }else{
                $this->success('注册成功');
            }
        }
        // print_r($quArray);die;
		$this->assign('gameLoginUrl',$this->config['GameLoginUrl']);
        $this->assign('qu' , $quArray);
        return $this->fetch();
    }

    // 发送短信
    public function sendSMS($mobile , $code = ''){
        // Build client
        $client = new USMSClient([
            "publicKey" => "4eZBKoT4KvcCTNABi3iWfk2Ht1NGKp65K",
            "privateKey" => "LPpt1JRcecjEAkqC8qq8V950Po7XR2Smv1fk9sB2wegJ",
            "projectId" => "org-fsswdq",
            "logger" => new DisabledLogger(),
        ]);

        // Describe Image
        try {
            $req = new SendUSMSMessageRequest();
            // "+5521967466411"
            $req->setPhoneNumbers([$mobile]);
            $req->setSigContent("Caçador");
            $req->setTemplateId("UTA230131ESUUTI");
            $req->setTemplateParams([$code]);
            $resp = $client->sendUSMSMessage($req);
            $res = $resp->toArray();
            if ($res['Message'] == 'Send success' && $res['RetCode'] == 0){
                return true;
            }
            Log::debug('send sms failed' , [$resp]);
            return false;
        } catch (UCloudException $e) {
            $msg = $e->getMessage();
            Log::debug('send sms failed' , [$msg]);
            return false;
        }
    }


    public function verify(){
        $mobile = input('mobile');
        if(!$mobile){
            $this->error('请输入手机号');
        }
        $qu = $this->request->post('qu');
        $qu = isset($this->quArray[$qu]) ? $this->quArray[$qu] : '';
        if (!$qu){
            $this->error('区号不正确');
        }
        $pattern = '/^1[3-9][0-9]{9}$/';
        if(!preg_match($pattern , $mobile)){
            $this->error('请输入有效的手机号');
        }
        $str = '';
        for($i =0 ; $i < 4 ; $i ++){
            $str .= mt_rand(0 , 9);
        }
        $sessonName = 'regcode';
        session($sessonName, $str);
        $res = $this->sendSMS($qu . $mobile , $str);
        if($res){
            $this->success('发送成功');
        }else{
            $this->error('发送失败');
        }
    }

    public function verify_inter(){
        $mobile = input('mobile');
        $qu = $this->request->post('qu');
        $str = '';
        if(!$mobile){
            $this->error('请输入手机号');
        }
        // 判断验证码是否过期
        if (!empty(Cache::get($mobile))) {
            $str = Cache::get($mobile);
        } else {
            for($i =0 ; $i < 6 ; $i ++){
                $str .= mt_rand(0 , 9);
            }
            Cache::set($mobile,$str,300);
        }
        $res = $this->sendSMS_inter($qu . $mobile , $str);
        if($res){
            $this->success('发送成功');
        }else{
            $this->error('发送失败');
        }
    }

    public function sendSMS_inter($mobile, $str) {
        $url = 'https://api.liasmart.com/api/SendSMS';
        $data = [
            'api_id' => 'API110108784937',
            'api_password' => 'oeP2jMDRvZ',
            'sms_type' => 'T',
            'encoding' => 'U',
            'sender_id' => 'LIASMT',
            'phonenumber' => $mobile,
            'textmessage' => "[CrazyFishing]Your verification code is {$str}, valid within 5 minutes."
        ];
        $opts = [
            'http' => [
                'method' => 'POST',
                'content' => json_encode($data,true),
                'header'  => "Content-type: application/json ",
            ]
        ];

        $res = file_get_contents($url,false,stream_context_create($opts));
        $res = json_decode($res,true);
        if ($res['status'] == 'S') {
            $this->success('发送成功');
        } else {
            $this->error('发送失败');
        }
    }

    // 活动
    public function activity(){
        $id = input('id');
        $map = ['id' => $id];
        // $list = Db::table('ym_manage.activitys')->where($map)->order('id' , 'desc')->select();
        $list = Db::table('ym_manage.activity')->where($map)->field('image')->find();
        $this->assign('list' , $list);
        return $this->fetch();
    }

    // 活动内容
    public function activityContent(){
        $id = input('id');
        $map = ['id' => $id];
        $find = Db::table('ym_manage.activitys')->where($map)->find();
        $this->success(['content' => $find['content']]);
        return $this->fetch();
    }

    public function newregister(){
        $quArray = $this->quArray;
        if ($this->request->isPost()){
            $type =  $this->request->post('type' , 'mobile');
            $isMobile = $type == 'mobile';
            $isAccount = $type == 'account';
            $parentId = $this->request->get('id');
            $qu = $this->request->post('qu');
            $mobile = $this->request->post('mobile');
            $verify = $this->request->post('verify');
            $account_verify = $this->request->post('account_verify');
            $password = $this->request->post('password');
            $confirmPass = $this->request->post('confirm_password');
            $account = $this->request->post('account');
            if ($isMobile && !$mobile){
                $this->error('手机号不能为空');
            }
            if (!$password) {
                $this->error('密码不能为空');
            }
            if ($isAccount && !$account_verify){
                $this->error('验证码不能为空');
            }
            if ($isMobile && !$verify){
                $this->error('验证码不能为空');
            }
            if ($isAccount && $password != $confirmPass){
                $this->error('两次输入不一致');
            }
            if ($isAccount){
                if (mb_strlen($account , 'utf8') > 16){
                    $this->error('账号16字符以下');
                }
                if (!(preg_match('/[0-9]+[a-zA-Z]+/' , $account) || preg_match('/[a-zA-Z]+[0-9]+/' , $account))){
                    $this->error('账号必须字母+数字组合');
                }
            }
            if (
                ($isMobile && $verify != session('regcode')) ||
                ($isAccount && !captcha_check($account_verify))
            ){
                $this->error('验证码不正确');
            }
            $qu = isset($quArray[$qu]) ? $quArray[$qu] : '';
            if ($isMobile && !$qu){
                $this->error('区号不正确');
            }
            if ($isMobile){
                $account = $mobile;
                $nickname = preg_replace('/^(\d{3})\d+(\d{4})$/' , '$1xxxx$2' , $account);
            }
            if ($isAccount){
                $nickname = $account;
            }
            $time = time();
            $createdUid = $parentId;
            $sign = 'register' . $account . $password . $time . $this->config['PrivateKey'];
            $sign = md5($sign);
            $url = $this->config['GameServiceApi'] ."/ml_api?act=register&accountname=" . $account . "&nickname=" . $nickname . "&pwd=" . $password . "&time=" . $time . "&agc=" . $createdUid . "&sign=" . $sign;
            $res = _request($url , false , 'get' , null , 2);
            $res = json_decode($res , true);
            if ($res){
                if ($res['status'] != 0){
                    $this->error($res['msg']);
                }
                $currentId = $res['userid'];
                Db::startTrans();
                if ($parentId > 0){
                    $find = Db::table('ym_manage.account_invites')->where([
                        'invite_uid' => $parentId ,
                        'invitee_uid' => $currentId ,
                    ])->lock(true)->find();
                    if (!$find){
                        Db::table('ym_manage.account_invites')->insert([
                            'invite_uid' => $parentId ,
                            'invitee_uid' => $currentId ,
                            'created_at' => date('Y-m-d H:i:s') ,
                        ]);
                    }
                    // 记录这个代理名下
                    $uidFind = Db::table('ym_manage.uidglaid')->where([
                        'aid' => $parentId ,
                        'uid' => $currentId ,
                    ])->find();
                    if(!$uidFind){
                        Db::table('ym_manage.uidglaid')->insert([
                            'aid' => $parentId ,
                            'uid' => $currentId ,
                            'createtime' => time() ,
                        ]);
                    }
                    // 一共邀请了多少人
                    $count = Db::table('ym_manage.account_invites')->where(['invite_uid' => $parentId])->lock(true)->count();
                    $findItem = [];
                    foreach ($this->gameConfig as $val){
                        if ($count >= $val['number']){
                            $findItem = $val;
                        }
                    }
                    if ($findItem){
                        $send = Db::table('ym_manage.account_invite_sends')->where([
                            'uid' => $parentId ,
                            'number' => $findItem['number'] ,
                        ])->lock(true)->find();
                        if (!$send){
                            $date = date('Y-m-d H:i:s');
                            Db::table('ym_manage.account_invite_sends')->insert([
                                'uid' => $parentId ,
                                'number' => $findItem['number'] ,
                                'gold' => $findItem['gold'] ,
                                'status' => 0 ,
                                'created_at' => $date ,
                                'updated_at' => $date ,
                            ]);
                        }
                    }
                }
                Db::commit();
                $this->success('注册成功');
            }else{
                $this->error('注册失败！');
            }
        }
        // print_r($quArray);die;
		$this->assign('gameLoginUrl',$this->config['GameLoginUrl']);
        $this->assign('qu' , $quArray);
        return $this->fetch();
    }

    // 邮箱注册
    public function register_sendmsg_email(){

        $quArray = $this->quArray;
        if ($this->request->isPost()){
            $parentId = $this->request->get('id');
            $email = $this->request->post('email');
            $verify = $this->request->post('verify');
            $password = $this->request->post('password');
            if (!$email){
                $this->error('email不能为空');
            }
            if (!$password) {
                $this->error('密码不能为空');
            }
            if (!$verify){
                $this->error('验证码不能为空');
            }
            if (empty(Cache::get($email))) {
                $this->error('请重新获取验证码');
            } else {
                if ($verify != Cache::get($email)) {
                    $this->error('验证码不正确');
                }
            }

            $account = $email;
            $nickname = $email;
            $time = time();
            $createdUid = $parentId;
            $sign = 'register' . $account . $password . $time . $this->config['PrivateKey'];
            $sign = md5($sign);
            $url = $this->config['GameServiceApi'] ."/ml_api?act=register&accountname=" . $account . "&nickname=" . $nickname . "&pwd=" . $password . "&time=" . $time . "&agc=" . $createdUid . "&sign=" . $sign;
            $res = _request($url , false , 'get' , null , 2);
            $res = json_decode($res , true);
            if ($res){
                if ($res['status'] != 0){
                    $this->error($res['msg']);
                }
                $currentId = $res['userid'];
                Db::startTrans();
                if ($parentId > 0){
                    $find = Db::table('ym_manage.account_invites')->where([
                        'invite_uid' => $parentId ,
                        'invitee_uid' => $currentId ,
                    ])->lock(true)->find();
                    if (!$find){
                        Db::table('ym_manage.account_invites')->insert([
                            'invite_uid' => $parentId ,
                            'invitee_uid' => $currentId ,
                            'created_at' => date('Y-m-d H:i:s') ,
                        ]);
                    }
                    // 记录这个代理名下
                    $uidFind = Db::table('ym_manage.uidglaid')->where([
                        'aid' => $parentId ,
                        'uid' => $currentId ,
                    ])->find();
                    if(!$uidFind){
                        Db::table('ym_manage.uidglaid')->insert([
                            'aid' => $parentId ,
                            'uid' => $currentId ,
                            'createtime' => time() ,
                        ]);
                    }
                    // 一共邀请了多少人
                    $count = Db::table('ym_manage.account_invites')->where(['invite_uid' => $parentId])->lock(true)->count();
                    $findItem = [];
                    foreach ($this->gameConfig as $val){
                        if ($count >= $val['number']){
                            $findItem = $val;
                        }
                    }
                    if ($findItem){
                        $send = Db::table('ym_manage.account_invite_sends')->where([
                            'uid' => $parentId ,
                            'number' => $findItem['number'] ,
                        ])->lock(true)->find();
                        if (!$send){
                            $date = date('Y-m-d H:i:s');
                            Db::table('ym_manage.account_invite_sends')->insert([
                                'uid' => $parentId ,
                                'number' => $findItem['number'] ,
                                'gold' => $findItem['gold'] ,
                                'status' => 0 ,
                                'created_at' => $date ,
                                'updated_at' => $date ,
                            ]);
                        }
                    }
                }
                Db::commit();
                $this->success('注册成功');
            }else{
                $this->success('注册成功');
            }
        }
        // print_r($quArray);die;
		$this->assign('gameLoginUrl',$this->config['GameLoginUrl']);
        $this->assign('qu' , $quArray);
        return $this->fetch();
    }

    public function sendSMS_email($email, $str) {
        $url = 'https://sms.nbfmg.com/api/mail/method';
        $email_content = '<div>Hello, '.$email.'</div>';
        $email_content .= '<div>Content: Registration is successful! Verification code: '. $str .'</div>';
        $email_content .= '<div>Time:'.date('Y-m-d H:i:s').'</div>';
        $email_content .= '<div>Official website: 777mini</div>';
        $data = [
            'signature' => 'HfkLyjYV7FmyLwST',
            'user' => 'mail_777',
            'Subject' => 'registration message',
            'To' => $email,
            'cmd' => 'SendMail',
            'Body' => $email_content
        ];

        $opts = [
            'ssl' => [
                'verify_peer' => false,
                'verify_peer_name' => false,
            ],
            'http' => [
                'method' => 'POST',
                'content' => http_build_query($data),
                'header'  => "Content-type: application/x-www-form-urlencoded ",
            ]
        ];

        $res = file_get_contents($url,false,stream_context_create($opts));
        $res = json_decode($res,true);
        if ($res['message'] == 'Sent success') {
            $this->success('发送成功');
        } else {
            $this->error('发送失败');
        }
    }

    public function verify_email(){
        $email = input('email');
        $str = '';
        if(!$email){
            $this->error('请输入邮箱');
        }
        // 判断验证码是否过期
        if (!empty(Cache::get($email))) {
            $str = Cache::get($email);
        } else {
            for($i =0 ; $i < 6 ; $i ++){
                $str .= mt_rand(0 , 9);
            }
            Cache::set($email,$str,300);
        }
        $res = $this->sendSMS_email($email, $str);
        if($res){
            $this->success('发送成功');
        }else{
            $this->error('发送失败');
        }
    }
}
