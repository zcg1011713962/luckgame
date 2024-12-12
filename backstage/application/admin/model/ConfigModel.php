<?php
namespace app\admin\model;
use think\Model;
use think\Db;

class ConfigModel extends Model
{
				
	public function getConfig($flag){
		if(empty($flag)){ return false; }
		$config = Db::table('ym_manage.config')->where('flag',$flag)->find();		
		return $config;
	}

	public function setConfig($flag,$value){
		if(empty($flag)){ return false; }
		$rs = Db::table('ym_manage.config')->where('flag',$flag)->data([ 'value' => $value ])->update();	
		return $rs;
	}

	public static function getSystemConfig() {
		$configArr = ['SystemTitle','SystemUrl','GameServiceApi','GameLoginUrl','SignKey','SignKey_nongfu','PrivateKey','GameServiceKey','PaymentKey','PaymentAnother','MchId', 'WithdrawalChannel'];
        $configRes = Db::table('ym_manage.config')->where([
            'name' => $configArr
        ])->select();
        $config = [];
        foreach ($configRes as $k => $v) {
            $config[$v['name']] = $v['value'];
        }
		return $config;
	}

	public static function setSystemConfig($params) {
		foreach ($params as $k => $v) {
            Db::table('ym_manage.config')->where('name',$k)->update(['value' => $v]);
        }
	}

	public static function getIcon() {
		return Db::table('ym_manage.config')->where('name','GameIcon')->value('value');
	}

	public static function getPayScale() {
		return json_decode(Db::table('ym_manage.config')->where('name','PayScale')->value('value'),true);
	}

	public static function getGameConfig($name) {
		return json_decode(Db::table('ym_manage.config')->where('name',"{$name}")->value('value'),true);
	}

	public static function saveIcon($actName, $iconUrl) {
		$iconList = self::getIcon();
		if (!$iconList) {
			$iconListArr = [];
		} else {
			$iconListArr = json_decode($iconList,true);
		}
		$iconListArr[$actName] = $iconUrl;
		Db::table('ym_manage.config')->where('name','GameIcon')->update(['value' => json_encode($iconListArr)]);
	}

	public static function setPayConfig($params) {

		$paramsData = ['cash' => floatval($params['cashScale']), 'payment' => floatval($params['paymentScale']), 'givecommission' => intval($params['givecommission']), 'taxation' => intval($params['taxation'])];
		Db::table('ym_manage.config')->where('name','PayScale')->update(['value' => json_encode($paramsData)]);
	}


    /**
     * 充值赠送列表
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public static function getRechargeGiftList($where, $limit = 20)
    {
        $list = Db::table('ym_manage.system_recharge_gift')
            ->where('delete_at', '=', 0)
            ->where($where)
            ->order('id','DESC')
            ->paginate($limit)->toArray();

        return $list;
    }

    /**
     * 添加充值赠送记录
     * @param $data
     * @return int|string
     */
    public static function saveRechargeGift($data)
    {
        return Db::table('ym_manage.system_recharge_gift')->insertGetId($data);
    }

    public static function delRechargeGift($id)
    {
        return Db::table('ym_manage.system_recharge_gift')->where('id', $id)->update([
            'delete_at' => time()
        ]);
    }

    /**
     * 充值赠送列表
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public static function getRechargeBoxList($where, $limit = 20)
    {
        $list = Db::table('ym_manage.system_treasure_box')
            ->where('delete_at', '=', 0)
            ->where($where)
            ->order('id','DESC')
            ->paginate($limit)->toArray();

        return $list;
    }

    /**
     * 添加充值赠送记录
     * @param $data
     * @return int|string
     */
    public static function saveRechargeBox($data)
    {
        return Db::table('ym_manage.system_treasure_box')->insertGetId($data);
    }

    public static function delRechargeBox($id)
    {
        return Db::table('ym_manage.system_treasure_box')->where('id', $id)->update([
            'delete_at' => time()
        ]);
    }

}