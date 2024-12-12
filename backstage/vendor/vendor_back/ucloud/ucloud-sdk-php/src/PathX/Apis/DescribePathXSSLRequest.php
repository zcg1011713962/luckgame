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
namespace UCloud\PathX\Apis;

use UCloud\Core\Request\Request;

class DescribePathXSSLRequest extends Request
{
    public function __construct()
    {
        parent::__construct(["Action" => "DescribePathXSSL"]);
        $this->markRequired("ProjectId");
    }

    

    /**
     * ProjectId: 项目ID。请参考[GetProjectList接口](../summary/get_project_list.html)
     *
     * @return string|null
     */
    public function getProjectId()
    {
        return $this->get("ProjectId");
    }

    /**
     * ProjectId: 项目ID。请参考[GetProjectList接口](../summary/get_project_list.html)
     *
     * @param string $projectId
     */
    public function setProjectId($projectId)
    {
        $this->set("ProjectId", $projectId);
    }

    /**
     * SSLId: SSL证书的Id，不传分页获取证书列表
     *
     * @return string|null
     */
    public function getSSLId()
    {
        return $this->get("SSLId");
    }

    /**
     * SSLId: SSL证书的Id，不传分页获取证书列表
     *
     * @param string $sslId
     */
    public function setSSLId($sslId)
    {
        $this->set("SSLId", $sslId);
    }

    /**
     * SearchValue: 不为空则按证书名称、证书域名模糊搜索 分页返回结果
     *
     * @return string|null
     */
    public function getSearchValue()
    {
        return $this->get("SearchValue");
    }

    /**
     * SearchValue: 不为空则按证书名称、证书域名模糊搜索 分页返回结果
     *
     * @param string $searchValue
     */
    public function setSearchValue($searchValue)
    {
        $this->set("SearchValue", $searchValue);
    }

    /**
     * Limit: 最大返回条数，默认100，最大400
     *
     * @return integer|null
     */
    public function getLimit()
    {
        return $this->get("Limit");
    }

    /**
     * Limit: 最大返回条数，默认100，最大400
     *
     * @param int $limit
     */
    public function setLimit($limit)
    {
        $this->set("Limit", $limit);
    }

    /**
     * Offset: 偏移值 默认为0
     *
     * @return integer|null
     */
    public function getOffset()
    {
        return $this->get("Offset");
    }

    /**
     * Offset: 偏移值 默认为0
     *
     * @param int $offset
     */
    public function setOffset($offset)
    {
        $this->set("Offset", $offset);
    }
}
