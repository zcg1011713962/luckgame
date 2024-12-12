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
namespace UCloud\UHost\Apis;

use UCloud\Core\Request\Request;

class GetAttachedDiskUpgradePriceRequest extends Request
{
    public function __construct()
    {
        parent::__construct(["Action" => "GetAttachedDiskUpgradePrice"]);
        $this->markRequired("Region");
        $this->markRequired("DiskSpace");
        $this->markRequired("DiskId");
        $this->markRequired("UHostId");
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
     * Zone: 可用区。参见 [可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *
     * @return string|null
     */
    public function getZone()
    {
        return $this->get("Zone");
    }

    /**
     * Zone: 可用区。参见 [可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *
     * @param string $zone
     */
    public function setZone($zone)
    {
        $this->set("Zone", $zone);
    }

    /**
     * ProjectId: 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *
     * @return string|null
     */
    public function getProjectId()
    {
        return $this->get("ProjectId");
    }

    /**
     * ProjectId: 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *
     * @param string $projectId
     */
    public function setProjectId($projectId)
    {
        $this->set("ProjectId", $projectId);
    }

    /**
     * DiskSpace: 磁盘大小，单位GB，步长为10。取值范围需大于当前磁盘大小，最大值请参考[[api:uhost-api:disk_type|磁盘类型]]。
     *
     * @return integer|null
     */
    public function getDiskSpace()
    {
        return $this->get("DiskSpace");
    }

    /**
     * DiskSpace: 磁盘大小，单位GB，步长为10。取值范围需大于当前磁盘大小，最大值请参考[[api:uhost-api:disk_type|磁盘类型]]。
     *
     * @param int $diskSpace
     */
    public function setDiskSpace($diskSpace)
    {
        $this->set("DiskSpace", $diskSpace);
    }

    /**
     * DiskId: 磁盘ID。参见 [DescribeUHostInstance](describe_uhost_instance.html)返回值中的DiskSet。
     *
     * @return string|null
     */
    public function getDiskId()
    {
        return $this->get("DiskId");
    }

    /**
     * DiskId: 磁盘ID。参见 [DescribeUHostInstance](describe_uhost_instance.html)返回值中的DiskSet。
     *
     * @param string $diskId
     */
    public function setDiskId($diskId)
    {
        $this->set("DiskId", $diskId);
    }

    /**
     * UHostId: UHost实例ID。 参见 [DescribeUHostInstance](describe_uhost_instance.html)。
     *
     * @return string|null
     */
    public function getUHostId()
    {
        return $this->get("UHostId");
    }

    /**
     * UHostId: UHost实例ID。 参见 [DescribeUHostInstance](describe_uhost_instance.html)。
     *
     * @param string $uHostId
     */
    public function setUHostId($uHostId)
    {
        $this->set("UHostId", $uHostId);
    }

    /**
     * BackupMode: 磁盘备份方案。枚举值：\\ > NONE，无备份 \\ > DATAARK，数据方舟 \\> SNAPSHOT(SNAPSHOT模式目前仅在上海C支持)，快照 \\ 当前磁盘支持的备份模式参考 [[api:uhost-api:disk_type|磁盘类型]]。默认值为当前的备份模式。
     *
     * @return string|null
     */
    public function getBackupMode()
    {
        return $this->get("BackupMode");
    }

    /**
     * BackupMode: 磁盘备份方案。枚举值：\\ > NONE，无备份 \\ > DATAARK，数据方舟 \\> SNAPSHOT(SNAPSHOT模式目前仅在上海C支持)，快照 \\ 当前磁盘支持的备份模式参考 [[api:uhost-api:disk_type|磁盘类型]]。默认值为当前的备份模式。
     *
     * @param string $backupMode
     */
    public function setBackupMode($backupMode)
    {
        $this->set("BackupMode", $backupMode);
    }
}
