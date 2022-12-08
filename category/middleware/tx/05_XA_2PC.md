## 两阶段提交协议
XA 首先定义了两种角色，全局的事务管理器（Transaction Manager） 和 局部资源管理器（resource Manager）。这里全局事务管理器就是来协调各个节点统一操作的角色，通常我们也称为事务协调者。局部资源管理器也就是参与事务执行的进程，通常我们也称为事务参与者。 事务的执行过程由协调者统一来决策，其它节点只需要按照协调者的指令来完成具体的事务操作即可。而协调者在协商各个事务节点的过程中、什么情况下决定集体提交事务，什么情况下又决定集体回滚事务，这里取决于XA事务模型里使用了哪种协商协议（2PC、3PC)。  
**2PC 协议的核心思路是协调者通过和参与者通过两个阶段的协商达到最终操作的一致性，首先第一阶段的目的是确认各个参与者可否具备执行事务的条件。然后根据第一阶段各个参与者响应的结果，制定出第二阶段的事务策略。如果第一阶段有任意一个参与者不具备事务执行条件，那么第二阶段的决策就是统一回滚，只有在所有参与者都具备事务执行的条件下，才进行整体事务的提交**

![](./img/两阶段事务概览.png)

### 准备阶段
首先协调者向所有参与者发起Prepare指令， 参与者收到指令后首先检查是否具备事务执行条件，在具备条件后，参与者开始对事务相关的数据进行加锁、然后再生成事务相关日志(redo log、undo log)，最后参与者会根据这两个操作的执行情况来向协调者响应成功或失败。
![](./img/2PC准备阶段.png)

### 提交阶段
当协调者收到所有参与者的响应结果后，协调者会根据结果来做出最终决策，如果所有参与者都响应成功，那么协调者会决定提交事务，并且记录全局事务信息（事务信息、状态为commit），然后向所有参与者发送commit指令，参与者收到commit指令后会对上一阶段生成的事务数据进行最后的提交。
![](./img/2PC提交阶段1.png)

当有任意一个参与者响应失败（或者超时），协调者会决定回滚事务，并且记录全局事务状态（事务信息、状态为abort），然后向所有参与者发送abort指令，当参与者收到abort指令后，会进行事务回滚，清除上一个阶段生成的redo log 和undo log。

![](./img/2PC提交阶段2.png)

### 两阶段提交异常
#### 参与者挂掉
如果在第一阶段，协调者发送Prepare指令给所有的参与者后，参与者挂掉了，那么此时协调者因为迟迟收不到参与者的消息而导致超时，所以协调者在超时之后会统一发送abort指令进行事务回滚。

如果在第二阶段，协调者发送commit或者abort指令给所有参与者后，参与者挂掉了，那么协调者会在超时之后进行消息重发，直到参与者恢复后收到到commit或者abort ，向协调者返回成功。

![](./img/2PC提交阶段_参与者挂掉.png)

#### 协调者挂掉
协调者在第一阶段发送Prepare指令后挂掉，那么此时参与者此时会一直得不到协调者下一步的指令，那么此时参与者会一直陷入阻塞状态，资源也会一直被锁住，直到协调者恢复之后向参与者发出下一步的指令。

协调者在第二阶段挂掉，那么此时协调者已向所有者发出最后阶段的指令了，所以收到指令的参与者会完成最后的commit或rollback操作，对于参与者来说事务已经结束，所以不存在阻塞和锁的问题， 当协调者恢复后，会把事务日志状态标记为结束。

![](./img/2PC提交阶段_协调者挂掉.png)

#### 网络丢包
在第一阶段，协调者发送给参与者的消息丢失了，那么此时参与者会因为没有收到消息不会执行任何动作，所以也不会响应协调者任何消息，此时协调者会因为没有收到参与者的响应而超时，所以协调者会决定决定回滚事务，向所有参与者发送abort指令。

![](./img/2PC提交阶段_准备阶段网络丢包.png)

在第二阶段，无论是协调者发送给参与者消息丢失、还是参与者响应协调者消息丢失，都会导致协调者超时，所以这种时候协调者会进行重试，直到所有参与者都响应成功。

![](./img/2PC提交阶段_提交阶段网络丢包.png)

#### 数据不一致
我们发现在一般的的场景里，出现了问题2PC好像都能解决 ，但我们去抽丝剥茧的挖细节的时，就会发现2PC在某些场景会出现数据不一致的情况。

