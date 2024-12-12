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
namespace UCloud\VPC;

use UCloud\Core\Client;
use UCloud\Core\Exception\UCloudException;
use UCloud\VPC\Apis\AddSnatRuleRequest;
use UCloud\VPC\Apis\AddSnatRuleResponse;
use UCloud\VPC\Apis\AddVPCNetworkRequest;
use UCloud\VPC\Apis\AddVPCNetworkResponse;
use UCloud\VPC\Apis\AddWhiteListResourceRequest;
use UCloud\VPC\Apis\AddWhiteListResourceResponse;
use UCloud\VPC\Apis\AllocateBatchSecondaryIpRequest;
use UCloud\VPC\Apis\AllocateBatchSecondaryIpResponse;
use UCloud\VPC\Apis\AllocateSecondaryIpRequest;
use UCloud\VPC\Apis\AllocateSecondaryIpResponse;
use UCloud\VPC\Apis\AllocateVIPRequest;
use UCloud\VPC\Apis\AllocateVIPResponse;
use UCloud\VPC\Apis\AssociateRouteTableRequest;
use UCloud\VPC\Apis\AssociateRouteTableResponse;
use UCloud\VPC\Apis\CloneRouteTableRequest;
use UCloud\VPC\Apis\CloneRouteTableResponse;
use UCloud\VPC\Apis\CreateNATGWRequest;
use UCloud\VPC\Apis\CreateNATGWResponse;
use UCloud\VPC\Apis\CreateNATGWPolicyRequest;
use UCloud\VPC\Apis\CreateNATGWPolicyResponse;
use UCloud\VPC\Apis\CreateNetworkAclRequest;
use UCloud\VPC\Apis\CreateNetworkAclResponse;
use UCloud\VPC\Apis\CreateNetworkAclAssociationRequest;
use UCloud\VPC\Apis\CreateNetworkAclAssociationResponse;
use UCloud\VPC\Apis\CreateNetworkAclEntryRequest;
use UCloud\VPC\Apis\CreateNetworkAclEntryResponse;
use UCloud\VPC\Apis\CreateNetworkInterfaceRequest;
use UCloud\VPC\Apis\CreateNetworkInterfaceResponse;
use UCloud\VPC\Apis\CreateRouteTableRequest;
use UCloud\VPC\Apis\CreateRouteTableResponse;
use UCloud\VPC\Apis\CreateSnatDnatRuleRequest;
use UCloud\VPC\Apis\CreateSnatDnatRuleResponse;
use UCloud\VPC\Apis\CreateSubnetRequest;
use UCloud\VPC\Apis\CreateSubnetResponse;
use UCloud\VPC\Apis\CreateVPCRequest;
use UCloud\VPC\Apis\CreateVPCResponse;
use UCloud\VPC\Apis\CreateVPCIntercomRequest;
use UCloud\VPC\Apis\CreateVPCIntercomResponse;
use UCloud\VPC\Apis\DeleteNATGWRequest;
use UCloud\VPC\Apis\DeleteNATGWResponse;
use UCloud\VPC\Apis\DeleteNATGWPolicyRequest;
use UCloud\VPC\Apis\DeleteNATGWPolicyResponse;
use UCloud\VPC\Apis\DeleteNetworkAclRequest;
use UCloud\VPC\Apis\DeleteNetworkAclResponse;
use UCloud\VPC\Apis\DeleteNetworkAclAssociationRequest;
use UCloud\VPC\Apis\DeleteNetworkAclAssociationResponse;
use UCloud\VPC\Apis\DeleteNetworkAclEntryRequest;
use UCloud\VPC\Apis\DeleteNetworkAclEntryResponse;
use UCloud\VPC\Apis\DeleteRouteTableRequest;
use UCloud\VPC\Apis\DeleteRouteTableResponse;
use UCloud\VPC\Apis\DeleteSecondaryIpRequest;
use UCloud\VPC\Apis\DeleteSecondaryIpResponse;
use UCloud\VPC\Apis\DeleteSnatDnatRuleRequest;
use UCloud\VPC\Apis\DeleteSnatDnatRuleResponse;
use UCloud\VPC\Apis\DeleteSnatRuleRequest;
use UCloud\VPC\Apis\DeleteSnatRuleResponse;
use UCloud\VPC\Apis\DeleteSubnetRequest;
use UCloud\VPC\Apis\DeleteSubnetResponse;
use UCloud\VPC\Apis\DeleteVPCRequest;
use UCloud\VPC\Apis\DeleteVPCResponse;
use UCloud\VPC\Apis\DeleteVPCIntercomRequest;
use UCloud\VPC\Apis\DeleteVPCIntercomResponse;
use UCloud\VPC\Apis\DeleteWhiteListResourceRequest;
use UCloud\VPC\Apis\DeleteWhiteListResourceResponse;
use UCloud\VPC\Apis\DescribeInstanceNetworkInterfaceRequest;
use UCloud\VPC\Apis\DescribeInstanceNetworkInterfaceResponse;
use UCloud\VPC\Apis\DescribeNATGWRequest;
use UCloud\VPC\Apis\DescribeNATGWResponse;
use UCloud\VPC\Apis\DescribeNATGWPolicyRequest;
use UCloud\VPC\Apis\DescribeNATGWPolicyResponse;
use UCloud\VPC\Apis\DescribeNetworkAclRequest;
use UCloud\VPC\Apis\DescribeNetworkAclResponse;
use UCloud\VPC\Apis\DescribeNetworkAclAssociationRequest;
use UCloud\VPC\Apis\DescribeNetworkAclAssociationResponse;
use UCloud\VPC\Apis\DescribeNetworkAclAssociationBySubnetRequest;
use UCloud\VPC\Apis\DescribeNetworkAclAssociationBySubnetResponse;
use UCloud\VPC\Apis\DescribeNetworkAclEntryRequest;
use UCloud\VPC\Apis\DescribeNetworkAclEntryResponse;
use UCloud\VPC\Apis\DescribeNetworkInterfaceRequest;
use UCloud\VPC\Apis\DescribeNetworkInterfaceResponse;
use UCloud\VPC\Apis\DescribeRouteTableRequest;
use UCloud\VPC\Apis\DescribeRouteTableResponse;
use UCloud\VPC\Apis\DescribeSecondaryIpRequest;
use UCloud\VPC\Apis\DescribeSecondaryIpResponse;
use UCloud\VPC\Apis\DescribeSnatDnatRuleRequest;
use UCloud\VPC\Apis\DescribeSnatDnatRuleResponse;
use UCloud\VPC\Apis\DescribeSnatRuleRequest;
use UCloud\VPC\Apis\DescribeSnatRuleResponse;
use UCloud\VPC\Apis\DescribeSubnetRequest;
use UCloud\VPC\Apis\DescribeSubnetResponse;
use UCloud\VPC\Apis\DescribeSubnetResourceRequest;
use UCloud\VPC\Apis\DescribeSubnetResourceResponse;
use UCloud\VPC\Apis\DescribeVIPRequest;
use UCloud\VPC\Apis\DescribeVIPResponse;
use UCloud\VPC\Apis\DescribeVPCRequest;
use UCloud\VPC\Apis\DescribeVPCResponse;
use UCloud\VPC\Apis\DescribeVPCIntercomRequest;
use UCloud\VPC\Apis\DescribeVPCIntercomResponse;
use UCloud\VPC\Apis\DescribeWhiteListResourceRequest;
use UCloud\VPC\Apis\DescribeWhiteListResourceResponse;
use UCloud\VPC\Apis\EnableWhiteListRequest;
use UCloud\VPC\Apis\EnableWhiteListResponse;
use UCloud\VPC\Apis\GetAvailableResourceForPolicyRequest;
use UCloud\VPC\Apis\GetAvailableResourceForPolicyResponse;
use UCloud\VPC\Apis\GetAvailableResourceForSnatRuleRequest;
use UCloud\VPC\Apis\GetAvailableResourceForSnatRuleResponse;
use UCloud\VPC\Apis\GetAvailableResourceForWhiteListRequest;
use UCloud\VPC\Apis\GetAvailableResourceForWhiteListResponse;
use UCloud\VPC\Apis\GetNetworkAclTargetResourceRequest;
use UCloud\VPC\Apis\GetNetworkAclTargetResourceResponse;
use UCloud\VPC\Apis\ListSubnetForNATGWRequest;
use UCloud\VPC\Apis\ListSubnetForNATGWResponse;
use UCloud\VPC\Apis\ModifyRouteRuleRequest;
use UCloud\VPC\Apis\ModifyRouteRuleResponse;
use UCloud\VPC\Apis\MoveSecondaryIPMacRequest;
use UCloud\VPC\Apis\MoveSecondaryIPMacResponse;
use UCloud\VPC\Apis\ReleaseVIPRequest;
use UCloud\VPC\Apis\ReleaseVIPResponse;
use UCloud\VPC\Apis\SetGwDefaultExportRequest;
use UCloud\VPC\Apis\SetGwDefaultExportResponse;
use UCloud\VPC\Apis\UpdateNATGWPolicyRequest;
use UCloud\VPC\Apis\UpdateNATGWPolicyResponse;
use UCloud\VPC\Apis\UpdateNATGWSubnetRequest;
use UCloud\VPC\Apis\UpdateNATGWSubnetResponse;
use UCloud\VPC\Apis\UpdateNetworkAclRequest;
use UCloud\VPC\Apis\UpdateNetworkAclResponse;
use UCloud\VPC\Apis\UpdateNetworkAclEntryRequest;
use UCloud\VPC\Apis\UpdateNetworkAclEntryResponse;
use UCloud\VPC\Apis\UpdateRouteTableAttributeRequest;
use UCloud\VPC\Apis\UpdateRouteTableAttributeResponse;
use UCloud\VPC\Apis\UpdateSnatRuleRequest;
use UCloud\VPC\Apis\UpdateSnatRuleResponse;
use UCloud\VPC\Apis\UpdateSubnetAttributeRequest;
use UCloud\VPC\Apis\UpdateSubnetAttributeResponse;
use UCloud\VPC\Apis\UpdateVIPAttributeRequest;
use UCloud\VPC\Apis\UpdateVIPAttributeResponse;
use UCloud\VPC\Apis\UpdateVPCNetworkRequest;
use UCloud\VPC\Apis\UpdateVPCNetworkResponse;

