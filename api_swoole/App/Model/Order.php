<?php
namespace App\Model;

use App\Model\Model;
use App\Model\Constants\RedisKey;
use App\Model\Constants\MysqlTables;
use App\Utility\Helper;
use EasySwoole\Utility\Random;
use App\Task\MysqlQuery;
use EasySwoole\EasySwoole\Swoole\Task\TaskManager;
use EasySwoole\EasySwoole\Config;
use EasySwoole\EasySwoole\Logger;

class Order extends Model
{
    //获取所有订单记录
    public function getAll($keywords = '', $orderby = '', $stime=0, $etime=0, $page = 0, $username = '') : array
    {
        $curUser = $this->getTokenObj();
        
        $_limit_value = 20;
        $_limit_offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $_limit_value : 0;
        $result = ['total'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $_limit_value, 'list'=> []];
      
        $parentId = isset($account) && $account ? $account['id'] : $curUser->account_id;
        
        //查询字段
        $fieldstrs = '*'; 
        //排序字段
        if ($orderby) {
            list($_od_f, $_od_b) = explode("|", $orderby);
            $_od_b = strtoupper($_od_b);
            if ($_od_f === false || ! $_od_b || ! in_array($_od_b, ['DESC', 'ASC'])) {
                $this->setErrMsg('orderby参数非法');
                return $result;
            }
            $orderby = [$_od_f, $_od_b];
        } else {
            $orderby = ['a.id', 'DESC'];
        }
        //db查询
        $db = $this->mysql->getDb();
        if($stime) {
            $db->where('a.create_time >= '. $stime);
        }
        if($etime) {
            $db->where('a.create_time <= '. $etime);
        }
        if ($keywords) {
            $db->where("a.uid LIKE '%".str_replace('-', '', $keywords)."%' OR a.id LIKE '%{$keywords}%'");
        }
        $ds = $db->orderBy($orderby[0], $orderby[1])->withTotalCount()->get($this->getTable('s_shop_order').' as a', [$_limit_offset, $_limit_value], $fieldstrs);
        //记录总数
        $result['total'] = $db->getTotalCount();
        foreach ($ds as $_p) {
            $_pids[] = $_p['uid'];
            $result['list'][] = $_p;
        }
        if (isset($_pids) && $_pids) {
            if (!! ($_onlines = $this->models->curl_model->getOnlinePlayerOne($_pids))) {
                foreach ($result['list'] as $pk=> $pp) {
                    $result['list'][$pk]['online'] = $_onlines[$pp['uid']] ? 1 : 0;
                }
            }
        }
        return $result;
    }

    /**
     * 根据起始时间，支付状态，支付渠道，用户渠道 统计饼图数据
     */
    public function getPieData($start_time, $end_time, $status=100, $pay_channel=100, $user_channel=100) : array {
        $where = "";
        if($start_time) {
            $where = " where create_time>= {$start_time}";
        }
        if($end_time) {
            if(empty($where)) {
                $where = " where create_time <= {$end_time}";  
            } else {
                $where .= " and create_time <= {$end_time}";
            }
        }
        if($status != 100) {
            if(empty($where)) {
                $where = " where status = {$status}";  
            } else {
                $where .= " and status <= {$status}";
            }
        }
        //支付渠道
        if($pay_channel != 100) {
            if(empty($where)) {
                $where = " where pay_channel = {$pay_channel}";  
            } else {
                $where .= " and pay_channel <= {$pay_channel}";
            }
        }
        //用户渠道
        if($user_channel != 100) {
            if(empty($where)) {
                $where = " where user_channel = {$user_channel}";  
            } else {
                $where .= " and user_channel = {$user_channel}";
            }
        }
        $ret = [];
        $sql = "select title, count(*) as total from " . $this->getTable('s_shop_order') . $where . " group by title ";
        $db = $this->mysql->getDb();
        $data = $db->rawQuery($sql);
        $ret['data1'] = $data;
        $sql2 = "select platform, count(*) as total from " . $this->getTable('s_shop_order') . $where . " group by platform ";
        $data2 = $db->rawQuery($sql2);
        foreach ($data2 as $key => $value) {
            if($value['platform'] == 1) {
                $data2[$key]['platform'] = '安卓';
            } else {
                $data2[$key]['platform'] = 'IOS';
            }
        }
        $ret['data2'] = $data2;
        $result = ['total'=> 0, 'page'=> 1, 'limit'=> 20, 'list'=> []];
        $result['list'] = $ret;
        return $result;
    }

    /**
     * 总充值TOP100的排名
     */
    public function getTopHundred($start_time, $end_time, $pay_channel=100, $user_channel=100) {
        $where = " ";
        if($start_time) {
            $where = " where create_time>= {$start_time}";
        }
        if($end_time) {
            if(empty($where)) {
                $where = " where create_time <= {$end_time}";  
            } else {
                $where .= " and create_time <= {$end_time}";
            }
        }
        //支付渠道
        if($pay_channel != 100) {
            if(empty($where)) {
                $where = " where pay_channel = {$pay_channel}";  
            } else {
                $where .= " and pay_channel = {$pay_channel}";
            }
        }
        //用户渠道
        if($user_channel != 100) {
            if(empty($where)) {
                $where = " where user_channel = {$user_channel}";  
            } else {
                $where .= " and user_channel = {$user_channel}";
            }
        }
        $sql = "select uid, count(*) as total from " . $this->getTable('s_shop_order') . $where . " group by uid ";
        $db = $this->mysql->getDb();
        $data = $db->rawQuery($sql);
        $result = ['total'=> 0, 'page'=> 1, 'limit'=> 20, 'list'=> []];
        $result['list'] = $data;
        return $result;
    }

    //获取转率数据
    public function getConversionRate($start_time, $end_time, $stype) {
        $where = " ";
        if($start_time) {
            $start_date = date('Y-m-d', $start_time);
            $where = " where time>= {$start_date}";
        }
        if($end_time) {
            $end_date = date('Y-m-d', $end_time);
            if(empty($where)) {
                $where = " where time <= {$end_date}";  
            } else {
                $where .= " and time <= {$end_date}";
            }
        }
        if($stype != 100) {
            if(empty($where)) {
                $where = " where stype = {$stype}";  
            } else {
                $where .= " and stype = {$stype}";
            }
        }
        $sql = "select * from stat_shop_day " . $where;
        $db = $this->mysql->getDb();
        $data = $db->rawQuery($sql);
        $result = ['total'=> 0, 'page'=> 1, 'limit'=> 20, 'list'=> []];
        foreach($data as $k=>$v) {
            $data[$k]['showrate'] = 0;
            $data[$k]['payrate'] = 0;
            if($v['orders']) {
                $data[$k]['payrate'] = round($v['pays']/$v['orders']*100,2) . '%'; //付费转换率
            } 
            if($v['times']) {
                $data[$k]['showrate'] = round($v['pays']/$v['times']*100,2) . '%'; //展示的付费转换率
            }
        }
        $result['list'] = $data;
        return $result;
    }
}