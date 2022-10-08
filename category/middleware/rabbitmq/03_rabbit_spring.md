---

### RabbitAdmin
> RabbitAdmin可以很好的操纵RabbitMQ,在Spring中进行注入即可。**autoStartUp必须设置为true，否则Spring容器不会自动加载RabbitAdmin类**  
RabbitAdmin底层就是从Spring容器中获取Exchange,Bingding,RoutingKey以及Queue的@Bean声明。然后通过RabbitTemplate的execute方法执行相应的对应的声明,修改、删除等一系列RabbitMQ基础操作功能

#### RabbitAdmin注入
``` java
@Configuration
@ComponentScan({"com.boson.*"})
public class RabbitMQConfig
{
    @Bean
    public ConnectionFactory connectionFactory()
    {
        CachingConnectionFactory ret = new CachingConnectionFactory();
        ret.setAddresses("127.0.0.1:5673");
        ret.setUsername("guest");
        ret.setPassword("guest");
        ret.setVirtualHost("/");
        return ret;
    }
    @Bean
    public RabbitAdmin rabbitAdmin(ConnectionFactory connectionFactory)
    {
        RabbitAdmin rabbitAdmin = new RabbitAdmin(connectionFactory);
        rabbitAdmin.setAutoStartup(true);
        return rabbitAdmin;
    }
}
```


#### RabbitAdmin队列及绑定关系
``` java
@SpringBootTest
class RabbitSpringApplicationTests {

	@Autowired
	private RabbitAdmin rabbitAdmin;

	@Test
	public void test_binding()
	{
		TopicExchange exchange = new TopicExchange("test_exchange");
		rabbitAdmin.declareExchange(exchange);

		Queue queue = new Queue("test_queue");
		rabbitAdmin.declareQueue(queue);

		Binding binding = new Binding("test_queue", Binding.DestinationType.QUEUE, "test_exchange", "test", new HashMap<>());
		rabbitAdmin.declareBinding(binding);
	}

}
```

### RabbitAdmin源码
> 首先需要确认一点的是Spring将消息队列进行抽象,抽象出了Spring-amqp的包,amqp-client是操作rabbitmq的包。spring-rabbit是将springboot同amqp-client进行整合并且提供了一系列符合springboot规则操作方式,诸如声明式注解之类的

> AmqpAdmin 是来自 Spring-amqp包，是最顶层的接口，定义了一系列操作消息队列的方法。RabbitAdmin在初始化的时候声明的 rabbitTemplate。 rabbitTemplate才是操作rabbitmq的核心方法。rabbitTemplate中使用了大量的来自amqp-client的类。

> rabbitTemplate 简化了同步RabbitMQ访问(发送和接收消息)。

