<?php

namespace app\admin\controller;

use think\Db;
use think\facade\Cookie;
use app\admin\model\UserModel;
use app\admin\model\ConfigModel;
use app\admin\model\GameModel;

class User extends Parents
{
    private $config;

    public function __construct()
    {
        parent::__construct();
        $this->config = ConfigModel::getSystemConfig();
    }

    public function lists($robot = 0)
    {
        $this->assign('robot', $robot);
        $this->assign('breadcrumb_name', $robot == 1 ? '机器人列表' : '会员列表');
        return $this->fetch();
    }

    public function getlists($robot = 0)
    {
        $user = new UserModel;
        $params = request()->param();
        $searchstr = !empty($params['searchstr']) ? $params['searchstr'] : '';
        $begin_time = !empty($params["begin_time"]) ? $params["begin_time"] : "";
        $end_time = !empty($params["end_time"]) ? $params["end_time"] : "";
        $res = $user->getUserListV1($params['limit'], $searchstr, $robot, $begin_time, $end_time);
        return [
            'code'           => 0,
            'msg'            => 'ok',
            'count'          => $res['total'],
            'total_score'    => $res["total_score"] ?? 0,
            "total_diamond"  => $res["total_diamond"] ?? 0,
            "total_recharge" => $res["total_recharge"] ?? 0,
            'data'           => $res['data'],
        ];
    }

    public function dels()
    {
        return $this->fetch();
    }

    public function add()
    {
        return $this->fetch();
    }

    public function editinfo()
    {
        return $this->fetch();
    }

    public function editpwd()
    {
        $id = request()->param('id');
        if (empty($id)) {
            $this->error('参数有误', 'admin\User\editpwd');
        }

        $user = new UserModel;
        $info = $user->getUserInfo($id);
        $this->assign('info', $info);

        return $this->fetch();
    }

    public function doeditpwd()
    {
        $data = request()->post();
        if (empty($data)) {
            die('参数有误');
        }

        if (empty($data['username']) || empty($data['uid'])) {
            die('用户参数有误');
        }
        if (empty($data['newpass']) || empty($data['repass'])) {
            die('密码参数有误');
        }
        if ($data['newpass'] != $data['repass']) {
            die('两次密码确认有误');
        }

        $user = new UserModel;
        $res = $user->setUserPwd($data);
        if ($res) {
            echo 'success';
        } else {
            echo '修改密码失败';
        }
    }

    public function addscore()
    {
        $id = request()->param('id');
        if (empty($id)) {
            $this->error('参数有误', 'admin\User\editpwd');
        }

        $user = new UserModel;
        $info = $user->getUserInfo($id);
        $this->assign('info', $info);

        return $this->fetch();
    }

    public function doAddscore()
    {
        $data = request()->post();
        if (empty($data)) {
            die('参数有误');
        }

        if (empty($data['username']) || empty($data['uid'])) {
            die('用户参数有误');
        }
        //if(empty($data['score']) || empty($data['addscore']) ){ die('金币参数有误'); }
        if (empty($data['addscore'])) {
            die('金币参数有误');
        }

        $user = new UserModel;
        $res = $user->setUserScore($data, 1);
        if ($res) {
            echo 'success';
        } else {
            echo '金币增加失败:' . json_encode($res);
        }
    }

    public function delscore()
    {
        $id = request()->param('id');
        if (empty($id)) {
            $this->error('参数有误', 'admin\User\editpwd');
        }

        $user = new UserModel;
        $info = $user->getUserInfo($id);
        $this->assign('info', $info);

        return $this->fetch();
    }

