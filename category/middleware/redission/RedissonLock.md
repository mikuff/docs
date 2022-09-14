## tryLock()
> tryLock() 仅仅会在空闲的时候获取到锁。如果可用，则获取锁，并立即返回true,如果不可用则立即返回false。**及时加锁, 及时失败**。


### 测试代码
```java
@SpringBootTest
@Slf4j
public class RedissonTestApplicationTests {

    @Autowired
    private RedissonClient redisson;

    /*
     * @Author lwl
     * @Description tryLock无参数、单线程测试
     * @Date 2022/8/9 10:05
     * @param
     * @Return void
     **/
    @Test
    void testTryLockNoArgsBySimpleThread() throws InterruptedException {
        RLock lock = redisson.getLock("DEMO_3");
        try {
            log.info(Thread.currentThread().getName() + ",获取到锁");
            boolean b = lock.tryLock();
            if (b) {
                log.info(Thread.currentThread().getName() + ",加锁成功");
            } else {
                log.info(Thread.currentThread().getName() + ",加锁失败");
            }

            Thread.sleep(5 * 1000);
        } finally {
            log.info(Thread.currentThread().getName() + ",释放锁");
            lock.unlock();
        }
    }

    /*
     * @Author lwl
     * @Description tryLock无参数、多线程测试
     * @Date 2022/8/9 10:05
     * @param
     * @Return void
     **/
    @Test
    void testTryLockNoArgsByMultipleThread() throws InterruptedException {
        CountDownLatch latch = new CountDownLatch(1);
        ExecutorService executorService = Executors.newFixedThreadPool(3);
        for (int i = 0; i < 3; i++) {
            Runnable runnable = () -> {
                try {
                    RLock lock = redisson.getLock("DEMO_3");
                    boolean b = lock.tryLock();
                    if (b) {
                        log.info(Thread.currentThread().getName() + ",加锁成功");
                    } else {
                        log.info(Thread.currentThread().getName() + ",加锁失败");
                    }

                } catch (Exception e) {
                    log.info(Thread.currentThread().getName() + "," + e.getLocalizedMessage());
                }
            };
            executorService.submit(runnable);
        }
        executorService.shutdown();
        log.info("开始执行");
        latch.countDown();
        Thread.sleep(100000);
    }
}
```

### 测试结果
``` log
2022-08-09 10:07:37.930  INFO 23048 --- [           main] c.e.r.RedissonTestApplicationTests       : 开始执行
2022-08-09 10:07:37.970  INFO 23048 --- [pool-1-thread-3] c.e.r.RedissonTestApplicationTests       : pool-1-thread-3,加锁失败
2022-08-09 10:07:37.970  INFO 23048 --- [pool-1-thread-1] c.e.r.RedissonTestApplicationTests       : pool-1-thread-1,加锁失败
2022-08-09 10:07:37.971  INFO 23048 --- [pool-1-thread-2] c.e.r.RedissonTestApplicationTests       : pool-1-thread-2,加锁成功
```

### 源码分析
```java
public class RedissonLock extends RedissonExpirable implements RLock {

    @Override
    public boolean tryLock() {
        return get(tryLockAsync());
    }

    @Override
    public RFuture<Boolean> tryLockAsync() {
        return tryLockAsync(Thread.currentThread().getId());
    }

    @Override
    public RFuture<Boolean> tryLockAsync(long threadId) {
        return tryAcquireOnceAsync(-1, null, threadId);
    }

    // 加锁仅进行一次，成功则成功，失败则失败
    private RFuture<Boolean> tryAcquireOnceAsync(long leaseTime, TimeUnit unit, long threadId) {
        if (leaseTime != -1) {
            return tryLockInnerAsync(leaseTime, unit, threadId, RedisCommands.EVAL_NULL_BOOLEAN);
        }
        
        // tryLock() 加锁的实际逻辑走的是 tryLockInnerAsync 这个方法
        RFuture<Boolean> ttlRemainingFuture = tryLockInnerAsync(commandExecutor.getConnectionManager().getCfg().getLockWatchdogTimeout(), TimeUnit.MILLISECONDS, threadId, RedisCommands.EVAL_NULL_BOOLEAN);
        ttlRemainingFuture.onComplete((ttlRemaining, e) -> {
            if (e != null) {
                return;
            }

            // 加锁成功并且获取到锁之后,执行锁续期操作
            if (ttlRemaining) {
                scheduleExpirationRenewal(threadId);
            }
        });
        return ttlRemainingFuture;
    }

}

```

