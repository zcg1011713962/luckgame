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

class ReinstallUHostInstanceRequest extends Request
{
    public function __construct()
    {
        parent::__construct(["Action" => "ReinstallUHostInstance"]);
        $this->markRequired("Region");
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
     * UHostId: UHost实例资源ID 参见 [DescribeUHostInstance](describe_uhost_instance.html)
     *
     * @return string|null
     */
    public function getUHostId()
    {
        return $this->get("UHostId");
    }

    /**
     * UHostId: UHost实例资源ID 参见 [DescribeUHostInstance](describe_uhost_instance.html)
     *
     * @param string $uHostId
     */
    public function setUHostId($uHostId)
    {
        $this->set("UHostId", $uHostId);
    }

    /**
     * Password: 如果重装UHost实例时LoginMode为Password，则必须填写，如果LoginMode为KeyPair，不需要填写 （密码格式使用BASE64编码；举例如下：# echo -n Password1 | base64UGFzc3dvcmQx。）
     *
     * @return string|null
     */
    public function getPassword()
    {
        return $this->get("Password");
    }

    /**
     * Password: 如果重装UHost实例时LoginMode为Password，则必须填写，如果LoginMode为KeyPair，不需要填写 （密码格式使用BASE64编码；举例如下：# echo -n Password1 | base64UGFzc3dvcmQx。）
     *
     * @param string $password
     */
    public function setPassword($password)
    {
        $this->set("Password", $password);
    }

    /**
     * ImageId: 镜像Id，默认使用原镜像 参见 [DescribeImage](describe_image.html)
     *
     * @return string|null
     */
    public function getImageId()
    {
        return $this->get("ImageId");
    }

    /**
     * ImageId: 镜像Id，默认使用原镜像 参见 [DescribeImage](describe_image.html)
     *
     * @param string $imageId
     */
    public function setImageId($imageId)
    {
        $this->set("ImageId", $imageId);
    }

    /**
     * ReserveDisk: 是否保留数据盘，保留：Yes，不报留：No， 默认：Yes；如果是从Windows重装为Linux或反之，则无法保留数据盘（该参数目前仅对本地数据盘起作用）
     *
     * @return string|null
     */
    public function getReserveDisk()
    {
        return $this->get("ReserveDisk");
    }

    /**
     * ReserveDisk: 是否保留数据盘，保留：Yes，不报留：No， 默认：Yes；如果是从Windows重装为Linux或反之，则无法保留数据盘（该参数目前仅对本地数据盘起作用）
     *
     * @param string $reserveDisk
     */
    public function setReserveDisk($reserveDisk)
    {
        $this->set("ReserveDisk", $reserveDisk);
    }

    /**
     * BootDiskSpace: 系统盘大小。 单位：GB， 范围[20,100]， 步长：10
     *
     * @return integer|null
     */
    public function getBootDiskSpace()
    {
        return $this->get("BootDiskSpace");
    }

    /**
     * BootDiskSpace: 系统盘大小。 单位：GB， 范围[20,100]， 步长：10
     *
     * @param int $bootDiskSpace
     */
    public function setBootDiskSpace($bootDiskSpace)
    {
        $this->set("BootDiskSpace", $bootDiskSpace);
    }

    /**
     * UserData: cloudinit初始化使用。注意：1、总数据量大小不超多16K 2、使用base64编码
     *
     * @return string|null
     */
    public function getUserData()
    {
        return $this->get("UserData");
    }

    /**
     * UserData: cloudinit初始化使用。注意：1、总数据量大小不超多16K 2、使用base64编码
     *
     * @param string $userData
     */
    public function setUserData($userData)
    {
        $this->set("UserData", $userData);
    }

    /**
     * AutoDataDiskInit: 数据盘是否需要自动分区挂载。当镜像支持Cloud-init Feature时可填写此字段。取值“On”（默认值）， “Off”
     *
     * @return string|null
     */
    public function getAutoDataDiskInit()
    {
        return $this->get("AutoDataDiskInit");
    }

    /**
     * AutoDataDiskInit: 数据盘是否需要自动分区挂载。当镜像支持Cloud-init Feature时可填写此字段。取值“On”（默认值）， “Off”
     *
     * @param string $autoDataDiskInit
     */
    public function setAutoDataDiskInit($autoDataDiskInit)
    {
        $this->set("AutoDataDiskInit", $autoDataDiskInit);
    }

    /**
     * LoginMode: 主机登陆模式。密码（默认选项）: Password，密钥 KeyPair。
     *
     * @return string|null
     */
    public function getLoginMode()
    {
        return $this->get("LoginMode");
    }

    /**
     * LoginMode: 主机登陆模式。密码（默认选项）: Password，密钥 KeyPair。
     *
     * @param string $loginMode
     */
    public function setLoginMode($loginMode)
    {
        $this->set("LoginMode", $loginMode);
    }

    /**
     * KeyPairId: KeypairId 密钥对ID，LoginMode为KeyPair时此项必须。
     *
     * @return string|null
     */
    public function getKeyPairId()
    {
        return $this->get("KeyPairId");
    }

    /**
     * KeyPairId: KeypairId 密钥对ID，LoginMode为KeyPair时此项必须。
     *
     * @param string $keyPairId
     */
    public function setKeyPairId($keyPairId)
    {
        $this->set("KeyPairId", $keyPairId);
    }
}
