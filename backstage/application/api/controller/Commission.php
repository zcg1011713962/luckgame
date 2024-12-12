<?php

namespace app\api\controller;

use think\Db;

class Commission extends Init
{
    /**
     * 手续费返佣
     * @return void
     */
    public function fee(){
        $user_id = $this->request->post('user_id');
        $game_id = $this->request->post('game_id');
        $money = $this->request->post('cost');//交易金额
        $rate = 30;//百分比手续费
        $brokerage = $rate; // 扣除手续费百分比
        $fee = ($brokerage / 100) * $money; //手续费
        $money = $money - $fee;//减掉手续费真是金额
        //返佣比例
        $commission = [
            'lv_1'=>30,
            'lv_2'=>20,
            'lv_3'=>10,
        ];
        /************* 发放交易奖励 *********/
        $userList = $this->parent_user($user_id, 3);
        if ($userList) {
            foreach ($userList as $v) {
                if ($v['status'] === 1) {
                    $d_reward  = $commission['lv_'.$v['lv']];
                    $reward = round($money * ($d_reward / 100), 2); //奖励百分比
                    if ($reward == 0) continue;
                    $data = [
                        'user_id' => $v['user_id'],
                        'subordinate_id' => $user_id,
                        'money' => $reward,
                        'lv' => $v['lv'],
                        'game_id' => $game_id,//返佣类型
                        'status' => 1,
                        'create_time'=>time(),
                        'update_time'=>time()
                    ];
                    Db::table('ym_manage.commission_log')->add($data);
                    //增加上级余额
                    Db::table('gameaccount.userinfo_imp')->where('userId',$v['pid'])->setInc('score',$reward);
                }
            }
        }
    }
    /**
     * 获取上级会员
     * Created by PhpStorm.
     * User: Administrator
     * Date: 2021/8/5
     * Time: 20:24
     * Author: 禁止使用本软件（系统）用于任何违法违规业务或项目,造成的任何法律后果允由使用者（或运营者）承担
     * @param $user_id
     * @param int $num
     * @param int $lv
     * @return array|false
     * @throws \think\db\exception\DataNotFoundException
     * @throws \think\db\exception\DbException
     * @throws \think\db\exception\ModelNotFoundException
     */
    public function parent_user($user_id, $num = 1, $lv = 1)
    {
        $pid = Db::table('ym_manage.agentinfo')->where('uid', $user_id)->value('pid');
        $uinfo = Db::table('ym_manage.agentinfo')->where('uid', $pid)->find();

        if ($uinfo) {
            if ($uinfo['pid'] && $num > 1) $data = $this->parent_user($uinfo['uid'], $num - 1, $lv + 1);
            $data[] = ['user_id' => $uinfo['uid'], 'pid' => $uinfo['pid'],'lv' => $lv];
            return $data;
        }
        return false;
    }
}