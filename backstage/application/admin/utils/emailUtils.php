<?php
namespace app\admin\utils;

class emailUtils {
    public static function getEmail($result) {
        foreach ($result as $k => $v) {
            $result[$k]['sendname'] = '系统';
            if ($v['type'] == 999) {
                $result[$k]['username'] = '所有人';
            }
            switch($v['type']) {
                case '999':
                    $result[$k]['typename'] = '群发';
                    break;
                case '2':
                    $result[$k]['typename'] = '私信';
                    break;
            }
        }

        return $result;
    }
}
