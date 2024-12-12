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
namespace UCloud\UBill\Models;

use UCloud\Core\Response\Response;

class BillDetailItem extends Response
{
    

    /**
     * Amount: 订单总金额
     *
     * @return string|null
     */
    public function getAmount()
    {
        return $this->get("Amount");
    }

    /**
     * Amount: 订单总金额
     *
     * @param string $amount
     */
    public function setAmount($amount)
    {
        $this->set("Amount", $amount);
    }

    /**
     * AmountReal: 现金账户支付
     *
     * @return string|null
     */
    public function getAmountReal()
    {
        return $this->get("AmountReal");
    }

    /**
     * AmountReal: 现金账户支付
     *
     * @param string $amountReal
     */
    public function setAmountReal($amountReal)
    {
        $this->set("AmountReal", $amountReal);
    }

    /**
     * AmountFree: 赠送金额抵扣
     *
     * @return string|null
     */
    public function getAmountFree()
    {
        return $this->get("AmountFree");
    }

    /**
     * AmountFree: 赠送金额抵扣
     *
     * @param string $amountFree
     */
    public function setAmountFree($amountFree)
    {
        $this->set("AmountFree", $amountFree);
    }

    /**
     * AmountCoupon: 代金券抵扣
     *
     * @return string|null
     */
    public function getAmountCoupon()
    {
        return $this->get("AmountCoupon");
    }

    /**
     * AmountCoupon: 代金券抵扣
     *
     * @param string $amountCoupon
     */
    public function setAmountCoupon($amountCoupon)
    {
        $this->set("AmountCoupon", $amountCoupon);
    }

    /**
     * AzGroupCName: 可用区
     *
     * @return string|null
     */
    public function getAzGroupCName()
    {
        return $this->get("AzGroupCName");
    }

    /**
     * AzGroupCName: 可用区
     *
     * @param string $azGroupCName
     */
    public function setAzGroupCName($azGroupCName)
    {
        $this->set("AzGroupCName", $azGroupCName);
    }

    /**
     * ChargeType: 计费方式 (筛选项, 默认全部)。枚举值：\\ > Dynamic:按时 \\ > Month:按月 \\ > Year:按年 \\ > Once:一次性按量 \\ > Used:按量 \\ > Post:后付费
     *
     * @return string|null
     */
    public function getChargeType()
    {
        return $this->get("ChargeType");
    }

    /**
     * ChargeType: 计费方式 (筛选项, 默认全部)。枚举值：\\ > Dynamic:按时 \\ > Month:按月 \\ > Year:按年 \\ > Once:一次性按量 \\ > Used:按量 \\ > Post:后付费
     *
     * @param string $chargeType
     */
    public function setChargeType($chargeType)
    {
        $this->set("ChargeType", $chargeType);
    }

    /**
     * CreateTime: 创建时间（时间戳）
     *
     * @return integer|null
     */
    public function getCreateTime()
    {
        return $this->get("CreateTime");
    }

    /**
     * CreateTime: 创建时间（时间戳）
     *
     * @param int $createTime
     */
    public function setCreateTime($createTime)
    {
        $this->set("CreateTime", $createTime);
    }

    /**
     * StartTime: 开始时间（时间戳）
     *
     * @return integer|null
     */
    public function getStartTime()
    {
        return $this->get("StartTime");
    }

    /**
     * StartTime: 开始时间（时间戳）
     *
     * @param int $startTime
     */
    public function setStartTime($startTime)
    {
        $this->set("StartTime", $startTime);
    }

    /**
     * OrderNo: 订单号
     *
     * @return string|null
     */
    public function getOrderNo()
    {
        return $this->get("OrderNo");
    }

    /**
     * OrderNo: 订单号
     *
     * @param string $orderNo
     */
    public function setOrderNo($orderNo)
    {
        $this->set("OrderNo", $orderNo);
    }

    /**
     * OrderType: 订单类型 (筛选项, 默认全部) 。枚举值：\\ > OT_BUY:新购 \\ > OT_RENEW:续费 \\ > OT_UPGRADE:升级 \\ > OT_REFUND:退费 \\ > OT_DOWNGRADE:降级 \\ > OT_SUSPEND:结算 \\ > OT_PAYMENT:删除资源回款 \\ > OT_POSTPAID_PAYMENT:后付费回款 \\ > OT_RECOVER:删除恢复 \\ > OT_POSTPAID_RENEW:过期续费回款
     *
     * @return string|null
     */
    public function getOrderType()
    {
        return $this->get("OrderType");
    }

    /**
     * OrderType: 订单类型 (筛选项, 默认全部) 。枚举值：\\ > OT_BUY:新购 \\ > OT_RENEW:续费 \\ > OT_UPGRADE:升级 \\ > OT_REFUND:退费 \\ > OT_DOWNGRADE:降级 \\ > OT_SUSPEND:结算 \\ > OT_PAYMENT:删除资源回款 \\ > OT_POSTPAID_PAYMENT:后付费回款 \\ > OT_RECOVER:删除恢复 \\ > OT_POSTPAID_RENEW:过期续费回款
     *
     * @param string $orderType
     */
    public function setOrderType($orderType)
    {
        $this->set("OrderType", $orderType);
    }

