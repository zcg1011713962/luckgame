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

class DescribeWhiteListResourceRequest extends Request
{
    public function __construct()
    {
        parent::__construct(["Action" => "DescribeWhiteListResource"]);
        $this->markRequired("ProjectId");
        $this->markRequired("Region");
        $this->markRequired("NATGWIds");
    }

    

    /**
     * ProjectId: 项目id
     *
     * @return string|null
     */
    public function getProjectId()
    {
        return $this->get("ProjectId");
    }

    /**
     * ProjectId: 项目id
     *
     * @param string $projectId
     */
    public function setProjectId($projectId)
    {
        $this->set("ProjectId", $projectId);
    }

    /**
     * Region: 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *
     * @return string|null
     */
    public function getRegion()
    {
        return $this->get("Region");
    }

    /**
     * Region: 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *
     * @param string $region
     */
    public function setRegion($region)
    {
        $this->set("Region", $region);
    }

    /**
     * NATGWIds: NAT网关的Id
     *
     * @return string[]|null
     */
    public function getNATGWIds()
    {
        return $this->get("NATGWIds");
    }

    /**
     * NATGWIds: NAT网关的Id
     *
     * @param string[] $natgwIds
     */
    public function setNATGWIds(array $natgwIds)
    {
        $this->set("NATGWIds", $natgwIds);
    }

    /**
     * Offset: 数据偏移量, 默认为0
     *
     * @return integer|null
     */
    public function getOffset()
    {
        return $this->get("Offset");
    }

    /**
     * Offset: 数据偏移量, 默认为0
     *
     * @param int $offset
     */
    public function setOffset($offset)
    {
        $this->set("Offset", $offset);
    }

    /**
     * Limit: 数据分页值, 默认为20
     *
     * @return integer|null
     */
    public function getLimit()
    {
        return $this->get("Limit");
    }

    /**
     * Limit: 数据分页值, 默认为20
     *
     * @param int $limit
     */
    public function setLimit($limit)
    {
        $this->set("Limit", $limit);
    }
}
