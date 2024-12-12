<?php
namespace App\Model;

abstract class AbstractModel
{
    /**
     * 设置错误代码
     * @param number $code
     */
    abstract function setErrCode($code = 0) : void;
    /**
     * 获取错误代码
     * @return string
     */
    abstract function getErrCode() : string;
    /**
     * 设置错误消息
     * @param string $msg
     */
    abstract function setErrMsg($msg = '') : void;
    /**
     * 获取错误消息
     * @return string
     */
    abstract function getErrMsg() : array;
    /**
     * 获取错误信息
     * @return string
     */
    abstract function getErrMsgStr() : string;
    /**
     * 设置错误数据
     * @param array $data
     */
    abstract function setErrData($data = []) : void;
    /**
     * 获取错误数据
     * @return array
     */
    abstract function getErrData() : array;
}