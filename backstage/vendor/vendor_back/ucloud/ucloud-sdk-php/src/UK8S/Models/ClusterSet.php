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
namespace UCloud\UK8S\Models;

use UCloud\Core\Response\Response;

class ClusterSet extends Response
{
    

    /**
     * ClusterName: 资源名字
     *
     * @return string|null
     */
    public function getClusterName()
    {
        return $this->get("ClusterName");
    }

    /**
     * ClusterName: 资源名字
     *
     * @param string $clusterName
     */
    public function setClusterName($clusterName)
    {
        $this->set("ClusterName", $clusterName);
    }

    /**
     * ClusterId: 集群ID
     *
     * @return string|null
     */
    public function getClusterId()
    {
        return $this->get("ClusterId");
    }

    /**
     * ClusterId: 集群ID
     *
     * @param string $clusterId
     */
    public function setClusterId($clusterId)
    {
        $this->set("ClusterId", $clusterId);
    }

    /**
     * VPCId: 所属VPC
     *
     * @return string|null
     */
    public function getVPCId()
    {
        return $this->get("VPCId");
    }

    /**
     * VPCId: 所属VPC
     *
     * @param string $vpcId
     */
    public function setVPCId($vpcId)
    {
        $this->set("VPCId", $vpcId);
    }

    /**
     * SubnetId: 所属子网
     *
     * @return string|null
     */
    public function getSubnetId()
    {
        return $this->get("SubnetId");
    }

    /**
     * SubnetId: 所属子网
     *
     * @param string $subnetId
     */
    public function setSubnetId($subnetId)
    {
        $this->set("SubnetId", $subnetId);
    }

    /**
     * PodCIDR: Pod网段
     *
     * @return string|null
     */
    public function getPodCIDR()
    {
        return $this->get("PodCIDR");
    }

    /**
     * PodCIDR: Pod网段
     *
     * @param string $podCIDR
     */
    public function setPodCIDR($podCIDR)
    {
        $this->set("PodCIDR", $podCIDR);
    }

    /**
     * ServiceCIDR: 服务网段
     *
     * @return string|null
     */
    public function getServiceCIDR()
    {
        return $this->get("ServiceCIDR");
    }

    /**
     * ServiceCIDR: 服务网段
     *
     * @param string $serviceCIDR
     */
    public function setServiceCIDR($serviceCIDR)
    {
        $this->set("ServiceCIDR", $serviceCIDR);
    }

    /**
     * MasterCount: Master 节点数量
     *
     * @return integer|null
     */
    public function getMasterCount()
    {
        return $this->get("MasterCount");
    }

    /**
     * MasterCount: Master 节点数量
     *
     * @param int $masterCount
     */
    public function setMasterCount($masterCount)
    {
        $this->set("MasterCount", $masterCount);
    }

    /**
     * ApiServer: 集群apiserver地址
     *
     * @return string|null
     */
    public function getApiServer()
    {
        return $this->get("ApiServer");
    }

    /**
     * ApiServer: 集群apiserver地址
     *
     * @param string $apiServer
     */
    public function setApiServer($apiServer)
    {
        $this->set("ApiServer", $apiServer);
    }

    /**
     * K8sVersion: 集群版本
     *
     * @return string|null
     */
    public function getK8sVersion()
    {
        return $this->get("K8sVersion");
    }

    /**
     * K8sVersion: 集群版本
     *
     * @param string $k8sVersion
     */
    public function setK8sVersion($k8sVersion)
    {
        $this->set("K8sVersion", $k8sVersion);
    }

    /**
     * ClusterLogInfo: 创建集群时判断如果为NORESOURCE则为没资源，否则为空
     *
     * @return string|null
     */
    public function getClusterLogInfo()
    {
        return $this->get("ClusterLogInfo");
    }

    /**
     * ClusterLogInfo: 创建集群时判断如果为NORESOURCE则为没资源，否则为空
     *
     * @param string $clusterLogInfo
     */
    public function setClusterLogInfo($clusterLogInfo)
    {
        $this->set("ClusterLogInfo", $clusterLogInfo);
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
     * NodeCount: Node节点数量
     *
     * @return integer|null
     */
    public function getNodeCount()
    {
        return $this->get("NodeCount");
    }

    /**
     * NodeCount: Node节点数量
     *
     * @param int $nodeCount
     */
    public function setNodeCount($nodeCount)
    {
        $this->set("NodeCount", $nodeCount);
    }

    /**
     * ExternalApiServer: 集群外部apiserver地址
     *
     * @return string|null
     */
    public function getExternalApiServer()
    {
        return $this->get("ExternalApiServer");
    }

    /**
     * ExternalApiServer: 集群外部apiserver地址
     *
     * @param string $externalApiServer
     */
    public function setExternalApiServer($externalApiServer)
    {
        $this->set("ExternalApiServer", $externalApiServer);
    }

    /**
     * Status: 集群状态，枚举值：初始化："INITIALIZING"；启动中："STARTING"；创建失败："CREATEFAILED"；正常运行："RUNNING"；添加节点："ADDNODE"；删除节点："DELNODE"；删除中："DELETING"；删除失败："DELETEFAILED"；错误："ERROR"；升级插件："UPDATE_PLUGIN"；更新插件信息："UPDATE_PLUGIN_INFO"；异常："ABNORMAL"；升级集群中："UPGRADING"；容器运行时切换："CONVERTING"
     *
     * @return string|null
     */
    public function getStatus()
    {
        return $this->get("Status");
    }

    /**
     * Status: 集群状态，枚举值：初始化："INITIALIZING"；启动中："STARTING"；创建失败："CREATEFAILED"；正常运行："RUNNING"；添加节点："ADDNODE"；删除节点："DELNODE"；删除中："DELETING"；删除失败："DELETEFAILED"；错误："ERROR"；升级插件："UPDATE_PLUGIN"；更新插件信息："UPDATE_PLUGIN_INFO"；异常："ABNORMAL"；升级集群中："UPGRADING"；容器运行时切换："CONVERTING"
     *
     * @param string $status
     */
    public function setStatus($status)
    {
        $this->set("Status", $status);
    }
}
