# SQL 优化
---

## 如何获取存在性能问题的SQL
- 通过用户反馈获取存在性能问题的SQL
- 通过慢查询获取存在性能问题的SQL
- 实时获取存在性能问题的SQL

## 慢查询日志
### 配置慢查询日志
``` txt
[mysqld]
slow_query_log = ON
slow_query_log_file = /usr/local/mysql/data/slow.log

#单位是秒
long_query_time = 1 


# 重启mysql
sudo service mysql restart
```

> 使用慢查询日志获取有性能问题的SQL：<br/>
> slow_query_log 启动停止记录慢查询日志<br/>
> slow_query_log_file 指定慢查询日志的存储路径及文件<br/>
> long_query_time 指定记录慢查询日志SQL执行时间的阈值<br/>
> log_queries_not_using_indexes 是否记录未使用索引的SQL<br/>
> 记录所有符合条件的SQL，包括查询语句，数据修改语句，已经回滚的SQL<br/>

``` log
# 用户信息
# User@Host: root[root] @ localhost []  Id:     2

# 查询时间
# Query_time: 0.106497  

# 查询所使用锁的时间
# Lock_time: 0.000075 

# 返回的数据行数
# Rows_sent: 300024  

# 扫描的数据行数
# Rows_examined: 300024

# SQL执行的时间戳
SET timestamp=1585290238;

# sql语句
select first_name,last_name from employees where emp_no is not null;
```