/**
 * This client is used to call actions of **VPC** service
 */
class VPCClient extends Client
{

    /**
     * AddSnatRule - 对于绑定了多个EIP的NAT网关，您可以将一个子网下的某台云主机映射到某个特定的EIP上，规则生效后，则该云主机通过该特定的EIP访问互联网。
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/add_snat_rule
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (string) NAT网关的ID
     *     "SourceIp" => (string) 需要出外网的私网IP地址，例如10.9.7.xx
     *     "SnatIp" => (string) EIP的ip地址,例如106.75.xx.xx
     *     "Name" => (string) snat规则名称，默认为“出口规则”
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return AddSnatRuleResponse
     * @throws UCloudException
     */
    public function addSnatRule(AddSnatRuleRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new AddSnatRuleResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * AddVPCNetwork - 添加VPC网段
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/add_vpc_network
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCId" => (string) 源VPC短ID
     *     "Network" => (array<string>) 增加网段
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return AddVPCNetworkResponse
     * @throws UCloudException
     */
    public function addVPCNetwork(AddVPCNetworkRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new AddVPCNetworkResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * AddWhiteListResource - 添加NAT网关白名单
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/add_white_list_resource
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "NATGWId" => (string) NAT网关Id
     *     "ResourceIds" => (array<string>) 可添加白名单的资源Id
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return AddWhiteListResourceResponse
     * @throws UCloudException
     */
    public function addWhiteListResource(AddWhiteListResourceRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new AddWhiteListResourceResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * AllocateBatchSecondaryIp - 批量申请虚拟网卡辅助IP
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/allocate_batch_secondary_ip
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "Zone" => (string) 可用区。参见 [可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "Mac" => (string) 节点mac
     *     "ObjectId" => (string) 资源Id
     *     "SubnetId" => (string) 子网Id（若未指定，则根据zone获取默认子网进行创建）
     *     "VPCId" => (string) vpcId
     *     "Ip" => (array<string>) 【arry】支持按如下方式申请：①按网段：如192.168.1.32/27，掩码数字最小为27   ②指定IP地址，如192.168.1.3
     *     "Count" => (integer) 申请的内网IP数量
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "IpsInfo" => (array<object>) 详见IpsInfo[
     *         [
     *             "Ip" => (string) 内网IP地址
     *             "Mask" => (string) 掩码
     *             "Gateway" => (string) 网关
     *             "Mac" => (string) MAC地址
     *             "SubnetId" => (string) 子网资源ID
     *             "VPCId" => (string) VPC资源ID
     *             "Status" => (object) IP分配结果，详见StatusInfo[
     *                 "StatusCode" => (string) 枚举值：Succeeded，Failed
     *                 "Message" => (string) IP分配失败原因
     *             ]
     *         ]
     *     ]
     * ]
     *
     * @return AllocateBatchSecondaryIpResponse
     * @throws UCloudException
     */
    public function allocateBatchSecondaryIp(AllocateBatchSecondaryIpRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new AllocateBatchSecondaryIpResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * AllocateSecondaryIp - 分配ip（用于uk8s使用）
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/allocate_secondary_ip
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "Zone" => (string) 可用区。参见 [可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "Mac" => (string) 节点mac
     *     "ObjectId" => (string) 资源Id
     *     "SubnetId" => (string) 子网Id（若未指定，则根据zone获取默认子网进行创建）
     *     "VPCId" => (string) vpcId
     *     "Ip" => (string) 指定Ip分配
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "IpInfo" => (object) [
     *         "Ip" => (string)
     *         "Mask" => (string)
     *         "Gateway" => (string)
     *         "Mac" => (string)
     *         "SubnetId" => (string)
     *         "VPCId" => (string)
     *     ]
     * ]
     *
     * @return AllocateSecondaryIpResponse
     * @throws UCloudException
     */
    public function allocateSecondaryIp(AllocateSecondaryIpRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new AllocateSecondaryIpResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * AllocateVIP - 根据提供信息，申请内网VIP(Virtual IP），多用于高可用程序作为漂移IP。
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/allocate_vip
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域
     *     "Zone" => (string) 可用区
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCId" => (string) 指定vip所属的VPC
     *     "SubnetId" => (string) 子网id
     *     "Ip" => (string) 指定ip
     *     "Count" => (integer) 申请数量，默认: 1
     *     "Name" => (string) vip名，默认：VIP
     *     "Tag" => (string) 业务组名称，默认为Default
     *     "Remark" => (string) 备注
     *     "BusinessId" => (string) 业务组
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "VIPSet" => (array<object>) 申请到的VIP资源相关信息[
     *         [
     *             "VIP" => (string) 虚拟ip
     *             "VIPId" => (string) 虚拟ip id
     *             "VPCId" => (string) VPC id
     *         ]
     *     ]
     *     "DataSet" => (array<string>) 申请到的VIP地址
     * ]
     *
     * @return AllocateVIPResponse
     * @throws UCloudException
     */
    public function allocateVIP(AllocateVIPRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new AllocateVIPResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * AssociateRouteTable - 绑定子网的路由表
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/associate_route_table
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "SubnetId" => (string) 子网ID
     *     "RouteTableId" => (string) 路由表资源ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return AssociateRouteTableResponse
     * @throws UCloudException
     */
    public function associateRouteTable(AssociateRouteTableRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new AssociateRouteTableResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CloneRouteTable - 将现有的路由表复制为一张新的路由表
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/clone_route_table
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "RouteTableId" => (string) 被克隆的路由表ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "RouteTableId" => (string) 复制后新的路由表资源ID
     * ]
     *
     * @return CloneRouteTableResponse
     * @throws UCloudException
     */
    public function cloneRouteTable(CloneRouteTableRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CloneRouteTableResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateNATGW - 创建NAT网关
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_natgw
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWName" => (string) NAT网关名称
     *     "EIPIds" => (array<string>) NAT网关绑定的EIPId
     *     "FirewallId" => (string) NAT网关绑定的防火墙Id
     *     "SubnetworkIds" => (array<string>) NAT网关绑定的子网Id，默认为空。
     *     "VPCId" => (string) NAT网关所属的VPC Id。默认为Default VPC Id
     *     "IfOpen" => (integer) 白名单开关标记。0表示关闭，1表示开启。默认为0
     *     "Tag" => (string) 业务组。默认为空
     *     "Remark" => (string) 备注。默认为空
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "NATGWId" => (string) 申请到的NATGateWay Id
     * ]
     *
     * @return CreateNATGWResponse
     * @throws UCloudException
     */
    public function createNATGW(CreateNATGWRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateNATGWResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateNATGWPolicy - 添加NAT网关端口转发规则
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_natgw_policy
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "NATGWId" => (string) NAT网关Id
     *     "Protocol" => (string) 协议类型。枚举值为：TCP、UDP
     *     "SrcEIPId" => (string) 源IP。填写对应的EIP Id
     *     "SrcPort" => (string) 源端口。可填写固定端口，也可填写端口范围。支持的端口范围为1-65535
     *     "DstIP" => (string) 目标IP。填写对应的目标IP地址
     *     "DstPort" => (string) 目标端口。可填写固定端口，也可填写端口范围。支持的端口范围为1-65535
     *     "PolicyName" => (string) 转发策略名称。默认为空
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "PolicyId" => (string) 创建时分配的策略Id
     * ]
     *
     * @return CreateNATGWPolicyResponse
     * @throws UCloudException
     */
    public function createNATGWPolicy(CreateNATGWPolicyRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateNATGWPolicyResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateNetworkAcl - 创建网络ACL
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_network_acl
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VpcId" => (string) 将要创建的ACL所属VPC的ID
     *     "AclName" => (string) ACL的名称
     *     "Description" => (string) ACL的描述
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "AclId" => (string) 创建的ACL的ID
     * ]
     *
     * @return CreateNetworkAclResponse
     * @throws UCloudException
     */
    public function createNetworkAcl(CreateNetworkAclRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateNetworkAclResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateNetworkAclAssociation - 创建ACL的绑定关系
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_network_acl_association
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "AclId" => (string) ACL的ID
     *     "SubnetworkId" => (string) 需要绑定的子网ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "AssociationId" => (string) 创建的绑定关系的ID
     *     "PrevAssociation" => (object) 该子网之前的绑定关系信息[
     *         "AssociationId" => (string) 绑定ID
     *         "AclId" => (string) ACL的ID
     *         "SubnetworkId" => (string) 绑定的子网ID
     *         "CreateTime" => (integer) 创建的Unix时间戳
     *     ]
     * ]
     *
     * @return CreateNetworkAclAssociationResponse
     * @throws UCloudException
     */
    public function createNetworkAclAssociation(CreateNetworkAclAssociationRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateNetworkAclAssociationResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateNetworkAclEntry - 创建ACL的规则
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_network_acl_entry
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "AclId" => (string) ACL的ID
     *     "Priority" => (integer) Entry的优先级，对于同样的Direction来说，不能重复
     *     "Direction" => (string) 出向或者入向（“Ingress”, "Egress")
     *     "IpProtocol" => (string) 协议规则描述
     *     "CidrBlock" => (string) IPv4段的CIDR表示
     *     "PortRange" => (string) 针对的端口范围
     *     "EntryAction" => (string) 规则的行为("Accept", "Reject")
     *     "Description" => (string) 描述。长度限制为不超过32字节。
     *     "TargetType" => (integer) 应用目标类型。0代表“子网内全部资源”，1代表“子网内指定资源”，默认为0
     *     "TargetResourceIds" => (array<string>) 应用目标资源列表。默认为全部资源生效。TargetType为0时不用填写该值。
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "EntryId" => (string) 创建的Entry的ID
     * ]
     *
     * @return CreateNetworkAclEntryResponse
     * @throws UCloudException
     */
    public function createNetworkAclEntry(CreateNetworkAclEntryRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateNetworkAclEntryResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateNetworkInterface - 创建虚拟网卡
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_network_interface
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "VPCId" => (string) 所属VPCID
     *     "SubnetId" => (string) 所属子网ID
     *     "Name" => (string) 虚拟网卡名称，默认为 NetworkInterface
     *     "PrivateIp" => (array<string>) 指定内网IP。当前一个网卡仅支持绑定一个内网IP
     *     "SecurityGroupId" => (string) 防火墙GroupId，默认：Web推荐防火墙 可由DescribeSecurityGroupResponse中的GroupId取得
     *     "Tag" => (string) 业务组
     *     "Remark" => (string) 备注
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "NetworkInterface" => (object) 若创建成功，则返回虚拟网卡信息。创建失败，无此参数[
     *         "InterfaceId" => (string) 虚拟网卡资源ID
     *         "VPCId" => (string) 所属VPC
     *         "SubnetId" => (string) 所属子网
     *         "PrivateIpSet" => (array<string>) 关联内网IP。当前一个网卡仅支持绑定一个内网IP
     *         "MacAddress" => (string) 关联Mac
     *         "Status" => (integer) 绑定状态
     *         "Name" => (string) 虚拟网卡名称
     *         "Netmask" => (string) 内网IP掩码
     *         "Gateway" => (string) 默认网关
     *         "AttachInstanceId" => (string) 绑定实例资源ID
     *         "Default" => (boolean) 是否是绑定实例的默认网卡 false:不是 true:是
     *         "CreateTime" => (integer) 创建时间
     *         "Remark" => (string) 备注
     *         "Tag" => (string) 业务组
     *     ]
     * ]
     *
     * @return CreateNetworkInterfaceResponse
     * @throws UCloudException
     */
    public function createNetworkInterface(CreateNetworkInterfaceRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateNetworkInterfaceResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateRouteTable - 创建路由表
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_route_table
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCId" => (string) 所属的VPC资源ID
     *     "Name" => (string) 路由表名称。默认为RouteTable
     *     "Tag" => (string) 路由表所属业务组
     *     "Remark" => (string) 备注
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "RouteTableId" => (string) 路由表ID
     * ]
     *
     * @return CreateRouteTableResponse
     * @throws UCloudException
     */
    public function createRouteTable(CreateRouteTableRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateRouteTableResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateSnatDnatRule - 调用接口后会自动创建内外网IP之间的SNAT和DNAT规则，支持TCP、UDP协议全端口
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_snat_dnat_rule
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "PrivateIp" => (array<string>) 内网P地址
     *     "EIP" => (array<string>) EIP的IP地址。按入参顺序，PrivateIp与EIP一一对应建立映射关系。
     *     "NATGWId" => (string) 映射所使用的NAT网关资源ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return CreateSnatDnatRuleResponse
     * @throws UCloudException
     */
    public function createSnatDnatRule(CreateSnatDnatRuleRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateSnatDnatRuleResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateSubnet - 创建子网
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_subnet
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCId" => (string) VPC资源ID
     *     "Subnet" => (string) 子网网络地址，例如192.168.0.0
     *     "Netmask" => (integer) 子网网络号位数，默认为24
     *     "SubnetName" => (string) 子网名称，默认为Subnet
     *     "Tag" => (string) 业务组名称，默认为Default
     *     "Remark" => (string) 备注
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "SubnetId" => (string) 子网ID
     * ]
     *
     * @return CreateSubnetResponse
     * @throws UCloudException
     */
    public function createSubnet(CreateSubnetRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateSubnetResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateVPC - 创建VPC
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_vpc
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "Name" => (string) VPC名称
     *     "Network" => (array<string>) VPC网段
     *     "Tag" => (string) 业务组名称
     *     "Remark" => (string) 备注
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "VPCId" => (string) VPC资源Id
     * ]
     *
     * @return CreateVPCResponse
     * @throws UCloudException
     */
    public function createVPC(CreateVPCRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateVPCResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * CreateVPCIntercom - 新建VPC互通关系
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/create_vpc_intercom
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 源VPC所在地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 源VPC所在项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCId" => (string) 源VPC短ID
     *     "DstVPCId" => (string) 目的VPC短ID
     *     "DstRegion" => (string) 目的VPC所在地域，默认与源VPC同地域。
     *     "DstProjectId" => (string) 目的VPC项目ID。默认与源VPC同项目。
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return CreateVPCIntercomResponse
     * @throws UCloudException
     */
    public function createVPCIntercom(CreateVPCIntercomRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new CreateVPCIntercomResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteNATGW - 删除NAT网关
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_natgw
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (string) NAT网关Id
     *     "ReleaseEip" => (boolean) 是否释放绑定的EIP。true：解绑并释放；false：只解绑不释放。默认为false
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteNATGWResponse
     * @throws UCloudException
     */
    public function deleteNATGW(DeleteNATGWRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteNATGWResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteNATGWPolicy - 删除NAT网关端口转发规则
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_natgw_policy
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "NATGWId" => (string) NAT网关Id
     *     "PolicyId" => (string) 端口转发规则Id
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteNATGWPolicyResponse
     * @throws UCloudException
     */
    public function deleteNATGWPolicy(DeleteNATGWPolicyRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteNATGWPolicyResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteNetworkAcl - 删除网络ACL
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_network_acl
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "AclId" => (string) 需要删除的AclId
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteNetworkAclResponse
     * @throws UCloudException
     */
    public function deleteNetworkAcl(DeleteNetworkAclRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteNetworkAclResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteNetworkAclAssociation - 删除网络ACL绑定关系
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_network_acl_association
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "AclId" => (string) 需要删除的AclId
     *     "SubnetworkId" => (string) 绑定的子网ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteNetworkAclAssociationResponse
     * @throws UCloudException
     */
    public function deleteNetworkAclAssociation(DeleteNetworkAclAssociationRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteNetworkAclAssociationResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteNetworkAclEntry - 删除ACL的规则
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_network_acl_entry
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "AclId" => (string) Acl的ID
     *     "EntryId" => (string) 需要删除的EntryId
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteNetworkAclEntryResponse
     * @throws UCloudException
     */
    public function deleteNetworkAclEntry(DeleteNetworkAclEntryRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteNetworkAclEntryResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteRouteTable - 删除自定义路由表
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_route_table
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "RouteTableId" => (string) 路由表资源ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteRouteTableResponse
     * @throws UCloudException
     */
    public function deleteRouteTable(DeleteRouteTableRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteRouteTableResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteSecondaryIp - 删除ip（用于uk8s使用）
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_secondary_ip
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "Zone" => (string) 可用区。参见 [可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "Ip" => (string) ip
     *     "Mac" => (string) mac
     *     "SubnetId" => (string) 子网Id
     *     "VPCId" => (string) VPCId
     *     "ObjectId" => (string) 资源Id
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteSecondaryIpResponse
     * @throws UCloudException
     */
    public function deleteSecondaryIp(DeleteSecondaryIpRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteSecondaryIpResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteSnatDnatRule - 删除NAT创建内外网IP映射规则
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_snat_dnat_rule
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "EIP" => (array<string>) EIP的IP地址,PrivateIp与EIP需一一对应
     *     "PrivateIp" => (array<string>) 内网P地址
     *     "NATGWId" => (string) 映射所使用的NAT网关资源ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteSnatDnatRuleResponse
     * @throws UCloudException
     */
    public function deleteSnatDnatRule(DeleteSnatDnatRuleRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteSnatDnatRuleResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteSnatRule - 删除指定的出口规则（SNAT规则）
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_snat_rule
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (string) NAT网关的ID
     *     "SourceIp" => (string) 需要出外网的私网IP地址，例如10.9.7.xx
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteSnatRuleResponse
     * @throws UCloudException
     */
    public function deleteSnatRule(DeleteSnatRuleRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteSnatRuleResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteSubnet - 删除子网
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_subnet
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "SubnetId" => (string) 子网ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteSubnetResponse
     * @throws UCloudException
     */
    public function deleteSubnet(DeleteSubnetRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteSubnetResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteVPC - 删除VPC
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_vpc
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCId" => (string) VPC资源Id
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteVPCResponse
     * @throws UCloudException
     */
    public function deleteVPC(DeleteVPCRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteVPCResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteVPCIntercom - 删除VPC互通关系
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_vpc_intercom
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 源VPC所在地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 源VPC所在项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCId" => (string) 源VPC短ID
     *     "DstVPCId" => (string) 目的VPC短ID
     *     "DstRegion" => (string) 目的VPC所在地域，默认为源VPC所在地域
     *     "DstProjectId" => (string) 目的VPC所在项目ID，默认为源VPC所在项目ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteVPCIntercomResponse
     * @throws UCloudException
     */
    public function deleteVPCIntercom(DeleteVPCIntercomRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteVPCIntercomResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DeleteWhiteListResource - 删除NAT网关白名单列表
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/delete_white_list_resource
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "NATGWId" => (string) NAT网关Id
     *     "ResourceIds" => (array<string>) 删除白名单的资源Id
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return DeleteWhiteListResourceResponse
     * @throws UCloudException
     */
    public function deleteWhiteListResource(DeleteWhiteListResourceRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DeleteWhiteListResourceResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeInstanceNetworkInterface - 展示云主机绑定的网卡信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_instance_network_interface
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "InstanceId" => (string) 云主机ID
     *     "Offset" => (integer) 默认为0
     *     "Limit" => (integer) 默认为20
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "NetworkInterfaceSet" => (array<object>) 虚拟网卡信息[
     *         [
     *             "InterfaceId" => (string) 虚拟网卡资源ID
     *             "VPCId" => (string) 所属VPC
     *             "SubnetId" => (string) 所属子网
     *             "PrivateIpSet" => (array<string>) 关联内网IP。当前一个网卡仅支持绑定一个内网IP
     *             "MacAddress" => (string) 关联Mac
     *             "Status" => (integer) 绑定状态
     *             "Name" => (string) 虚拟网卡名称
     *             "Netmask" => (string) 内网IP掩码
     *             "Gateway" => (string) 默认网关
     *             "AttachInstanceId" => (string) 绑定实例资源ID
     *             "Default" => (boolean) 是否是绑定实例的默认网卡 false:不是 true:是
     *             "CreateTime" => (integer) 创建时间
     *             "Remark" => (string) 备注
     *             "Tag" => (string) 业务组
     *             "EIPIdSet" => (array<string>) 虚拟网卡绑定的EIP ID信息
     *             "FirewallIdSet" => (array<string>) 虚拟网卡绑定的防火墙ID信息
     *         ]
     *     ]
     * ]
     *
     * @return DescribeInstanceNetworkInterfaceResponse
     * @throws UCloudException
     */
    public function describeInstanceNetworkInterface(DescribeInstanceNetworkInterfaceRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeInstanceNetworkInterfaceResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeNATGW - 获取NAT网关信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_natgw
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWIds" => (array<string>) NAT网关Id。默认为该项目下所有NAT网关
     *     "Offset" => (integer) 数据偏移量。默认为0
     *     "Limit" => (integer) 数据分页值。默认为20
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "TotalCount" => (integer) 满足条件的实例的总数
     *     "DataSet" => (array<object>) 查到的NATGW信息列表[
     *         [
     *             "NATGWId" => (string) natgw id
     *             "NATGWName" => (string) natgw名称
     *             "Tag" => (string) 业务组
     *             "Remark" => (string) 备注
     *             "CreateTime" => (integer) natgw创建时间
     *             "FirewallId" => (string) 绑定的防火墙Id
     *             "VPCId" => (string) 所属VPC Id
     *             "SubnetSet" => (array<object>) 子网 Id[
     *                 [
     *                     "SubnetworkId" => (string) 子网id
     *                     "Subnet" => (string) 子网网段
     *                     "SubnetName" => (string) 子网名字
     *                 ]
     *             ]
     *             "IPSet" => (array<object>) 绑定的EIP 信息[
     *                 [
     *                     "EIPId" => (string) 外网IP的 EIPId
     *                     "Weight" => (integer) 权重为100的为出口
     *                     "BandwidthType" => (string) EIP带宽类型
     *                     "Bandwidth" => (integer) 带宽
     *                     "IPResInfo" => (array<object>) 外网IP信息[
     *                         [
     *                             "OperatorName" => (string) IP的运营商信息
     *                             "EIP" => (string) 外网IP
     *                         ]
     *                     ]
     *                 ]
     *             ]
     *             "VPCName" => (string) VPC名称
     *             "IsSnatpoolEnabled" => (string) 枚举值，“enable”，默认出口规则使用了负载均衡；“disable”，默认出口规则未使用负载均衡。
     *             "PolicyId" => (array<string>) 转发策略Id
     *         ]
     *     ]
     * ]
     *
     * @return DescribeNATGWResponse
     * @throws UCloudException
     */
    public function describeNATGW(DescribeNATGWRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeNATGWResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeNATGWPolicy - 展示NAT网关端口转发规则
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_natgw_policy
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "NATGWId" => (string) NAT网关Id
     *     "Limit" => (integer) 返回数据长度，默认为10000
     *     "Offset" => (integer) 列表起始位置偏移量，默认为0
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "TotalCount" => (integer) 满足条件的转发策略总数
     *     "DataSet" => (array<object>) 查到的NATGW 转发策略的详细信息[
     *         [
     *             "NATGWId" => (string) NAT网关Id
     *             "PolicyId" => (string) 转发策略Id
     *             "Protocol" => (string) 协议类型
     *             "SrcEIP" => (string) 端口转发前端EIP
     *             "SrcEIPId" => (string) 端口转发前端EIP Id
     *             "SrcPort" => (string) 源端口
     *             "DstIP" => (string) 目的地址
     *             "DstPort" => (string) 目的端口
     *             "PolicyName" => (string) 转发策略名称
     *         ]
     *     ]
     * ]
     *
     * @return DescribeNATGWPolicyResponse
     * @throws UCloudException
     */
    public function describeNATGWPolicy(DescribeNATGWPolicyRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeNATGWPolicyResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeNetworkAcl - 获取网络ACL
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_network_acl
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "Offset" => (integer) 列表偏移量
     *     "Limit" => (string) 列表获取的个数限制
     *     "VpcId" => (string) 需要获取的ACL所属的VPC的ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "AclList" => (array<object>) ACL的信息，具体结构见下方AclInfo[
     *         [
     *             "VpcId" => (string) ACL所属的VPC ID
     *             "AclId" => (string) ACL的ID
     *             "AclName" => (string) 名称
     *             "Description" => (string) 描述
     *             "Entries" => (array<object>) 所有的规则[
     *                 [
     *                     "EntryId" => (string) Entry的ID
     *                     "Priority" => (string) 优先级
     *                     "Direction" => (string) 出向或者入向
     *                     "IpProtocol" => (string) 针对的IP协议
     *                     "CidrBlock" => (string) IP段的CIDR信息
     *                     "PortRange" => (string) Port的段信息
     *                     "EntryAction" => (string) 匹配规则的动作
     *                     "TargetType" => (integer) 应用目标类型。 0代表“子网内全部资源” ，1代表“子网内指定资源” 。
     *                     "CreateTime" => (integer) 创建的Unix时间戳
     *                     "UpdateTime" => (integer) 更改的Unix时间戳
     *                     "TargetResourceList" => (array<object>) 应用目标资源信息。TargetType为0时不返回该值。具体结构见下方TargetResourceInfo[
     *                         [
     *                             "SubnetworkId" => (string) 子网ID
     *                             "ResourceName" => (string) 资源名称
     *                             "ResourceId" => (string) 资源ID
     *                             "ResourceType" => (integer) 资源类型
     *                             "SubResourceName" => (string) 资源绑定的虚拟网卡的名称
     *                             "SubResourceId" => (string) 资源绑定的虚拟网卡的ID
     *                             "SubResourceType" => (integer) 资源绑定虚拟网卡的类型
     *                             "PrivateIp" => (string) 资源内网IP
     *                         ]
     *                     ]
     *                     "TargetResourceCount" => (integer) 应用目标资源数量。TargetType为0时不返回该值。
     *                 ]
     *             ]
     *             "Associations" => (array<object>) 所有的绑定关系，具体结构见下方AssociationInfo[
     *                 [
     *                     "AssociationId" => (string) 绑定ID
     *                     "AclId" => (string) ACL的ID
     *                     "SubnetworkId" => (string) 绑定的子网ID
     *                     "CreateTime" => (integer) 创建的Unix时间戳
     *                 ]
     *             ]
     *             "CreateTime" => (integer) 创建的Unix时间戳
     *             "UpdateTime" => (integer) 更改的Unix时间戳
     *         ]
     *     ]
     * ]
     *
     * @return DescribeNetworkAclResponse
     * @throws UCloudException
     */
    public function describeNetworkAcl(DescribeNetworkAclRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeNetworkAclResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeNetworkAclAssociation - 获取网络ACL的绑定关系列表
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_network_acl_association
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "AclId" => (string) Acl的ID
     *     "Offset" => (integer) 列表偏移量
     *     "Limit" => (string) 列表获取的个数限制
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "AssociationList" => (array<object>) 绑定信息列表[
     *         [
     *             "AssociationId" => (string) 绑定ID
     *             "AclId" => (string) ACL的ID
     *             "SubnetworkId" => (string) 绑定的子网ID
     *             "CreateTime" => (integer) 创建的Unix时间戳
     *         ]
     *     ]
     * ]
     *
     * @return DescribeNetworkAclAssociationResponse
     * @throws UCloudException
     */
    public function describeNetworkAclAssociation(DescribeNetworkAclAssociationRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeNetworkAclAssociationResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeNetworkAclAssociationBySubnet - 获取子网的ACL绑定信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_network_acl_association_by_subnet
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "SubnetworkId" => (string) 子网的ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "Association" => (object) 绑定信息[
     *         "AssociationId" => (string) 绑定ID
     *         "AclId" => (string) ACL的ID
     *         "SubnetworkId" => (string) 绑定的子网ID
     *         "CreateTime" => (integer) 创建的Unix时间戳
     *     ]
     * ]
     *
     * @return DescribeNetworkAclAssociationBySubnetResponse
     * @throws UCloudException
     */
    public function describeNetworkAclAssociationBySubnet(DescribeNetworkAclAssociationBySubnetRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeNetworkAclAssociationBySubnetResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeNetworkAclEntry - 获取ACL的规则信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_network_acl_entry
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "AclId" => (string) ACL的ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "EntryList" => (array<object>) 所有的规则信息[
     *         [
     *             "EntryId" => (string) Entry的ID
     *             "Priority" => (string) 优先级
     *             "Direction" => (string) 出向或者入向
     *             "IpProtocol" => (string) 针对的IP协议
     *             "CidrBlock" => (string) IP段的CIDR信息
     *             "PortRange" => (string) Port的段信息
     *             "EntryAction" => (string) 匹配规则的动作
     *             "TargetType" => (integer) 应用目标类型。 0代表“子网内全部资源” ，1代表“子网内指定资源” 。
     *             "CreateTime" => (integer) 创建的Unix时间戳
     *             "UpdateTime" => (integer) 更改的Unix时间戳
     *             "TargetResourceList" => (array<object>) 应用目标资源信息。TargetType为0时不返回该值。具体结构见下方TargetResourceInfo[
     *                 [
     *                     "SubnetworkId" => (string) 子网ID
     *                     "ResourceName" => (string) 资源名称
     *                     "ResourceId" => (string) 资源ID
     *                     "ResourceType" => (integer) 资源类型
     *                     "SubResourceName" => (string) 资源绑定的虚拟网卡的名称
     *                     "SubResourceId" => (string) 资源绑定的虚拟网卡的ID
     *                     "SubResourceType" => (integer) 资源绑定虚拟网卡的类型
     *                     "PrivateIp" => (string) 资源内网IP
     *                 ]
     *             ]
     *             "TargetResourceCount" => (integer) 应用目标资源数量。TargetType为0时不返回该值。
     *         ]
     *     ]
     * ]
     *
     * @return DescribeNetworkAclEntryResponse
     * @throws UCloudException
     */
    public function describeNetworkAclEntry(DescribeNetworkAclEntryRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeNetworkAclEntryResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeNetworkInterface - 展示虚拟网卡信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_network_interface
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "VPCId" => (string) 所属VPC
     *     "SubnetId" => (string) 所属子网
     *     "InterfaceId" => (array<string>) 虚拟网卡ID,可指定 0~n
     *     "OnlyDefault" => (boolean) 若为true 只返回默认网卡默认为false
     *     "NoRecycled" => (boolean) 若为true 过滤绑定在回收站主机中的网卡。默认为false。
     *     "Tag" => (string) 业务组
     *     "Limit" => (integer) 默认为20
     *     "Offset" => (integer) 默认为0
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "NetworkInterfaceSet" => (array<object>) 虚拟网卡信息[
     *         [
     *             "InterfaceId" => (string) 虚拟网卡资源ID
     *             "VPCId" => (string) 所属VPC
     *             "SubnetId" => (string) 所属子网
     *             "PrivateIpSet" => (array<string>) 关联内网IP。当前一个网卡仅支持绑定一个内网IP
     *             "MacAddress" => (string) 关联Mac
     *             "Status" => (integer) 绑定状态
     *             "PrivateIp" => (array<object>) 网卡的内网IP信息[
     *                 [
     *                     "IpType" => (string) ip类型 SecondaryIp/PrimaryIp
     *                     "IpAddr" => (array<string>) ip 地址
     *                 ]
     *             ]
     *             "Name" => (string) 虚拟网卡名称
     *             "Netmask" => (string) 内网IP掩码
     *             "Gateway" => (string) 默认网关
     *             "AttachInstanceId" => (string) 绑定实例资源ID
     *             "Default" => (boolean) 是否是绑定实例的默认网卡 false:不是 true:是
     *             "CreateTime" => (integer) 创建时间
     *             "Remark" => (string) 备注
     *             "Tag" => (string) 业务组
     *             "EIPIdSet" => (array<string>) 虚拟网卡绑定的EIP ID信息
     *             "FirewallIdSet" => (array<string>) 虚拟网卡绑定的防火墙ID信息
     *             "PrivateIpLimit" => (object) 网卡的内网IP配额信息[
     *                 "PrivateIpCount" => (integer) 网卡拥有的内网IP数量
     *                 "PrivateIpQuota" => (integer) 网卡内网IP配额
     *             ]
     *         ]
     *     ]
     *     "TotalCount" => (integer) 虚拟网卡总数
     * ]
     *
     * @return DescribeNetworkInterfaceResponse
     * @throws UCloudException
     */
    public function describeNetworkInterface(DescribeNetworkInterfaceRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeNetworkInterfaceResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeRouteTable - 获取路由表详细信息(包括路由策略)
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_route_table
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "VPCId" => (string) 所属VPC的资源ID
     *     "RouteTableId" => (string) 路由表资源ID
     *     "OffSet" => (integer) 数据偏移量。默认为0
     *     "Limit" => (integer) 数据分页值。默认为20
     *     "BusinessId" => (string) 业务组ID
     *     "Brief" => (boolean) 默认为 false, 返回详细路由规则信息
     *     "LongId" => (string) 默认为 false, 表示路由表是短 ID
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "RouteTables" => (array<object>) 路由表信息[
     *         [
     *             "RouteTableId" => (string) 路由表资源ID
     *             "RouteTableType" => (integer) 路由表类型。1为默认路由表，0为自定义路由表
     *             "SubnetCount" => (integer) 绑定该路由表的子网数量
     *             "SubnetIds" => (array<string>) 绑定该路由表的子网
     *             "VPCId" => (string) 路由表所属的VPC资源ID
     *             "VPCName" => (string) 路由表所属的VPC资源名称
     *             "Tag" => (string) 路由表所属业务组
     *             "Remark" => (string) 路由表备注
     *             "CreateTime" => (integer) 创建时间戳
     *             "RouteRules" => (array<object>) 路由规则[
     *                 [
     *                     "AccountId" => (integer) 项目ID信息
     *                     "DstAddr" => (string) 目的地址
     *                     "DstPort" => (integer) 保留字段，暂未使用
     *                     "NexthopId" => (string) 路由下一跳资源ID
     *                     "NexthopType" => (string) 路由表下一跳类型。LOCAL，本VPC内部通信路由；PUBLIC，公共服务路由；CNAT，外网路由；UDPN，跨域高速通道路由；HYBRIDGW，混合云路由；INSTANCE，实例路由；VNET，VPC联通路由；IPSEC VPN，指向VPN网关的路由。
     *                     "InstanceType" => (string) 实例类型，枚举值：UHOST，云主机；UNI，虚拟网卡；PHOST，物理云主机
     *                     "OriginAddr" => (string) 保留字段，暂未使用
     *                     "Priority" => (integer) 保留字段，暂未使用
     *                     "Remark" => (string) 路由规则备注
     *                     "RouteRuleId" => (string) 规则ID
     *                     "RouteTableId" => (string) 路由表资源ID
     *                     "RuleType" => (integer) 路由规则类型。0，系统路由规则；1，自定义路由规则
     *                     "SrcAddr" => (string) 保留字段，暂未使用
     *                     "SrcPort" => (integer) 保留字段，暂未使用
     *                     "VNetId" => (string) 所属的VPC
     *                 ]
     *             ]
     *         ]
     *     ]
     *     "TotalCount" => (integer) RouteTables字段的数量
     * ]
     *
     * @return DescribeRouteTableResponse
     * @throws UCloudException
     */
    public function describeRouteTable(DescribeRouteTableRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeRouteTableResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeSecondaryIp - 查询SecondaryIp（uk8s使用）
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_secondary_ip
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "SubnetId" => (string) 子网Id
     *     "VPCId" => (string) VPCId
     *     "Ip" => (string) Ip
     *     "Mac" => (string) Mac
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "DataSet" => (array<object>) [
     *         [
     *             "Ip" => (string)
     *             "Mask" => (string)
     *             "Gateway" => (string)
     *             "Mac" => (string)
     *             "SubnetId" => (string)
     *             "VPCId" => (string)
     *         ]
     *     ]
     * ]
     *
     * @return DescribeSecondaryIpResponse
     * @throws UCloudException
     */
    public function describeSecondaryIp(DescribeSecondaryIpRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeSecondaryIpResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeSnatDnatRule - 获取基于NAT创建的内外网IP映射规则信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_snat_dnat_rule
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (array<string>) 获取NAT上添加的所有SnatDnatRule信息
     *     "EIP" => (array<string>) 获取EIP对应的SnatDnatRule信息
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "DataSet" => (array<object>) 规则信息[
     *         [
     *             "PrivateIp" => (string) 内网IP地址
     *             "NATGWId" => (string) 映射所使用的NAT网关资源ID
     *             "EIP" => (string) EIP的IP地址
     *         ]
     *     ]
     * ]
     *
     * @return DescribeSnatDnatRuleResponse
     * @throws UCloudException
     */
    public function describeSnatDnatRule(DescribeSnatDnatRuleRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeSnatDnatRuleResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeSnatRule - 获取Nat网关的出口规则（SNAT规则）
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_snat_rule
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (string) NAT网关的ID
     *     "SourceIp" => (string) 需要出外网的私网IP地址，例如10.9.7.xx
     *     "SnatIp" => (string) EIP的ip地址,例如106.75.xx.xx
     *     "Offset" => (string) 偏移，默认为0
     *     "Limit" => (string) 分页，默认为20
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "DataSet" => (array<object>) 某个NAT网关的所有Snat规则[
     *         [
     *             "SnatIp" => (string) EIP地址，如106.76.xx.xx
     *             "SourceIp" => (string) 资源的内网IP地址
     *             "SubnetworkId" => (string) SourceIp所属的子网id
     *             "Name" => (string) snat规则名称
     *         ]
     *     ]
     *     "TotalCount" => (integer) 规则数量
     * ]
     *
     * @return DescribeSnatRuleResponse
     * @throws UCloudException
     */
    public function describeSnatRule(DescribeSnatRuleRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeSnatRuleResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeSubnet - 获取子网信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_subnet
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "SubnetIds" => (array<string>) 子网id数组，适用于一次查询多个子网信息
     *     "SubnetId" => (string) 子网id，适用于一次查询一个子网信息
     *     "RouteTableId" => (string) 路由表Id
     *     "VPCId" => (string) VPC资源id
     *     "Tag" => (string) 业务组名称，默认为Default
     *     "Offset" => (integer) 偏移量，默认为0
     *     "Limit" => (integer) 列表长度，默认为20
     *     "ShowAvailableIPs" => (boolean) 是否返回子网的可用IP数，true为是，false为否，默认不返回
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "TotalCount" => (integer) 子网总数量
     *     "DataSet" => (array<object>) 子网信息数组，具体资源见下方SubnetInfo[
     *         [
     *             "Zone" => (string) 可用区名称
     *             "IPv6Network" => (string) 子网关联的IPv6网段
     *             "VPCId" => (string) VPCId
     *             "VPCName" => (string) VPC名称
     *             "SubnetId" => (string) 子网Id
     *             "SubnetName" => (string) 子网名称
     *             "Remark" => (string) 备注
     *             "Tag" => (string) 业务组
     *             "SubnetType" => (integer) 子网类型
     *             "Subnet" => (string) 子网网段
     *             "Netmask" => (string) 子网掩码
     *             "Gateway" => (string) 子网网关
     *             "CreateTime" => (integer) 创建时间
     *             "HasNATGW" => (boolean) 是否有natgw
     *             "RouteTableId" => (string) 路由表Id
     *             "AvailableIPs" => (integer) 可用IP数量
     *         ]
     *     ]
     * ]
     *
     * @return DescribeSubnetResponse
     * @throws UCloudException
     */
    public function describeSubnet(DescribeSubnetRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeSubnetResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeSubnetResource - 展示子网资源
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_subnet_resource
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "SubnetId" => (string) 子网id
     *     "ResourceType" => (string) 资源类型，默认为全部资源类型。枚举值为：UHOST，云主机；PHOST，物理云主机；ULB，负载均衡；UHADOOP_HOST，hadoop节点；UFORTRESS_HOST，堡垒机；UNATGW，NAT网关；UKAFKA，Kafka消息队列；UMEM，内存存储；DOCKER，容器集群；UDB，数据库；UDW，数据仓库；VIP，内网VIP.
     *     "Offset" => (integer) 列表起始位置偏移量，默认为0
     *     "Limit" => (integer) 单页返回数据长度，默认为20
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "TotalCount" => (integer) 总数
     *     "DataSet" => (array<object>) 返回数据集，请见SubnetResource[
     *         [
     *             "Name" => (string) 名称
     *             "ResourceId" => (string) 资源Id
     *             "ResourceType" => (string) 资源类型。对应的资源类型：UHOST，云主机；PHOST，物理云主机；ULB，负载均衡；UHADOOP_HOST，hadoop节点；UFORTRESS_HOST，堡垒机；UNATGW，NAT网关；UKAFKA，分布式消息系统；UMEM，内存存储；DOCKER，容器集群；UDB，数据库；UDW，数据仓库；VIP，内网VIP.
     *             "IP" => (string) 资源ip
     *         ]
     *     ]
     * ]
     *
     * @return DescribeSubnetResourceResponse
     * @throws UCloudException
     */
    public function describeSubnetResource(DescribeSubnetResourceRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeSubnetResourceResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeVIP - 获取内网VIP详细信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_vip
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "Zone" => (string) 可用区。参见 [可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCId" => (string) vpc的id,指定SubnetId时必填
     *     "SubnetId" => (string) 子网id，不指定则获取VPCId下的所有vip
     *     "VIPId" => (string) VIP ID
     *     "Tag" => (string) 业务组名称, 默认为 Default
     *     "BusinessId" => (string) 业务组
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "VIPSet" => (array<object>) 内网VIP详情，请见VIPDetailSet[
     *         [
     *             "Zone" => (string) 地域
     *             "VIPId" => (string) 虚拟ip id
     *             "CreateTime" => (integer) 创建时间
     *             "RealIp" => (string) 真实主机ip
     *             "VIP" => (string) 虚拟ip
     *             "SubnetId" => (string) 子网id
     *             "VPCId" => (string) VPC id
     *             "Name" => (string) VIP名称
     *             "Remark" => (string) VIP备注
     *             "Tag" => (string) VIP所属业务组
     *         ]
     *     ]
     *     "DataSet" => (array<string>) 内网VIP地址列表
     *     "TotalCount" => (integer) vip数量
     * ]
     *
     * @return DescribeVIPResponse
     * @throws UCloudException
     */
    public function describeVIP(DescribeVIPRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeVIPResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeVPC - 获取VPC信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_vpc
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCIds" => (array<string>) VPCId
     *     "Tag" => (string) 业务组名称
     *     "Offset" => (integer)
     *     "Limit" => (integer)
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "DataSet" => (array<object>) vpc信息，具体结构见下方VPCInfo[
     *         [
     *             "NetworkInfo" => (array<object>) [
     *                 [
     *                     "Network" => (string) vpc地址空间
     *                     "SubnetCount" => (integer) 地址空间中子网数量
     *                 ]
     *             ]
     *             "SubnetCount" => (integer)
     *             "CreateTime" => (integer)
     *             "UpdateTime" => (integer)
     *             "Tag" => (string)
     *             "Name" => (string)
     *             "VPCId" => (string) VPCId
     *             "Network" => (array<string>)
     *             "IPv6Network" => (string) VPC关联的IPv6网段
     *             "OperatorName" => (string) VPC关联的IPv6网段所属运营商
     *         ]
     *     ]
     * ]
     *
     * @return DescribeVPCResponse
     * @throws UCloudException
     */
    public function describeVPC(DescribeVPCRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeVPCResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeVPCIntercom - 获取VPC互通信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_vpc_intercom
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 源VPC所在地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 源VPC所在项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "VPCId" => (string) VPC短ID
     *     "DstRegion" => (string) 目的VPC所在地域，默认为全部地域
     *     "DstProjectId" => (string) 目的项目ID，默认为全部项目
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "DataSet" => (array<object>) 联通VPC信息数组[
     *         [
     *             "ProjectId" => (string) 项目Id
     *             "VPCType" => (integer) vpc类型（1表示托管VPC，0表示公有云VPC）
     *             "AccountId" => (integer) 项目Id（数字）
     *             "Network" => (array<string>) VPC的地址空间
     *             "DstRegion" => (string) 所属地域
     *             "Name" => (string) VPC名字
     *             "VPCId" => (string) VPCId
     *             "Tag" => (string) 业务组（未分组显示为 Default）
     *         ]
     *     ]
     * ]
     *
     * @return DescribeVPCIntercomResponse
     * @throws UCloudException
     */
    public function describeVPCIntercom(DescribeVPCIntercomRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeVPCIntercomResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * DescribeWhiteListResource - 展示NAT网关白名单资源列表
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/describe_white_list_resource
     *
     * Arguments:
     *
     * $args = [
     *     "ProjectId" => (string) 项目id
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "NATGWIds" => (array<string>) NAT网关的Id
     *     "Offset" => (integer) 数据偏移量, 默认为0
     *     "Limit" => (integer) 数据分页值, 默认为20
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "DataSet" => (array<object>) 白名单资源的详细信息，详见DescribeResourceWhiteListDataSet[
     *         [
     *             "NATGWId" => (string) NATGateWay Id
     *             "IfOpen" => (integer) 白名单开关标记
     *             "ObjectIPInfo" => (array<object>) 白名单详情[
     *                 [
     *                     "GwType" => (string) natgw字符串
     *                     "PrivateIP" => (string) 白名单资源的内网IP
     *                     "ResourceId" => (string) 白名单资源Id信息
     *                     "ResourceName" => (string) 白名单资源名称
     *                     "ResourceType" => (string) 白名单资源类型
     *                     "SubResourceId" => (string) 资源绑定的虚拟网卡的实例ID
     *                     "SubResourceName" => (string) 资源绑定的虚拟网卡的实例名称
     *                     "SubResourceType" => (string) 资源绑定的虚拟网卡的类型
     *                     "VPCId" => (string) 白名单资源所属VPCId
     *                 ]
     *             ]
     *         ]
     *     ]
     *     "TotalCount" => (integer) 上述DataSet总数量
     * ]
     *
     * @return DescribeWhiteListResourceResponse
     * @throws UCloudException
     */
    public function describeWhiteListResource(DescribeWhiteListResourceRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new DescribeWhiteListResourceResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * EnableWhiteList - 修改NAT网关白名单开关
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/enable_white_list
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "NATGWId" => (string) NAT网关Id
     *     "IfOpen" => (integer) 白名单开关标记。0：关闭；1：开启。默认为0
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return EnableWhiteListResponse
     * @throws UCloudException
     */
    public function enableWhiteList(EnableWhiteListRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new EnableWhiteListResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * GetAvailableResourceForPolicy - 获取NAT网关可配置端口转发规则的资源信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/get_available_resource_for_policy
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (string) NAT网关Id
     *     "Limit" => (integer) 返回数据长度，默认为20
     *     "Offset" => (integer) 列表起始位置偏移量，默认为0
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "DataSet" => (array<object>) 支持资源类型的信息[
     *         [
     *             "ResourceId" => (string) 资源的Id
     *             "PrivateIP" => (string) 资源对应的内网Ip
     *             "ResourceType" => (string) 资源类型。"uhost"：云主机； "upm"，物理云主机； "hadoophost"：hadoop节点； "fortresshost"：堡垒机： "udockhost"，容器
     *         ]
     *     ]
     * ]
     *
     * @return GetAvailableResourceForPolicyResponse
     * @throws UCloudException
     */
    public function getAvailableResourceForPolicy(GetAvailableResourceForPolicyRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new GetAvailableResourceForPolicyResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * GetAvailableResourceForSnatRule - 获取可用于添加snat规则（出口规则）的资源列表
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/get_available_resource_for_snat_rule
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (string) NAT网关Id
     *     "Offset" => (integer) 数据偏移量, 默认为0
     *     "Limit" => (integer) 数据分页值, 默认为20
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "DataSet" => (array<object>) 返回的资源详细信息[
     *         [
     *             "ResourceId" => (string) 资源ID
     *             "ResourceName" => (string) 资源名称
     *             "PrivateIP" => (string) 资源内网IP
     *             "ResourceType" => (string) 资源类型
     *             "SubnetworkId" => (string) 资源所属VPC的ID
     *             "VPCId" => (string) 资源所属子网的ID
     *         ]
     *     ]
     *     "TotalCount" => (integer) 总数
     * ]
     *
     * @return GetAvailableResourceForSnatRuleResponse
     * @throws UCloudException
     */
    public function getAvailableResourceForSnatRule(GetAvailableResourceForSnatRuleRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new GetAvailableResourceForSnatRuleResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * GetAvailableResourceForWhiteList - 获取NAT网关可添加白名单的资源
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/get_available_resource_for_white_list
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (string) NAT网关Id
     *     "Offset" => (integer) 数据偏移量, 默认为0
     *     "Limit" => (integer) 数据分页值, 默认为20
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "DataSet" => (array<object>) 返回白名单列表的详细信息[
     *         [
     *             "ResourceId" => (string) 资源类型Id
     *             "ResourceName" => (string) 资源名称
     *             "PrivateIP" => (string) 资源的内网Ip
     *             "ResourceType" => (string) 资源类型。"uhost"：云主机； "upm"，物理云主机； "hadoophost"：hadoop节点； "fortresshost"：堡垒机： "udockhost"，容器
     *             "SubResourceName" => (string) 资源绑定的虚拟网卡的实例名称
     *             "VPCId" => (string) 资源所属VPCId
     *             "SubnetworkId" => (string) 资源所属子网Id
     *             "SubResourceId" => (string) 资源绑定的虚拟网卡的实例ID
     *             "SubResourceType" => (string) 资源绑定的虚拟网卡的实例类型
     *         ]
     *     ]
     *     "TotalCount" => (integer) 白名单资源列表的总的个数
     * ]
     *
     * @return GetAvailableResourceForWhiteListResponse
     * @throws UCloudException
     */
    public function getAvailableResourceForWhiteList(GetAvailableResourceForWhiteListRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new GetAvailableResourceForWhiteListResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * GetNetworkAclTargetResource - 获取ACL规则应用目标列表
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/get_network_acl_target_resource
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "SubnetworkId" => (array<string>) 子网ID。
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "TargetResourceList" => (array<object>) ACL规则应用目标资源列表，具体结构见下方TargetResourceInfo[
     *         [
     *             "SubnetworkId" => (string) 子网ID
     *             "ResourceName" => (string) 资源名称
     *             "ResourceId" => (string) 资源ID
     *             "ResourceType" => (integer) 资源类型
     *             "SubResourceName" => (string) 资源绑定的虚拟网卡的名称
     *             "SubResourceId" => (string) 资源绑定的虚拟网卡的ID
     *             "SubResourceType" => (integer) 资源绑定虚拟网卡的类型
     *             "PrivateIp" => (string) 资源内网IP
     *         ]
     *     ]
     *     "TotalCount" => (integer) ACL规则应用目标资源总数
     * ]
     *
     * @return GetNetworkAclTargetResourceResponse
     * @throws UCloudException
     */
    public function getNetworkAclTargetResource(GetNetworkAclTargetResourceRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new GetNetworkAclTargetResourceResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * ListSubnetForNATGW - 展示NAT网关可绑定的子网列表
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/list_subnet_for_natgw
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCId" => (string) NAT网关所属VPC Id。默认值为Default VPC Id
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     *     "DataSet" => (array<object>) 具体参数请见NatgwSubnetDataSet[
     *         [
     *             "SubnetId" => (string) 子网id
     *             "Subnet" => (string) 子网网段
     *             "Netmask" => (string) 掩码
     *             "SubnetName" => (string) 子网名字
     *             "HasNATGW" => (boolean) 是否绑定NATGW
     *         ]
     *     ]
     * ]
     *
     * @return ListSubnetForNATGWResponse
     * @throws UCloudException
     */
    public function listSubnetForNATGW(ListSubnetForNATGWRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new ListSubnetForNATGWResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * ModifyRouteRule - 路由策略增、删、改
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/modify_route_rule
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "RouteTableId" => (string) 通过DescribeRouteTable拿到
     *     "RouteRule" => (array<string>) 格式: RouteRuleId | 目的网段 | 下一跳类型（支持INSTANCE、VIP） | 下一跳 |优先级（保留字段，填写0即可）| 备注 | 增、删、改标志（add/delete/update） 。"添加"示例: test_id | 10.8.0.0/16 | instance | uhost-xd8ja | 0 | Default Route Rule| add (添加的RouteRuleId填任意非空字符串) 。"删除"示例: routerule-xk3jxa | 10.8.0.0/16 | instance | uhost-xd8ja | 0 | Default Route Rule| delete (RouteRuleId来自DescribeRouteTable中)     。“修改”示例: routerule-xk3jxa | 10.8.0.0/16 | instance | uhost-cjksa2 | 0 | Default Route Rule| update (RouteRuleId来自DescribeRouteTable中)
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return ModifyRouteRuleResponse
     * @throws UCloudException
     */
    public function modifyRouteRule(ModifyRouteRuleRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new ModifyRouteRuleResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * MoveSecondaryIPMac - 把 Secondary IP 从旧 MAC 迁移到新 MAC
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/move_secondary_ip_mac
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "Ip" => (string) Secondary IP
     *     "OldMac" => (string) 旧 Mac。Secondary IP 当前所绑定的 Mac
     *     "NewMac" => (string) 新 Mac。Secondary IP 迁移的目的 Mac
     *     "SubnetId" => (string) 子网 ID。IP/OldMac/NewMac 三者必须在同一子网
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return MoveSecondaryIPMacResponse
     * @throws UCloudException
     */
    public function moveSecondaryIPMac(MoveSecondaryIPMacRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new MoveSecondaryIPMacResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * ReleaseVIP - 释放VIP资源
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/release_vip
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域
     *     "Zone" => (string) 可用区
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写
     *     "VIPId" => (string) 内网VIP的id
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return ReleaseVIPResponse
     * @throws UCloudException
     */
    public function releaseVIP(ReleaseVIPRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new ReleaseVIPResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * SetGwDefaultExport - 设置NAT网关的默认出口
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/set_gw_default_export
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "NATGWId" => (string) NAT网关Id
     *     "ExportIp" => (string) NAT网关绑定的EIP。ExportIp和ExportEipId必填一个
     *     "ExportEipId" => (string) NAT网关绑定的EIP Id。ExportIp和ExportEipId必填一个
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return SetGwDefaultExportResponse
     * @throws UCloudException
     */
    public function setGwDefaultExport(SetGwDefaultExportRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new SetGwDefaultExportResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * UpdateNATGWPolicy - 更新NAT网关端口转发规则
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/update_natgw_policy
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (string) NAT网关Id
     *     "PolicyId" => (string) 转发策略Id
     *     "Protocol" => (string) 协议类型。枚举值为：TCP 、 UDP
     *     "SrcEIPId" => (string) 源IP。填写对应的EIP Id
     *     "SrcPort" => (string) 源端口。可填写固定端口，也可填写端口范围。支持的端口范围为1-6553
     *     "DstIP" => (string) 目标IP。填写对应的目标IP地址
     *     "DstPort" => (string) 目标端口。可填写固定端口，也可填写端口范围。支持的端口范围为1-65535
     *     "PolicyName" => (string) 转发策略名称。默认为空
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return UpdateNATGWPolicyResponse
     * @throws UCloudException
     */
    public function updateNATGWPolicy(UpdateNATGWPolicyRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new UpdateNATGWPolicyResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * UpdateNATGWSubnet - 更新NAT网关绑定的子网
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/update_natgw_subnet
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目Id。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (string) NAT网关Id
     *     "SubnetworkIds" => (array<string>) NAT网关绑定的子网Id
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return UpdateNATGWSubnetResponse
     * @throws UCloudException
     */
    public function updateNATGWSubnet(UpdateNATGWSubnetRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new UpdateNATGWSubnetResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * UpdateNetworkAcl - 更改ACL
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/update_network_acl
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "AclName" => (string) Acl的名称
     *     "AclId" => (string) 需要更改的ACL ID
     *     "Description" => (string) 描述
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return UpdateNetworkAclResponse
     * @throws UCloudException
     */
    public function updateNetworkAcl(UpdateNetworkAclRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new UpdateNetworkAclResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * UpdateNetworkAclEntry - 更新ACL的规则
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/update_network_acl_entry
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "AclId" => (string) ACL的ID
     *     "EntryId" => (string) 需要更新的Entry Id
     *     "Priority" => (integer) Entry的优先级，对于同样的Direction来说，不能重复
     *     "Direction" => (string) 出向或者入向（“Ingress”, "Egress")
     *     "IpProtocol" => (string) 针对的协议规则
     *     "CidrBlock" => (string) IPv4段的CIDR表示
     *     "PortRange" => (string) 针对的端口范围
     *     "EntryAction" => (string) 规则的行为("Accept", "Reject")
     *     "Description" => (string) 描述
     *     "TargetType" => (integer) 应用目标类型。0代表“子网内全部资源”， 1代表“子网内指定资源”。默认为0
     *     "TargetResourceIds" => (array<string>) 应用目标资源列表。默认为全部资源生效。TargetType为0时不用填写该值
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return UpdateNetworkAclEntryResponse
     * @throws UCloudException
     */
    public function updateNetworkAclEntry(UpdateNetworkAclEntryRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new UpdateNetworkAclEntryResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * UpdateRouteTableAttribute - 更新路由表基本信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/update_route_table_attribute
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "RouteTableId" => (string) 路由表ID
     *     "Name" => (string) 名称
     *     "Remark" => (string) 备注
     *     "Tag" => (string) 业务组名称
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return UpdateRouteTableAttributeResponse
     * @throws UCloudException
     */
    public function updateRouteTableAttribute(UpdateRouteTableAttributeRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new UpdateRouteTableAttributeResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * UpdateSnatRule - 更新指定的出口规则（SNAT规则）
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/update_snat_rule
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](https://docs.ucloud.cn/api/summary/regionlist)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](https://docs.ucloud.cn/api/summary/get_project_list)
     *     "NATGWId" => (string) NAT网关的ID，
     *     "SourceIp" => (string) 需要出外网的私网IP地址，例如10.9.7.xx
     *     "SnatIp" => (string) EIP的ip地址,例如106.75.xx.xx
     *     "Name" => (string) snat名称，即出口规则名称
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return UpdateSnatRuleResponse
     * @throws UCloudException
     */
    public function updateSnatRule(UpdateSnatRuleRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new UpdateSnatRuleResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * UpdateSubnetAttribute - 更新子网信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/update_subnet_attribute
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "SubnetId" => (string) 子网ID
     *     "Name" => (string) 子网名称(如果Name不填写，Tag必须填写)
     *     "Tag" => (string) 业务组名称(如果Tag不填写，Name必须填写)
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return UpdateSubnetAttributeResponse
     * @throws UCloudException
     */
    public function updateSubnetAttribute(UpdateSubnetAttributeRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new UpdateSubnetAttributeResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * UpdateVIPAttribute - 更新VIP信息
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/update_vip_attribute
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VIPId" => (string) 内网VIP的资源Id
     *     "Remark" => (string) 内网VIP的备注
     *     "Name" => (string) 内网VIP的名称
     *     "Tag" => (string) 内网VIP所属的业务组
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return UpdateVIPAttributeResponse
     * @throws UCloudException
     */
    public function updateVIPAttribute(UpdateVIPAttributeRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new UpdateVIPAttributeResponse($resp->toArray(), $resp->getRequestId());
    }

    /**
     * UpdateVPCNetwork - 更新VPC网段
     *
     * See also: https://docs.ucloud.cn/api/vpc2.0-api/update_vpc_network
     *
     * Arguments:
     *
     * $args = [
     *     "Region" => (string) 地域。 参见 [地域和可用区列表](../summary/regionlist.html)
     *     "ProjectId" => (string) 项目ID。不填写为默认项目，子帐号必须填写。 请参考[GetProjectList接口](../summary/get_project_list.html)
     *     "VPCId" => (string) VPC的ID
     *     "Network" => (array<string>) 需要保留的VPC网段。当前仅支持删除VPC网段，添加网段请参考[AddVPCNetwork](https://docs.ucloud.cn/api/vpc2.0-api/add_vpc_network)
     * ]
     *
     * Outputs:
     *
     * $outputs = [
     * ]
     *
     * @return UpdateVPCNetworkResponse
     * @throws UCloudException
     */
    public function updateVPCNetwork(UpdateVPCNetworkRequest $request = null)
    {
        $resp = $this->invoke($request);
        return new UpdateVPCNetworkResponse($resp->toArray(), $resp->getRequestId());
    }
}
