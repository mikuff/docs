## OOM
--- 
### 堆内存溢出
``` java
java.lang.OutOfMemoryError: Java heap space
```
**原因**
    1、代码中可能存在大对象分配 
    2、可能存在内存泄露，导致在多次GC之后，还是无法找到一块足够大的内存容纳当前对象。
**排查思路**
    1、检查是否存在大对象的分配
    2、dump 内存镜像,mat工具排查是否存在内存泄漏
    3、 -Xmx 加大堆内存
    4、检查是否有大量的自定义的 Finalizable 对象

### 永久代/元空间溢出
``` java
java.lang.OutOfMemoryError: PermGen space
java.lang.OutOfMemoryError: Metaspace
```
**原因**
> 永久代是 HotSot 虚拟机对方法区的具体实现，存放了被虚拟机加载的类信息、常量、静态变量、JIT编译后的代码等。JDK8后，元空间替换了永久代，元空间使用的是本地内存，还有其它细节变化：
- 字符串常量由永久代转移到堆中
- 和永久代相关的JVM参数已移除
可能原因有如下几种：
- 在Java7之前，频繁的错误使用String.intern()方法
- 运行期间生成了大量的代理类，导致方法区被撑爆，无法卸载
- 应用长时间运行，没有重启
**排查思路**
1、检查是否永久代空间或者元空间设置的过小
2、检查代码中是否存在大量的反射操作
3、dump之后通过mat检查是否存在大量由于反射生成的代理类
4、重启JVM

### GC overhead limit exceeded
``` java
java.lang.OutOfMemoryError：GC overhead limit exceeded
```
**原因**
这个是JDK6新加的错误类型，一般都是堆太小导致的。Sun 官方对此的定义：超过98%的时间用来做GC并且回收了不到2%的堆内存时会抛出此异常。
**排查思路**
1、检查项目中是否有大量的死循环或有使用大内存的代码，优化代码。
2、添加参数 -XX:-UseGCOverheadLimit 禁用这个检查，其实这个参数解决不了内存问题，只是把错误的信息延后，最终出现 java.lang.OutOfMemoryError: Java heap space。
3、dump内存，检查是否存在内存泄露，如果没有，加大内存。

### 方法栈溢出
```java
java.lang.OutOfMemoryError : unable to create new native Thread
```
**原因**
出现这种异常，基本上都是创建的了大量的线程导致的
**排查思路**
1、通过 -Xss 降低的每个线程栈大小的容量
2、线程总数也受到系统空闲内存和操作系统的限制，检查是否该系统下有此限制：
    - /proc/sys/kernel/pid_max
    - /proc/sys/kernel/thread-max
    - maxuserprocess（ulimit -u）
    - /proc/sys/vm/maxmapcount

### 非常规溢出
#### 分配超大数组
``` java
java.lang.OutOfMemoryError: Requested array size exceeds VM limit
```
**原因**
这种情况一般是由于不合理的数组分配请求导致的，在为数组分配内存之前，JVM 会执行一项检查。要分配的数组在该平台是否可以寻址(addressable)，如果不能寻址(addressable)就会抛出这个错误。  
**解决方法**
就是检查你的代码中是否有创建超大数组的地方。

#### swap溢出
``` java
java.lang.OutOfMemoryError: Out of swap space
```
**原因**
这种情况一般是操作系统导致的，可能的原因有：
1、swap 分区大小分配不足；
2、其他进程消耗了所有的内存。

**排查思路**
1、其它服务进程可以选择性的拆分出去
2、加大swap分区大小，或者加大机器内存大小


#### 本地方法溢出
```java
java.lang.OutOfMemoryError: stack_trace_with_native_method
```
本地方法在运行时出现了内存分配失败，和之前的方法栈溢出不同，方法栈溢出发生在 JVM 代码层面，而本地方法溢出发生在JNI代码或本地方法处。
这个异常出现的概率极低，只能通过操作系统本地工具进行诊断，


## Java 平台标准版故障排除指南
> 参考 (理解 OutOfMemoryError 异常)[https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/memleaks002.html]

> 内存泄漏的一个常见迹象是java.lang.OutOfMemoryError异常。通常，当 Java 堆中没有足够的空间来分配对象时会引发此错误。在这种情况下，垃圾收集器无法腾出空间来容纳新对象，并且无法进一步扩展堆。此外，当本机内存不足以支持 Java 类的加载时，可能会引发此错误。在极少数情况下，java.lang.OutOfMemoryError当花费过多时间进行垃圾收集并且释放的内存很少时，可能会抛出

### Exception in thread thread_name: java.lang.OutOfMemoryError: Java heap space
原因：详细消息Java heap space指示无法在 Java 堆中分配对象。此错误不一定意味着内存泄漏。问题可以像配置问题一样简单，其中指定的堆大小（或默认大小，如果未指定）对于应用程序来说是不够的。
在其他情况下，特别是对于长期存在的应用程序，该消息可能表明应用程序无意中持有对对象的引用，这可以防止对象被垃圾收集。这是内存泄漏的 Java 语言等价物。注意：应用程序调用的 API 也可能无意中持有对象引用。

