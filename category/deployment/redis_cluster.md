# redis cluster 部署
> 部署使用 docker-compose，部署分别为3主3从

## 文件
> 使用kotlin代码生成配置文件和目录，配合后面的docker-compose 文件一起使用
```kotlin
fun main() {
    // 文件生成的配置文件和文件夹存储位置
    var path = "E:\\部署\\redis-cluster\\";

    // 宿主机IP
    var docker_host = "172.17.0.1";

    // 容器端口列表
    var port_range = (6371..6376);

    // 容器内redis密码
    var password = "liweilong_test";

    port_range.forEach { index ->
        val file = File("${path}redis-${index}")
        file.deleteOnExit();

        val conf = File("${path}redis-${index}\\conf")
        conf.mkdirs();

        val data = File("${path}redis-${index}\\data")
        data.mkdirs();

        val config = File("${path}redis-${index}\\conf\\redis.conf")
        config.writeText("""
port ${index}
cluster-enabled yes
cluster-config-file nodes-6371.conf
cluster-node-timeout 5000
appendonly yes
protected-mode no
requirepass ${password}
masterauth ${password}
cluster-announce-ip ${docker_host}
cluster-announce-port ${index}
cluster-announce-bus-port 1${index}
        """.trimIndent())
    }
}
```
> docker-compose配置文件
``` yml
version: "3"

services:
  redis-6371:
    image: redis
    container_name: redis-6371 # 容器名称
    restart: always
    volumes:
      - ./redis-6371/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6371/data:/data
    ports:
      - 6371:6371
      - 16371:16371
    command:
      redis-server /usr/local/etc/redis/redis.conf

  redis-6372:
    image: redis
    container_name: redis-6372
    volumes:
      - ./redis-6372/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6372/data:/data
    ports:
      - 6372:6372
      - 16372:16372
    command:
      redis-server /usr/local/etc/redis/redis.conf

  redis-6373:
    image: redis
    container_name: redis-6373
    volumes:
      - ./redis-6373/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6373/data:/data
    ports:
      - 6373:6373
      - 16373:16373
    command:
      redis-server /usr/local/etc/redis/redis.conf

  redis-6374:
    image: redis
    container_name: redis-6374
    restart: always
    volumes:
      - ./redis-6374/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6374/data:/data
    ports:
      - 6374:6374
      - 16374:16374
    command:
      redis-server /usr/local/etc/redis/redis.conf

  redis-6375:
    image: redis
    container_name: redis-6375
    volumes:
      - ./redis-6375/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6375/data:/data
    ports:
      - 6375:6375
      - 16375:16375
    command:
      redis-server /usr/local/etc/redis/redis.conf

  redis-6376:
    image: redis
    container_name: redis-6376
    volumes:
      - ./redis-6376/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-6376/data:/data
    ports:
      - 6376:6376
      - 16376:16376
    command:
      redis-server /usr/local/etc/redis/redis.conf
```

## 生成容器
``` shell
root@VM-4-13-debian:~/deployment/redis-cluster# docker-compose up -d
[+] Running 6/6
 ⠿ Container redis-6373  Started                                                                                    1.8s
 ⠿ Container redis-6374  Started                                                                                    1.8s
 ⠿ Container redis-6376  Started                                                                                    1.9s
 ⠿ Container redis-6375  Started                                                                                    1.3s
 ⠿ Container redis-6371  Started                                                                                    1.9s
 ⠿ Container redis-6372  Started                                                                                    1.8s
```

