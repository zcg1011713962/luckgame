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

class HolderList extends Response
{
    

    /**
     * ResourceId: 容器组资源id
     *
     * @return string|null
     */
    public function getResourceId()
    {
        return $this->get("ResourceId");
    }

    /**
     * ResourceId: 容器组资源id
     *
     * @param string $resourceId
     */
    public function setResourceId($resourceId)
    {
        $this->set("ResourceId", $resourceId);
    }

    /**
     * HolderName: 容器组名称
     *
     * @return string|null
     */
    public function getHolderName()
    {
        return $this->get("HolderName");
    }

    /**
     * HolderName: 容器组名称
     *
     * @param string $holderName
     */
    public function setHolderName($holderName)
    {
        $this->set("HolderName", $holderName);
    }

    /**
     * SubnetId: 容器组子网id
     *
     * @return string|null
     */
    public function getSubnetId()
    {
        return $this->get("SubnetId");
    }

    /**
     * SubnetId: 容器组子网id
     *
     * @param string $subnetId
     */
    public function setSubnetId($subnetId)
    {
        $this->set("SubnetId", $subnetId);
    }

    /**
     * InnerIp: 容器组内网ip
     *
     * @return string|null
     */
    public function getInnerIp()
    {
        return $this->get("InnerIp");
    }

    /**
     * InnerIp: 容器组内网ip
     *
     * @param string $innerIp
     */
    public function setInnerIp($innerIp)
    {
        $this->set("InnerIp", $innerIp);
    }

