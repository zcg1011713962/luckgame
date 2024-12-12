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
namespace UCloud\UHost\Models;

use UCloud\Core\Response\Response;

class KeyPairDesc extends Response
{
    

    /**
     * ProjectId: 项目ID。
     *
     * @return string|null
     */
    public function getProjectId()
    {
        return $this->get("ProjectId");
    }

    /**
     * ProjectId: 项目ID。
     *
     * @param string $projectId
     */
    public function setProjectId($projectId)
    {
        $this->set("ProjectId", $projectId);
    }

    /**
     * KeyPairId: 密钥对ID。
     *
     * @return string|null
     */
    public function getKeyPairId()
    {
        return $this->get("KeyPairId");
    }

    /**
     * KeyPairId: 密钥对ID。
     *
     * @param string $keyPairId
     */
    public function setKeyPairId($keyPairId)
    {
        $this->set("KeyPairId", $keyPairId);
    }

    /**
     * KeyPairName: 密钥对名称。 长度为1~63个英文或中文字符。
     *
     * @return string|null
     */
    public function getKeyPairName()
    {
        return $this->get("KeyPairName");
    }

    /**
     * KeyPairName: 密钥对名称。 长度为1~63个英文或中文字符。
     *
     * @param string $keyPairName
     */
    public function setKeyPairName($keyPairName)
    {
        $this->set("KeyPairName", $keyPairName);
    }

    /**
     * KeyPairFingerPrint: 密钥对指纹。md5(ProjectId|KeyPairId|PublicKey)
     *
     * @return string|null
     */
    public function getKeyPairFingerPrint()
    {
        return $this->get("KeyPairFingerPrint");
    }

    /**
     * KeyPairFingerPrint: 密钥对指纹。md5(ProjectId|KeyPairId|PublicKey)
     *
     * @param string $keyPairFingerPrint
     */
    public function setKeyPairFingerPrint($keyPairFingerPrint)
    {
        $this->set("KeyPairFingerPrint", $keyPairFingerPrint);
    }

    /**
     * CreateTime: 密钥对的创建时间，格式为Unix Timestamp。
     *
     * @return integer|null
     */
    public function getCreateTime()
    {
        return $this->get("CreateTime");
    }

    /**
     * CreateTime: 密钥对的创建时间，格式为Unix Timestamp。
     *
     * @param int $createTime
     */
    public function setCreateTime($createTime)
    {
        $this->set("CreateTime", $createTime);
    }
}