比如说，协调者在第二阶段向部分参与者发送了commit指令后挂了，那么此时收到了commit指令的参与者会进行事务提交，然后未收到消息的参与者还是等着协调者的指令，所以这个时候会产生数据的不一致，此时必须要等协调者恢复之后重新发送指令，参与者才能达到最终的一致状态。

![](./img/2PC提交阶段_数据不一致.png)

还有如果在第二阶段网络发生问题导致部分消息丢失，有些参与者收到了commit指令，有些参与者还没有收到commit指令，结果收到了指令的参与者提交了事务，没收到消息的参与者还在等指令，它不知道该进行回滚还是提交，这个时候同样也会产生数据不一致的问题。

### 两阶段提交遗留问题
- **性能问题**: 从事务开始到事务最终提交或回滚，这期间所有参与者的资源一致处于锁定状态，所以注定2PC的性能不会太高。
- **数据不一致风险**: 从上面我们分析知道，极端情况下不管是由于协调者故障，还是网络分区都会有导致数据不一致的风险。
- **协调者故障导致的事务阻塞问题**: 在两阶段提交协议里，我们会发现协调者是一个至关重要角色，参与者无论任何时候出问题，都会在因为协调者没收到参与者的消息而超时，协调者超时之后任然能做出下一步的决策，但是协调者问题后，流程就没办法继续了，此时参与者因为没有收到协调者下一步指令不知道是该进行commit还是rollback（这里也许有人会有疑问，既然协调者可以超时，那参与者为什么不可以超时呢，这个问题放到3PC解答），所有的参与者必须等待协调者恢复之后才能做出下一步的动作。

**2PC 核心是通过两个阶段的协商达到最终操作的一致性， 第一阶段的目的是确认各个参与者可否具备执行事务的条件。根据第一阶段的结果然后第二阶段再决定整体事务是进行提交还是回滚**   
**2PC大部分情况都能协商各个参与者达成一致，但是在极端情况下（协调者挂了、网络分区），还是会产生数据不一致问题，除此之外协调者单点故障会造成事务阻塞，然后2PC整个事务过程是会锁定资源的，所有性能也不高**


## atomikos 2pc

``` java

@Configuration
@MapperScan(basePackages = {"com.lwl.atomikos.mapper.dsone"}, sqlSessionFactoryRef = "dsOneSqlSessionFactory")
@MapperScan(basePackages = {"com.lwl.atomikos.mapper.dstwo"}, sqlSessionFactoryRef = "dsTwoSqlSessionFactory")
public class DbConfiguration {

    // 数据源dsOne
    @Bean
    @Primary
    @ConfigurationProperties(prefix = "spring.datasource.druid.ds-one")
    public DataSourceProperties dsOneProperties() {
        return new DataSourceProperties();
    }

    @Bean
    @Primary
    public DataSource dsOneDataSource() {

        // 数据源配置信息
        DataSourceProperties dsOneProperties = dsOneProperties();

        // druid连接池数据源
        DruidXADataSource  dataSource = new DruidXADataSource();
        dataSource.setDriverClassName(dsOneProperties.getDriverClassName());
        dataSource.setUrl(dsOneProperties.getUrl());
        dataSource.setUsername(dsOneProperties.getUsername());
        dataSource.setPassword(dsOneProperties.getPassword());

        // 包装atomikos数据源
        AtomikosDataSourceBean atomikosDataSourceBean = new AtomikosDataSourceBean();
        atomikosDataSourceBean.setUniqueResourceName("ds-one");
        atomikosDataSourceBean.setXaDataSource(dataSource);
        return atomikosDataSourceBean;
    }

    // 数据源dsTwo
    @Bean
    @ConfigurationProperties(prefix = "spring.datasource.druid.ds-two")
    public DataSourceProperties dsTwoProperties() {
        return new DataSourceProperties();
    }

    @Bean
    public DataSource dsTwoDataSource() {
        // 数据源配置信息
        DataSourceProperties dsTwoProperties = dsTwoProperties();

        // druid连接池数据源
        DruidXADataSource  dataSource = new DruidXADataSource();
        dataSource.setDriverClassName(dsTwoProperties.getDriverClassName());
        dataSource.setUrl(dsTwoProperties.getUrl());
        dataSource.setUsername(dsTwoProperties.getUsername());
        dataSource.setPassword(dsTwoProperties.getPassword());

        // 包装atomikos数据源
        AtomikosDataSourceBean atomikosDataSourceBean = new AtomikosDataSourceBean();
        atomikosDataSourceBean.setUniqueResourceName("ds-two");
        atomikosDataSourceBean.setXaDataSource(dataSource);
        return atomikosDataSourceBean;
    }


    // 用于使用的是mybatis，因此通过数据dsOne构建MybatisSqlSessionFactoryBean
    // 如果是jdbc则直接构建jdbcTemplate
    @Bean
    public SqlSessionFactory dsOneSqlSessionFactory() throws Exception {
        MybatisSqlSessionFactoryBean factoryBean = new MybatisSqlSessionFactoryBean();
        factoryBean.setDataSource(dsOneDataSource());
        factoryBean.setMapperLocations(new PathMatchingResourcePatternResolver().getResources("classpath*:mapper/*.xml"));
        return factoryBean.getObject();
    }

    @Bean
    public SqlSessionTemplate dsOneSqlSessionTemplate() throws Exception {
        SqlSessionTemplate template = new SqlSessionTemplate(dsOneSqlSessionFactory());
        return template;
    }

    // dsTwo构建MybatisSqlSessionFactoryBean
    @Bean
    public SqlSessionFactory dsTwoSqlSessionFactory() throws Exception {
        MybatisSqlSessionFactoryBean factoryBean = new MybatisSqlSessionFactoryBean();
        factoryBean.setDataSource(dsTwoDataSource());
        factoryBean.setMapperLocations(new PathMatchingResourcePatternResolver().getResources("classpath*:mapper/*.xml"));
        return factoryBean.getObject();
    }

    @Bean
    public SqlSessionTemplate dsTwoSqlSessionTemplate() throws Exception {
        SqlSessionTemplate template = new SqlSessionTemplate(dsTwoSqlSessionFactory());
        return template;
    }
}
```