    /**
     * IpList: 容器组外网ip集合（详情参考IpList）
     *
     * @return IpList[]|null
     */
    public function getIpList()
    {
        $items = $this->get("IpList");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new IpList($item));
        }
        return $result;
    }

    /**
     * IpList: 容器组外网ip集合（详情参考IpList）
     *
     * @param IpList[] $ipList
     */
    public function setIpList(array $ipList)
    {
        $result = [];
        foreach ($ipList as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * State: 容器组运行状态0：初始化；1：拉取镜像；2：启动中；3：运行中；4：错误；5：正在重启；6：正在删除；7：已经删除；8：容器运行错误；9：启动失败；99：异常
     *
     * @return integer|null
     */
    public function getState()
    {
        return $this->get("State");
    }

    /**
     * State: 容器组运行状态0：初始化；1：拉取镜像；2：启动中；3：运行中；4：错误；5：正在重启；6：正在删除；7：已经删除；8：容器运行错误；9：启动失败；99：异常
     *
     * @param int $state
     */
    public function setState($state)
    {
        $this->set("State", $state);
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
     * ExpireTime: 过期时间
     *
     * @return integer|null
     */
    public function getExpireTime()
    {
        return $this->get("ExpireTime");
    }

    /**
     * ExpireTime: 过期时间
     *
     * @param int $expireTime
     */
    public function setExpireTime($expireTime)
    {
        $this->set("ExpireTime", $expireTime);
    }

    /**
     * Type: 线路类型（运营商类型： 0-其它, 1-一线城市单线,2-二线城市单线, 3-全国教育网, 4-全国三通）
     *
     * @return integer|null
     */
    public function getType()
    {
        return $this->get("Type");
    }

    /**
     * Type: 线路类型（运营商类型： 0-其它, 1-一线城市单线,2-二线城市单线, 3-全国教育网, 4-全国三通）
     *
     * @param int $type
     */
    public function setType($type)
    {
        $this->set("Type", $type);
    }

    /**
     * IdcId: 机房id
     *
     * @return string|null
     */
    public function getIdcId()
    {
        return $this->get("IdcId");
    }

    /**
     * IdcId: 机房id
     *
     * @param string $idcId
     */
    public function setIdcId($idcId)
    {
        $this->set("IdcId", $idcId);
    }

    /**
     * OcName: 机房名称
     *
     * @return string|null
     */
    public function getOcName()
    {
        return $this->get("OcName");
    }

    /**
     * OcName: 机房名称
     *
     * @param string $ocName
     */
    public function setOcName($ocName)
    {
        $this->set("OcName", $ocName);
    }

    /**
     * Province: 省份名称
     *
     * @return string|null
     */
    public function getProvince()
    {
        return $this->get("Province");
    }

    /**
     * Province: 省份名称
     *
     * @param string $province
     */
    public function setProvince($province)
    {
        $this->set("Province", $province);
    }

    /**
     * City: 城市名称
     *
     * @return string|null
     */
    public function getCity()
    {
        return $this->get("City");
    }

    /**
     * City: 城市名称
     *
     * @param string $city
     */
    public function setCity($city)
    {
        $this->set("City", $city);
    }

    /**
     * RestartStrategy: 0：总是；1：失败是；2：永不
     *
     * @return integer|null
     */
    public function getRestartStrategy()
    {
        return $this->get("RestartStrategy");
    }

    /**
     * RestartStrategy: 0：总是；1：失败是；2：永不
     *
     * @param int $restartStrategy
     */
    public function setRestartStrategy($restartStrategy)
    {
        $this->set("RestartStrategy", $restartStrategy);
    }

    /**
     * DockerCount: 容器数量
     *
     * @return integer|null
     */
    public function getDockerCount()
    {
        return $this->get("DockerCount");
    }

    /**
     * DockerCount: 容器数量
     *
     * @param int $dockerCount
     */
    public function setDockerCount($dockerCount)
    {
        $this->set("DockerCount", $dockerCount);
    }

    /**
     * DockerInfo: 容器信息（详情参考DockerInfo）
     *
     * @return DockerInfo[]|null
     */
    public function getDockerInfo()
    {
        $items = $this->get("DockerInfo");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new DockerInfo($item));
        }
        return $result;
    }

    /**
     * DockerInfo: 容器信息（详情参考DockerInfo）
     *
     * @param DockerInfo[] $dockerInfo
     */
    public function setDockerInfo(array $dockerInfo)
    {
        $result = [];
        foreach ($dockerInfo as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * ProductType: 机器类型（normal经济型，hf标准型）
     *
     * @return string|null
     */
    public function getProductType()
    {
        return $this->get("ProductType");
    }

    /**
     * ProductType: 机器类型（normal经济型，hf标准型）
     *
     * @param string $productType
     */
    public function setProductType($productType)
    {
        $this->set("ProductType", $productType);
    }

    /**
     * NetLimit: 外网绑定的带宽
     *
     * @return integer|null
     */
    public function getNetLimit()
    {
        return $this->get("NetLimit");
    }

    /**
     * NetLimit: 外网绑定的带宽
     *
     * @param int $netLimit
     */
    public function setNetLimit($netLimit)
    {
        $this->set("NetLimit", $netLimit);
    }

    /**
     * FirewallId: 外网防火墙id
     *
     * @return string|null
     */
    public function getFirewallId()
    {
        return $this->get("FirewallId");
    }

    /**
     * FirewallId: 外网防火墙id
     *
     * @param string $firewallId
     */
    public function setFirewallId($firewallId)
    {
        $this->set("FirewallId", $firewallId);
    }

    /**
     * StorVolumeInfo: 存储卷信息（详情参考StorVolumeInfo）
     *
     * @return StorVolumeInfo[]|null
     */
    public function getStorVolumeInfo()
    {
        $items = $this->get("StorVolumeInfo");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new StorVolumeInfo($item));
        }
        return $result;
    }

    /**
     * StorVolumeInfo: 存储卷信息（详情参考StorVolumeInfo）
     *
     * @param StorVolumeInfo[] $storVolumeInfo
     */
    public function setStorVolumeInfo(array $storVolumeInfo)
    {
        $result = [];
        foreach ($storVolumeInfo as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * StorVolumeCount: 存储卷数量
     *
     * @return integer|null
     */
    public function getStorVolumeCount()
    {
        return $this->get("StorVolumeCount");
    }

    /**
     * StorVolumeCount: 存储卷数量
     *
     * @param int $storVolumeCount
     */
    public function setStorVolumeCount($storVolumeCount)
    {
        $this->set("StorVolumeCount", $storVolumeCount);
    }

    /**
     * ImageList: 容器组镜像密钥列表（详情参考ImageList）
     *
     * @return ImageList[]|null
     */
    public function getImageList()
    {
        $items = $this->get("ImageList");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new ImageList($item));
        }
        return $result;
    }

    /**
     * ImageList: 容器组镜像密钥列表（详情参考ImageList）
     *
     * @param ImageList[] $imageList
     */
    public function setImageList(array $imageList)
    {
        $result = [];
        foreach ($imageList as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }
}