    public function doDelscore()
    {
        $data = request()->post();
        if (empty($data)) {
            die('参数有误');
        }

        if (empty($data['username']) || empty($data['uid'])) {
            die('用户参数有误');
        }
        //if(empty($data['score']) || empty($data['addscore']) ){ die('金币参数有误'); }
        if (empty($data['addscore'])) {
            die('金币参数有误');
        }

        // 判断是否在大厅，如果不在大厅不让下分
        $isMinusGold = true;
        $gameModel = new GameModel;
        $userList = $gameModel->getOnlineList();
        if (!empty($userList)) {
            foreach ($userList as $k => $v) {
                if ($data['uid'] == $v['_userId']) {
                    if ($v['GameId'] != 0) {
                        $isMinusGold = false;
                        break;
                    }
                }
            }
        }

        $user = new UserModel;
        $res = $user->setUserScore($data, 2);
        if ($res && $isMinusGold) {
            echo 'success';
        } else {
            echo '金币减少失败:' . json_encode($res);
        }
    }

    public function doCanLogin()
    {
        $data = request()->post();
        if (empty($data)) {
            die('参数有误');
        }

        if (empty($data['i'])) {
            die('用户参数有误');
        }
        if (!isset($data['t'])) {
            die('封禁参数有误');
        }

        $user = new UserModel;
        $res = $user->setUserFeng($data);
        if ($res) {
            echo 'success';
        } else {
            echo '封禁操作失败:' . json_encode($res);
        }
    }

    public function doVip()
    {
        $data = request()->post();
        if (empty($data)) {
            die('参数有误');
        }

        if (empty($data['i'])) {
            die('用户参数有误');
        }
        if (!isset($data['t'])) {
            die('状态参数有误');
        }

        $user = new UserModel;
        $res = $user->setUserVip($data);
        if ($res) {
            echo 'success';
        } else {
            echo 'VIP操作失败:' . json_encode($res);
        }
    }

    public function recharge()
    {

        $user = new UserModel;
        $num = 10;//每页显示数

        $res = $user->rechargeLogs($num);
        $this->assign('list', $res['list']);
        $this->assign('page', $res['page']);

        $count = $user->rechargeLogsCount();
        $this->assign('count', $count);

        $res1 = $user->rechargeLogs1($num);
        $this->assign('list1', $res1['list']);
        $this->assign('page1', $res1['page']);

        $count1 = $user->rechargeLogsCount1();
        $this->assign('count1', $count1);

        return $this->fetch();
    }

    public function doRecharge()
    {
        $data = request()->post();
        if (empty($data)) {
            die('参数有误');
        }

        if (empty($data['account'])) {
            die('用户参数有误');
        }
        if (empty($data['fee'])) {
            die('金额参数有误');
        }
        if (empty($data['type'])) {
            die('充值类型有误');
        }

        $user = new UserModel;
        $info = $user->getUserInfo($data['account']);

        if ($data['type'] == '金币') {
            $res = $user->insertScore($info['Account'], $data['fee']);
        } elseif ($data['type'] == '房卡') {
            $res = $user->insertDiamond($info['Account'], $data['fee']);
        } else {
            $res = false;
        }


        if ($res) {
            echo 'success';
        } else {
            echo '充值失败:' . json_encode($res);
        }
    }

    public function addDiamond()
    {
        $id = request()->param('id');
        if (empty($id)) {
            $this->error('参数有误', 'admin\User\editpwd');
        }

        $user = new UserModel;
        $info = $user->getUserInfo($id);
        $this->assign('info', $info);

        return $this->fetch('adddiamond');
    }

    public function doAdddiamond()
    {
        $data = request()->post();
        if (empty($data)) {
            die('参数有误');
        }

        if (empty($data['username']) || empty($data['uid'])) {
            die('用户参数有误');
        }
        if (empty($data['addscore'])) {
            die('房卡参数有误');
        }

        $user = new UserModel;
        $res = $user->setUserDiamond($data, 1);
        if ($res) {
            echo 'success';
        } else {
            echo '房卡增加失败:' . json_encode($res);
        }
    }

    public function delDiamond()
    {
        $id = request()->param('id');
        if (empty($id)) {
            $this->error('参数有误', 'admin\User\editpwd');
        }

        $user = new UserModel;
        $info = $user->getUserInfo($id);
        $this->assign('info', $info);

        return $this->fetch('deldiamond');
    }