``` java
@Configuration
public class AtomikosConfig {

    @Bean(name = "atomikosTransactionManager")
    public TransactionManager atomikosTransactionManager() {
        UserTransactionManager userTransactionManager = new UserTransactionManager();
        userTransactionManager.setForceShutdown(false);
        return userTransactionManager;
    }

    @Bean(name = "userTransaction")
    public UserTransaction userTransaction() throws Throwable {
        UserTransactionImp userTransactionImp = new UserTransactionImp();
        userTransactionImp.setTransactionTimeout(10000);
        return userTransactionImp;
    }

    @Bean(name = "transactionManager")
    @DependsOn({"userTransaction", "atomikosTransactionManager"})
    @Primary
    public PlatformTransactionManager transactionManager() throws Throwable {
        UserTransaction userTransaction = userTransaction();
        TransactionManager atomikosTransactionManager = atomikosTransactionManager();
        return new JtaTransactionManager(userTransaction, atomikosTransactionManager);
    }
}

```

``` java
@Service
public class AtomikosServiceImpl implements AtomikosService {

    @Override
    @Transactional(rollbackFor = RuntimeException.class)
    public void insertAll() {
        UserEntity user = new UserEntity();
        user.setUsername("ds-one-" + UUID.randomUUID().toString());
        user.setAddress("测试-one");
        user.setCreateDate(new Date());
        atomikosDsoneMapper.insert(user);

        UserEntity userTwo = new UserEntity();
        userTwo.setUsername("ds-two-" + UUID.randomUUID().toString());
        userTwo.setAddress("测试-two");
        userTwo.setCreateDate(new Date());
        atomikosDstwoMapper.insert(userTwo);

        int i = Math.abs(new Random().nextInt(10));
        if (i % 2 == 0) {
            throw new RuntimeException("抛出异常");
        }
    }
}
```
### 成功日志分析
``` log
2022-12-08 14:39:36.106 DEBUG 16972 --- [nio-8011-exec-3] c.a.i.i.CompositeTransactionManagerImp   : createCompositeTransaction ( 10000 ): created new ROOT transaction with id 172.25.224.1.tm167048157610500002
Creating a new SqlSession
Registering transaction synchronization for SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@76071908]
2022-12-08 14:39:36.107 DEBUG 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AbstractDataSourceBean   : AtomikosDataSoureBean 'ds-one': getConnection()...
2022-12-08 14:39:36.107  INFO 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AbstractDataSourceBean   : AtomikosDataSoureBean 'ds-one': init...
2022-12-08 14:39:36.107 DEBUG 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@21d7a7fd: calling getAutoCommit...
2022-12-08 14:39:36.107 DEBUG 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@21d7a7fd: calling toString...
JDBC Connection [com.mysql.cj.jdbc.ConnectionImpl@21d7a7fd] will be managed by Spring
2022-12-08 14:39:36.107 DEBUG 16972 --- [nio-8011-exec-3] c.a.icatch.imp.CompositeTransactionImp   : addParticipant ( XAResourceTransaction: 3137322E32352E3232342E312E746D313637303438313537363130353030303032:3137322E32352E3232342E312E746D33 ) for transaction 172.25.224.1.tm167048157610500002
2022-12-08 14:39:36.108 DEBUG 16972 --- [nio-8011-exec-3] c.a.datasource.xa.XAResourceTransaction  : XAResource.start ( 3137322E32352E3232342E312E746D313637303438313537363130353030303032:3137322E32352E3232342E312E746D33 , XAResource.TMNOFLAGS ) on resource ds-one represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@6a3055da
2022-12-08 14:39:36.111 DEBUG 16972 --- [nio-8011-exec-3] c.a.icatch.imp.CompositeTransactionImp   : registerSynchronization ( com.atomikos.jdbc.AtomikosConnectionProxy$JdbcRequeueSynchronization@3d9d34ba ) for transaction 172.25.224.1.tm167048157610500002
2022-12-08 14:39:36.111 DEBUG 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@21d7a7fd: calling prepareStatement(INSERT INTO test_atomikos  ( id,
username,
address,
create_date )  VALUES  ( ?,
?,
?,
? ))...
Releasing transactional SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@76071908]
Creating a new SqlSession
Registering transaction synchronization for SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@50cfc8d3]
2022-12-08 14:39:36.115 DEBUG 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AbstractDataSourceBean   : AtomikosDataSoureBean 'ds-two': getConnection()...
2022-12-08 14:39:36.116  INFO 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AbstractDataSourceBean   : AtomikosDataSoureBean 'ds-two': init...
2022-12-08 14:39:36.116 DEBUG 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@b16876c: calling getAutoCommit...
2022-12-08 14:39:36.116 DEBUG 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@b16876c: calling toString...
JDBC Connection [com.mysql.cj.jdbc.ConnectionImpl@b16876c] will be managed by Spring
2022-12-08 14:39:36.116 DEBUG 16972 --- [nio-8011-exec-3] c.a.icatch.imp.CompositeTransactionImp   : addParticipant ( XAResourceTransaction: 3137322E32352E3232342E312E746D313637303438313537363130353030303032:3137322E32352E3232342E312E746D34 ) for transaction 172.25.224.1.tm167048157610500002
2022-12-08 14:39:36.116 DEBUG 16972 --- [nio-8011-exec-3] c.a.datasource.xa.XAResourceTransaction  : XAResource.start ( 3137322E32352E3232342E312E746D313637303438313537363130353030303032:3137322E32352E3232342E312E746D34 , XAResource.TMNOFLAGS ) on resource ds-two represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@38b16286
2022-12-08 14:39:36.118 DEBUG 16972 --- [nio-8011-exec-3] c.a.icatch.imp.CompositeTransactionImp   : registerSynchronization ( com.atomikos.jdbc.AtomikosConnectionProxy$JdbcRequeueSynchronization@3d9d34ba ) for transaction 172.25.224.1.tm167048157610500002
2022-12-08 14:39:36.118 DEBUG 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@b16876c: calling prepareStatement(INSERT INTO test_atomikos  ( id,
username,
address,
create_date )  VALUES  ( ?,
?,
?,
? ))...
Releasing transactional SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@50cfc8d3]
Transaction synchronization committing SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@76071908]
Transaction synchronization committing SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@50cfc8d3]
Transaction synchronization deregistering SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@76071908]
Transaction synchronization closing SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@76071908]
Transaction synchronization deregistering SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@50cfc8d3]
Transaction synchronization closing SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@50cfc8d3]
2022-12-08 14:39:36.123 DEBUG 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@21d7a7fd: close()...
2022-12-08 14:39:36.123 DEBUG 16972 --- [nio-8011-exec-3] c.a.datasource.xa.XAResourceTransaction  : XAResource.end ( 3137322E32352E3232342E312E746D313637303438313537363130353030303032:3137322E32352E3232342E312E746D33 , XAResource.TMSUCCESS ) on resource ds-one represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@6a3055da
2022-12-08 14:39:36.124 DEBUG 16972 --- [nio-8011-exec-3] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@b16876c: close()...
2022-12-08 14:39:36.125 DEBUG 16972 --- [nio-8011-exec-3] c.a.datasource.xa.XAResourceTransaction  : XAResource.end ( 3137322E32352E3232342E312E746D313637303438313537363130353030303032:3137322E32352E3232342E312E746D34 , XAResource.TMSUCCESS ) on resource ds-two represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@38b16286
2022-12-08 14:39:36.126 DEBUG 16972 --- [nio-8011-exec-3] c.a.icatch.imp.CompositeTransactionImp   : commit() done (by application) of transaction 172.25.224.1.tm167048157610500002
2022-12-08 14:39:36.129 DEBUG 16972 --- [nio-8011-exec-3] c.a.datasource.xa.XAResourceTransaction  : XAResource.prepare ( 3137322E32352E3232342E312E746D313637303438313537363130353030303032:3137322E32352E3232342E312E746D33 ) returning OK on resource ds-one represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@6a3055da
2022-12-08 14:39:36.132 DEBUG 16972 --- [nio-8011-exec-3] c.a.datasource.xa.XAResourceTransaction  : XAResource.prepare ( 3137322E32352E3232342E312E746D313637303438313537363130353030303032:3137322E32352E3232342E312E746D34 ) returning OK on resource ds-two represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@38b16286
2022-12-08 14:39:36.133 DEBUG 16972 --- [nio-8011-exec-3] c.a.datasource.xa.XAResourceTransaction  : XAResource.commit ( 3137322E32352E3232342E312E746D313637303438313537363130353030303032:3137322E32352E3232342E312E746D33 , false ) on resource ds-one represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@6a3055da
2022-12-08 14:39:36.135 DEBUG 16972 --- [nio-8011-exec-3] c.a.datasource.xa.XAResourceTransaction  : XAResource.commit ( 3137322E32352E3232342E312E746D313637303438313537363130353030303032:3137322E32352E3232342E312E746D34 , false ) on resource ds-two represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@38b16286
```