```java
@ManagedResource(description = "Admin Tasks")
public class RabbitAdmin implements AmqpAdmin, ApplicationContextAware, ApplicationEventPublisherAware,
		BeanNameAware, InitializingBean {

	// 初始化 RabbitTemplate
	public RabbitAdmin(ConnectionFactory connectionFactory) {
		Assert.notNull(connectionFactory, "ConnectionFactory must not be null");
		this.connectionFactory = connectionFactory;
		this.rabbitTemplate = new RabbitTemplate(connectionFactory);
	}

	@Override
	public void afterPropertiesSet() {

		// 加锁,确保队列的初始化的线程安全性
		synchronized (this.lifecycleMonitor) {

			// 如果该类已经初始化过 或 没有开启自动注入则不进行初始化
			if (this.running || !this.autoStartup) {
				return;
			}
			// 设置默认的连接重试配置
			if (this.retryTemplate == null && !this.retryDisabled) {
				this.retryTemplate = new RetryTemplate();
				this.retryTemplate.setRetryPolicy(new SimpleRetryPolicy(DECLARE_MAX_ATTEMPTS));
				ExponentialBackOffPolicy backOffPolicy = new ExponentialBackOffPolicy();
				backOffPolicy.setInitialInterval(DECLARE_INITIAL_RETRY_INTERVAL);
				backOffPolicy.setMultiplier(DECLARE_RETRY_MULTIPLIER);
				backOffPolicy.setMaxInterval(DECLARE_MAX_RETRY_INTERVAL);
				this.retryTemplate.setBackOffPolicy(backOffPolicy);
			}

			if (this.connectionFactory instanceof CachingConnectionFactory &&
					((CachingConnectionFactory) this.connectionFactory).getCacheMode() == CacheMode.CONNECTION) {
				this.logger.warn("RabbitAdmin auto declaration is not supported with CacheMode.CONNECTION");
				return;
			}

			// 防止频繁重试导致堆栈溢出
			final AtomicBoolean initializing = new AtomicBoolean(false);

			this.connectionFactory.addConnectionListener(connection -> {

				// 如果已经初始化过则直接return
				if (!initializing.compareAndSet(false, true)) {
					return;
				}
				try {
					if (this.retryTemplate != null) {
						this.retryTemplate.execute(c -> {

							// 执行主要的初始化方法
							initialize();
							return null;
						});
					}
					else {
						initialize();
					}
				}
				finally {
					// 已经初始化过了 CAS
					initializing.compareAndSet(true, false);
				}

			});

			this.running = true;

		}
	}

				
	@Override // NOSONAR complexity
	public void initialize() {

		// spring是否正常初始化
		if (this.applicationContext == null) {
			this.logger.debug("no ApplicationContext has been set, cannot auto-declare Exchanges, Queues, and Bindings");
			return;
		}

		this.logger.debug("Initializing declarations");

		// 从spring容器中取出 交换机,队列,绑定关系,自定义声明的类，并分别装在不同的集合中
		Collection<Exchange> contextExchanges = new LinkedList<Exchange>(
				this.applicationContext.getBeansOfType(Exchange.class).values());
		Collection<Queue> contextQueues = new LinkedList<Queue>(
				this.applicationContext.getBeansOfType(Queue.class).values());
		Collection<Binding> contextBindings = new LinkedList<Binding>(
				this.applicationContext.getBeansOfType(Binding.class).values());
		Collection<DeclarableCustomizer> customizers =
				this.applicationContext.getBeansOfType(DeclarableCustomizer.class).values();

		// 从spring容器中获取 Collection<Declarables> 并按照 Declarables 所属的类分别放到不同的集合中
		processDeclarables(contextExchanges, contextQueues, contextBindings);

		// 去除带有自定义属性的类
		final Collection<Exchange> exchanges = filterDeclarables(contextExchanges, customizers);
		final Collection<Queue> queues = filterDeclarables(contextQueues, customizers);
		final Collection<Binding> bindings = filterDeclarables(contextBindings, customizers);

		for (Exchange exchange : exchanges) {
			if ((!exchange.isDurable() || exchange.isAutoDelete())  && this.logger.isInfoEnabled()) {
				this.logger.info("Auto-declaring a non-durable or auto-delete Exchange ("
						+ exchange.getName()
						+ ") durable:" + exchange.isDurable() + ", auto-delete:" + exchange.isAutoDelete() + ". "
						+ "It will be deleted by the broker if it shuts down, and can be redeclared by closing and "
						+ "reopening the connection.");
			}
		}

		for (Queue queue : queues) {
			if ((!queue.isDurable() || queue.isAutoDelete() || queue.isExclusive()) && this.logger.isInfoEnabled()) {
				this.logger.info("Auto-declaring a non-durable, auto-delete, or exclusive Queue ("
						+ queue.getName()
						+ ") durable:" + queue.isDurable() + ", auto-delete:" + queue.isAutoDelete() + ", exclusive:"
						+ queue.isExclusive() + ". "
						+ "It will be redeclared if the broker stops and is restarted while the connection factory is "
						+ "alive, but all messages will be lost.");
			}
		}

		if (exchanges.size() == 0 && queues.size() == 0 && bindings.size() == 0 && this.manualDeclarables.size() == 0) {
			this.logger.debug("Nothing to declare");
			return;
		}

		// 调用 rabbitTemplate 进行声明
		this.rabbitTemplate.execute(channel -> {
			declareExchanges(channel, exchanges.toArray(new Exchange[exchanges.size()]));
			declareQueues(channel, queues.toArray(new Queue[queues.size()]));
			declareBindings(channel, bindings.toArray(new Binding[bindings.size()]));
			return null;
		});

		// 特殊处理手动申报的
		if (this.manualDeclarables.size() > 0) {
			synchronized (this.manualDeclarables) {
				this.logger.debug("Redeclaring manually declared Declarables");
				for (Declarable dec : this.manualDeclarables.values()) {
					if (dec instanceof Queue) {
						declareQueue((Queue) dec);
					}
					else if (dec instanceof Exchange) {
						declareExchange((Exchange) dec);
					}
					else {
						declareBinding((Binding) dec);
					}
				}
			}
		}
		this.logger.debug("Declarations finished");

	}
}
```
### RabbitmqTemplate
``` java
	@Test
	public void rabbit_template_test()
	{
		// 使用消息对象
		MessageProperties messageProperties = new MessageProperties();
		messageProperties.setContentType("text/plain");
		messageProperties.getHeaders().put("desc","消息描述");
		messageProperties.getHeaders().put("type","自定义消息类型");

		Message message = new Message("消息内容".getBytes(), messageProperties);
		rabbitTemplate.send("test_exchange","test",message,new CorrelationData(){

		});

		// converAndSend
		rabbitTemplate.convertAndSend("test_exchange","test","测试消息");

	}
```

