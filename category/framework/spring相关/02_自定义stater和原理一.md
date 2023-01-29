## spring spi 和 java spi

## 自定义stater实现
### pom.xml
``` xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.0.3.RELEASE</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    <groupId>com.lwl</groupId>
    <artifactId>my-spring-boot-stater-auto</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>my-spring-boot-stater-autoconfigure</name>
    <description>my-spring-boot-stater-autoconfigure</description>
    <packaging>jar</packaging>

    <properties>
        <java.version>1.8</java.version>
    </properties>
    <dependencies>
        <!-- 基本配置 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
        </dependency>
        
        <!-- 用于配置文件校验 -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
    </dependencies>
</project>

```

### yml文件属性配置类
``` java
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import javax.validation.constraints.NotNull;

@ConfigurationProperties(prefix = "lwl.prop")
@Validated
public class LwlProperties {

    @NotNull(message = "prefix is not null")
    private String prefix;

    @NotNull(message = "suffix is not null")
    private String suffix;

    public String getPrefix() {
        return prefix;
    }

    public void setPrefix(String prefix) {
        this.prefix = prefix;
    }

    public String getSuffix() {
        return suffix;
    }

    public void setSuffix(String suffix) {
        this.suffix = suffix;
    }
}
```

### 普通服务类
``` java
public class LwlService {

    LwlProperties lwlProperties;

    public LwlProperties getLwlProperties() {
        return lwlProperties;
    }

    public void setLwlProperties(LwlProperties lwlProperties) {
        this.lwlProperties = lwlProperties;
    }

    public String sayHello(String name) {
        return lwlProperties.getPrefix() + "-" + name + "-" + lwlProperties.getSuffix();
    }
}
```

### bean自动注入类
``` java
@EnableConfigurationProperties(LwlProperties.class)
@ConditionalOnWebApplication
public class LwlAutoConfiguration {

    @Autowired
    private LwlProperties lwlProperties;

    @Bean
    public LwlService lwlService() {
        LwlService lwlService = new LwlService();
        lwlService.setLwlProperties(lwlProperties);
        return lwlService;
    }
}
```

### META-INF/spring.factories配置
``` java
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
  com.lwl.autoconfiguration.LwlAutoConfiguration
```


## 问题和猜想
1、spring 的 stater和java的spi是什么关系  
2、自定义starter引入之后即能够正常的使用@Autowired等注解，即意味着整个bean的加载是在ioc容器初始的过程中进行的  
3、spring进行stater加载的起点是META-INF/spring.factories，那么应该有一个是能寻找到这些文件的，并且将这些文件放入的spring的容器中的  
4、spring在进行bean注入的时候，@ConditionalOnWebApplication @ConditonOnClass这些类代表着某种过滤规则，这些规则spring是如何处理的  

## spring stater和java spi
SPI 全称为 Service Provider Interface，是一种服务发现机制。SPI 的本质是将接口实现类的全限定名配置在文件中，并由服务加载器读取配置文件，加载实现类。这样可以在运行时，动态为接口替换实现类。    

### java spi
java本身提供了spi的实现，举个最简单的例子，数据库连接java.sql.Driver支持mysql和oracel的驱动，并且jdbc本身也没有使用spring。  

**java spi的定义规则**
- 在META-INF/services/目录中创建以接口全限定名命名的文件该文件内容为Api具体实现类的全限定名
- 使用ServiceLoader类动态加载META-INF中的实现类
- 如SPI的实现类为Jar则需要放在主程序classPath中
- Api具体实现类必须有一个不带参数的构造方法