#### 加锁
```java
<T> RFuture<T> tryLockInnerAsync(long leaseTime, TimeUnit unit, long threadId, RedisStrictCommand<T> command) {
        internalLockLeaseTime = unit.toMillis(leaseTime);

        return evalWriteAsync(getName(), LongCodec.INSTANCE, command,
                "if (redis.call('exists', KEYS[1]) == 0) then " +
                        "redis.call('hincrby', KEYS[1], ARGV[2], 1); " +
                        "redis.call('pexpire', KEYS[1], ARGV[1]); " +
                        "return nil; " +
                        "end; " +
                        "if (redis.call('hexists', KEYS[1], ARGV[2]) == 1) then " +
                        "redis.call('hincrby', KEYS[1], ARGV[2], 1); " +
                        "redis.call('pexpire', KEYS[1], ARGV[1]); " +
                        "return nil; " +
                        "end; " +
                        "return redis.call('pttl', KEYS[1]);",
                Collections.singletonList(getName()), internalLockLeaseTime, getLockName(threadId));
    }
```
> 加锁的主要逻辑就是这段lua代码,传入的参数: KEYS[1]是传入的key名称,ARGV[1]是锁的租约时间 默认是30S,ARGV(2)是锁名称(uuid+:+线程ID)

    - 先用exists key命令判断是否锁是否被占据了，没有的话就用hset命令写入，key为锁的名称，field为"客户端唯一ID:线程ID"，value为1
    - 锁被占据了，判断是否是当前线程占据的，是的话value值加1
    - 锁不是被当前线程占据，返回锁剩下的过期时长
> **用了redis的Hash结构存储数据，如果发现当前线程已经持有锁了，就用hincrby命令将value值加1，value的值将决定释放锁的时候调用解锁命令的次数，达到实现锁的可重入性效果**

#### 续期
```java
 private void scheduleExpirationRenewal(long threadId) {
    ExpirationEntry entry = new ExpirationEntry();
    ExpirationEntry oldEntry = EXPIRATION_RENEWAL_MAP.putIfAbsent(getEntryName(), entry);
    if (oldEntry != null) {
        oldEntry.addThreadId(threadId);
    } else {
        entry.addThreadId(threadId);
        renewExpiration();
    }
}

private void renewExpiration() {
    ExpirationEntry ee = EXPIRATION_RENEWAL_MAP.get(getEntryName());
    if (ee == null) {
        return;
    }
    
    Timeout task = commandExecutor.getConnectionManager().newTimeout(new TimerTask() {
        @Override
        public void run(Timeout timeout) throws Exception {
            ExpirationEntry ent = EXPIRATION_RENEWAL_MAP.get(getEntryName());
            if (ent == null) {
                return;
            }
            Long threadId = ent.getFirstThreadId();
            if (threadId == null) {
                return;
            }
            
            RFuture<Boolean> future = renewExpirationAsync(threadId);
            future.onComplete((res, e) -> {
                if (e != null) {
                    log.error("Can't update lock " + getName() + " expiration", e);
                    return;
                }
                
                if (res) {
                    // reschedule itself
                    renewExpiration();
                }
            });
        }
    }, internalLockLeaseTime / 3, TimeUnit.MILLISECONDS);
    
    ee.setTimeout(task);
}

protected RFuture<Boolean> renewExpirationAsync(long threadId) {
    return evalWriteAsync(getName(), LongCodec.INSTANCE, RedisCommands.EVAL_BOOLEAN,
            "if (redis.call('hexists', KEYS[1], ARGV[2]) == 1) then " +
                    "redis.call('pexpire', KEYS[1], ARGV[1]); " +
                    "return 1; " +
                    "end; " +
                    "return 0;",
            Collections.singletonList(getName()),
            internalLockLeaseTime, getLockName(threadId));
}
```
> 当添加锁成功之后,为了避免任务没有执行完成,而导致redis中hashfield过期失效,因此加锁成功之后需要给锁添加续期的操作    
> 代码逻辑中可以很明确的体现除起了一个异步线程，线程通过每10秒钟的方式会对锁field 进行续期。假设key锁field因为其他某种原因从redis中消失了(过期、其他redis客户端释放了锁)，异步线程就不会在进行续期   
> 虽然tryLock()无参数是及时加锁，及时释放，**但是也表名 redission的设计思想中，只要加锁成功，就会进行续约操作**

