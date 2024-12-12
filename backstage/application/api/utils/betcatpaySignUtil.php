<?php
namespace app\api\utils;



class BetcatpaySignUtil{

    const SIGN = 'sign';
    const KEY = 'key';
    const EXT = 'extra';

    public static function create($appSecret, $map) {
        $signStr = self::createSignStr($appSecret, $map);
        return hash('sha256', $signStr);
    }

    public static function createSignStr($appSecret, $map) {
        $signStr = self::joinMap($map);
        $signStr .= '&'. self::KEY . '=' . $appSecret;

        return $signStr;
    }

    private static function prepareMap($map) {
        if (!is_array($map)) {
            return array();
        }

        if (array_key_exists(self::SIGN, $map)) {
            unset($map[self::SIGN]);
        }
        ksort($map);
        reset($map);

        return $map;
    }

    private static function joinMap($map) {
        if (!is_array($map)) {
            return '';
        }

        $map = self::prepareMap($map);
        $pair = array();
        foreach($map as $key => $value) {
            if (self::isIgnoredItem($key, $value)) {
                continue;
            }

            $tmp = $key . '=';
            if(0 === strcmp(self::EXT, $key)) {
                 $tmp .= self::joinMap($value);
            } else {
                $tmp .= $value;
            }

            $pair[] = $tmp;
        }

        if (empty($pair)) {
            return '';
        }

        return join('&', $pair);
    }

    private static function isIgnoredItem($key, $value) {
        if (empty($key) || empty($value)) {
            return true;
        }

        if (0 === strcmp(self::SIGN, $key)) {
            return true;
        }

        if (0 === strcmp(self::EXT, $key)) {
            return false;
        }

        if (is_string($value)) {
            return false;
        }
        
        if (is_numeric($value)) {
            return false;
        }

        if (is_bool($value)) {
            return false;
        }
         
        return true;
    }
}
?>