    /**
     * ProjectName: 项目名称
     *
     * @return string|null
     */
    public function getProjectName()
    {
        return $this->get("ProjectName");
    }

    /**
     * ProjectName: 项目名称
     *
     * @param string $projectName
     */
    public function setProjectName($projectName)
    {
        $this->set("ProjectName", $projectName);
    }

    /**
     * ResourceId: 资源ID
     *
     * @return string|null
     */
    public function getResourceId()
    {
        return $this->get("ResourceId");
    }

    /**
     * ResourceId: 资源ID
     *
     * @param string $resourceId
     */
    public function setResourceId($resourceId)
    {
        $this->set("ResourceId", $resourceId);
    }

    /**
     * ResourceType: 产品类型。枚举值：\\ > uhost:云主机 \\ > udisk:普通云硬盘 \\ > udb:云数据库 \\ > eip:弹性IP \\ > ufile:对象存储 \\ > fortress_host:堡垒机 \\ > ufs:文件存储 \\ > waf:WEB应用防火墙 \\ > ues:弹性搜索 \\ > udisk_ssd:SSD云硬盘 \\ > rssd:RSSD云硬盘
     *
     * @return string|null
     */
    public function getResourceType()
    {
        return $this->get("ResourceType");
    }

    /**
     * ResourceType: 产品类型。枚举值：\\ > uhost:云主机 \\ > udisk:普通云硬盘 \\ > udb:云数据库 \\ > eip:弹性IP \\ > ufile:对象存储 \\ > fortress_host:堡垒机 \\ > ufs:文件存储 \\ > waf:WEB应用防火墙 \\ > ues:弹性搜索 \\ > udisk_ssd:SSD云硬盘 \\ > rssd:RSSD云硬盘
     *
     * @param string $resourceType
     */
    public function setResourceType($resourceType)
    {
        $this->set("ResourceType", $resourceType);
    }

    /**
     * ResourceTypeCode: 产品类型代码
     *
     * @return integer|null
     */
    public function getResourceTypeCode()
    {
        return $this->get("ResourceTypeCode");
    }

    /**
     * ResourceTypeCode: 产品类型代码
     *
     * @param int $resourceTypeCode
     */
    public function setResourceTypeCode($resourceTypeCode)
    {
        $this->set("ResourceTypeCode", $resourceTypeCode);
    }

    /**
     * ItemDetails: 产品配置
     *
     * @return ItemDetail[]|null
     */
    public function getItemDetails()
    {
        $items = $this->get("ItemDetails");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new ItemDetail($item));
        }
        return $result;
    }

    /**
     * ItemDetails: 产品配置
     *
     * @param ItemDetail[] $itemDetails
     */
    public function setItemDetails(array $itemDetails)
    {
        $result = [];
        foreach ($itemDetails as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * ResourceExtendInfo: 资源标识
     *
     * @return ResourceExtendInfo[]|null
     */
    public function getResourceExtendInfo()
    {
        $items = $this->get("ResourceExtendInfo");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new ResourceExtendInfo($item));
        }
        return $result;
    }

    /**
     * ResourceExtendInfo: 资源标识
     *
     * @param ResourceExtendInfo[] $resourceExtendInfo
     */
    public function setResourceExtendInfo(array $resourceExtendInfo)
    {
        $result = [];
        foreach ($resourceExtendInfo as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * ShowHover: 订单支付状态。枚举值：\\> 0:未支付 \\ > 1:已支付
     *
     * @return integer|null
     */
    public function getShowHover()
    {
        return $this->get("ShowHover");
    }

    /**
     * ShowHover: 订单支付状态。枚举值：\\> 0:未支付 \\ > 1:已支付
     *
     * @param int $showHover
     */
    public function setShowHover($showHover)
    {
        $this->set("ShowHover", $showHover);
    }

    /**
     * UserEmail: 账户邮箱
     *
     * @return string|null
     */
    public function getUserEmail()
    {
        return $this->get("UserEmail");
    }

    /**
     * UserEmail: 账户邮箱
     *
     * @param string $userEmail
     */
    public function setUserEmail($userEmail)
    {
        $this->set("UserEmail", $userEmail);
    }

    /**
     * UserName: 账户名
     *
     * @return string|null
     */
    public function getUserName()
    {
        return $this->get("UserName");
    }

    /**
     * UserName: 账户名
     *
     * @param string $userName
     */
    public function setUserName($userName)
    {
        $this->set("UserName", $userName);
    }

    /**
     * UserDisplayName: 账户昵称
     *
     * @return string|null
     */
    public function getUserDisplayName()
    {
        return $this->get("UserDisplayName");
    }

    /**
     * UserDisplayName: 账户昵称
     *
     * @param string $userDisplayName
     */
    public function setUserDisplayName($userDisplayName)
    {
        $this->set("UserDisplayName", $userDisplayName);
    }

    /**
     * Admin: 是否为主账号。枚举值：\\ > 0:子账号 \\ > 1:主账号
     *
     * @return integer|null
     */
    public function getAdmin()
    {
        return $this->get("Admin");
    }

    /**
     * Admin: 是否为主账号。枚举值：\\ > 0:子账号 \\ > 1:主账号
     *
     * @param int $admin
     */
    public function setAdmin($admin)
    {
        $this->set("Admin", $admin);
    }
}