## tryLock(long waitTime, long leaseTime, TimeUnit unit)
> 这里的三个参数,等待时间(waitTime),租约时间(leaseTime),时间单位类型
- 等待时间是指在加锁过程中整体的代码执行时间(包括自旋)
- 租约时间是指在redis中被加锁的key的过期时间

```java
public class RedissonLock extends RedissonExpirable implements RLock {
    @Override
    public boolean tryLock(long waitTime, long leaseTime, TimeUnit unit) throws InterruptedException {
        long time = unit.toMillis(waitTime);
        long current = System.currentTimeMillis();
        long threadId = Thread.currentThread().getId();

        // 尝试进行加锁，如果加锁成功tryAcquire()返回的是null值,加锁失败返回的是redis中锁的过期时间. 
        Long ttl = tryAcquire(leaseTime, unit, threadId);
        // lock acquired
        if (ttl == null) {
            return true;
        }
        
        // 如果加锁的时间超过了设置的等待时间,则判定加锁失败, 直接return false
        time -= System.currentTimeMillis() - current;
        if (time <= 0) {
            acquireFailed(threadId);
            return false;
        }
        
        // 尝试进行订阅, 如果订阅超时且订阅成功就取消订阅,判定加锁失败 return false
        current = System.currentTimeMillis();

        // 订阅分布式锁, 解锁时进行通知
        RFuture<RedissonLockEntry> subscribeFuture = subscribe(threadId);
        if (!subscribeFuture.await(time, TimeUnit.MILLISECONDS)) {
            if (!subscribeFuture.cancel(false)) {
                subscribeFuture.onComplete((res, e) -> {
                    if (e == null) {
                        // 等待超时，直接取消订阅
                        unsubscribe(subscribeFuture, threadId);
                    }
                });
            }
            acquireFailed(threadId);
            return false;
        }

        try {
            // 再次计算时间,time(剩余时间) - 订阅时间,如果剩余时间小于等于0,则判定加锁失败，return false
            time -= System.currentTimeMillis() - current;
            if (time <= 0) {
                acquireFailed(threadId);
                return false;
            }

            // 自旋进行尝试加锁
            while (true) {
                
                // 再次尝试进行加锁，如果加锁成功则返回true,如果失败则返回加锁的key的还有多少时间过期
                long currentTime = System.currentTimeMillis();
                ttl = tryAcquire(leaseTime, unit, threadId);
                if (ttl == null) {
                    return true;
                }

                // 计算代码执行时间，如果到目前为止代码执行时间超过等待时间,则判定加锁失败,return false
                time -= System.currentTimeMillis() - currentTime;
                if (time <= 0) {
                    acquireFailed(threadId);
                    return false;
                }


                // 根据锁TTL，调整阻塞等待时长；
                // 1、latch其实是个信号量Semaphore，调用其tryAcquire方法会让当前线程阻塞一段时间，避免在while循环中频繁请求获锁；
                // 当其他线程释放了占用的锁，会广播解锁消息，监听器接收解锁消息，并释放信号量，最终会唤醒阻塞在这里的线程
                // 该Semaphore的release方法，会在订阅解锁消息的监听器消息处理方法org.redisson.pubsub.LockPubSub#onMessage调用；
                currentTime = System.currentTimeMillis();
                if (ttl >= 0 && ttl < time) {
                    subscribeFuture.getNow().getLatch().tryAcquire(ttl, TimeUnit.MILLISECONDS);
                } else {
                    subscribeFuture.getNow().getLatch().tryAcquire(time, TimeUnit.MILLISECONDS);
                }

                // 如果剩余时间小于0则就判定加锁失败，return false
                time -= System.currentTimeMillis() - currentTime;
                if (time <= 0) {
                    acquireFailed(threadId);
                    return false;
                }
            }
        } finally {
            // 如果代码执行中出现异常就取消订阅,用于兜底的情况处理
            unsubscribe(subscribeFuture, threadId);
        }
    }
}
```
> 可以看出加锁的主体逻辑是 **初始加锁 -> 订阅 -> 自旋加锁 -> 兜底取消订阅,在整个逻辑中贯穿waitTime时间限制**。要么线程拿到锁返回成功；要么没拿到锁并且等待时间还没过就继续循环拿锁，同时监听锁是否被释放
### 加锁
```java
public class RedissonLock extends RedissonExpirable implements RLock {
    private Long tryAcquire(long leaseTime, TimeUnit unit, long threadId) {
        return get(tryAcquireAsync(leaseTime, unit, threadId));
    }

    private <T> RFuture<Long> tryAcquireAsync(long leaseTime, TimeUnit unit, long threadId) {
        // 如果传入了租期时间，则不会启动看门狗线程进行续约
        if (leaseTime != -1) {
            return tryLockInnerAsync(leaseTime, unit, threadId, RedisCommands.EVAL_LONG);
        }
        RFuture<Long> ttlRemainingFuture = tryLockInnerAsync(commandExecutor.getConnectionManager().getCfg().getLockWatchdogTimeout(), TimeUnit.MILLISECONDS, threadId, RedisCommands.EVAL_LONG);
        ttlRemainingFuture.onComplete((ttlRemaining, e) -> {
            if (e != null) {
                return;
            }
            // lock acquired
            if (ttlRemaining == null) {

                // 定时线程用于续约,增加过期时间
                scheduleExpirationRenewal(threadId);
            }
        });
        return ttlRemainingFuture;
    }
}    

```
### 订阅
``` java

订阅解锁消息 redisson_lock__channel:{$KEY}，并通过await方法阻塞等待锁释放，解决了无效的锁申请浪费资源的问题：
基于信息量，当锁被其它资源占用时，当前线程通过 Redis 的 channel 订阅锁的释放事件，一旦锁释放会发消息通知待等待的线程进行竞争
当 this.await返回false，说明等待时间已经超出获取锁最大等待时间，取消订阅并返回获取锁失败
当 this.await返回true，进入循环尝试获取锁
current = System.currentTimeMillis();
// 订阅分布式锁，解锁时进行通知
final RFuture<RedissonLockEntry> subscribeFuture = subscribe(threadId);
```

