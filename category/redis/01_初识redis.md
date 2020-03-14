# 初识redis
---

## redis 
> Redis是一个开源的使用ANSI C语言编写、遵守BSD协议、支持网络、可基于内存亦可持久化的日志型、Key-Value数据库，并提供多种语言的API。 

## redis 特征
* 速度快，10w OPS(数据存储到内存，用C语言实现，单线程)
* 持久化(redis将所有数据保存到内存当中，并且对数据的更新将异步的保存到磁盘上)
* 多种数据结构(String/Blobs/Bitmaps,Hash Tables(object!),Linked List,Sets,Sorted Sets)
* 多种编辑语言(java,php,python ...)
* 功能丰富(发布订阅，lua脚本，事务，pipeline)
* 简单(不依赖外部的库，单线程模型)
* 主从复制
* 高可用，分布式(Redis-Sentinel(v2.8)支持高可用，Redis-Cluster(v3.0)支持分布式)

## redis 典型使用场景
* 缓存系统
* 计数器
* 消息队列
* 排行榜
* 社交网络
* 实时系统

## redis 安装和配置
### redis 可执行文件说明
* redis-server 启动redis服务器
* redis-cli redis客户端命令行
* redis-benchmark redis性能测试工具
* redis-check-aof AOF文件修复工具
* redis-check-dump RDB文件检查工具
* redis-sentinel Sentinel服务器(2.8以后)

### redis 三种启动方式
* 最简启动 redis-server
* 动态参数启动 redis-server --port 6380
* 配置文件启动 redis-server configPaht

### redis 客户端返回值
> 状态回复<br/>
127.0.0.1:6379> ping <br/>
PONG

> 错误回复<br/>
127.0.0.1:6379> hget hello field<br/>
(error) WRONGTYPE Operation against a key holding the wrong kind of value

> 整数回复<br/>
127.0.0.1:6379> incr hello<br/>
(integer) 1

> 字符串回复<br/>
127.0.0.1:6379> get hello<br/>
"world"

> 多行字符串回复<br/>
> 127.0.0.1:6379> mget hello foo<br/>
> 1) "world"<br/>
> 2) "bar"<br/>

### redis 常用配置
* daemonize 是否是守护进程(no|yes)
* port redis对外端口
* logfile redis系统日志
* dir redis工作目录
