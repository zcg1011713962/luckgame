<?php

namespace app\admin\utils;

/**
 * 数据处理扩展
 * Class DataExtend
 * @package think\admin\extend
 */
class DataExtend
{
    /**
     * 一维数组转多维数据树
     * @param array $its 待处理数据
     * @param string $cid 自己的主键
     * @param string $pid 上级的主键
     * @param string $sub 子数组名称
     * @return array
     */
    public static function arr2tree(array $its, $cid = 'id', $pid = 'pid', $sub = 'sub')
    {
        //[$tree, $its] = [[], array_column($its, null, $cid)];
		$tree = [];
		$its = array_column($its, null, $cid);
        foreach ($its as $it) isset($its[$it[$pid]]) ? $its[$it[$pid]][$sub][] = &$its[$it[$cid]] : $tree[] = &$its[$it[$cid]];
        return $tree;
    }

    /**
     * 一维数组转数据树表
     * @param array $its 待处理数据
     * @param string $cid 自己的主键
     * @param string $pid 上级的主键
     * @param string $path 当前 PATH
     * @return array
     */
    public static function arr2table(array $its, $cid = 'id', $pid = 'pid', $path = 'path')
    {
        $call = function (array $its, callable $call, array &$data = [], $parent = '') use ($cid, $pid, $path) {
            foreach ($its as $it) {
                $ts = empty($it['sub']) ? [] : $it['sub'];
                unset($it['sub']);
                $it[$path] = "{$parent}-{$it[$cid]}";
                $it['spc'] = count($ts);
                $it['spt'] = substr_count($parent, '-');
                $it['spl'] = str_repeat('ㅤ├ㅤ', $it['spt']);
                $it['sps'] = ",{$it[$cid]},";
                array_walk_recursive($ts, function ($val, $key) use ($cid, &$it) {
                    if ($key === $cid) $it['sps'] .= "{$val},";
                });
                $it['spp'] = arr2str(str2arr(strtr($parent . $it['sps'], '-', ',')));
                $data[] = $it;
                if (empty($ts)) continue;
                $call($ts, $call, $data, $it[$path]);
            }
            return $data;
        };
        return $call(static::arr2tree($its, $cid, $pid), $call);
    }

    /**
     * 获取数据树子ID集合
     * @param array $list 数据列表
     * @param mixed $value 起始有效ID值
     * @param string $ckey 当前主键ID名称
     * @param string $pkey 上级主键ID名称
     * @return array
     */
    public static function getArrSubIds(array $list, $value = 0, $ckey = 'id', $pkey = 'pid')
    {
        $ids = [intval($value)];
        foreach ($list as $vo) if (intval($vo[$pkey]) > 0 && intval($vo[$pkey]) === intval($value)) {
            $ids = array_merge($ids, static::getArrSubIds($list, intval($vo[$ckey]), $ckey, $pkey));
        }
        return $ids;
    }
}