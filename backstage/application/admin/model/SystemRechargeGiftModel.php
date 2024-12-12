<?php

namespace app\admin\model;

use think\facade\Cookie;
use think\Model;
use think\Db;

class SystemRechargeGiftModel extends Model
{
    protected $table = 'system_recharge_gift';

    /**
     * 发放博主工资记录
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public function getMenuList($where, $limit = 30)
    {
        $list = Db::table('ym_manage.system_recharge_gift')
            ->where($where)
            ->order('sort desc')
            ->paginate($limit)
            ->toArray();
        return $list;
    }

    /**
     * 菜单详情
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public static function getMenuInfo($where)
    {
        $list = Db::table('ym_manage.system_recharge_gift')
            ->where($where)
            ->find();
        return $list;
    }

    /**
     * 添加菜单
     * @param $data
     * @return int|string
     */
    public static function addMenuInfo($data)
    {
        return Db::table('ym_manage.system_recharge_gift')->insertGetId($data);
    }

    /**
     * 更新菜单
     * @param $id
     * @return int|string
     * @throws \think\Exception
     * @throws \think\exception\PDOException
     */
    public static function updateMenu($data)
    {
        $id = isset($data['id']) ? $data['id'] : 0;
        unset($data['id']);
        return Db::table('ym_manage.system_recharge_gift')->where('id', $id)->update($data);
    }

    /**
     * 获取充值赠送的金额
     * @param int $recharge 充值金额
     * @param int $userId  会员ID
     * @return int|mixed
     * @throws \think\db\exception\DataNotFoundException
     * @throws \think\db\exception\ModelNotFoundException
     * @throws \think\exception\DbException
     */
    public static function getGiveMoney($recharge, $userId = 0)
    {
        $give = 0;
        if (empty($recharge)) {
            return $give;
        }

        $where = [];
        $where[] = ['recharge_money', '>=', $recharge];
        $where[] = ['type', '=', 1];
        $info = Db::table('ym_manage.system_recharge_gift')
            ->where('delete_at', 0)
            ->where($where)
            ->order('recharge_money asc')
            ->find();
        if ($info) {
            $give = $info['gift_money'];
            Db::table('ym_manage.recharge_give_log')->insertGetId([
                'user_id' => $userId,
                'recharge_money' => $recharge,
                'give' => $give,
                'type' => 1,
                'createtime' => date('Y-m-d H:i:s'),
            ]);
        }

        // 查询累计充值金额
        if ($userId > 0) {
            $add = Db::table('ym_manage.rechargelog')->where('type', 1)
                ->where('userid', $userId)
                ->sum('czfee');
            $reduce = Db::table('ym_manage.rechargelog')->where('type', 0)
                ->where('userid', $userId)
                ->sum('czfee');
            $total = $add - $reduce;
            $total = sprintf('%.2f', $total / 100);

            $where = [];
            $where[] = ['recharge_money', '<=', $total];
            $where[] = ['type', '=', 2];
            $info = Db::table('ym_manage.system_recharge_gift')
                ->where('delete_at', 0)
                ->where($where)
                ->order('recharge_money desc')
                ->find();

            if ($info) {
                $log = Db::table('ym_manage.recharge_accumulate_log')
                    ->where('userid', $userId)
                    ->where('recharge_money', '<=', $info['recharge_money'])
                    ->where('type', '=', 1)
                    ->order('recharge_money asc')
                    ->find();

                if (empty($log)) {
                    Db::table('ym_manage.recharge_accumulate_log')->insertGetId([
                        'adminid' => Cookie::get('admin_user_id') ?: 1,
                        'userid' => $userId,
                        'createtime' => time(),
                        'recharge_money' => $info['recharge_money'],
                        'total_fee' => $total,
                        'give' => $info['gift_money'],
                        'type' => 1,
                    ]);
                    $give += $info['gift_money'];
                    Db::table('ym_manage.recharge_give_log')->insertGetId([
                        'user_id' => $userId,
                        'recharge_money' => $recharge,
                        'give' => $info['gift_money'],
                        'type' => 1,
                        'createtime' => date('Y-m-d H:i:s'),
                    ]);
                }
            }
        }
        $give = sprintf('%.2f', $give);
        return $give * 100; // 元转为分
    }

    /**
     * 获取累计充值赠送的宝箱
     * @param int $recharge 充值金额
     * @param int $userId  会员ID
     * @return int|mixed
     * @throws \think\db\exception\DataNotFoundException
     * @throws \think\db\exception\ModelNotFoundException
     * @throws \think\exception\DbException
     */
    public static function getGiveBox($recharge, $userId = 0)
    {
        $give = 0;
        if (empty($recharge)) {
            return $give;
        }

        // 查询累计充值金额
        if ($userId > 0) {
            $add = Db::table('ym_manage.rechargelog')->where('type', 1)
                ->where('userid', $userId)
                ->sum('czfee');
            $reduce = Db::table('ym_manage.rechargelog')->where('type', 0)
                ->where('userid', $userId)
                ->sum('czfee');
            $total = $add - $reduce;
            $total = sprintf('%.2f', $total / 100);

            $where = [];
            $where[] = ['recharge_money', '<=', $total];
            $info = Db::table('ym_manage.system_treasure_box')
                ->where('delete_at', 0)
                ->where($where)
                ->order('recharge_money desc')
                ->find();

            if ($info) {

                $log = Db::table('ym_manage.recharge_accumulate_log')
                    ->where('userid', $userId)
                    ->where('recharge_money', '<=', $info['recharge_money'])
                    ->where('type', '=', 2)
                    ->order('recharge_money asc')
                    ->find();

                if (empty($log)) {
                    Db::table('ym_manage.recharge_accumulate_log')->insertGetId([
                        'adminid' => Cookie::get('admin_user_id') ?: 1,
                        'userid' => $userId,
                        'createtime' => time(),
                        'recharge_money' => $info['recharge_money'],
                        'total_fee' => $total,
                        'give' => $info['gift_money'],
                        'type' => 2,
                    ]);
                    $give += $info['gift_money'];

                    // 赠送记录
                    Db::table('ym_manage.recharge_give_log')->insertGetId([
                        'user_id' => $userId,
                        'recharge_money' => $recharge,
                        'give' => $info['gift_money'],
                        'type' => 2,
                        'createtime' => date('Y-m-d H:i:s'),
                    ]);
                }
            }
        }
        $give = sprintf('%.2f', $give);
        return $give * 100; // 元转为分
    }
	
}