## 构建集群
``` shell
# 进入一个容器内部
root@VM-4-13-debian:~/deployment/redis-cluster# docker exec -it redis-6371 bash
# 构建集群
root@b74b84d77898:/data# redis-cli -a liweilong_test --cluster create 172.17.0.1:6371 172.17.0.1:6372 172.17.0.1:6373 172.17.0.1:6374 172.17.0.1:6375 172.17.0.1:6376 --cluster-replicas 1
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
Adding replica 172.17.0.1:6375 to 172.17.0.1:6371
Adding replica 172.17.0.1:6376 to 172.17.0.1:6372
Adding replica 172.17.0.1:6374 to 172.17.0.1:6373
>>> Trying to optimize slaves allocation for anti-affinity
[WARNING] Some slaves are in the same host as their master
M: c38f4597630082c7abf786fbdd68012ccce87b86 172.17.0.1:6371
   slots:[0-5460] (5461 slots) master
M: e534ce115c343da74c064e46c1c505c42bf323c9 172.17.0.1:6372
   slots:[5461-10922] (5462 slots) master
M: a6e1b39b0552c553cca87f5211479ded6ca5d35b 172.17.0.1:6373
   slots:[10923-16383] (5461 slots) master
S: af04acbb006161e3dcbc02ab85d1c877a44a302d 172.17.0.1:6374
   replicates e534ce115c343da74c064e46c1c505c42bf323c9
S: 66ffce7551d60e11c38e49026957a21d0e7aa3f6 172.17.0.1:6375
   replicates a6e1b39b0552c553cca87f5211479ded6ca5d35b
S: 9d312df094c34cbfc8b11b4a276c150bf05f6abe 172.17.0.1:6376
   replicates c38f4597630082c7abf786fbdd68012ccce87b86
Can I set the above configuration? (type 'yes' to accept): yes
>>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join
.
>>> Performing Cluster Check (using node 172.17.0.1:6371)
M: c38f4597630082c7abf786fbdd68012ccce87b86 172.17.0.1:6371
   slots:[0-5460] (5461 slots) master
   1 additional replica(s)
S: 9d312df094c34cbfc8b11b4a276c150bf05f6abe 172.17.0.1:6376
   slots: (0 slots) slave
   replicates c38f4597630082c7abf786fbdd68012ccce87b86
S: 66ffce7551d60e11c38e49026957a21d0e7aa3f6 172.17.0.1:6375
   slots: (0 slots) slave
   replicates a6e1b39b0552c553cca87f5211479ded6ca5d35b
S: af04acbb006161e3dcbc02ab85d1c877a44a302d 172.17.0.1:6374
   slots: (0 slots) slave
   replicates e534ce115c343da74c064e46c1c505c42bf323c9
M: e534ce115c343da74c064e46c1c505c42bf323c9 172.17.0.1:6372
   slots:[5461-10922] (5462 slots) master
   1 additional replica(s)
M: a6e1b39b0552c553cca87f5211479ded6ca5d35b 172.17.0.1:6373
   slots:[10923-16383] (5461 slots) master
   1 additional replica(s)
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.

```

## 验证
```shell
127.0.0.1:6371> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:6
cluster_my_epoch:1
cluster_stats_messages_ping_sent:226
cluster_stats_messages_pong_sent:208
cluster_stats_messages_sent:434
cluster_stats_messages_ping_received:203
cluster_stats_messages_pong_received:226
cluster_stats_messages_meet_received:5
cluster_stats_messages_received:434
total_cluster_links_buffer_limit_exceeded:0
127.0.0.1:6371> cluster nodes
9d312df094c34cbfc8b11b4a276c150bf05f6abe 172.17.0.1:6376@16376 slave c38f4597630082c7abf786fbdd68012ccce87b86 0 1692155449124 1 connected
66ffce7551d60e11c38e49026957a21d0e7aa3f6 172.17.0.1:6375@16375 slave a6e1b39b0552c553cca87f5211479ded6ca5d35b 0 1692155449000 3 connected
af04acbb006161e3dcbc02ab85d1c877a44a302d 172.17.0.1:6374@16374 slave e534ce115c343da74c064e46c1c505c42bf323c9 0 1692155450127 2 connected
e534ce115c343da74c064e46c1c505c42bf323c9 172.17.0.1:6372@16372 master - 0 1692155448622 2 connected 5461-10922
c38f4597630082c7abf786fbdd68012ccce87b86 172.17.0.1:6371@16371 myself,master - 0 1692155448000 1 connected 0-5460
a6e1b39b0552c553cca87f5211479ded6ca5d35b 172.17.0.1:6373@16373 master - 0 1692155449000 3 connected 10923-16383
```