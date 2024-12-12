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
namespace UCloud\UEC\Models;

use UCloud\Core\Response\Response;

class FirewallInfo extends Response
{
    

    /**
     * FirewallId: 防火墙Id
     *
     * @return string|null
     */
    public function getFirewallId()
    {
        return $this->get("FirewallId");
    }

    /**
     * FirewallId: 防火墙Id
     *
     * @param string $firewallId
     */
    public function setFirewallId($firewallId)
    {
        $this->set("FirewallId", $firewallId);
    }

    /**
     * Name: 防火墙名称
     *
     * @return string|null
     */
    public function getName()
    {
        return $this->get("Name");
    }

    /**
     * Name: 防火墙名称
     *
     * @param string $name
     */
    public function setName($name)
    {
        $this->set("Name", $name);
    }

    /**
     * CreateTime: 创建时间
     *
     * @return integer|null
     */
    public function getCreateTime()
    {
        return $this->get("CreateTime");
    }

    /**
     * CreateTime: 创建时间
     *
     * @param int $createTime
     */
    public function setCreateTime($createTime)
    {
        $this->set("CreateTime", $createTime);
    }

    /**
     * Rule: 防火墙规则组，详情参见RuleInfo
     *
     * @return RuleInfo[]|null
     */
    public function getRule()
    {
        $items = $this->get("Rule");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new RuleInfo($item));
        }
        return $result;
    }

    /**
     * Rule: 防火墙规则组，详情参见RuleInfo
     *
     * @param RuleInfo[] $rule
     */
    public function setRule(array $rule)
    {
        $result = [];
        foreach ($rule as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * ResourceCount: 防火墙绑定资源数量
     *
     * @return integer|null
     */
    public function getResourceCount()
    {
        return $this->get("ResourceCount");
    }

    /**
     * ResourceCount: 防火墙绑定资源数量
     *
     * @param int $resourceCount
     */
    public function setResourceCount($resourceCount)
    {
        $this->set("ResourceCount", $resourceCount);
    }

    /**
     * Type: 防火墙组类型，枚举值为： "user defined", 用户自定义防火墙； "recommend web", 默认Web防火墙； "recommend non web", 默认非Web防火墙
     *
     * @return string|null
     */
    public function getType()
    {
        return $this->get("Type");
    }

    /**
     * Type: 防火墙组类型，枚举值为： "user defined", 用户自定义防火墙； "recommend web", 默认Web防火墙； "recommend non web", 默认非Web防火墙
     *
     * @param string $type
     */
    public function setType($type)
    {
        $this->set("Type", $type);
    }

    /**
     * Remark: 描述
     *
     * @return string|null
     */
    public function getRemark()
    {
        return $this->get("Remark");
    }

    /**
     * Remark: 描述
     *
     * @param string $remark
     */
    public function setRemark($remark)
    {
        $this->set("Remark", $remark);
    }
}
