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
namespace UCloud\VPC\Apis;

use UCloud\Core\Request\Request;

class DescribeSubnetRequest extends Request
{
    public function __construct()
    {
        parent::__construct(["Action" => "DescribeSubnet"]);
        $this->markRequired("Region");
    }

    

    /**
     * Region: 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *
     * @return string|null
     */
    public function getRegion()
    {
        return $this->get("Region");
    }

    /**
     * Region: 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *
     * @param string $region
     */
    public function setRegion($region)
    {
        $this->set("Region", $region);
    }

    /**
     * ProjectId: 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *
     * @return string|null
     */
    public function getProjectId()
    {
        return $this->get("ProjectId");
    }

    /**
     * ProjectId: 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *
     * @param string $projectId
     */
    public function setProjectId($projectId)
    {
        $this->set("ProjectId", $projectId);
    }

    /**
     * SubnetIds: 子网id数组，适用于一次查询多个子网信息
     *
     * @return string[]|null
     */
    public function getSubnetIds()
    {
        return $this->get("SubnetIds");
    }

    /**
     * SubnetIds: 子网id数组，适用于一次查询多个子网信息
     *
     * @param string[] $subnetIds
     */
    public function setSubnetIds(array $subnetIds)
    {
        $this->set("SubnetIds", $subnetIds);
    }

    /**
     * SubnetId: 子网id，适用于一次查询一个子网信息
     *
     * @return string|null
     */
    public function getSubnetId()
    {
        return $this->get("SubnetId");
    }

    /**
     * SubnetId: 子网id，适用于一次查询一个子网信息
     *
     * @param string $subnetId
     */
    public function setSubnetId($subnetId)
    {
        $this->set("SubnetId", $subnetId);
    }

    /**
     * RouteTableId: 路由表Id
     *
     * @return string|null
     */
    public function getRouteTableId()
    {
        return $this->get("RouteTableId");
    }

    /**
     * RouteTableId: 路由表Id
     *
     * @param string $routeTableId
     */
    public function setRouteTableId($routeTableId)
    {
        $this->set("RouteTableId", $routeTableId);
    }

    /**
     * VPCId: VPC资源id
     *
     * @return string|null
     */
    public function getVPCId()
    {
        return $this->get("VPCId");
    }

    /**
     * VPCId: VPC资源id
     *
     * @param string $vpcId
     */
    public function setVPCId($vpcId)
    {
        $this->set("VPCId", $vpcId);
    }

    /**
     * Tag: 业务组名称，默认为Default
     *
     * @return string|null
     */
    public function getTag()
    {
        return $this->get("Tag");
    }

    /**
     * Tag: 业务组名称，默认为Default
     *
     * @param string $tag
     */
    public function setTag($tag)
    {
        $this->set("Tag", $tag);
    }

    /**
     * Offset: 偏移量，默认为0
     *
     * @return integer|null
     */
    public function getOffset()
    {
        return $this->get("Offset");
    }

    /**
     * Offset: 偏移量，默认为0
     *
     * @param int $offset
     */
    public function setOffset($offset)
    {
        $this->set("Offset", $offset);
    }

    /**
     * Limit: 列表长度，默认为20
     *
     * @return integer|null
     */
    public function getLimit()
    {
        return $this->get("Limit");
    }

    /**
     * Limit: 列表长度，默认为20
     *
     * @param int $limit
     */
    public function setLimit($limit)
    {
        $this->set("Limit", $limit);
    }

    /**
     * ShowAvailableIPs: 是否返回子网的可用IP数，true为是，false为否，默认不返回
     *
     * @return boolean|null
     */
    public function getShowAvailableIPs()
    {
        return $this->get("ShowAvailableIPs");
    }

    /**
     * ShowAvailableIPs: 是否返回子网的可用IP数，true为是，false为否，默认不返回
     *
     * @param boolean $showAvailableIPs
     */
    public function setShowAvailableIPs($showAvailableIPs)
    {
        $this->set("ShowAvailableIPs", $showAvailableIPs);
    }
}
