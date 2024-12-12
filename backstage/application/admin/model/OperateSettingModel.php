<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;

class OperateSettingModel extends Model {

    public function getBlackList($limit = 30, $id = 0) {
        $sql = Db::table('ym_manage.black_list bl')
                ->join('ym_manage.admin ad','bl.admin_id = ad.id')
                ->where('bl.delete_at',0)
                ->field('bl.*, ad.username');
        if (!empty($id)) {
            return $sql->where('bl.id',$id)->find();
        }
        $result = $sql->paginate($limit)->toArray();
        return $result;
    }
    
    public function saveBlack($params) {
        try {
            if (isset($params['id'])) {
                Db::table('ym_manage.black_list')->update($params);
            } else {
                Db::table('ym_manage.black_list')->insert($params);
            }
            return true;
        } catch(\Exception $e) {
            return false;
        }
    }

    public function deleteBlack($id) {
        return Db::table('ym_manage.black_list')->update([
            'id' => $id,
            'delete_at' => time()
        ]);
    }

    public function getLedBanner($limit = 30, $id = 0) {
        $sql = Db::table('gameaccount.server_log')
                ->field('*, FROM_UNIXTIME(begin_time) format_begin_time, FROM_UNIXTIME(end_time) format_end_time');
        if (!empty($id)) {
            return $sql->where('id',$id)->find();
        }
        $result = $sql->paginate($limit)->toArray();
        return $result;
    }

    public function saveLed($params) {
        try {
            if (isset($params['id'])) {
                Db::table('gameaccount.server_log')->update($params);
            } else {
                Db::table('gameaccount.server_log')->insert($params);
            }
            return true;
        } catch(\Exception $e) {
            return false;
        }
    }

    public function deleteLed($id, $stauts) {
        return Db::table('gameaccount.server_log')->update([
            'id' => $id,
            'status' => $stauts
        ]);
    }

    public function getBanner($limit = 30, $id = 0) {
        $sql = Db::table('ym_manage.banner');
        if (!empty($id)) {
            return $sql->where('id',$id)->find();
        }
        $result = $sql->paginate($limit)->toArray();
        return $result;
    }

    public function saveBanner($params) {
        try {
            if (isset($params['id'])) {
                Db::table('ym_manage.banner')->update($params);
            } else {
                Db::table('ym_manage.banner')->insert($params);
            }
            return true;
        } catch(\Exception $e) {
            return false;
        }
    }

    public function deleteBanner($id, $stauts) {
        return Db::table('ym_manage.banner')->update([
            'id' => $id,
            'status' => $stauts
        ]);
    }

}