### SimpleMessageListenerContainer
> 简单消费容器,主要用于对消费者的配置项。
> - 监听多个队列、自动启动、自动声明等
> - 设置事务特征，事务管理器，事务属性，事务的容量(并发) 是否开启事务、回滚消息等
> - 设置消费者的数量,最小最大消费数量、批量消费
> - 消息的确认模式(自动签收，手工签收) 是否重回队列,异常捕获handler函数
> - 设置消费者的标签生成策略、是否独占模式、消费者属性
> - 设置具体的监听器、消息转换器等

> **SimpleMessageListenerContainer可以进行动态的设置，比如在运行中的应用可以动态的修改其消费者数量的大小、接受消息的模式等。很多基于Rabbitmq的自制化后端管控台在在进行动态化设置的时候，也是根据这一特征去实现的，所以可以看出SpringAMQP非常的强大**

```java
  @Bean
    public SimpleMessageListenerContainer simpleMessageListenerContainer(ConnectionFactory connectionFactory)
    {
        SimpleMessageListenerContainer ret = new SimpleMessageListenerContainer(connectionFactory);
        // 设置监听队列名称
        ret.setQueueNames("test_queue");
        // 设置消费者数量
        ret.setConcurrentConsumers(1);
        // 设置最大消费者数量
        ret.setMaxConcurrentConsumers(5);
        // 设置是否重回队列
        ret.setDefaultRequeueRejected(false);
        // 设置ack 自动ack或手动ack
        ret.setAcknowledgeMode(AcknowledgeMode.AUTO);
        // 设置消费端的标签策略
        ret.setConsumerTagStrategy(new ConsumerTagStrategy() {
            @Override
            public String createConsumerTag(String queue) {
               return queue+"_"+UUID.randomUUID().toString();
            }
        });
        // 设置消息监听
        ret.setMessageListener(new MessageListener() {
            @Override
            public void onMessage(Message message) {
                String messageStr = new String(message.getBody());
                System.out.println("接受到消息: "+message);
            }
        });
        return ret;
    }

```

### MessageListenerAdapter

```java
    @Bean
    public SimpleMessageListenerContainer simpleMessageListenerContainer(ConnectionFactory connectionFactory)
    {
        SimpleMessageListenerContainer ret = new SimpleMessageListenerContainer(connectionFactory);
        // 设置监听队列名称
        ret.setQueueNames("test_queue");
        // 设置消费者数量
        ret.setConcurrentConsumers(1);
        // 设置最大消费者数量
        ret.setMaxConcurrentConsumers(5);
        // 设置是否重回队列
        ret.setDefaultRequeueRejected(false);
        // 设置ack 自动ack或手动ack
        ret.setAcknowledgeMode(AcknowledgeMode.AUTO);
        // 设置消费端的标签策略
        ret.setConsumerTagStrategy(new ConsumerTagStrategy() {
            @Override
            public String createConsumerTag(String queue) {
               return queue+"_"+UUID.randomUUID().toString();
            }
        });
        // 设置自定义适配器
        MessageListenerAdapter adapter = new MessageListenerAdapter(new MessageDelegate());
        ret.setMessageListener(adapter);

    	// 适配器方式. 默认是有自己的方法名字的：handleMessage
    	// 可以自己指定一个方法的名字: consumeMessage
    	// 也可以添加一个转换器: 从字节数组转换为String
    	MessageListenerAdapter adapter = new MessageListenerAdapter(new MessageDelegate());
    	adapter.setDefaultListenerMethod("consumeMessage");
    	adapter.setMessageConverter(new TextMessageConverter());
    	ret.setMessageListener(adapter);
    	
    	// 适配器方式: 队列名称和方法名称匹配
    	MessageListenerAdapter adapter = new MessageListenerAdapter(new MessageDelegate());
    	adapter.setMessageConverter(new TextMessageConverter());
    	Map<String, String> queueOrTagToMethodName = new HashMap<>();
    	queueOrTagToMethodName.put("queue001", "method1");
    	queueOrTagToMethodName.put("queue002", "method2");
    	adapter.setQueueOrTagToMethodName(queueOrTagToMethodName);
    	container.setMessageListener(adapter);    	
    	*/


        return ret;
    }
```

