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
namespace UCloud\UAccount\Models;

use UCloud\Core\Response\Response;

class ProjectListInfo extends Response
{
    

    /**
     * ProjectId: 项目ID
     *
     * @return string|null
     */
    public function getProjectId()
    {
        return $this->get("ProjectId");
    }

    /**
     * ProjectId: 项目ID
     *
     * @param string $projectId
     */
    public function setProjectId($projectId)
    {
        $this->set("ProjectId", $projectId);
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
     * CreateTime: 创建时间(Unix时间戳)
     *
     * @return integer|null
     */
    public function getCreateTime()
    {
        return $this->get("CreateTime");
    }

    /**
     * CreateTime: 创建时间(Unix时间戳)
     *
     * @param int $createTime
     */
    public function setCreateTime($createTime)
    {
        $this->set("CreateTime", $createTime);
    }

    /**
     * IsDefault: 是否为默认项目
     *
     * @return boolean|null
     */
    public function getIsDefault()
    {
        return $this->get("IsDefault");
    }

    /**
     * IsDefault: 是否为默认项目
     *
     * @param boolean $isDefault
     */
    public function setIsDefault($isDefault)
    {
        $this->set("IsDefault", $isDefault);
    }

    /**
     * ResourceCount: 项目下资源数量（已废弃，不建议使用）
     *
     * @return integer|null
     */
    public function getResourceCount()
    {
        return $this->get("ResourceCount");
    }

    /**
     * ResourceCount: 项目下资源数量（已废弃，不建议使用）
     *
     * @param int $resourceCount
     */
    public function setResourceCount($resourceCount)
    {
        $this->set("ResourceCount", $resourceCount);
    }

    /**
     * MemberCount: 项目下成员数量
     *
     * @return integer|null
     */
    public function getMemberCount()
    {
        return $this->get("MemberCount");
    }

    /**
     * MemberCount: 项目下成员数量
     *
     * @param int $memberCount
     */
    public function setMemberCount($memberCount)
    {
        $this->set("MemberCount", $memberCount);
    }

    /**
     * ParentId: 父项目ID（已废弃）
     *
     * @return string|null
     */
    public function getParentId()
    {
        return $this->get("ParentId");
    }

    /**
     * ParentId: 父项目ID（已废弃）
     *
     * @param string $parentId
     */
    public function setParentId($parentId)
    {
        $this->set("ParentId", $parentId);
    }

    /**
     * ParentName: 父项目名称（已废弃）
     *
     * @return string|null
     */
    public function getParentName()
    {
        return $this->get("ParentName");
    }

    /**
     * ParentName: 父项目名称（已废弃）
     *
     * @param string $parentName
     */
    public function setParentName($parentName)
    {
        $this->set("ParentName", $parentName);
    }
}
