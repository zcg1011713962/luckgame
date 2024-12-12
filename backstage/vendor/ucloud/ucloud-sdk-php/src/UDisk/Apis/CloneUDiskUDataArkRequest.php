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
namespace UCloud\UDisk\Apis;

use UCloud\Core\Request\Request;

class CloneUDiskUDataArkRequest extends Request
{
    public function __construct()
    {
        parent::__construct(["Action" => "CloneUDiskUDataArk"]);
        $this->markRequired("Region");
        $this->markRequired("Zone");
        $this->markRequired("Name");
        $this->markRequired("UDiskId");
        $this->markRequired("SnapshotTime");
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
     * Name: 实例名称
     *
     * @return string|null
     */
    public function getName()
    {
        return $this->get("Name");
    }

    /**
     * Name: 实例名称
     *
     * @param string $name
     */
    public function setName($name)
    {
        $this->set("Name", $name);
    }

    /**
     * UDiskId: 需要克隆的源盘id
     *
     * @return string|null
     */
    public function getUDiskId()
    {
        return $this->get("UDiskId");
    }

    /**
     * UDiskId: 需要克隆的源盘id
     *
     * @param string $uDiskId
     */
    public function setUDiskId($uDiskId)
    {
        $this->set("UDiskId", $uDiskId);
    }

    /**
     * SnapshotTime: 指定从方舟克隆的备份时间点
     *
     * @return integer|null
     */
    public function getSnapshotTime()
    {
        return $this->get("SnapshotTime");
    }

    /**
     * SnapshotTime: 指定从方舟克隆的备份时间点
     *
     * @param int $snapshotTime
     */
    public function setSnapshotTime($snapshotTime)
    {
        $this->set("SnapshotTime", $snapshotTime);
    }

    /**
     * Comment: Disk注释
     *
     * @return string|null
     */
    public function getComment()
    {
        return $this->get("Comment");
    }

    /**
     * Comment: Disk注释
     *
     * @param string $comment
     */
    public function setComment($comment)
    {
        $this->set("Comment", $comment);
    }

    /**
     * ChargeType: Year , Month, Dynamic，Postpay 默认: Dynamic
     *
     * @return string|null
     */
    public function getChargeType()
    {
        return $this->get("ChargeType");
    }

    /**
     * ChargeType: Year , Month, Dynamic，Postpay 默认: Dynamic
     *
     * @param string $chargeType
     */
    public function setChargeType($chargeType)
    {
        $this->set("ChargeType", $chargeType);
    }

    /**
     * Quantity: 购买时长 默认: 1
     *
     * @return integer|null
     */
    public function getQuantity()
    {
        return $this->get("Quantity");
    }

    /**
     * Quantity: 购买时长 默认: 1
     *
     * @param int $quantity
     */
    public function setQuantity($quantity)
    {
        $this->set("Quantity", $quantity);
    }

    /**
     * UDataArkMode: 【开启数据方舟入口已关闭】是否开启数据方舟。Yes：开启，No：不开启，默认值：No
     *
     * @return string|null
     */
    public function getUDataArkMode()
    {
        return $this->get("UDataArkMode");
    }

    /**
     * UDataArkMode: 【开启数据方舟入口已关闭】是否开启数据方舟。Yes：开启，No：不开启，默认值：No
     *
     * @param string $uDataArkMode
     */
    public function setUDataArkMode($uDataArkMode)
    {
        $this->set("UDataArkMode", $uDataArkMode);
    }

    /**
     * SnapshotService: 是否开启快照服务（开启快照服务，可免费开启数据方舟）。Yes：开启，No：不开启，默认值：No
     *
     * @return string|null
     */
    public function getSnapshotService()
    {
        return $this->get("SnapshotService");
    }

    /**
     * SnapshotService: 是否开启快照服务（开启快照服务，可免费开启数据方舟）。Yes：开启，No：不开启，默认值：No
     *
     * @param string $snapshotService
     */
    public function setSnapshotService($snapshotService)
    {
        $this->set("SnapshotService", $snapshotService);
    }

    /**
     * Size: 购买UDisk大小,单位:GB,范围[1~8000]。(UDisk大小设定对本地盘备份有效，对云盘备份无效)
     *
     * @return integer|null
     */
    public function getSize()
    {
        return $this->get("Size");
    }

    /**
     * Size: 购买UDisk大小,单位:GB,范围[1~8000]。(UDisk大小设定对本地盘备份有效，对云盘备份无效)
     *
     * @param int $size
     */
    public function setSize($size)
    {
        $this->set("Size", $size);
    }

    /**
     * Tag: 业务组 默认：Default
     *
     * @return string|null
     */
    public function getTag()
    {
        return $this->get("Tag");
    }

    /**
     * Tag: 业务组 默认：Default
     *
     * @param string $tag
     */
    public function setTag($tag)
    {
        $this->set("Tag", $tag);
    }

    /**
     * RdmaClusterId: RDMA集群id。指定RSSD云盘克隆到对应的RDMA集群。
     *
     * @return string|null
     */
    public function getRdmaClusterId()
    {
        return $this->get("RdmaClusterId");
    }

    /**
     * RdmaClusterId: RDMA集群id。指定RSSD云盘克隆到对应的RDMA集群。
     *
     * @param string $rdmaClusterId
     */
    public function setRdmaClusterId($rdmaClusterId)
    {
        $this->set("RdmaClusterId", $rdmaClusterId);
    }

    /**
     * HostId: Host实例ID。克隆出的云盘可直接挂载到该主机上。
     *
     * @return string|null
     */
    public function getHostId()
    {
        return $this->get("HostId");
    }

    /**
     * HostId: Host实例ID。克隆出的云盘可直接挂载到该主机上。
     *
     * @param string $hostId
     */
    public function setHostId($hostId)
    {
        $this->set("HostId", $hostId);
    }

    /**
     * CouponId: 使用的代金券id
     *
     * @return string|null
     */
    public function getCouponId()
    {
        return $this->get("CouponId");
    }

    /**
     * CouponId: 使用的代金券id
     *
     * @param string $couponId
     */
    public function setCouponId($couponId)
    {
        $this->set("CouponId", $couponId);
    }
}