```java
public class MessageDelegate {

	// 默认适配方法
    public void handleMessage(byte[] messageBody)
    {
        System.out.println("默认方法,消息内容:"+new String(messageBody));
    }
    // 自己指定的适配器方法
   	public void consumeMessage(byte[] messageBody) {
		System.err.println("字节数组方法, 消息内容:" + new String(messageBody));
	}
	public void consumeMessage(String messageBody) {
		System.err.println("字符串方法, 消息内容:" + messageBody);
	}
	
	// 队列名称匹配
	public void method1(String messageBody) {
		System.err.println("method1 收到消息内容:" + new String(messageBody));
	}
	
	public void method2(String messageBody) {
		System.err.println("method2 收到消息内容:" + new String(messageBody));
	}
}

```

### MessageConveter
> 由于rabbitmq用于传输的byte数组,使用转换器是可以进行扩展。如接收到rabbit数据转换为 javaBean, json, 也可以转换成为图片、pdf之类的

#### SimpleMessageListenerContainer
``` java
    @Bean
    public SimpleMessageListenerContainer messageContainer(ConnectionFactory connectionFactory) {
    	
    	SimpleMessageListenerContainer container = new SimpleMessageListenerContainer(connectionFactory);
    	container.setQueues(queue001(), queue002(), queue003(), queue_image(), queue_pdf());
    	container.setConcurrentConsumers(1);
    	container.setMaxConcurrentConsumers(5);
    	container.setDefaultRequeueRejected(false);
    	container.setAcknowledgeMode(AcknowledgeMode.AUTO);
    	container.setExposeListenerChannel(true);
    	container.setConsumerTagStrategy(new ConsumerTagStrategy() {
			@Override
			public String createConsumerTag(String queue) {
				return queue + "_" + UUID.randomUUID().toString();
			}
		});
   
        // 1.1 支持json格式的转换器
        /**
        MessageListenerAdapter adapter = new MessageListenerAdapter(new MessageDelegate());
        adapter.setDefaultListenerMethod("consumeMessage");
        
        Jackson2JsonMessageConverter jackson2JsonMessageConverter = new Jackson2JsonMessageConverter();
        adapter.setMessageConverter(jackson2JsonMessageConverter);
        
        container.setMessageListener(adapter);
        */
    	
        // 1.2 DefaultJackson2JavaTypeMapper & Jackson2JsonMessageConverter 支持java对象转换
        /**
        MessageListenerAdapter adapter = new MessageListenerAdapter(new MessageDelegate());
        adapter.setDefaultListenerMethod("consumeMessage");
        
        Jackson2JsonMessageConverter jackson2JsonMessageConverter = new Jackson2JsonMessageConverter();
        
        DefaultJackson2JavaTypeMapper javaTypeMapper = new DefaultJackson2JavaTypeMapper();
        jackson2JsonMessageConverter.setJavaTypeMapper(javaTypeMapper);
        
        adapter.setMessageConverter(jackson2JsonMessageConverter);
        container.setMessageListener(adapter);
        */
        
        //1.3 DefaultJackson2JavaTypeMapper & Jackson2JsonMessageConverter 支持java对象多映射转换
        /**
        MessageListenerAdapter adapter = new MessageListenerAdapter(new MessageDelegate());
        adapter.setDefaultListenerMethod("consumeMessage");
        Jackson2JsonMessageConverter jackson2JsonMessageConverter = new Jackson2JsonMessageConverter();
        DefaultJackson2JavaTypeMapper javaTypeMapper = new DefaultJackson2JavaTypeMapper();
        
        Map<String, Class<?>> idClassMapping = new HashMap<String, Class<?>>();
		idClassMapping.put("order", com.bfxy.spring.entity.Order.class);
		idClassMapping.put("packaged", com.bfxy.spring.entity.Packaged.class);
		
		javaTypeMapper.setIdClassMapping(idClassMapping);
		
		jackson2JsonMessageConverter.setJavaTypeMapper(javaTypeMapper);
        adapter.setMessageConverter(jackson2JsonMessageConverter);
        container.setMessageListener(adapter);
        */
        
        //1.4 ext convert
        MessageListenerAdapter adapter = new MessageListenerAdapter(new MessageDelegate());
        adapter.setDefaultListenerMethod("consumeMessage");
        
        // 全局转换器,支持多种转换组合
		ContentTypeDelegatingMessageConverter convert = new ContentTypeDelegatingMessageConverter();
		
		TextMessageConverter textConvert = new TextMessageConverter();
		convert.addDelegate("text", textConvert);
		convert.addDelegate("html/text", textConvert);
		convert.addDelegate("xml/text", textConvert);
		convert.addDelegate("text/plain", textConvert);
		
		Jackson2JsonMessageConverter jsonConvert = new Jackson2JsonMessageConverter();
		convert.addDelegate("json", jsonConvert);
		convert.addDelegate("application/json", jsonConvert);
		
		ImageMessageConverter imageConverter = new ImageMessageConverter();
		convert.addDelegate("image/png", imageConverter);
		convert.addDelegate("image", imageConverter);
		
		PDFMessageConverter pdfConverter = new PDFMessageConverter();
		convert.addDelegate("application/pdf", pdfConverter);
        
		
		adapter.setMessageConverter(convert);
		container.setMessageListener(adapter);
		
    	return container;
    	
    }
    

```

