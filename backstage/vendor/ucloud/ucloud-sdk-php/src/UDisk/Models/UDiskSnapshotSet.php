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
namespace UCloud\UDisk\Models;

use UCloud\Core\Response\Response;

class UDiskSnapshotSet extends Response
{
    

    /**
     * Zone: 可用区
     *
     * @return string|null
     */
    public function getZone()
    {
        return $this->get("Zone");
    }

    /**
     * Zone: 可用区
     *
     * @param string $zone
     */
    public function setZone($zone)
    {
        $this->set("Zone", $zone);
    }

    /**
     * SnapshotId: 快照Id
     *
     * @return string|null
     */
    public function getSnapshotId()
    {
        return $this->get("SnapshotId");
    }

    /**
     * SnapshotId: 快照Id
     *
     * @param string $snapshotId
     */
    public function setSnapshotId($snapshotId)
    {
        $this->set("SnapshotId", $snapshotId);
    }

    /**
     * Name: 快照名称
     *
     * @return string|null
     */
    public function getName()
    {
        return $this->get("Name");
    }

    /**
     * Name: 快照名称
     *
     * @param string $name
     */
    public function setName($name)
    {
        $this->set("Name", $name);
    }

    /**
     * UDiskId: 快照的源UDisk的Id
     *
     * @return string|null
     */
    public function getUDiskId()
    {
        return $this->get("UDiskId");
    }

    /**
     * UDiskId: 快照的源UDisk的Id
     *
     * @param string $uDiskId
     */
    public function setUDiskId($uDiskId)
    {
        $this->set("UDiskId", $uDiskId);
    }

    /**
     * UDiskName: 快照的源UDisk的Name
     *
     * @return string|null
     */
    public function getUDiskName()
    {
        return $this->get("UDiskName");
    }

    /**
     * UDiskName: 快照的源UDisk的Name
     *
     * @param string $uDiskName
     */
    public function setUDiskName($uDiskName)
    {
        $this->set("UDiskName", $uDiskName);
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
     * Size: 容量单位GB
     *
     * @return integer|null
     */
    public function getSize()
    {
        return $this->get("Size");
    }

    /**
     * Size: 容量单位GB
     *
     * @param int $size
     */
    public function setSize($size)
    {
        $this->set("Size", $size);
    }

    /**
     * Status: 快照状态，Normal:正常,Failed:失败,Creating:制作中
     *
     * @return string|null
     */
    public function getStatus()
    {
        return $this->get("Status");
    }

    /**
     * Status: 快照状态，Normal:正常,Failed:失败,Creating:制作中
     *
     * @param string $status
     */
    public function setStatus($status)
    {
        $this->set("Status", $status);
    }

    /**
     * DiskType: 磁盘类型，0：普通数据盘；1：普通系统盘；2：SSD数据盘；3：SSD系统盘；4：RSSD数据盘；5：RSSD系统盘。
     *
     * @return integer|null
     */
    public function getDiskType()
    {
        return $this->get("DiskType");
    }

    /**
     * DiskType: 磁盘类型，0：普通数据盘；1：普通系统盘；2：SSD数据盘；3：SSD系统盘；4：RSSD数据盘；5：RSSD系统盘。
     *
     * @param int $diskType
     */
    public function setDiskType($diskType)
    {
        $this->set("DiskType", $diskType);
    }

    /**
     * ExpiredTime: 过期时间
     *
     * @return integer|null
     */
    public function getExpiredTime()
    {
        return $this->get("ExpiredTime");
    }

    /**
     * ExpiredTime: 过期时间
     *
     * @param int $expiredTime
     */
    public function setExpiredTime($expiredTime)
    {
        $this->set("ExpiredTime", $expiredTime);
    }

    /**
     * Comment: 快照描述
     *
     * @return string|null
     */
    public function getComment()
    {
        return $this->get("Comment");
    }

    /**
     * Comment: 快照描述
     *
     * @param string $comment
     */
    public function setComment($comment)
    {
        $this->set("Comment", $comment);
    }

    /**
     * IsUDiskAvailable: 对应磁盘是否处于可用状态
     *
     * @return boolean|null
     */
    public function getIsUDiskAvailable()
    {
        return $this->get("IsUDiskAvailable");
    }

    /**
     * IsUDiskAvailable: 对应磁盘是否处于可用状态
     *
     * @param boolean $isUDiskAvailable
     */
    public function setIsUDiskAvailable($isUDiskAvailable)
    {
        $this->set("IsUDiskAvailable", $isUDiskAvailable);
    }

    /**
     * Version: 快照版本
     *
     * @return string|null
     */
    public function getVersion()
    {
        return $this->get("Version");
    }

    /**
     * Version: 快照版本
     *
     * @param string $version
     */
    public function setVersion($version)
    {
        $this->set("Version", $version);
    }

    /**
     * UHostId: 对应磁盘制作快照时所挂载的主机
     *
     * @return string|null
     */
    public function getUHostId()
    {
        return $this->get("UHostId");
    }

    /**
     * UHostId: 对应磁盘制作快照时所挂载的主机
     *
     * @param string $uHostId
     */
    public function setUHostId($uHostId)
    {
        $this->set("UHostId", $uHostId);
    }

    /**
     * UKmsMode: 是否是加密盘快照，是:"Yes", 否:"No"
     *
     * @return string|null
     */
    public function getUKmsMode()
    {
        return $this->get("UKmsMode");
    }

    /**
     * UKmsMode: 是否是加密盘快照，是:"Yes", 否:"No"
     *
     * @param string $uKmsMode
     */
    public function setUKmsMode($uKmsMode)
    {
        $this->set("UKmsMode", $uKmsMode);
    }

    /**
     * CmkId: 该快照的cmk id
     *
     * @return string|null
     */
    public function getCmkId()
    {
        return $this->get("CmkId");
    }

    /**
     * CmkId: 该快照的cmk id
     *
     * @param string $cmkId
     */
    public function setCmkId($cmkId)
    {
        $this->set("CmkId", $cmkId);
    }

    /**
     * DataKey: 该快照的密文密钥
     *
     * @return string|null
     */
    public function getDataKey()
    {
        return $this->get("DataKey");
    }

    /**
     * DataKey: 该快照的密文密钥
     *
     * @param string $dataKey
     */
    public function setDataKey($dataKey)
    {
        $this->set("DataKey", $dataKey);
    }

    /**
     * CmkIdStatus: 该快照cmk的状态, Enabled(正常)，Disabled(失效)，Deleted(删除)，NoCmkId(非加密盘)
     *
     * @return string|null
     */
    public function getCmkIdStatus()
    {
        return $this->get("CmkIdStatus");
    }

    /**
     * CmkIdStatus: 该快照cmk的状态, Enabled(正常)，Disabled(失效)，Deleted(删除)，NoCmkId(非加密盘)
     *
     * @param string $cmkIdStatus
     */
    public function setCmkIdStatus($cmkIdStatus)
    {
        $this->set("CmkIdStatus", $cmkIdStatus);
    }

    /**
     * CmkIdAlias: cmk id 别名
     *
     * @return string|null
     */
    public function getCmkIdAlias()
    {
        return $this->get("CmkIdAlias");
    }

    /**
     * CmkIdAlias: cmk id 别名
     *
     * @param string $cmkIdAlias
     */
    public function setCmkIdAlias($cmkIdAlias)
    {
        $this->set("CmkIdAlias", $cmkIdAlias);
    }
}
