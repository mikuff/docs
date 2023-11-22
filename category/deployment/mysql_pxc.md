# mysql pxc 部署
> 部署使用 docker-compose，部署分别5台及其，以及Traefik

## 拉取镜像
``` shell
docker pull percona/percona-xtradb-cluster:5.7.34-31.51
```

## docker-compose
``` yaml
version : '3.7'
networks:
  traefik-pxc:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.16.238.0/24
services:
  traefik:
    image: traefik:v2.4
    command:
      - "--providers.docker=true"
      - "--entrypoints.pxc.address=:3301"
      - "--api=true" 
      - "--api.insecure=true"
      - "--providers.docker"
    ports:
      - "8080:8080"  # Traefik dashboard
      - "3301:3301"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
    networks:
      - traefik-pxc
  

  db1:
    container_name: db1
    image: percona/percona-xtradb-cluster:5.7.34-31.51
    privileged: true
    networks:
      traefik-pxc:
        ipv4_address: 172.16.238.9
    ports:
      - "30001:3306"
    environment:
      - "CLUSTER_NAME=MYSQL_PXC"
      - "XTRABACKUP_PASSWORD=liweilong_test"
      - "MYSQL_ROOT_PASSWORD=liweilong_test"
      - "TZ=Asia/Shanghai"
    volumes:
      - ./data/v1/data:/var/lib/mysql
      - ./data/v1/backup:/data
    labels:
      - "traefik.enable=true"
      - "traefik.tcp.routers.pxc-cluster.rule=HostSNI(`*`)"
      - "traefik.tcp.routers.pxc-cluster.entrypoints=pxc"
      - "traefik.tcp.services.pxc-cluster.loadbalancer.server.port=3306"



  db2:
    container_name: db2
    image: percona/percona-xtradb-cluster:5.7.34-31.51
    privileged: true
    networks:
      traefik-pxc:
        ipv4_address: 172.16.238.3
    environment:
      - "CLUSTER_NAME=MYSQL_PXC"
      - "XTRABACKUP_PASSWORD=liweilong_test"
      - "TZ=Asia/Shanghai"
      - "CLUSTER_JOIN=db1"
    ports:
      - "30002:3306"
    volumes:
      - ./data/v2/data:/var/lib/mysql
      - ./data/v2/backup:/data
    depends_on:
      - db1
    labels:
      - "traefik.enable=true"
      - "traefik.tcp.routers.pxc-cluster.rule=HostSNI(`*`)"
      - "traefik.tcp.routers.pxc-cluster.entrypoints=pxc"
      - "traefik.tcp.services.pxc-cluster.loadbalancer.server.port=3306"

  db3:
    container_name: db3
    image: percona/percona-xtradb-cluster:5.7.34-31.51
    privileged: true
    networks:
      traefik-pxc:
        ipv4_address: 172.16.238.4
    environment:
      - "CLUSTER_NAME=MYSQL_PXC"
      - "XTRABACKUP_PASSWORD=liweilong_test"
      - "TZ=Asia/Shanghai"
      - "CLUSTER_JOIN=db1"
    ports:
      - "30003:3306"
    volumes:
      - ./data/v3/data:/var/lib/mysql
      - ./data/v3/backup:/data
    depends_on:
      - db1
    labels:
      - "traefik.enable=true"
      - "traefik.tcp.routers.pxc-cluster.rule=HostSNI(`*`)"
      - "traefik.tcp.routers.pxc-cluster.entrypoints=pxc"
      - "traefik.tcp.services.pxc-cluster.loadbalancer.server.port=3306"

  db4:
    container_name: db4
    image: percona/percona-xtradb-cluster:5.7.34-31.51
    privileged: true
    networks:
      traefik-pxc:
        ipv4_address: 172.16.238.5
    environment:
      - "CLUSTER_NAME=MYSQL_PXC"
      - "XTRABACKUP_PASSWORD=liweilong_test"
      - "TZ=Asia/Shanghai"
      - "CLUSTER_JOIN=db1"
    ports:
      - "30004:3306"
    volumes:
      - ./data/v4/data:/var/lib/mysql
      - ./data/v4/backup:/data
    depends_on:
      - db1
    labels:
      - "traefik.enable=true"
      - "traefik.tcp.routers.pxc-cluster.rule=HostSNI(`*`)"
      - "traefik.tcp.routers.pxc-cluster.entrypoints=pxc"
      - "traefik.tcp.services.pxc-cluster.loadbalancer.server.port=3306"

  db5:
    container_name: db5
    image: percona/percona-xtradb-cluster:5.7.34-31.51
    privileged: true
    networks:
      traefik-pxc:
        ipv4_address: 172.16.238.6
    environment:
      - "CLUSTER_NAME=MYSQL_PXC"
      - "XTRABACKUP_PASSWORD=liweilong_test"
      - "TZ=Asia/Shanghai"
      - "CLUSTER_JOIN=db1"
    ports:
      - "30005:3306"
    volumes:
      - ./data/v5/data:/var/lib/mysql
      - ./data/v5/backup:/data
    depends_on:
      - db1
    labels:
      - "traefik.enable=true"
      - "traefik.tcp.routers.pxc-cluster.rule=HostSNI(`*`)"
      - "traefik.tcp.routers.pxc-cluster.entrypoints=pxc"
      - "traefik.tcp.services.pxc-cluster.loadbalancer.server.port=3306"
```
> 需要将对应的 ./data/文件夹赋予权限为 777，chmod -r 777 ./data/

## 启动
``` shell
# 先启动 traefik
root@VM-4-13-debian:~/deployment/mysql_pxc# docker-compose up -d traefik
[+] Running 2/2
 ⠿ Network mysql_pxc_traefik-pxc  Created                                                             0.1s
 ⠿ Container mysql_pxc-traefik-1  Started                                                             0.7s


# 分别启动集群
root@VM-4-13-debian:~/deployment/mysql_pxc# docker-compose up -d db1
[+] Running 1/1
 ⠿ Container db1  Started                                                                             0.6s
root@VM-4-13-debian:~/deployment/mysql_pxc# docker-compose up -d db2
[+] Running 2/2
 ⠿ Container db1  Running                                                                             0.0s
 ⠿ Container db2  Started                                                                             0.6s
root@VM-4-13-debian:~/deployment/mysql_pxc# docker-compose up -d db3
[+] Running 2/2
 ⠿ Container db1  Running                                                                             0.0s
 ⠿ Container db3  Started                                                                             0.6s
root@VM-4-13-debian:~/deployment/mysql_pxc# docker-compose up -d db4
[+] Running 2/2
 ⠿ Container db1  Running                                                                             0.0s
 ⠿ Container db4  Started                                                                             0.7s
root@VM-4-13-debian:~/deployment/mysql_pxc# docker-compose up -d db5
[+] Running 2/2
 ⠿ Container db1  Started                                                                             0.6s
 ⠿ Container db5  Started                                                                             1.5s
root@VM-4-13-debian:~/deployment/mysql_pxc# 

```

## web界面
http://1.117.112.179:8080/dashboard/#/
