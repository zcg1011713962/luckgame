#!/bin/sh 

# 检查 Docker 网络是否存在，如果不存在，则创建
netname=$(docker network list | grep gamenet | awk '{print $2}')
if [ "$netname" == "" ]; then
    echo "Creating gamenet network"
    if docker network create --subnet=172.24.0.0/16 --gateway=172.24.0.1 gamenet; then
        echo "gamenet network created successfully"
    else
        echo "Failed to create gamenet network"
        exit 1
    fi
else
    echo "The gamenet network already exists"
fi

# 使用 Docker Compose 启动服务
docker-compose -f docker-compose.yml up -d
