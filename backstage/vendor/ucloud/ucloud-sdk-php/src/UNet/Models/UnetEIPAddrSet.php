<?php
/**
 * Copyright 2022 UCloud Technology Co., Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
namespace UCloud\UNet\Models;

use UCloud\Core\Response\Response;

class UnetEIPAddrSet extends Response
{
    

    /**
     * OperatorName: 运营商信息如: 电信: Telecom, 联通: Unicom, 国际: International, Duplet: 双线IP（电信+联通), BGP: Bgp
     *
     * @return string|null
     */
    public function getOperatorName()
    {
        return $this->get("OperatorName");
    }

    /**
     * OperatorName: 运营商信息如: 电信: Telecom, 联通: Unicom, 国际: International, Duplet: 双线IP（电信+联通), BGP: Bgp
     *
     * @param string $operatorName
     */
    public function setOperatorName($operatorName)
    {
        $this->set("OperatorName", $operatorName);
    }

    /**
     * IP: IP地址
     *
     * @return string|null
     */
    public function getIP()
    {
        return $this->get("IP");
    }

    /**
     * IP: IP地址
     *
     * @param string $ip
     */
    public function setIP($ip)
    {
        $this->set("IP", $ip);
    }
}
