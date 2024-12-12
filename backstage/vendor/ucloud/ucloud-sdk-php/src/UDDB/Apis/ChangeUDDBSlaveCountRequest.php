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
namespace UCloud\UDDB\Apis;

use UCloud\Core\Request\Request;

class ChangeUDDBSlaveCountRequest extends Request
{
    public function __construct()
    {
        parent::__construct(["Action" => "ChangeUDDBSlaveCount"]);
        $this->markRequired("Region");
        $this->markRequired("Zone");
        $this->markRequired("ProjectId");
        $this->markRequired("UDDBId");
        $this->markRequired("SlaveCount");
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
     * Zone: 可用区。参见 [可用区列表](../summary/regionlist.html)
     *
     * @return string|null
     */
    public function getZone()
    {
        return $this->get("Zone");
    }

    /**
     * Zone: 可用区。参见 [可用区列表](../summary/regionlist.html)
     *
     * @param string $zone
     */
    public function setZone($zone)
    {
        $this->set("Zone", $zone);
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
     * UDDBId: UDDB资源id
     *
     * @return string|null
     */
    public function getUDDBId()
    {
        return $this->get("UDDBId");
    }

    /**
     * UDDBId: UDDB资源id
     *
     * @param string $uddbId
     */
    public function setUDDBId($uddbId)
    {
        $this->set("UDDBId", $uddbId);
    }

    /**
     * SlaveCount: 每个数据节点的只读实例个数, 取值必须>=0
     *
     * @return string|null
     */
    public function getSlaveCount()
    {
        return $this->get("SlaveCount");
    }

    /**
     * SlaveCount: 每个数据节点的只读实例个数, 取值必须>=0
     *
     * @param string $slaveCount
     */
    public function setSlaveCount($slaveCount)
    {
        $this->set("SlaveCount", $slaveCount);
    }
}