此错误的另一个潜在来源是过度使用终结器的应用程序。如果一个类有一个finalize方法，那么该类型的对象在垃圾回收时不会回收它们的空间。相反，在垃圾回收之后，对象会排队等待最终确定，这将在稍后发生。在 Oracle Sun 实现中，终结器由为终结队列提供服务的守护线程执行。如果终结器线程无法跟上终结队列，那么 Java 堆可能会填满，并且这种类型的OutOfMemoryError会抛出异常。可能导致这种情况的一种情况是，当应用程序创建高优先级线程时，会导致终结队列以比终结器线程服务该队列的速率更快的速率增加。

### Exception in thread thread_name: java.lang.OutOfMemoryError: GC Overhead limit exceeded
原因： “GC 开销限制超出”的详细消息表明垃圾收集器一直在运行，Java 程序进展非常缓慢。垃圾回收后，如果 Java 进程花费大约 98% 以上的时间进行垃圾回收，并且如果它回收的堆空间少于 2%，并且到目前为止一直在做最后 5 个（编译时间常数）连续垃圾集合，然后java.lang.OutOfMemoryError抛出 a。通常会抛出此异常，因为实时数据量几乎无法放入 Java 堆中，几乎没有用于新分配的可用空间。

行动：增加堆大小。超过 GC Overhead limit的java.lang.OutOfMemoryError异常可以用命令行标志关闭。-XX:-UseGCOverheadLimit

### Exception in thread thread_name: java.lang.OutOfMemoryError: Requested array size exceeds VM limit
原因：详细消息“请求的数组大小超过 VM 限制”表明应用程序（或该应用程序使用的 API）试图分配大于堆大小的数组。例如，如果应用程序尝试分配 512 MB 的数组，但最大堆大小为 256 MB，OutOfMemoryError则会抛出请求的数组大小超出 VM 限制的原因。

行动：通常问题要么是配置问题（堆大小太小），要么是导致应用程序尝试创建巨大数组的错误（例如，当数组中的元素数量是使用计算尺寸不正确）。
### Exception in thread thread_name: java.lang.OutOfMemoryError: Metaspace
原因： Java 类元数据（Java 类的虚拟机内部表示）分配在本机内存（这里称为元空间）中。如果类元数据的元空间已用尽，则会引发java.lang.OutOfMemoryError带有详细信息的异常。MetaSpace可用于类元数据的元空间量受参数 限制，该参数MaxMetaSpaceSize在命令行中指定。当类元数据所需的本机内存量超过MaxMetaSpaceSize时，将引发java.lang.OutOfMemoryError带有详细信息的异常。MetaSpace

行动：如果MaxMetaSpaceSize，已在命令行上设置，增加其值。MetaSpace从与 Java 堆相同的地址空间分配。减小 Java 堆的大小将为MetaSpace. 如果 Java 堆中的可用空间过多，这只是一个正确的权衡

### Exception in thread thread_name: java.lang.OutOfMemoryError: request size bytes for reason. Out of swap space?
原因：详细消息“request size bytes for reason . Out of swap space?” 似乎是个OutOfMemoryError例外。但是，当从本机堆分配失败并且本机堆可能接近耗尽时，Java HotSpot VM 代码会报告此明显异常。该消息指示失败请求的大小（以字节为单位）以及内存请求的原因。通常原因是报告分配失败的源模块的名称，尽管有时它是实际原因。

操作：当抛出此错误消息时，VM 调用致命错误处理机制（即，它生成一个致命错误日志文件，其中包含有关崩溃时线程、进程和系统的有用信息）。在本机堆耗尽的情况下，日志中的堆内存和内存映射信息会很有用。

### Exception in thread thread_name: java.lang.OutOfMemoryError: Compressed class space
原因：在 64 位平台上，指向类元数据的指针可以由 32 位偏移量（带有UseCompressedOops）表示。这由命令行标志控制UseCompressedClassPointers（默认开启）。如果UseCompressedClassPointers使用 ，则可用于类元数据的空间量固定为 amount CompressedClassSpaceSize。UseCompressedClassPointers如果超过所需的空间CompressedClassSpaceSize，则会抛出java.lang.OutOfMemoryError带有详细压缩的类空间。

行动：增加CompressedClassSpaceSize关闭UseCompressedClassPointers。注意：的可接受大小是有界限的CompressedClassSpaceSize。例如-XX: CompressedClassSpaceSize=4g，超出可接受范围将导致消息如
CompressedClassSpaceSize4294967296 无效；必须介于 1048576 和 3221225472 之间。

### Exception in thread thread_name: java.lang.OutOfMemoryError: reason stack_trace_with_native_method
原因：如果错误消息的详细信息部分是“ reason stack_trace_with_native_method ”并且打印了堆栈跟踪，其中顶部帧是本地方法，那么这表明本地方法遇到了分配失败。此消息与上一条消息之间的区别在于，分配失败是在 Java 本机接口 (JNI) 或本机方法中检测到的，而不是在 JVM 代码中检测到的。
操作：如果引发此类OutOfMemoryError异常，您可能需要使用操作系统的本机实用程序来进一步诊断问题。有关可用于各种操作系统的工具的更多信息，请参阅本机操作系统工具。
