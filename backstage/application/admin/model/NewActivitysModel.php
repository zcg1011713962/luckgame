<?php
namespace app\admin\model;
use think\Model;
use think\Db;

class NewActivitysModel extends Model {

    // 获取活动类型
    public function getActivityType() {
        return Db::table('ym_manage.activity_type')->where('status',0)->select();
    }

    // 获取活动列表
    public function getActivityList($limit = 30, $operator_id = 0, $status = 99, $value = '', $id = 0) {

        $sql = Db::table('ym_manage.activity a')
            ->field('a.*,at.name as typename,ad.username')
            ->join('ym_manage.activity_type at','a.type = at.id')
            ->join('ym_manage.admin ad','a.operator_id = ad.id')
            ->order('sort','desc');

        if (!empty($operator_id)) {
           $sql->where('a.operator_id',$operator_id);
        }
        if ($status != 99) {
            $sql->where('a.status',$status);
        }
        if (!empty($value)) {
            $sql->where('a.name','like',"%{$value}%");
        }

        if (!empty($id)) {
            $sql->where('a.id',$id);
            return $sql->find();
        }

        return $sql->paginate($limit)->toArray();
    }

    // 保存活动内容
    public function saveActivity($params) {
        try {
            if ($params['image'] == 'undefined') {
                unset($params['image']);
            }
            if (isset($params['id'])) {
                Db::table('ym_manage.activity')->update($params);
            } else {
                Db::table('ym_manage.activity')->insert($params);
            }
            return true;
        } catch(\Exception $e) {
            return false;
        }
    }

    // 删除活动内容
    public function deleteActivity($params) {
        try {
            Db::table('ym_manage.activity')->update(['status' => $params['status'], 'id' => $params['Id']]);
            return true;
        } catch(\Exception $e) {
            return false;
        }
    }
    
    // 获取活动类型列表
    public function getActivityTypeList($limit = 30, $id = 0) {
        $sql = Db::table('ym_manage.activity_type');
        if (!empty($id)) {
            $sql->where('id',$id);
            return $sql->find();
        }
        return $sql->paginate($limit)->toArray();
    }

    // 删除活动类型
    public function deleteActivityType($params) {
        try {
            Db::table('ym_manage.activity_type')->update(['status' => $params['status'], 'id' => $params['Id']]);
            return true;
        } catch(\Exception $e) {
            return false;
        }
    }

    // 获取活动类型详细规则列表
    public function getActivityTypeInfo($templet) {
        return Db::table('ym_manage.'.$templet)->select();
    }

    // 保存活动类型数据
    public function saveActivityType($params, $son_operate) {
        try {

            // 主表跟新规则
            $update = [
                'id' => $params['id'],
                'begin_time' => $params['begin_time'],
                'end_time' => $params['end_time'],
                'win_statement_amount' => $params['win_statement_amount']
            ];
            if ($params['tem'] == 'activity_infomation_dayreward') {
                $update['minimum_recharge_amount'] = $params['minimum_recharge_amount'];
            }

            // 更新活动类型主表 
            Db::table('ym_manage.activity_type')->update($update);

            if ($son_operate == 'delete') {
                Db::table('ym_manage.'.$params['tem'])->delete(true);
                Db::table('ym_manage.'.$params['tem'])->insertAll($params['map_data']);
            }

            if ($son_operate == 'update') {
                // 子表更新
                foreach ($params['map_data'] as $v) {
                    Db::table('ym_manage.'.$params['tem'])->update($v);
                }
            }
            
            return true;

        } catch(\Exception $e) {
            return false;
        }
    }
}