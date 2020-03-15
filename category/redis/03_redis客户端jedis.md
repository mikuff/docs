# redis客户端 jedis
---
##直连
![](./img/jedis直连.png)
##连接池
![](./img/jedis连接池.png)
```java
public class PoolTest
{
    public static void main(String[] args)
    {
        Jedis jedis = null;
        GenericObjectPoolConfig config = new GenericObjectPoolConfig();
        // 使用config 来配置Jedis
        JedisPool jedisPool = new JedisPool(config,"localhost");
        try
        {
            jedis = jedisPool.getResource();
            String hello = jedis.get("hello");
            System.out.println(hello);
        }
        catch (Exception e)
        {
            e.printStackTrace();
        }
        finally
        {
            if(jedis != null)
                jedis.close();
        }

    }
}
```
## 直连和连接池对比
--|优点|缺点
-|-|-
直连|简单方便，适用于少量长连接场景|存在每次新建/关闭TCP开销.资源无法控制，存在链接泄漏的可能.Jedis对象不安全
连接池|Jedis预先生成，降低开销使用，连接池的形式保护和控制资源的使用|相对于直连，使用相对麻烦，尤其是在参数的管理上需要很多参数来保证，一旦规划不合理也会出现问题

## jedis 配置和优化
### common-pool配置
参数名|含义|默认值|使用建议
-|-|-|-
maxTotal|资源池最大连接数|8|-
maxIdle|资源池允许最大空闲数|8|建议maxTotal=maxIdle 减少创建新连接的开销
minIdle|资源池确保最小空闲数|0|建议预热minIdle，减少第一次启动后新连接的开销
jmxEnabled|是否开启jmx监控，可用于监控|true|建议开启
blockWhenExhausted|当资源池用尽时，调用者是否要等待，当只为true时，maxWaitMillis才会生效|true|建议使用默认值
maxWaitMillis|当资源池用尽后，调用者的最大等待时间|-1(表示永不超时)|不建议使用默认值
testOnBorrow|相资源池借用连接时，是否做连接有效性检测,无效链接会被移除|false|建议false
testOnReturn|相资源池归还连接时，是否做连接有效性检测,无效链接会被移除|false|建议false

### 常见问题及解决思路
- 慢查询阻塞，池子连接hang住，为每个操作设置超时时间以及 maxWaitMillis的超时时间
- 资源池设置不合理,例如qps高，池子小
- 连接泄露(没有close()):此类问题笔记难定位，例如client list，netstat等
- DNS异常

### 连接泄露演示
```java
public class JedisPoolTest {
    public static void main(String[] args) {
        JedisPoolConfig config = new JedisPoolConfig();
        config.setMaxTotal(10);
        config.setMaxWaitMillis(1000);
        JedisPool pool = new JedisPool(config, "localhost");

        for (int i=0;i<10;i++)
        {
            Jedis jedis = null;
            try {
                jedis = pool.getResource();
                jedis.ping();
            } catch (Exception e) {
                e.printStackTrace();
            }
            finally{
                //在连接使用完成之后，要使用close()将连接归还到连接池
                if(jedis != null)
                {
                    jedis.close();
                }
            }
        }
        pool.getResource().ping();
    }
}
```
```java
Exception in thread "main" redis.clients.jedis.exceptions.JedisExhaustedPoolException: Could not get a resource since the pool is exhausted
    at redis.clients.jedis.util.Pool.getResource(Pool.java:53)
    at redis.clients.jedis.JedisPool.getResource(JedisPool.java:234)
    at JedisPoolTest.main(JedisPoolTest.java:23)
Caused by: java.util.NoSuchElementException: Timeout waiting for idle object
    at org.apache.commons.pool2.impl.GenericObjectPool.borrowObject(GenericObjectPool.java:439)
    at org.apache.commons.pool2.impl.GenericObjectPool.borrowObject(GenericObjectPool.java:349)
    at redis.clients.jedis.util.Pool.getResource(Pool.java:50)
    ... 2 more
```