``` java
  public RFuture<E> subscribe(String entryName, String channelName) {
        // 从PublishSubscribeService获取对应的信号量。 相同的channelName获取的是同一个信号量
        // public AsyncSemaphore getSemaphore(ChannelName channelName) {
        //    return locks[Math.abs(channelName.hashCode() % locks.length)];
        // }

        AtomicReference<Runnable> listenerHolder = new AtomicReference<Runnable>();
        AsyncSemaphore semaphore = service.getSemaphore(new ChannelName(channelName));
        RPromise<E> newPromise = new RedissonPromise<E>() {
            @Override
            public boolean cancel(boolean mayInterruptIfRunning) {
                return semaphore.remove(listenerHolder.get());
            }
        };

        Runnable listener = new Runnable() {

            @Override
            public void run() {
                //  如果存在RedissonLockEntry， 则直接利用已有的监听
                E entry = entries.get(entryName);
                if (entry != null) {
                    entry.acquire();
                    semaphore.release();
                    entry.getPromise().onComplete(new TransferListener<E>(newPromise));
                    return;
                }
                
                E value = createEntry(newPromise);
                value.acquire();
                
                E oldValue = entries.putIfAbsent(entryName, value);
                if (oldValue != null) {
                    oldValue.acquire();
                    semaphore.release();
                    oldValue.getPromise().onComplete(new TransferListener<E>(newPromise));
                    return;
                }
                // 创建监听，
                RedisPubSubListener<Object> listener = createListener(channelName, value);
                // 订阅监听
                service.subscribe(LongCodec.INSTANCE, channelName, semaphore, listener);
            }
        };
        // 最终会执行listener.run
        semaphore.acquire(listener);
        listenerHolder.set(listener);
        
        return newPromise;
    }

```