#### jdbc spi
**加载 rt包**
``` java
public class DriverManager {
    /**
     * Load the initial JDBC drivers by checking the System property
     * jdbc.properties and then use the {@code ServiceLoader} mechanism
     */
    static {
        loadInitialDrivers();
        println("JDBC DriverManager initialized");
    }

    // 通过 spi 加载所有作为 Service Provider 的jar包
    // 它在里面查找的是Driver接口的服务类，所以它的文件路径就是：META-INF/services/java.sql.Driver
    private static void loadInitialDrivers() {
        String drivers;
        try {
            drivers = AccessController.doPrivileged(new PrivilegedAction<String>() {
                public String run() {
                    return System.getProperty("jdbc.drivers");
                }
            });
        } catch (Exception ex) {
            drivers = null;
        }

        AccessController.doPrivileged(new PrivilegedAction<Void>() {
            public Void run() {
                
                // 主要的加载就是在这里通过ServiceLoader进行加载 java.sql.Driver实现类
                ServiceLoader<Driver> loadedDrivers = ServiceLoader.load(Driver.class);
                Iterator<Driver> driversIterator = loadedDrivers.iterator();

                try{

                    // 查到之后创建对象
                    while(driversIterator.hasNext()) {
                        driversIterator.next();
                    }
                } catch(Throwable t) {
                // Do nothing
                }
                return null;
            }
        });

        println("DriverManager.initialize: jdbc.drivers = " + drivers);

        if (drivers == null || drivers.equals("")) {
            return;
        }

        // 这里预先执行一下反射
        String[] driversList = drivers.split(":");
        println("number of Drivers:" + driversList.length);
        for (String aDriver : driversList) {
            try {
                println("DriverManager.Initialize: loading " + aDriver);
                Class.forName(aDriver, true,
                        ClassLoader.getSystemClassLoader());
            } catch (Exception ex) {
                println("DriverManager.Initialize: load failed: " + ex);
            }
        }
    }
}

```
**创建实例 mysql包**
```java
public class Driver extends NonRegisteringDriver implements java.sql.Driver {
    public Driver() throws SQLException {
    }
    static {
        try {
            //调用DriverManager类的注册方法,向registeredDrivers集合注入本类实例
            DriverManager.registerDriver(new Driver());
        } catch (SQLException var1) {
            throw new RuntimeException("Can't register driver!");
        }
    }
}
```
**创建Connection rt包**
``` java
private static Connection getConnection(
    String url, java.util.Properties info, Class<?> caller) throws SQLException {
    
    // 获取当前线程的classloader，用于后面的加载校验
    ClassLoader callerCL = caller != null ? caller.getClassLoader() : null;
    synchronized(DriverManager.class) {
        if (callerCL == null) {
            callerCL = Thread.currentThread().getContextClassLoader();
        }
    }

    if(url == null) {
        throw new SQLException("The url cannot be null", "08001");
    }

    println("DriverManager.getConnection(\"" + url + "\")");

    SQLException reason = null;

    for(DriverInfo aDriver : registeredDrivers) {
        // 循环每个Driver的实例，调用其自身的connect方法进行连接
        if(isDriverAllowed(aDriver.driver, callerCL)) {
            try {
                println("    trying " + aDriver.driver.getClass().getName());
                Connection con = aDriver.driver.connect(url, info);
                if (con != null) {
                    // Success!
                    println("getConnection returning " + aDriver.driver.getClass().getName());
                    return (con);
                }
            } catch (SQLException ex) {
                if (reason == null) {
                    reason = ex;
                }
            }

        } else {
            println("    skipping: " + aDriver.getClass().getName());
        }

    }

    // if we got here nobody could connect.
    if (reason != null)    {
        println("getConnection failed: " + reason);
        throw reason;
    }

    println("getConnection: no suitable driver found for "+ url);
    throw new SQLException("No suitable driver found for "+ url, "08001");
}
```

#### spring stater
spring的stater设计的也参考了java spi的实现思路，即定义配置文件，然后通过加载器(ServiceLoader、SpringFactoriesLoader)的方式进行加载。Spring通过spring.handlers和spring.factories两种方式实现SPI机制，可以在不修改Spring源码的前提下，做到对Spring框架的扩展开发，本文仅介绍 spring.factories   
从上面的spring的stater和java spi的方式可以比较出两者的不同
- **配置文件的方式不同**: 
    - Java SPI是一个服务提供接口对应一个配置文件，配置文件中存放当前接口的所有实现类，多个服务提供接口对应多个配置文件，所有配置都在services目录下
    - Spring factories SPI是一个spring.factories配置文件存放多个接口及对应的实现类，以接口全限定名作为key，实现类作为value来配置，多个实现类用逗号隔开，仅spring.factories一个配置文件。

- **加载时机不同**
    - Java SPI使用了懒加载模式，即在调用ServiceLoader.load()时仅是返回了ServiceLoader实例，尚未解析接口对应的配置文件，在使用时即循环遍历时才正式解析返回服务提供接口的实现类实例
    - Spring factories SPI在调用SpringFactoriesLoader.loadFactories()时便已解析spring.facotries文件返回接口实现类的实例

**总的来说spring的spi和java的spi在实现思路上大同小异: 即定义配置文件，然后通过加载器(ServiceLoader、SpringFactoriesLoader)的方式进行加载，无非是两者将实现类所处的层级不同，java的spi是将实现类加载到classloader的层面上，而spring的spi则将实现类加载到的spring容器的层面，并依赖于spring容器对加载做了增强，如@Condition注解。**