### mysqldumpslow
``` shell
root@sibyl:/var/log/mysql# mysqldumpslow help

Reading mysql slow query log from help
Can't open help: No such file or directory at /usr/bin/mysqldumpslow line 97.
root@sibyl:/var/log/mysql# mysqldumpslow --help
Usage: mysqldumpslow [ OPTS... ] [ LOGS... ]

Parse and summarize the MySQL slow query log. Options are

  --verbose    verbose
  --debug      debug
  --help       write this text to standard output

  -v           verbose
  -d           debug
  -s ORDER     what to sort by (al, at, ar, c, l, r, t), 'at' is default
                al: average lock time
                ar: average rows sent
                at: average query time
                 c: count
                 l: lock time
                 r: rows sent
                 t: query time  
  -r           reverse the sort order (largest last instead of first)
  -t NUM       just show the top n queries
  -a           don't abstract all numbers to N and strings to 'S'
  -n NUM       abstract numbers with at least n digits within names
  -g PATTERN   grep: only consider stmts that include this string
  -h HOSTNAME  hostname of db server for *-slow.log filename (can be wildcard),
               default is '*', i.e. match all
  -i NAME      name of server instance (if using mysql.server startup script)
  -l           don't subtract lock time from total time

root@sibyl:/var/log/mysql# mysqldumpslow -s r -t 10 slow_query_log.log 

Reading mysql slow query log from slow_query_log.log
Count: 1  Time=0.09s (0s)  Lock=0.00s (0s)  Rows=300024.0 (300024), root[root]@localhost
  select last_name from employees where emp_no is not null

Count: 1  Time=0.11s (0s)  Lock=0.00s (0s)  Rows=300024.0 (300024), root[root]@localhost
  select first_name,last_name from employees where emp_no is not null

Count: 1  Time=0.00s (0s)  Lock=0.00s (0s)  Rows=6.0 (6), root[root]@localhost
  show databases

Count: 3  Time=0.00s (0s)  Lock=0.00s (0s)  Rows=1.0 (3), root[root]@DESKTOP-344TD17.lan
  SHOW SESSION VARIABLES LIKE 'S'

Count: 2  Time=0.00s (0s)  Lock=0.00s (0s)  Rows=1.0 (2), root[root]@DESKTOP-344TD17.lan
  SHOW SESSION STATUS LIKE 'S'

Count: 1  Time=2.00s (2s)  Lock=0.00s (0s)  Rows=1.0 (1), root[root]@localhost
  select sleep(N)

Count: 1  Time=0.00s (0s)  Lock=0.00s (0s)  Rows=1.0 (1), root[root]@localhost
  show variables like 'S'

Count: 4  Time=0.00s (0s)  Lock=0.00s (0s)  Rows=0.0 (0), root[root]@localhost


Count: 4  Time=0.00s (0s)  Lock=0.00s (0s)  Rows=0.0 (0), root[root]@localhost


Count: 4  Time=0.00s (0s)  Lock=0.00s (0s)  Rows=0.0 (0), root[root]@localhost


```
### pt-query-digest
``` shell
root@sibyl:/var/log/mysql# pt-query-digest --explain h=localhost,u=root,p=123 slow_query_log.log > ./slow_query_log.rep
```
``` txt

# 130ms user time, 0 system time, 32.38M rss, 42.90M vsz
# Current date: Fri Mar 27 14:39:02 2020
# Hostname: sibyl
# Files: slow_query_log.log
# Overall: 15 total, 8 unique, 0.01 QPS, 0.00x concurrency _______________
# Time range: 2020-03-27T06:20:21 to 2020-03-27T06:39:02
# Attribute          total     min     max     avg     95%  stddev  median
# ============     ======= ======= ======= ======= ======= ======= =======
# Exec time             2s   124us      2s   147ms   105ms   487ms   799us
# Lock time          989us       0   188us    65us    89us    42us    66us
# Rows sent        586.00k       1 292.99k  39.07k 283.86k  96.49k    0.99
# Rows examine     595.46k       0 292.99k  39.70k 283.86k  96.25k 1012.63
# Query size           590      14      67   39.33   54.21   13.23   36.69

# Profile
# Rank Query ID                         Response time Calls R/Call V/M   I
# ==== ================================ ============= ===== ====== ===== =
#    1 0x59A74D08D407B5EDF9A57DD5A41...  2.0009 90.7%     1 2.0009  0.00 SELECT
#    2 0xFACB41CCE036CC57C5CF5C39727...  0.1065  4.8%     1 0.1065  0.00 SELECT employees
# MISC 0xMISC                            0.0979  4.4%    13 0.0075   0.0 <6 ITEMS>

# Query 1: 0 QPS, 0x concurrency, ID 0x59A74D08D407B5EDF9A57DD5A41825CA at byte 0
# This item is included in the report because it matches --limit.
# Scores: V/M = 0.00
# Time range: all events occurred at 2020-03-27T06:20:21
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ============ === ======= ======= ======= ======= ======= ======= =======
# Count          6       1
# Exec time     90      2s      2s      2s      2s      2s       0      2s
# Lock time      0       0       0       0       0       0       0       0
# Rows sent      0       1       1       1       1       1       0       1
# Rows examine   0       0       0       0       0       0       0       0
# Query size     2      15      15      15      15      15       0      15
# String:
# Databases    employees
# Hosts        localhost
# Users        root
# Query_time distribution
#   1us
#  10us
# 100us
#   1ms
#  10ms
# 100ms
#    1s  ################################################################
#  10s+
# EXPLAIN /*!50100 PARTITIONS*/
select sleep(2)\G
# *************************** 1. row ***************************
#            id: 1
#   select_type: SIMPLE
#         table: NULL
#    partitions: NULL
#          type: NULL
# possible_keys: NULL
#           key: NULL
#       key_len: NULL
#           ref: NULL
#          rows: NULL

# Query 2: 0 QPS, 0x concurrency, ID 0xFACB41CCE036CC57C5CF5C3972749CA7 at byte 1787
# This item is included in the report because it matches --limit.
# Scores: V/M = 0.00
# Time range: all events occurred at 2020-03-27T06:23:58
# Attribute    pct   total     min     max     avg     95%  stddev  median
# ============ === ======= ======= ======= ======= ======= ======= =======
# Count          6       1
# Exec time      4   106ms   106ms   106ms   106ms   106ms       0   106ms
# Lock time      7    75us    75us    75us    75us    75us       0    75us
# Rows sent     49 292.99k 292.99k 292.99k 292.99k 292.99k       0 292.99k
# Rows examine  49 292.99k 292.99k 292.99k 292.99k 292.99k       0 292.99k
# Query size    11      67      67      67      67      67       0      67
# String:
# Databases    employees
# Hosts        localhost
# Users        root
# Query_time distribution
#   1us
#  10us
# 100us
#   1ms
#  10ms
# 100ms  ################################################################
#    1s
#  10s+
# Tables
#    SHOW TABLE STATUS FROM `employees` LIKE 'employees'\G
#    SHOW CREATE TABLE `employees`.`employees`\G
# EXPLAIN /*!50100 PARTITIONS*/
select first_name,last_name from employees where emp_no is not null\G
# *************************** 1. row ***************************
#            id: 1
#   select_type: SIMPLE
#         table: employees
#    partitions: NULL
#          type: index
# possible_keys: PRIMARY
#           key: index_first_last_name
#       key_len: 34
#           ref: NULL
#          rows: 299113
#      filtered: 90.00
#         Extra: Using where; Using index

```

## 实时获取有问题的sql
```sql
# 查询当前服务器执行超过60s的sql，周期性的来执行这条sql，就能查出有问题的sql
select id,`user`,`host`,DB,COMMAND,`time`,state,info from information_schema.PROCESSLIST where time >= 60;
```

## SQL预解析和生成执行计划
### sql语句执行流程
- 客户端发送SQL请求给服务器
- 服务器检查是否可以在查询缓存中命中该SQL
- 服务器端进行SQL解析，预处理，再由优化器生成对应的执行计划
- 根据执行计划，调用存储引擎API来查询数据
- 将结果返回给客户端

### 查询缓存对sql的影响
> 在解析sql之前，会优先检查这个sql是否命中缓存数据，通过一个大小写敏感的hash字符串实现的，由于是使用hash实现的，因此要求查询的语句和缓存的中的语句完全相同,如果相同，则直接从缓存中拿出查询结果，返回给客户端，整个过程中，sql没有被解析和执行