整体流程如下:
    - 协调者创建一个事务 atomikos的分布式事务,全局事务ID为172.25.224.1.tm167048327204900004
    - 添加A数据源的XAResource ,并开启 XAResource的XAResourceTransaction
    - 将A数据源的本地事务加入全局事务中
    - A数据源 执行SQL
    - 添加B数据源的XAResource ,并开启 XAResource的XAResourceTransaction
    - 将B数据源的本地事务加入全局事务中
    - B数据源 执行SQL
    - 关闭A数据源的XA事务
    - 关闭B数据源的XA事务
    - 协调者 prepare A数据源的XAResourceTransaction 成功
    - 协调者 prepare B数据源的XAResourceTransaction 成功
    - 协调者 commit A数据源的 XAResourceTransaction 
    - 协调者 commit A数据源的 XAResourceTransaction 


### 失败日志分析
``` log
2022-12-08 15:07:52.049 DEBUG 16972 --- [nio-8011-exec-6] c.a.i.i.CompositeTransactionManagerImp   : createCompositeTransaction ( 10000 ): created new ROOT transaction with id 172.25.224.1.tm167048327204900004
Creating a new SqlSession
Registering transaction synchronization for SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@7372aa48]
2022-12-08 15:07:52.049 DEBUG 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AbstractDataSourceBean   : AtomikosDataSoureBean 'ds-one': getConnection()...
2022-12-08 15:07:52.049  INFO 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AbstractDataSourceBean   : AtomikosDataSoureBean 'ds-one': init...
2022-12-08 15:07:52.049 DEBUG 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@21d7a7fd: calling getAutoCommit...
2022-12-08 15:07:52.049 DEBUG 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@21d7a7fd: calling toString...
JDBC Connection [com.mysql.cj.jdbc.ConnectionImpl@21d7a7fd] will be managed by Spring
2022-12-08 15:07:52.050 DEBUG 16972 --- [nio-8011-exec-6] c.a.icatch.imp.CompositeTransactionImp   : addParticipant ( XAResourceTransaction: 3137322E32352E3232342E312E746D313637303438333237323034393030303034:3137322E32352E3232342E312E746D37 ) for transaction 172.25.224.1.tm167048327204900004
2022-12-08 15:07:52.050 DEBUG 16972 --- [nio-8011-exec-6] c.a.datasource.xa.XAResourceTransaction  : XAResource.start ( 3137322E32352E3232342E312E746D313637303438333237323034393030303034:3137322E32352E3232342E312E746D37 , XAResource.TMNOFLAGS ) on resource ds-one represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@6a3055da
2022-12-08 15:07:52.052 DEBUG 16972 --- [nio-8011-exec-6] c.a.icatch.imp.CompositeTransactionImp   : registerSynchronization ( com.atomikos.jdbc.AtomikosConnectionProxy$JdbcRequeueSynchronization@afcbcdd4 ) for transaction 172.25.224.1.tm167048327204900004
2022-12-08 15:07:52.052 DEBUG 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@21d7a7fd: calling prepareStatement(INSERT INTO test_atomikos  ( id,
username,
address,
create_date )  VALUES  ( ?,
?,
?,
? ))...
Releasing transactional SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@7372aa48]
Creating a new SqlSession
Registering transaction synchronization for SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@2a0ae075]
2022-12-08 15:07:52.057 DEBUG 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AbstractDataSourceBean   : AtomikosDataSoureBean 'ds-two': getConnection()...
2022-12-08 15:07:52.057  INFO 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AbstractDataSourceBean   : AtomikosDataSoureBean 'ds-two': init...
2022-12-08 15:07:52.058 DEBUG 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@b16876c: calling getAutoCommit...
2022-12-08 15:07:52.058 DEBUG 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@b16876c: calling toString...
JDBC Connection [com.mysql.cj.jdbc.ConnectionImpl@b16876c] will be managed by Spring
2022-12-08 15:07:52.058 DEBUG 16972 --- [nio-8011-exec-6] c.a.icatch.imp.CompositeTransactionImp   : addParticipant ( XAResourceTransaction: 3137322E32352E3232342E312E746D313637303438333237323034393030303034:3137322E32352E3232342E312E746D38 ) for transaction 172.25.224.1.tm167048327204900004
2022-12-08 15:07:52.058 DEBUG 16972 --- [nio-8011-exec-6] c.a.datasource.xa.XAResourceTransaction  : XAResource.start ( 3137322E32352E3232342E312E746D313637303438333237323034393030303034:3137322E32352E3232342E312E746D38 , XAResource.TMNOFLAGS ) on resource ds-two represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@38b16286
2022-12-08 15:07:52.060 DEBUG 16972 --- [nio-8011-exec-6] c.a.icatch.imp.CompositeTransactionImp   : registerSynchronization ( com.atomikos.jdbc.AtomikosConnectionProxy$JdbcRequeueSynchronization@afcbcdd4 ) for transaction 172.25.224.1.tm167048327204900004
2022-12-08 15:07:52.060 DEBUG 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@b16876c: calling prepareStatement(INSERT INTO test_atomikos  ( id,
username,
address,
create_date )  VALUES  ( ?,
?,
?,
? ))...
Releasing transactional SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@2a0ae075]
2022-12-08 15:07:56.172 ERROR 16972 --- [nio-8011-exec-6] c.l.a.service.AtomikosServiceImpl        : 抛出异常了
Transaction synchronization deregistering SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@7372aa48]
Transaction synchronization closing SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@7372aa48]
Transaction synchronization deregistering SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@2a0ae075]
Transaction synchronization closing SqlSession [org.apache.ibatis.session.defaults.DefaultSqlSession@2a0ae075]
2022-12-08 15:07:56.176 DEBUG 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@21d7a7fd: close()...
2022-12-08 15:07:56.176 DEBUG 16972 --- [nio-8011-exec-6] c.a.datasource.xa.XAResourceTransaction  : XAResource.end ( 3137322E32352E3232342E312E746D313637303438333237323034393030303034:3137322E32352E3232342E312E746D37 , XAResource.TMSUCCESS ) on resource ds-one represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@6a3055da
2022-12-08 15:07:56.177 DEBUG 16972 --- [nio-8011-exec-6] c.atomikos.jdbc.AtomikosConnectionProxy  : atomikos connection proxy for com.mysql.cj.jdbc.ConnectionImpl@b16876c: close()...
2022-12-08 15:07:56.178 DEBUG 16972 --- [nio-8011-exec-6] c.a.datasource.xa.XAResourceTransaction  : XAResource.end ( 3137322E32352E3232342E312E746D313637303438333237323034393030303034:3137322E32352E3232342E312E746D38 , XAResource.TMSUCCESS ) on resource ds-two represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@38b16286
2022-12-08 15:07:56.181 DEBUG 16972 --- [nio-8011-exec-6] c.a.datasource.xa.XAResourceTransaction  : XAResource.rollback ( 3137322E32352E3232342E312E746D313637303438333237323034393030303034:3137322E32352E3232342E312E746D37 ) on resource ds-one represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@6a3055da
2022-12-08 15:07:56.195 DEBUG 16972 --- [nio-8011-exec-6] c.a.datasource.xa.XAResourceTransaction  : XAResource.rollback ( 3137322E32352E3232342E312E746D313637303438333237323034393030303034:3137322E32352E3232342E312E746D38 ) on resource ds-two represented by XAResource instance com.mysql.cj.jdbc.MysqlXAConnection@38b16286
2022-12-08 15:07:56.199 DEBUG 16972 --- [nio-8011-exec-6] c.a.icatch.imp.CompositeTransactionImp   : rollback() done of transaction 172.25.224.1.tm167048327204900004
2022-12-08 15:07:56.200 DEBUG 16972 --- [nio-8011-exec-6] c.a.icatch.imp.CompositeTransactionImp   : rollback() done of transaction 172.25.224.1.tm167048327204900004
2022-12-08 15:07:56.209 ERROR 16972 --- [nio-8011-exec-6] o.a.c.c.C.[.[.[/].[dispatcherServlet]    : Servlet.service() for servlet [dispatcherServlet] in context with path [] threw exception [Request processing failed; nested exception is java.lang.RuntimeException: 抛出异常] with root cause
```

