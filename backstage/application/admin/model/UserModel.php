<?php

namespace app\admin\model;

use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;
use app\api\model\ActivityModel;

class UserModel extends Model
{
    private $key    = '';
    private $apiurl = '';

    public function __construct()
    {
        parent::__construct();
        // 读取配置信息
        $config = ConfigModel::getSystemConfig();
        $this->apiurl = $config['GameServiceApi'];
        $this->key = $config['PrivateKey'];
        // $this->apiurl = Config::get('app.Recharge_API');
    }

    private function _request($url, $https = false, $method = 'get', $data = null)
    {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);           //设置URL
        curl_setopt($ch, CURLOPT_HEADER, false);       //不返回网页URL的头信息
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);//不直接输出返回一个字符串
        if ($https) {
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);//服务器端的证书不验证
            curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);//客户端证书不验证
        }
        if ($method == 'post') {
            curl_setopt($ch, CURLOPT_POST, true);       //设置为POST提交方式
            curl_setopt($ch, CURLOPT_POSTFIELDS, $data);//设置提交数据$data
        }
        $str = curl_exec($ch);//执行访问
        curl_close($ch);      //关闭curl释放资源
        return $str;
    }

    public function getUserListV1($limit = 30, $search = '', $robot = 0, $begin_time = "", $end_time = "")
    {
        $dbobj = Db::table('gameaccount.newuseraccounts')->alias('u')
            ->rightJoin('gameaccount.userinfo_imp i', 'u.Id=i.userId')
            ->leftJoin('ym_manage.admin a', 'a.id=ChannelType');
        $totaldbobj = Db::table('gameaccount.newuseraccounts')->alias('u')
            ->rightJoin('gameaccount.userinfo_imp i', 'u.Id=i.userId')
            ->leftJoin('ym_manage.admin a', 'a.id=ChannelType');
        if (trim($search) != '') {
            $dbobj = $dbobj->where('u.Id|u.Account', 'like', '%' . $search . '%');
            $totaldbobj = $totaldbobj->where('u.Id|u.Account', 'like', '%' . $search . '%');
        }
        if (trim($begin_time) != '') {
            $dbobj = $dbobj->where("u.AddDate", ">=", $begin_time);
            $totaldbobj = $totaldbobj->where("u.AddDate", ">=", $begin_time);
        }
        if (trim($end_time) != '') {
            $dbobj = $dbobj->where("u.AddDate", "<=", $end_time);
            $totaldbobj = $totaldbobj->where("u.AddDate", "<=", $end_time);
        }
        //是否机械人
//        if ($robot == 1) {
//            $dbobj->whereBetween('u.id', [1, 14999]);
//            $totaldbobj->whereBetween('u.id', [1, 14999]);
//        } else {
//            $dbobj->where('u.id', '>=', 15000);
//            $totaldbobj->where('u.id', '>=', 15000);
//        }
        $totaldbobj->field(["count(1) as total",
                            "sum(u.totalRecharge) as total_recharge",
                            "sum(i.score) score",
                            "sum(i.diamond) diamond",
                            "sum(i.bx_balance) as bx_balance",
                            " sum(i.bankScore) as bankScore", "sum(i.luckyCoin) luckyCoin "]);
        $dbobj->field(['u.*', 'i.*', 'a.username']);
        if (!empty($scoresort) || !empty($diamondsort)) {
            if (!empty($scoresort)) {
                $dbobj = $dbobj->order('i.score ' . $scoresort);
            } else {
                if (!empty($diamondsort)) {
                    $dbobj = $dbobj->order('i.diamond ' . $diamondsort);
                }
            }
        } else {
            $dbobj = $dbobj->order('u.Id desc');
        }
        $ret = $totaldbobj->find();
        $dbobj = $dbobj->paginate($limit)->toArray();
        $dbobj["total"] = $ret["total"];
        $dbobj["total_score"] = $ret["score"];
        $dbobj["total_diamond"] = $ret["diamond"];
        $dbobj["total_bx_balance"] = $ret["bx_balance"];
        $dbobj["total_bankScore"] = $ret["bankScore"];
        $dbobj["total_luckyCoin"] = $ret["luckyCoin"];
        $dbobj["total_recharge"] = $ret["total_recharge"];
        return $dbobj;

    }

    public function getInviteCodeList($limit = 30, $search = '', $robot = 0, $begin_time = '', $end_time = '', $invite_code = '')
    {
        $dbobj = Db::table('gameaccount.newuseraccounts')->alias('u')
            ->rightJoin('gameaccount.userinfo i', 'u.Id=i.userId')
            ->leftJoin('ym_manage.account_invite_sends yma', 'u.Id=yma.uid');
        $totaldbobj = Db::table('gameaccount.newuseraccounts')->alias('u')
            ->rightJoin('gameaccount.userinfo i', 'u.Id=i.userId')
            ->leftJoin('ym_manage.account_invite_sends yma', 'u.Id=yma.uid');
        if (trim($search) != '') {
            $dbobj = $dbobj->where('u.Id|u.Account', 'like', '%' . $search . '%');
            $totaldbobj = $totaldbobj->where('u.Id|u.Account', 'like', '%' . $search . '%');
        }
        if (trim($begin_time) != '') {
            $dbobj = $dbobj->where("u.AddDate", ">=", $begin_time);
            $totaldbobj = $totaldbobj->where("u.AddDate", ">=", $begin_time);
        }
        if (trim($end_time) != '') {
            $dbobj = $dbobj->where("u.AddDate", "<=", $end_time);
            $totaldbobj = $totaldbobj->where("u.AddDate", "<=", $end_time);

        }

        if (trim($invite_code) != '') {
            $dbobj = $dbobj->where('i.invite_code', '=', $invite_code);
            $totaldbobj = $totaldbobj->where('i.invite_code', '=', $invite_code);

        } else {

            $dbobj = $dbobj->where('i.invite_code !=""');
            $totaldbobj = $totaldbobj->where('i.invite_code !=""');
        }
        $dbobj->where('u.id', '>=', 15000);
        $totaldbobj->where('u.id', '>=', 15000);
        $dbobj->order('yma.number desc');
        $totaldbobj->field(['COUNT(1) as total', 'SUM(yma.number) as numbers', 'SUM(yma.gold) as golds']);
        $dbobj->field(['i.userId', 'i.invite_code', 'u.nickname', 'yma.number', 'yma.gold']);
        $ret = $totaldbobj->find();
        $dbobj = $dbobj->paginate($limit)->toArray();
        $dbobj["numbers"] = $ret["numbers"] ? $ret["numbers"] : 0;
        $dbobj["golds"] = $ret["golds"] ? $ret["golds"] : 0;
        $dbobj["total"] = $ret["total"] ? $ret["total"] : 0;
        return $dbobj;

    }

    public function getUserList($limit = 30, $search = '', $robot = 0)
    {

        $dbobj = Db::table('gameaccount.newuseraccounts')->alias('u')
            ->rightJoin('gameaccount.userinfo_imp i', 'u.Id=i.userId')
            ->leftJoin('ym_manage.admin a', 'a.id=u.ChannelType');
        if (trim($search) != '') {
            $dbobj = $dbobj->where('u.Id|u.Account', 'like', '%' . $search . '%');
        }
        $dbobj->field(['u.*', 'i.*', 'a.username']);
        if (!empty($scoresort) || !empty($diamondsort)) {

            if (!empty($scoresort)) {
                $dbobj = $dbobj->order('i.score ' . $scoresort);
            } else {
                if (!empty($diamondsort)) {
                    $dbobj = $dbobj->order('i.diamond ' . $diamondsort);
                }
            }

        } else {
            $dbobj = $dbobj->order('u.Id desc');
        }
        if ($robot == 1) {
            $dbobj->whereBetween('u.id', [1, 14999]);
        } else {
            $dbobj->where('u.id', '>=', 15000);
        }

        $dbobj = $dbobj->paginate($limit)->toArray();

        return $dbobj;
    }

    public function getUserCount($search = '')
    {
        if (!empty($search)) {
            return Db::table('gameaccount.newuseraccounts')
                ->where('Id|Account', 'eq', $search)
                ->where('id', '>=', '11000')
                ->count();
        } else {
            return Db::table('gameaccount.newuseraccounts')->where('id', '>=', '11000')->count();
        }
    }

    public function getMachineUserCount($search = '')
    {
        if (!empty($search)) {
            return Db::table('gameaccount.newuseraccounts')
                ->where('Id|Account', 'eq', $search)
                ->whereBetween('id', [1, 10487])
                ->count();
        } else {
            return Db::table('gameaccount.newuseraccounts')->whereBetween('id', [1, 10487])->count();
        }
    }

    public function totalRegisterNum()
    {
        $begin_time = date('Y-m-d', time());
        $end_time = date('Y-m-d H:i:s', strtotime($begin_time) + 86399);
        return Db::table('gameaccount.newuseraccounts')->field('COUNT(1) as count')->where([
            ['AddDate', '>=', $begin_time],
            ['AddDate', '<=', $end_time]
        ])->count();
    }

    public function totalWeekRegisterNum()
    {
        $now_time = time();
        $week = date('N', $now_time);
        $begin_day = $week - 1;
        $end_day = 7 - $week;
        $begin_time = date("Y-m-d", strtotime("- $begin_day  day", $now_time));
        $end_time = date("Y-m-d 23:59:59", strtotime("+$end_day day", $now_time));
        return Db::table('gameaccount.newuseraccounts')->field('COUNT(1) as count')->where([
            ['AddDate', '>=', $begin_time],
            ['AddDate', '<=', $end_time]
        ])->count();

    }

    public function getUserInfo($id)
    {
        if (empty($id)) {
            return false;
        }
        return Db::table('gameaccount.newuseraccounts')->alias('u')
            ->join('gameaccount.userinfo_imp i', 'u.Id=i.userId')
            ->find($id);
    }

    public function getUserInfoByAccount($account)
    {
        if (empty($account)) {
            return false;
        }
        return Db::table('gameaccount.newuseraccounts')->alias('u')
            ->join('gameaccount.userinfo_imp i', 'u.Id=i.userId')
            ->where('u.Account', $account)
            ->find();
    }

    public function setUserPwd($data)
    {
        if (empty($data)) {
            return false;
        }
        if (empty($data['username']) || empty($data['uid'])) {
            return false;
        }
        if (empty($data['newpass']) || empty($data['repass'])) {
            return false;
        }
        if ($data['newpass'] != $data['repass']) {
            return false;
        }

        $user = Db::table('gameaccount.newuseraccounts')
            ->where('Id', $data['uid'])
            ->where('Account', $data['username'])
            ->find();

        if ($user) {
            // return Db::name('gameaccount.newuseraccounts')
            // 			->where('Id', $user['Id'])
            // 			->data(['p' => $data['repass'],'Password' => md5($data['repass'])])
            // 			->update();

            $act = "pwdreset";
            $time = strtotime('now');
            $key = $this->key;
            $account = trim($user['Account']);
            $pwd = $data['newpass'];
            $sign = $act . $account . $pwd . $time . $key;
            $md5sign = md5($sign);
            $url = $this->apiurl . "/Activity/gameuse?act=" . $act . "&accountname=" . $account . "&pwd=" . $pwd . "&time=" . $time . "&sign=" . $md5sign;
            $res = $this->_request($url);

            $res = json_decode($res, true);
            if (isset($res) && ($res['status'] == '0')) {
                return true;
            }

        }

        return false;
    }

    public function setUserScore($data, $type)
    {
        if (empty($type) || !in_array($type, ['1', '2'])) {
            return false;
        }
        if (empty($data)) {
            return false;
        }
        if (empty($data['username']) || empty($data['uid'])) {
            return false;
        }
        //if(empty($data['score']) || empty($data['addscore']) ){ return false; }
        if (empty($data['addscore'])) {
            return false;
        }
        $addscore = round($data['addscore'], 2);
        $account = trim($data['username']);
        if (strpos($data['addscore'], '-') !== false || strpos($data['addscore'], '+') !== false) {
            die('金币数量不正确');
        }
        if ($type == '2') {
            // 检查用户的金币是否足
            $info = $this->getUserInfo($data['uid']);
            if ($info['score'] < $addscore) {
                die('用户可用数不足');
            }
            $addscore = 0 - $addscore;
        }

        return $this->insertScore($account, $addscore);

        die;
        //下面代码废弃
        $user = Db::table('gameaccount.newuseraccounts')
            ->where('Id', $data['uid'])
            ->where('Account', $data['username'])
            ->find();

        if ($user) {
            if ($user['score'] != $data['score']) {
                return false;
            }
            if ($type == '1') {
                $score = $user['score'] + $addscore;
                $logtype = 1;
                $totalRecharge = $user['totalRecharge'] + $addscore;
            } elseif ($type == '2') {
                $score = $user['score'] - $addscore;
                $logtype = 0;
                $totalRecharge = $user['totalRecharge'];
            } else {
                return false;
            }

            $res = Db::name('gameaccount.newuseraccounts')
                ->where('Id', $user['Id'])
                ->data(['score' => $score, 'totalRecharge' => $totalRecharge])
                ->update();
            if ($res) {
                $this->addRechargeLog($user['Id'], $addscore, $user['score'], $score, $logtype);
                return true;
            } else {
                return false;
            }
        }

        return false;
    }

    private function addRechargeLog($uid, $czfee, $oldfee, $newfee, $logtype, $give = 0)
    {
        $adminid = Cookie::get('admin_user_id');
        $log = array(
            'adminid'    => $adminid ? $adminid : 1,
            'userid'     => $uid,
            'createtime' => time(),
            'czfee'      => $czfee,
            'oldfee'     => $oldfee,
            'newfee'     => $newfee,
            'type'       => $logtype,//1 加 0 减
        );
        Db::name('ym_manage.rechargelog')->insert($log);

        try {
            // 更新等级
            $res = $this->countGrade($uid);
        } catch (\Exception $e) {
            // 错误
        }
    }

    public function setUserVip($data)
    {
        if (empty($data)) {
            return false;
        }
        if (empty($data['i'])) {
            return false;
        }
        if (!isset($data['t'])) {
            return false;
        }

        $user = Db::table('gameaccount.newuseraccounts')
            ->where('Id', $data['i'])
            ->find();
        if ($user) {

            $res = Db::name('gameaccount.newuseraccounts')
                ->where('Id', $user['Id'])
                ->data(['is_vip' => $data['t']])
                ->update();
            if ($res) {
                return true;
            }
        }

        return false;
    }

    public function setUserFeng($data)
    {
        if (empty($data)) {
            return false;
        }
        if (empty($data['i'])) {
            return false;
        }
        if (!isset($data['t'])) {
            return false;
        }

        $user = Db::table('gameaccount.newuseraccounts')
            ->where('Id', $data['i'])
            ->find();
        if ($user) {
            Db::name('gameaccount.newuseraccounts')
                ->where('Id', $user['Id'])
                ->data(['iscanlogin' => $data['t']])
                ->update();

            $act = "disabled";
            $time = strtotime('now');
            $key = $this->key;
            $account = trim($user['Account']);
            $state = $data['t'];//$state 1启用 0禁用
            $sign = $act . $account . $state . $time . $key;
            $md5sign = md5($sign);
            $url = $this->apiurl . "/Activity/gameuse?act=" . $act . "&accountname=" . $account . "&state=" . $state . "&time=" . $time . "&sign=" . $md5sign;
            $res = $this->_request($url);

            $res = json_decode($res, true);
            if (isset($res) && ($res['status'] == '0')) {
                return true;
            }
        }

        return false;
    }

    public function insertScore($account, $fee)
    {

        if (empty($account) || empty($fee)) {
            return false;
        }
        $account = trim($account);
        //$fee = round(floatval($fee),2) * 100; jacksun注释
        $fee = round(floatval($fee), 2);

        $user = $this->getUserInfoByAccount($account);
        if ($user) {

            $give = 0; // 充值赠送金额
            // 生成手动加金币单号
            $activityModel = new ActivityModel();
            if ($fee < 0) {
                $order = 'SDMJB' . '_' . $user['Id'] . '_' . date('Ymd') . str_pad(mt_rand(1, 999999), 5, '0', STR_PAD_LEFT) . '_17';
                $activityModel->payMentLog($user['Id'], $fee, $order, 11);
            }
            if ($fee > 0) {

                // 充值赠送
                //$give = SystemRechargeGiftModel::getGiveMoney(sprintf('%.2f', abs($fee) / 100), $user['Id']);
                //$fee += $give;

                // 累计充值赠送宝箱
                //$give = SystemRechargeGiftModel::getGiveBox(sprintf('%.2f', abs($fee) / 100), $user['Id']);
                //$fee += $give;
                //$fee = round($fee,2);

                $order = 'SDJJB' . '_' . $user['Id'] . '_' . date('Ymd') . str_pad(mt_rand(1, 999999), 5, '0', STR_PAD_LEFT) . '_16';
                $activityModel->payMentLog($user['Id'], $fee, $order, 10);
            }

            $act = "scoreedit";
            $time = strtotime('now');
            $key = $this->key;
            $sign = $act . $account . $fee . $time . $key;
            $md5sign = md5($sign);
            $url = $this->apiurl . "/Activity/gameuse?act=" . $act . "&accountname=" . $account . "&goldnum=" . $fee . "&time=" . $time . "&pay_sn=" . $order . "&sign=" . $md5sign;
            $res = $this->_request($url);
            //			file_put_contents('test.txt',$res);
            $res = json_decode($res, true);
            if (isset($res) && ($res['status'] == '0')) {
                $score = $user['score'] + $fee;
                $logtype = $fee > 0 ? 1 : 0;
                $this->addRechargeLog($user['Id'], abs($fee), $user['score'], $score, $logtype, $give);
                return true;
            } else {
                return json_encode($res);
            }

        }
        return false;
    }

    public function rechargeLogs($num = 10)
    {
        $list = Db::table('ym_manage.rechargelog')->order('id desc')->paginate($num, false, [
            'var_page' => 'jb',
        ]);
        $page = $list->render();

        return array(
            'list' => $list,
            'page' => $page
        );
    }

    public function rechargeLogsCount()
    {
        return Db::table('ym_manage.rechargelog')->count();
    }

    public function rechargeLogs1($num = 10)
    {
        $list = Db::table('ym_manage.fkrechargelog')->order('id desc')->paginate($num, false, [
            'var_page' => 'fk',
        ]);
        $page = $list->render();

        return array(
            'list' => $list,
            'page' => $page
        );
    }

    public function rechargeLogsCount1()
    {
        return Db::table('ym_manage.fkrechargelog')->count();
    }

    public function setUserDiamond($data, $type)
    {
        if (empty($type) || !in_array($type, ['1', '2'])) {
            return false;
        }
        if (empty($data)) {
            return false;
        }
        if (empty($data['username']) || empty($data['uid'])) {
            return false;
        }
        if (empty($data['addscore'])) {
            return false;
        }
        $addscore = round($data['addscore'], 0);
        //$account = trim($data['username']);
        $account = $data['username'];
        if (strpos($data['addscore'], '-') !== false || strpos($data['addscore'], '+') !== false) {
            die('金币数量不正确');
        }

        if ($type == '2') {
            $addscore = 0 - $addscore;
        }

        return $this->insertDiamond($account, $addscore);


    }

    public function setUserBankPwd($data)
    {
        return Db::table('gameaccount.newuseraccounts')->where('Id', $data['uid'])->update(['bankPwd' => $data['bankPwd']]);
    }

    public function insertDiamond($account, $fee)
    {
        if (empty($account) || empty($fee)) {
            return false;
        }
        $account = trim($account);
        $fee = intval($fee) * 1;

        $user = $this->getUserInfoByAccount($account);
        if ($user) {

            $act = "diamondedit";
            $time = strtotime('now');
            $key = $this->key;
            $sign = $act . $account . $fee . $time . $key;
            $md5sign = md5($sign);
            $url = $this->apiurl . "/Activity/gameuse?act=" . $act . "&accountname=" . $account . "&goldnum=" . $fee . "&time=" . $time . "&sign=" . $md5sign;
            $res = $this->_request($url);

            $res = json_decode($res, true);
            if (isset($res) && ($res['status'] == '0')) {
                $score = $user['diamond'] + $fee;
                $logtype = $fee > 0 ? 1 : 0;
                $this->addFKRechargeLog($user['Id'], abs($fee), $user['diamond'], $score, $logtype);
                return true;
            } else {
                return json_encode($res);
            }

        }
        return false;
    }

    private function addFKRechargeLog($uid, $czfee, $oldfee, $newfee, $logtype)
    {
        $adminid = Cookie::get('admin_user_id');
        $log = array(
            'adminid'    => $adminid,
            'userid'     => $uid,
            'createtime' => time(),
            'czfee'      => $czfee,
            'oldfee'     => $oldfee,
            'newfee'     => $newfee,
            'type'       => $logtype//1 加 0 减
        );
        Db::name('ym_manage.fkrechargelog')->insert($log);
    }

    public function getRealNum($account)
    {

        $act = "scorequery";
        $time = strtotime('now');
        $key = $this->key;
        $sign = $act . $account . $time . $key;
        $md5sign = md5($sign);
        $_url = $this->apiurl;
        $url = $_url . "/Activity/gameuse?act=" . $act . "&accountname=" . $account . "&time=" . $time . "&sign=" . $md5sign;
        //echo $url;
        $res = $this->_request($url);

        $res = json_decode($res, true);
        if (isset($res) && ($res['status'] == '0')) {
            return $res['data'];
        } else {
            return 'error:' . json_encode($res);
        }
    }

    public function localTongbu()
    {
        $ycdb = 'mysql://root:root@192.168.1.110:3406/gameaccount#utf8';
        $medb = 'mysql://root:@127.0.0.1:3406/gameaccount#utf8';

        $ycdb = Db::connect($ycdb);
        $medb = Db::connect($medb);

        $medb->query("TRUNCATE TABLE newuseraccounts;");
        $medb->query("TRUNCATE TABLE userinfo;");
        $medb->query("TRUNCATE TABLE userinfo_imp;");

        $db1 = $ycdb->table('newuseraccounts')->select();
        $db11 = $medb->table('newuseraccounts')->select();
        $db2 = $ycdb->table('userinfo')->select();
        $db22 = $medb->table('userinfo')->select();
        $db3 = $ycdb->table('userinfo_imp')->select();
        $db33 = $medb->table('userinfo_imp')->select();
        echo '奕辰数据库', count($db1), '-', count($db2), '-', count($db3), '<br/>';
        echo '我的数据库', count($db11), '-', count($db22), '-', count($db33), '<hr/>';

        foreach ($db1 as $k => $v) {
            $medb->table('newuseraccounts')->strict(false)->data($v)->insert();
        }
        foreach ($db2 as $k => $v) {
            $medb->table('userinfo')->strict(false)->data($v)->insert();
        }
        foreach ($db3 as $k => $v) {
            $medb->table('userinfo_imp')->strict(false)->data($v)->insert();
        }

        $db1 = $medb->table('newuseraccounts')->select();
        $db2 = $medb->table('userinfo')->select();
        $db3 = $medb->table('userinfo_imp')->select();
        echo '我的数据库', count($db1), '-', count($db2), '-', count($db3), '<br/>';

    }

    public function updateUserLevel($params)
    {
        if ($params['type'] == 'add') {
            $params['level'] += 1;
        }
        if ($params['type'] == 'minus') {
            $params['level'] -= 1;
        }
        Db::table('gameaccount.newuseraccounts')->where('Id', $params['uid'])->update(['housecard' => $params['level']]);
    }

    /**
     * 发放博主工资记录
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public function getUserSalaryList($where, $limit = 30)
    {
        $list = Db::table('gameaccount.user_blogger_salary')->alias('a')
            ->join('gameaccount.newuseraccounts b', 'a.user_id=b.Id')
            ->where($where)
            ->where('a.delete_at', 0)
            ->field('a.*, b.nickname, b.Account')
            ->order('a.id desc')
            ->paginate($limit)
            ->toArray();
        return $list;
    }

    /**
     * 添加工资发放记录
     * @param $data
     * @return int|string
     */
    public static function addUserSalaryInfo($data)
    {
        return Db::table('gameaccount.user_blogger_salary')->insertGetId($data);
    }

    /**
     * 用户等级记录
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public function getUserGradeList($where, $limit = 30)
    {
        $list = Db::table('gameaccount.user_grade')
            ->where($where)
            ->where('delete_at', 0)
            ->order('id asc')
            ->paginate($limit)
            ->toArray();
        return $list;
    }

    /**
     * 用户等级记录
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public function getUserGradeInfo($where)
    {
        $list = Db::table('gameaccount.user_grade')
            ->where($where)
            ->find();
        return $list;
    }

    /**
     * 添加用户等级记录
     * @param $data
     * @return int|string
     */
    public static function addUserGradeInfo($data)
    {
        return Db::table('gameaccount.user_grade')->insertGetId($data);
    }

    /**
     * 更新等级
     * @param $id
     * @return int|string
     * @throws \think\Exception
     * @throws \think\exception\PDOException
     */
    public static function updateRechargeGift($data)
    {
        $id = isset($data['id']) ? $data['id'] : 0;
        unset($data['id']);
        return Db::table('gameaccount.user_grade')->where('id', $id)->update($data);
    }

    /**
     * 根据累计充值金额判断用户等级
     * @param $userId
     * @return int
     * @throws \think\Exception
     * @throws \think\db\exception\DataNotFoundException
     * @throws \think\db\exception\ModelNotFoundException
     * @throws \think\exception\DbException
     * @throws \think\exception\PDOException
     */
    public function countGrade($userId)
    {
        $grade = 0;
        if (empty($userId)) {
            return $grade;
        }

        // 一周内的充值记录
        $sevenDays = strtotime('-7 days');
        $where = [
            ['createtime', '>=', $sevenDays]
        ];
        $add = Db::table('ym_manage.rechargelog')->where('type', 1)
            ->where('userid', $userId)
            ->where($where)
            ->sum('czfee');
        $reduce = Db::table('ym_manage.rechargelog')->where('type', 0)
            ->where('userid', $userId)
            ->where($where)
            ->sum('czfee');
        $total = $add - $reduce;
        $weekTotal = sprintf('%.2f', $total / 100);

        // 一月内的充值记录
        $sevenDays = strtotime('-30 days');
        $where = [
            ['createtime', '>=', $sevenDays]
        ];
        $add = Db::table('ym_manage.rechargelog')->where('type', 1)
            ->where('userid', $userId)
            ->where($where)
            ->sum('czfee');
        $reduce = Db::table('ym_manage.rechargelog')->where('type', 0)
            ->where('userid', $userId)
            ->where($where)
            ->sum('czfee');
        $total = $add - $reduce;
        $monthTotal = sprintf('%.2f', $total / 100);

        $where = [];
        $where[] = ['week_recharge_money', '<=', $weekTotal];
        $info = Db::table('gameaccount.user_grade')
            ->where('delete_at', 0)
            ->where($where)
            ->order('week_recharge_money desc')
            ->find();

        if ($info) {
            $grade = $info['id'];
        } else {
            $where = [];
            $where[] = ['month_recharge_money', '<=', $monthTotal];
            $info = Db::table('gameaccount.user_grade')
                ->where('delete_at', 0)
                ->where($where)
                ->order('month_recharge_money desc')
                ->find();

            if ($info) $grade = $info['id'];
        }

        // 更新等级
        if ($grade) {
            $res = Db::table('gameaccount.newuseraccounts')->where('Id', $userId)->update([
                'housecard' => $grade
            ]);
        }
        return $grade;
    }

}
