
> 该锁只针对单实例有效,且不可重入

## 加锁
> 加锁是通过 set key value nx px 实现的,nx 代表key存在的时候不设置值,返回0。如果key不存在则设置值,返回1。px 则是代表超时时间,单位是毫秒

## 解锁
> 解锁是通过lua脚本操作，使用lua脚本是为了解锁的原子性 先判断当前锁的字符串是否与传入的值相等，是的话就删除Key，解锁成功

```lua
if redis.call('get',KEYS[1]) == ARGV[1] then 
   return redis.call('del',KEYS[1]) 
else
   return 0 
end
```

## 示例代码
```java
package com.broadu.common.redis;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.connection.RedisStringCommands;
import org.springframework.data.redis.connection.ReturnType;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.types.Expiration;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

/**
 * redis分布式锁
 *
 * @author 端木超群
 * @date 2020/11/30
 */
@Slf4j
@Component
public class RedisDistributedLock {
    /**
     * redis模板类注入
     */
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    /**
     * 超时时间
     */
    private static final Long TIMEOUT_MILLIS = 60 * 1000L;

    /**
     * lua释放锁语句
     */
    private static final String UNLOCK_LUA = "if redis.call('get',KEYS[1]) == ARGV[1] then " +
            "return redis.call('del',KEYS[1]) else return 0 end";

    /**
     * 线程变量
     */
    private final ThreadLocal<String> lockFlag = new ThreadLocal<>();

    /**
     * 获取redis分布式锁
     *
     * @param key 加锁的key
     * @return 获取成功/失败
     */
    public boolean getLock(String key) {
        try {
            RedisCallback<Boolean> redisCallback = connection -> {
                String uuid = UUID.randomUUID().toString();
                log.info("获取redis分布式锁uuid:{}", uuid);
                lockFlag.set(uuid);
                return connection.set(key.getBytes(StandardCharsets.UTF_8), uuid.getBytes(StandardCharsets.UTF_8),
                        Expiration.milliseconds(TIMEOUT_MILLIS), RedisStringCommands.SetOption.SET_IF_ABSENT);
            };
            return Boolean.TRUE.equals(redisTemplate.execute(redisCallback));
        } catch (Exception e) {
            log.error("获取redis分布式锁失败，失败原因：{}", e.getMessage());
        }
        return false;
    }

    /**
     * 释放redis分布式锁
     *
     * @param key 加锁的key
     * @return 释放成功/失败
     */
    public boolean releaseLock(String key) {
        try {
            RedisCallback<Boolean> redisCallback = connection -> {
                String lockValue = lockFlag.get();
                log.info("获取redis分布式锁uuid：{}", lockValue);
                return connection.eval(UNLOCK_LUA.getBytes(), ReturnType.BOOLEAN, 1,
                        key.getBytes(StandardCharsets.UTF_8), lockValue.getBytes(StandardCharsets.UTF_8));
            };
            return Boolean.TRUE.equals(redisTemplate.execute(redisCallback));
        } catch (Exception e) {
            log.error("获取redis分布式锁失败，失败原因：{}", e.getMessage());
        } finally {
            lockFlag.remove();
        }
        return false;
    }
}
```
