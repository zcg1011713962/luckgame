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
namespace UCloud\ULB\Apis;

use UCloud\Core\Response\Response;

class CreateULBResponse extends Response
{
    

    /**
     * ULBId: 负载均衡实例的Id
     *
     * @return string|null
     */
    public function getULBId()
    {
        return $this->get("ULBId");
    }

    /**
     * ULBId: 负载均衡实例的Id
     *
     * @param string $ulbId
     */
    public function setULBId($ulbId)
    {
        $this->set("ULBId", $ulbId);
    }

    /**
     * IPv6AddressId: IPv6地址Id
     *
     * @return string|null
     */
    public function getIPv6AddressId()
    {
        return $this->get("IPv6AddressId");
    }

    /**
     * IPv6AddressId: IPv6地址Id
     *
     * @param string $iPv6AddressId
     */
    public function setIPv6AddressId($iPv6AddressId)
    {
        $this->set("IPv6AddressId", $iPv6AddressId);
    }
}