    public function doDeldiamond()
    {
        $data = request()->post();
        if (empty($data)) {
            die('参数有误');
        }

        if (empty($data['username']) || empty($data['uid'])) {
            die('用户参数有误');
        }
        if (empty($data['addscore'])) {
            die('房卡参数有误');
        }

        $user = new UserModel;
        $res = $user->setUserDiamond($data, 2);
        if ($res) {
            echo 'success';
        } else {
            echo '房卡减少失败:' . json_encode($res);
        }
    }

    public function nowRealNums()
    {
        $id = request()->param('id');
        if (empty($id)) {
            $this->error('参数有误', 'admin\User\editpwd');
        }
        //var_dump($id);

        $user = new UserModel;
        $info = $user->getUserInfo($id);
        //var_dump($info);
        $realnum = $user->getRealNum($info['Account']);
        //var_dump($realnum);
        $realnum['score'] = empty($realnum['score']) ? 0 : $realnum['score'];
        $realnum['diamond'] = empty($realnum['diamond']) ? 0 : $realnum['diamond'];
        //var_dump($realnum);
        $this->assign('info', $info);
        $this->assign('realnum', $realnum);

        return $this->fetch('nowRealNums');
    }

    public function localTongbu()
    {
        $user = new UserModel;
        $user->localTongbu();
    }

    public function addUser()
    {
        $post = $this->request->post();
        $account = $post['account'];
        if (!$account) {
            echo '必须输入账号';
            exit();
        }
        $nickname = $post['nickname'];
        if (!$nickname) {
            echo '必须输入昵称';
            exit();
        }
        $password = $post['pass'];
        if (!$password) {
            echo '必须输入密码';
            exit();
        }
        $createdUid = Cookie::get('admin_user_id');
        $time = time();
        $sign = 'register' . $account . $password . $time . $this->config['PrivateKey'];
        $sign = md5($sign);
        $url = $this->config['GameServiceApi'] . "/ml_api?act=register&accountname=" . $account . "&nickname=" . $nickname . "&pwd=" . $password . "&time=" . $time . "&agc=" . $createdUid . "&sign=" . $sign;
        $res = $this->_request($url, false, 'get', null, 2);
        $res = json_decode($res, true);
        echo $res ? ($res['status'] == 0 ? 1 : $res['msg']) : '调用失败';
    }

    public function batAdd()
    {
        $free = input('fee');
        if (!$free) {
            echo '金额不正确';
            exit;
        }
        if (strpos($free, '-') !== false) {
            echo '金额不能为负数';
            exit;
        }
        Db::table('gameaccount.userinfo_imp')->where('userId', '>', 15000)->setInc('score', $free);
        echo 'success';
    }

    public function batClear()
    {
        Db::table('gameaccount.userinfo_imp')->where('userId', '>', 15000)->update(['score' => 0]);
        echo 'success';
    }

    public function searchUserList()
    {
        $params = request()->param();
        $userModel = new UserModel;
        $userInfo = $userModel->getUserList(100, $params['value'], '', '', 1);
        return $this->_success($userInfo);
    }

    public function adjustLevel()
    {
        $params = request()->post();
        $userModel = new UserModel;
        if ($params['type'] == 'add' && $params['level'] >= 6) {
            return $this->_error('修改等级失败');
        }
        if ($params['type'] == 'minus' && $params['level'] <= 1) {
            return $this->_error('修改等级失败');
        }
        $userModel = $userModel->updateUserLevel($params);
        return $this->_success('', '修改等级成功');
    }

    // 获取在线人数列表
    public function gameLineList()
    {
        // 请求服务端接口获取数据 ...
        $gameModel = new GameModel;
        $params = request()->get();
        $gameList = $gameModel->getList($params);
        $this->assign('gameList', $gameList);
        $result = $gameModel->getOnlineList();
        // 整理数据，获取用户大于15000真实用户
        $gameUserOnline = [];
        $gameId = [];
        foreach ($result as $k => $v) {
//            if ($v['_userId'] >= 15000) {
                $gameUserOnline[$k] = $v;
                if ($v['GameId'] > 0) {
                    $gameId[$v['GameId']] = 1;
                }
                $gameUserOnline[$k]['gameName'] = '大厅';
//            }
        }
        $gameList = $gameModel->getGameListPorts(array_keys($gameId));
        // 结果输出
        foreach ($gameList as $k => $v) {
            foreach ($gameUserOnline as $key => $val) {
                if ($v['port'] == $val['GameId']) {
                    $gameUserOnline[$key]['gameName'] = $v['name'];
                }
            }
        }
        $this->assign('count', count($gameUserOnline));
        $this->assign('gameUserOnline', $gameUserOnline);
        return $this->fetch();
    }