整体流程如下:
    - 协调者创建一个事务 atomikos的分布式事务,全局事务ID为172.25.224.1.tm167048327204900004
    - 添加A数据源的XAResource ,并开启 XAResource的XAResourceTransaction
    - 将A数据源的本地事务加入全局事务中
    - A数据源 执行SQL
    - 添加B数据源的XAResource ,并开启 XAResource的XAResourceTransaction
    - 将B数据源的本地事务加入全局事务中
    - B数据源 执行SQL
    - **抛出异常**
    - 关闭A数据源的XA事务
    - 关闭B数据源的XA事务
    - 协调者 rollback A数据源的 XAResourceTransaction 
    - 协调者 rollback A数据源的 XAResourceTransaction 

**2PC机制完整的周期是,begin -> 业务逻辑 -> prepare -> commit,但是在全局事务决定回滚时，直接逐个发送rollback请求即可，不分阶段。两外2PC依赖于RM提供底层支持(一般是兼容XA)**

### 2PC 特点
**XA协议比较简单，目前很多商业数据库实现XA协议，使用分布式事务的成本也比较低。但是，XA也有致命的缺点，那就是性能不理想，特别是在交易下单链路，往往并发量很高，XA无法满足高并发场景。XA目前在商业数据库支持的比较理想，在mysql数据库中支持的不太理想，mysql的XA实现，没有记录prepare阶段日志，主备切换回导致主库与备库数据不一致。许多nosql也没有支持XA，这让XA的应用场景变得非常狭隘。在prepare阶段需要等待所有参与子事务的反馈，因此可能造成数据库资源锁定时间过长，不适合并发高以及子事务生命周长较长的业务场景。两阶段提交这种解决方案属于牺牲了一部分可用性来换取的一致性。**

## 参考
[关于如何实现一个 TCC 分布式事务框架的一点思考](https://zhuanlan.zhihu.com/p/237891585)
[两阶段提交](https://developer.aliyun.com/article/1025104#52-%E4%B8%A4%E9%98%B6%E6%AE%B5%E6%8F%90%E4%BA%A4)