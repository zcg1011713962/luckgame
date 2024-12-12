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
namespace UCloud\ULB\Models;

use UCloud\Core\Response\Response;

class FirewallSet extends Response
{
    

    /**
     * FirewallName: 防火墙名称
     *
     * @return string|null
     */
    public function getFirewallName()
    {
        return $this->get("FirewallName");
    }

    /**
     * FirewallName: 防火墙名称
     *
     * @param string $firewallName
     */
    public function setFirewallName($firewallName)
    {
        $this->set("FirewallName", $firewallName);
    }

    /**
     * FirewallId: 防火墙ID
     *
     * @return string|null
     */
    public function getFirewallId()
    {
        return $this->get("FirewallId");
    }

    /**
     * FirewallId: 防火墙ID
     *
     * @param string $firewallId
     */
    public function setFirewallId($firewallId)
    {
        $this->set("FirewallId", $firewallId);
    }
}
