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

class FirewallRuleSet extends Response
{
    

    /**
     * SrcIP: 源地址
     *
     * @return string|null
     */
    public function getSrcIP()
    {
        return $this->get("SrcIP");
    }

    /**
     * SrcIP: 源地址
     *
     * @param string $srcIP
     */
    public function setSrcIP($srcIP)
    {
        $this->set("SrcIP", $srcIP);
    }

    /**
     * Priority: 优先级
     *
     * @return string|null
     */
    public function getPriority()
    {
        return $this->get("Priority");
    }

    /**
     * Priority: 优先级
     *
     * @param string $priority
     */
    public function setPriority($priority)
    {
        $this->set("Priority", $priority);
    }

    /**
     * ProtocolType: 协议类型
     *
     * @return string|null
     */
    public function getProtocolType()
    {
        return $this->get("ProtocolType");
    }

    /**
     * ProtocolType: 协议类型
     *
     * @param string $protocolType
     */
    public function setProtocolType($protocolType)
    {
        $this->set("ProtocolType", $protocolType);
    }

    /**
     * DstPort: 目标端口
     *
     * @return string|null
     */
    public function getDstPort()
    {
        return $this->get("DstPort");
    }

    /**
     * DstPort: 目标端口
     *
     * @param string $dstPort
     */
    public function setDstPort($dstPort)
    {
        $this->set("DstPort", $dstPort);
    }

    /**
     * RuleAction: 防火墙动作
     *
     * @return string|null
     */
    public function getRuleAction()
    {
        return $this->get("RuleAction");
    }

    /**
     * RuleAction: 防火墙动作
     *
     * @param string $ruleAction
     */
    public function setRuleAction($ruleAction)
    {
        $this->set("RuleAction", $ruleAction);
    }

    /**
     * Remark: 防火墙规则备注
     *
     * @return string|null
     */
    public function getRemark()
    {
        return $this->get("Remark");
    }

    /**
     * Remark: 防火墙规则备注
     *
     * @param string $remark
     */
    public function setRemark($remark)
    {
        $this->set("Remark", $remark);
    }
}