``` java
public void acquire(Runnable listener) {
    acquire(listener, 1);
}

public void acquire(Runnable listener, int permits) {
    boolean run = false;

    synchronized (this) {
        // counter初始化值为1
        if (counter < permits) {
            // 如果不是第一次执行，则将listener加入到listeners集合中
            listeners.add(new Entry(listener, permits));
            return;
        } else {
            counter -= permits;
            run = true;
        }
    }

    // 第一次执行acquire， 才会执行listener.run()方法
    if (run) {
        listener.run();
    }
}
```

> 1、从PublishSubscribeService获取对应的信号量， 相同的channelName获取的是同一个信号量  
> 2、如果是第一次请求，则会立马执行listener.run()方法， 否则需要等上个线程获取到该信号量执行完方能执行； 
> 3、如果已经存在RedissonLockEntry， 则利用已经订阅就行  
> 4、如果不存在RedissonLockEntry， 则会创建新的RedissonLockEntry，然后执行  
> **线程会在自旋开始前进行订阅redis channel。在自旋过程中通过 subscribeFuture.getNow().getLatch().tryAcquire()调用信号量的方法来阻塞住相同锁的线程。当某一个线程释放锁之后，会广播解锁消息。监听器接收到解锁消息的时候
释放信号量。最终会唤起线程。这样就避免了在while循环中不停的向redis发起请求。**


## unlock()
``` java
public class RedissonLock extends RedissonExpirable implements RLock {
    @Override
    public void unlock() {
        try {
            get(unlockAsync(Thread.currentThread().getId()));
        } catch (RedisException e) {
            if (e.getCause() instanceof IllegalMonitorStateException) {
                throw (IllegalMonitorStateException) e.getCause();
            } else {
                throw e;
            }
        }
    }

    @Override
    public RFuture<Void> unlockAsync(long threadId) {
        RPromise<Void> result = new RedissonPromise<Void>();
        
        // 返回的RFuture如果持有的结果为true，说明解锁成功，返回NULL说明线程ID异常，加锁和解锁的客户端线程不是同一个线程
        RFuture<Boolean> future = unlockInnerAsync(threadId);
        
        
        future.onComplete((opStatus, e) -> {
            // 取消看门狗的续期任务
            cancelExpirationRenewal(threadId);

            if (e != null) {
                result.tryFailure(e);
                return;
            }

            if (opStatus == null) {
                IllegalMonitorStateException cause = new IllegalMonitorStateException("attempt to unlock lock, not locked by current thread by node id: "
                        + id + " thread-id: " + threadId);
                result.tryFailure(cause);
                return;
            }

            result.trySuccess(null);
        });

        return result;
    }


    protected RFuture<Boolean> unlockInnerAsync(long threadId) {
        return evalWriteAsync(getName(), LongCodec.INSTANCE, RedisCommands.EVAL_BOOLEAN,
                "if (redis.call('hexists', KEYS[1], ARGV[3]) == 0) then " +
                        "return nil;" +
                        "end; " +
                        "local counter = redis.call('hincrby', KEYS[1], ARGV[3], -1); " +
                        "if (counter > 0) then " +
                        "redis.call('pexpire', KEYS[1], ARGV[2]); " +
                        "return 0; " +
                        "else " +
                        "redis.call('del', KEYS[1]); " +
                        "redis.call('publish', KEYS[2], ARGV[1]); " +
                        "return 1; " +
                        "end; " +
                        "return nil;",
                Arrays.asList(getName(), getChannelName()), LockPubSub.UNLOCK_MESSAGE, internalLockLeaseTime, getLockName(threadId));
    }
}
```
### 解锁 lua
``` lua
1、如果分布式锁存在，但是value不匹配，表示锁已经被其他线程占用，无权释放锁，
if (redis.call('hexists', KEYS[1], ARGV[3]) == 0) then 
    return nil;
end; 
2、因为锁可重入，所以释放锁时不能把所有已获取的锁全都释放掉，一次只能释放一把锁，因此执行 hincrby 对锁的值减一
local counter = redis.call('hincrby', KEYS[1], ARGV[3], -1);
if (counter > 0) then
    2.1 释放一把锁后，如果还有剩余的锁，则刷新锁的失效时间并返回 0
    redis.call('pexpire', KEYS[1], ARGV[2]); 
    return 0;
else
    2.2 如果刚才释放的已经是最后一把锁，则执行del命令删除锁的key,并发布锁释放消息,返回 1
    redis.call('del', KEYS[1]); 
    2.3 这里的发布消息就是配合上面的信号量,释放信号量,最终会唤起线程。
    redis.call('publish', KEYS[2], ARGV[1]);
    return 1;
end;
return nil;
```