#### 查询缓存的相关配置
```txt
# 设置查询缓存是否可用，on，off，demand，如果是demand则在查询语句中使用sql_cache,sql_no_cache控制
query_cache_type

# 设置查询缓存的内存大小
query_cache_size

# 设置查询缓存可用的存储最大值
query_cache_limit

#设置表被锁之后，是否返回缓存中的数据
query_cache_wlock_invalidate

# 设置查询缓存分配的内存块最小单位
query_cache_min_res_unit

```

#### 查询缓存子过程
MySQL依照这个执行计划和存储引擎进行交互，这个阶段包括多个子过程：
- 解析SQL，预处理，优化SQL执行计划
- 语法解析阶段是通过关键字对MySQL语句进行解析，并生成一颗对应的”解析树“，MySQL解析器将使用MySQL语法规则验证和解析查询，
   	- 包括检查语法是否使用了正确的关键字、关键字的顺序是否正确等，预处理阶段是根据MySQL规则进一步检查解析树是否合法。 
   	- 检查查询中所涉及的表和数据列是否存在及名字或别名是否存在歧义等。
   	- 语法检查全部通过了，查询优化器就可以生成查询计划了。

### 生成错误的执行计划
- 统计信息不准确
- 执行计划中的成本估算不等同于实际的执行计划的成本。
- MySQL优化器所认为的最优可能与你所认为的最优不一样，基于其成本模型选择最优的执行计划。
- MySQL从不考虑其他并发的查询，这可能会影响当前查询的速度
- MySQL有时候也会基于一些固定的规则来生成执行计划
- MySQL不会考虑不受其控制的成本(存储过程、用户自定义的函数)

### mysql优化器可优化的sql类型
- 重新定义表的关联顺序
- 将外连接转化为内连接
- 使用等价变换规则， 列如(5 = 5 and a > 5) 将被改成 a > 5
- 优化count()、main()和max()
- 子查询优化，将子查询改为关联查询
- 提前终止查询
- 对in()条件进行优化， 先对in()中的数据进行排序，然后再根据二分查找的方式是否满足条件。

## 确认SQL查询所消耗的时间
### 使用profile
- set profiling = 1; 启动profile,这是一个session级的配制
- 执行查询
  - show profiles; 查看每一个查询所消耗的总时间的信息
  - show profile for query N; 查询的每个阶段所消耗的时间
  - show profile 这种查看方式官方不推荐使用了，推荐使用performance_schema;

### 使用performance_schema
``` sql
SET SQL_SAFE_UPDATES = 0;
UPDATE setup_instruments set enabled = 'YES', TIMED = 'YES' WHERE name LIKE 'stage%';
UPDATE setup_consumers set enabled = 'YES' WHERE NAME LIKE 'events%';
```

``` sql
SELECT a.THREAD_ID,SQL_TEXT,c.EVENT_NAME,(c.TIMER_END - c.TIMER_START)/1000000000 AS 'DURATION (ms)'
FROM events_statements_history_long a
JOIN threads b ON a.THREAD_ID=b.THREAD_ID
JOIN events_stages_history_long c ON c.THREAD_ID=b.THREAD_ID
AND c.EVENT_ID BETWEEN a.EVENT_ID AND a.END_EVENT_ID
WHERE b.PROCESSLIST_ID=CONNECTION_ID()
AND a.EVENT_NAME= 'statement/sql/select'
ORDER BY a.THREAD_ID,c.EVENT_ID;
```

## 特定场景下SQL优化
### 大表更新和删除
``` sql
DELIMITER $$
USE `imooc`$$
DROP PROCEDURE IF EXISTS `p_delete_rows`$$
CREATE DEFINER=`root`@`127.O.O.1` PROCEDURE `p_delete_rows`()
  BEGIN
  DECLARE v_rows INT;
  SET v_rows = 1;
  WHILE v_rows > 0
  DO
    DELETE FROM sbtestl WHERE id >= 90000 AND id <= 190000 LIMIT 5000;
    SELECT ROW_COUNT() INTO v_rows;
    SELECT SLEEP(5); 
  END WHILE;
END$$
DELIMITER ;
```
### 大表结构修改
``` shell
pt-online-schema-change \
--alter="MODIFY c VARCHAR(150) NOT NULL DEFAULT ''" \
--user=user \
--password=password \
D=database_name \
t=table_name \
--charset=utf8 \
--execute
```

### 优化not in 和 <>的查询
``` sql
select customer_id,first_name,last_name,email,
from customer
where customer_id
not in(select customer_id from payment);

# 可以将上述查询优化为left join的方式
select a.customer_id,a.first_name,a.last_name,a.email
from customer a
left join payment b on a.customer_id = b.customer_id
where b.customer_id is null;
```
### 汇总优化查询
``` sql
select count(*) from product_comment where product_id = 999;

# 这种方式可以使用汇总表来统计，以备后续的查询来使用

```