    public function bankpass()
    {
        $id = request()->param('id');
        if (empty($id)) {
            $this->error('参数有误', 'admin\User\bankpass');
        }

        $user = new UserModel;
        $info = $user->getUserInfo($id);
        $this->assign('info', $info);
        return $this->fetch();
    }

    public function editBankPwd()
    {
        $data = request()->post();
        if (empty($data)) {
            die('参数有误');
        }

        if (empty($data['uid'])) {
            die('用户参数有误');
        }
        if (empty($data['bankPwd'])) {
            die('银行密码参数有误');
        }

        $user = new UserModel;
        $res = $user->setUserBankPwd($data);
        if ($res) {
            echo 'success';
        } else {
            echo '银行密码修改失败:' . json_encode($res);
        }
    }


    /**
     * 博主添加工资
     * @return void
     */
    public function userSalary()
    {
        $userList = Db::table('gameaccount.newuseraccounts')
            ->where('Id', '>=', '11000')
            ->field('Id, Account, nickname')
            ->select();

        $this->assign('userList', $userList);
        return $this->fetch();
    }

    public function getUserSalary()
    {
        $params = $this->request->get();
        $where = [];
        if (!empty($params['user_id'])) {
            $where[] = ['a.user_id', '=', $params['user_id']];
        }
        if (!empty($params['begin_time'])) {
            $where[] = ['a.create_at', '>=', $params['begin_time']];
        }
        if (!empty($params['end_time'])) {
            $where[] = ['a.create_at', '<=', $params['end_time']];
        }
        $userModel = new UserModel();
        $result = $userModel->getUserSalaryList($where);
        return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];
    }

    /**
     * 添加博主发放工资
     * @return mixed
     */
    public function addUserSalary()
    {
        if ($this->request->isGet()) {
            $userList = Db::table('gameaccount.newuseraccounts')
                ->where('Id', '>=', '11000')
                ->field('Id, Account, nickname')
                ->select();

            $this->assign('userList', $userList);

            return $this->fetch();
        } else {

            $post = $this->request->post();
            $userId = isset($post['user_id']) ? $post['user_id'] : '';
            $rechargeMoney = isset($post['salary_money']) ? $post['salary_money'] : '';
            if (empty($rechargeMoney)) {
                return $this->_error('工资金额不能为空');
            }

            $res = UserModel::addUserSalaryInfo([
                'user_id'      => $userId,
                'salary_money' => $rechargeMoney,
                'create_at'    => date('Y-m-d H:i:s'),
                'operator'     => Cookie::get('admin_user_id') ?: 0,
            ]);
            if ($res === false) {
                return $this->_error('添加失败');
            }
            return $this->_success([], '添加成功');
        }
    }


    /**
     * 用户等级设置
     * @return void
     */
    public function userGrade()
    {
        return $this->fetch();
    }

    public function getUserGrade()
    {
        $params = $this->request->get();
        $where = [];

        $userModel = new UserModel();
        $result = $userModel->getUserGradeList($where);
        return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];
    }

    /**
     * 用户等级设置
     * @return mixed
     */
    public function addUserGrade()
    {
        if ($this->request->isGet()) {

            return $this->fetch();
        } else {

            $post = $this->request->post();
            $name = isset($post['name']) ? $post['name'] : '';
            if (empty($name)) {
                return $this->_error('等级名称不能为空');
            }
            $rechargeMoney = isset($post['week_recharge_money']) ? $post['week_recharge_money'] : '';
            if (empty($rechargeMoney)) {
                return $this->_error('周累计充值金额不能为空');
            }
            $monthMoney = isset($post['month_recharge_money']) ? $post['month_recharge_money'] : '';
            if (empty($monthMoney)) {
                return $this->_error('月累计充值金额不能为空');
            }

            $cachMoney = isset($post['cash_out_money']) ? $post['cash_out_money'] : '';
            if (empty($cachMoney)) {
                return $this->_error('日提现金额上限不能为空');
            }

            $cachNum = isset($post['cash_out_num']) ? $post['cash_out_num'] : '';
            if (empty($cachNum)) {
                return $this->_error('日提现次数上限不能为空');
            }

            $res = UserModel::addUserGradeInfo([
                'name'                 => $name,
                'week_recharge_money'  => $rechargeMoney,
                'month_recharge_money' => $monthMoney,
                'cash_out_money'       => $cachMoney,
                'cash_out_num'         => $cachNum,
                'remark'               => isset($post['remark']) ? $post['remark'] : '',
                'create_at'            => date('Y-m-d H:i:s'),
                'operator'             => Cookie::get('admin_user_id') ?: 0,
            ]);
            if ($res === false) {
                return $this->_error('添加失败');
            }
            return $this->_success([], '添加成功');
        }
    }

    /**
     * 删除等级
     * @return array
     * @throws \think\Exception
     * @throws \think\exception\PDOException
     */
    public function delUserGrade()
    {
        $id = $this->request->post('id');
        if (empty($id)) {
            return $this->_error('参数为空');
        }
        $data = [
            'id'        => $id,
            'delete_at' => time(),
        ];
        $res = UserModel::updateRechargeGift($data);
        if ($res === false) {
            return $this->_error('删除失败');
        }
        return $this->_success([], '删除成功');
    }

    /**
     * 编辑等级
     * @return array|mixed
     * @throws \think\Exception
     * @throws \think\exception\DbException
     * @throws \think\exception\PDOException
     */
    public function updateUserGrade()
    {
        $userModel = new UserModel();
        if ($this->request->isGet()) {
            $id = $this->request->param('id');
            $info = $userModel->getUserGradeInfo(['id' => $id]);
            $this->assign('info', $info);
            return $this->fetch();
        } else {

            $post = $this->request->post();
            $id = isset($post['id']) ? $post['id'] : '';
            if (empty($id)) {
                return $this->_error('数据参数错误');
            }
            $name = isset($post['name']) ? $post['name'] : '';
            if (empty($name)) {
                return $this->_error('等级名称不能为空');
            }
            $rechargeMoney = isset($post['week_recharge_money']) ? $post['week_recharge_money'] : '';
            if (empty($rechargeMoney)) {
                return $this->_error('周累计充值金额不能为空');
            }
            $monthMoney = isset($post['month_recharge_money']) ? $post['month_recharge_money'] : '';
            if (empty($monthMoney)) {
                return $this->_error('月累计充值金额不能为空');
            }

            $cachMoney = isset($post['cash_out_money']) ? $post['cash_out_money'] : '';
            if (empty($cachMoney)) {
                return $this->_error('日提现金额上限不能为空');
            }

            $cachNum = isset($post['cash_out_num']) ? $post['cash_out_num'] : '';
            if (empty($cachNum)) {
                return $this->_error('日提现次数上限不能为空');
            }

            $res = UserModel::updateRechargeGift([
                'id'                   => $id,
                'name'                 => $name,
                'week_recharge_money'  => $rechargeMoney,
                'month_recharge_money' => $monthMoney,
                'cash_out_money'       => $cachMoney,
                'cash_out_num'         => $cachNum,
                'remark'               => isset($post['remark']) ? $post['remark'] : '',
                'update_at'            => date('Y-m-d H:i:s'),
                'operator'             => Cookie::get('admin_user_id') ?: 0,
            ]);
            if ($res === false) {
                return $this->_error('编辑失败');
            }
            return $this->_success([], '编辑成功');
        }
    }

}