### IllegalMonitorStateException
> 非锁的持有者释放锁时抛出异常，这个问题本质上还是锁执行时间和过期时间的问题
> 1、线程A调用tryLock()方法，传入leaseTime参数。这个时候是不会启动看门狗线程的自动续期
> 2、因为A某种原因超时了，redis中锁过期了
> 3、线程B正常获取到了锁,开始执行业务代码
> 4、线程A再去释放锁,就会抛出 IllegalMonitorStateException

### 示例
```java

    @Test
    void testTryLockArgsBySimpleThread2() throws InterruptedException {

        // A线程，释放锁，不开启看门狗
        new Thread(() -> {
            RLock lock = redisson.getLock("DEMO_LOCK");
            try {
                boolean b = lock.tryLock(10, 5, TimeUnit.SECONDS);
                if (b) {
                    log.info("A 获取到了锁");
                }
                Thread.sleep(20 * 1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            } finally {
                log.info("A 释放了锁");
                lock.unlock();
            }
        }).start();
        Thread.sleep(5 * 1000);

        // A线程，不释放锁，开启看门狗
        new Thread(() -> {
            RLock lock = redisson.getLock("DEMO_LOCK");
            try {
                boolean b = lock.tryLock(6, TimeUnit.SECONDS);
                if (b) {
                    log.info("B 获取到了锁");
                }
                Thread.sleep(2 * 1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            } finally {
                log.info("B 不释放锁");
            }
        }).start();
        Thread.sleep(3000 * 10);
    }
```
```java
Exception in thread "Thread-3" java.lang.IllegalMonitorStateException: attempt to unlock lock, not locked by current thread by node id: c12bbc26-b49c-4f73-b130-f59df5fdd80a thread-id: 61
```
解决方法
``` java
finally
{
    if (rLock.isLocked()){
        rLock.unlock();
    }
}
```



## 存在的问题:  
### 单实例或slave-master
> 无论是通过set nx px 的方式使用分布式锁,还是 RedissonLock,都会存在下面两个问题  
> **1、单实例情况下redis挂掉,那所有的客户端都获取不到锁了**  
> **2、假设当前redis是多台机器做master-slave(一主多从和哨兵模式)。当在一个client在master上获取到锁,master挂掉之后,slave选举成功master, 由于加锁的key未完成同步,其他client 也会有机会加锁成功，执行业务代码,因此此时会有>=2个client执行了业务代码,不满足分布式锁的原则**   

### 锁过期时间和任务时间执行时间
> 由于使用set nx px 的形式,超时时间在具体使用的时候就会进行指定，且仅仅指定一次。如果业务的执行时间大于指定的超时时间就会出现业务代码未执行完成,redis中的key已经释放(锁释放).其他client也有机会进行加锁成功执行。  
> **在 RedissonLock 中通过另起一个线程进行续约的操作(看门狗) 后台起一个定时任务的线程，每隔一定时间对该锁进行续命，延长锁的时间来避免这个问题**  
> **当tryLock传入租约时间的时候不会启动看门狗线程**
    