#### ConverterBody 
``` java
@Data
public class ConverterBody {
	private byte[] body;
	
	public ConverterBody() {
	}
	public ConverterBody(byte[] body) {
		this.body = body;
	}
}
```

#### TextMessageConverter
``` java
public class TextMessageConverter implements MessageConverter {
	@Override
	public Message toMessage(Object object, MessageProperties messageProperties) throws MessageConversionException {
		return new Message(object.toString().getBytes(), messageProperties);
	}
	@Override
	public Object fromMessage(Message message) throws MessageConversionException {
		String contentType = message.getMessageProperties().getContentType();
		if(null != contentType && contentType.contains("text")) {
			return new String(message.getBody());
		}
		return message.getBody();
	}
}
```

#### ImageMessageConverter
``` java
public class ImageMessageConverter implements MessageConverter {

	@Override
	public Message toMessage(Object object, MessageProperties messageProperties) throws MessageConversionException {
		throw new MessageConversionException(" convert error ! ");
	}

	@Override
	public Object fromMessage(Message message) throws MessageConversionException {
		System.err.println("-----------Image MessageConverter----------");
		
		Object _extName = message.getMessageProperties().getHeaders().get("extName");
		String extName = _extName == null ? "png" : _extName.toString();
		
		byte[] body = message.getBody();
		String fileName = UUID.randomUUID().toString();
		String path = "d:/010_test/" + fileName + "." + extName;
		File f = new File(path);
		try {
			Files.copy(new ByteArrayInputStream(body), f.toPath());
		} catch (IOException e) {
			e.printStackTrace();
		}
		return f;
	}

}
```

#### MessageDelegate
``` java
public class MessageDelegate {
	public void consumeMessage(Map messageBody) {
		System.err.println("map方法, 消息内容:" + messageBody);
	}
	
	
	public void consumeMessage(Order order) {
		System.err.println("order对象, 消息内容, id: " + order.getId() + 
				", name: " + order.getName() + 
				", content: "+ order.getContent());
	}
	
	public void consumeMessage(Packaged pack) {
		System.err.println("package对象, 消息内容, id: " + pack.getId() + 
				", name: " + pack.getName() + 
				", content: "+ pack.getDescription());
	}
	
	public void consumeMessage(File file) {
		System.err.println("文件对象 方法, 消息内容:" + file.getName());
	}
}
```

### 代码技巧
> 从spring-rabbit可以用来模仿写呼叫系统的sdk包,首先定义一套呼叫系统的API，这一套API不进行任何实际呼叫系统操作。再写一个实际和呼叫系统打交道的jar包，最后在写一个呼叫系统和spring整合的包。这里的方式和感觉和sql的驱动包有些不同，sql的驱动的包主要是使用spi，而这个则是从代码架构层面进行了整合以实现不同的厂商的驱动。

> rabbitmq中的反射+默认方法名的方式可以借鉴。然后通过转换器去进行不同的参数匹配
