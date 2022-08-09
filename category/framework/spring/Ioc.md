# IOC
---

## IOC的核心理念
> **Spring ioc也就是让IoC Service Provider来为你服务**  
> 通常情况下，被注入对象会直接依赖于被依赖对象。但是，在IoC的场景中，二者之间通过IoC Service Provider来打交道，所有的被注入对象和依赖对象现在由IoC Service Provider统一管理。  
被注入对象需要 什么，直接跟IoC Service Provider招呼一声，后者就会把相应的被依赖对象注入到被注入对象中，从而达到IoC Service Provider为被注入对象服务的目的。
IoC Service Provider在这里就是通常的IoC容器所充 当的角色。从被注入对象的角度看，与之前直接寻求依赖对象相比，依赖对象的取得方式发生了反转，控制也从被注入对象转到了IoC Service Provider那里



###spring ioc源码分析
> 在spring启动的初始化过程中，主要分为两个阶段: **容器启动阶段**,**bean实例化阶段**  

### 容器初始化阶段
> 容器启动伊始，首先会通过某种途径加载Configuration MetaData。除了代码方式比较直接,在大部分情况下,容器需要依赖某些工具类(BeanDefinitionReader)对加载的Configuration MetaData.
> 进行解析和分析，并将分析后的信息编组为相应的BeanDefinition，最后把这些保存了bean定义必要信息的BeanDefinition，注册到相应的BeanDefinitionRegistry，这样容器启动工作就完成了  
> 该阶段所做的工作可以认为是准备性的，重点更加侧重于对象管理信息的收集


#### 测试代码
```java
/**
 * 分析spring将bean从xml加载到spring的全过程
 */
public class XmlLoadClassSource {

    public static void main(String[] args) {
        // 资源定位 以类路径的方式访问资源
        Resource classPathResource = new ClassPathResource("place/placeHolder.xml");
        // 通过返回的resource对象进行 BeanDefinition 的载入
        XmlBeanFactory factory = new XmlBeanFactory(classPathResource);
        System.out.println(factory.getBean("jdbcConfig"));
    }
}
```

#### 资源定位 

##### ClassPathResource
```java
public class ClassPathResource extends AbstractFileResolvingResource {
    
    private final String path;

    private ClassLoader classLoader;
    
    public ClassPathResource(String path) {
        this(path, (ClassLoader) null);
    }
    
     //校验字符串路径是否合法,并去除开头的/
     // 设置 ClassLoader
     public ClassPathResource(String path, ClassLoader classLoader) {
        Assert.notNull(path, "Path must not be null");
        String pathToUse = StringUtils.cleanPath(path);
        if (pathToUse.startsWith("/")) {
            pathToUse = pathToUse.substring(1);
        }
        this.path = pathToUse;
        this.classLoader = (classLoader != null ? classLoader : ClassUtils.getDefaultClassLoader());
    }
}
```

##### ClassUtils
```java
public abstract class ClassUtils {
    public static ClassLoader getDefaultClassLoader() {
    		ClassLoader cl = null;
    		try {
    		    // 获取当前线程的classLoader
    			cl = Thread.currentThread().getContextClassLoader();
    		}
    		catch (Throwable ex) {
    			// Cannot access thread context ClassLoader - falling back...
    		}
    		if (cl == null) {
    		    // 如果没有当前线程的classLoader则适应当前类的classLoader,
    			// No thread context class loader -> use class loader of this class.
    			cl = ClassUtils.class.getClassLoader();
    			if (cl == null) {
    				// getClassLoader() returning null indicates the bootstrap ClassLoader
    				try {
    				    // 如果没有当前类的classloader则使用系统默认的classloader
    					cl = ClassLoader.getSystemClassLoader();
    				}
    				catch (Throwable ex) {
    					// Cannot access system ClassLoader - oh well, maybe the caller can live with null...
    				}
    			}
    		}
    		return cl;
    	}
}
```

#### BeanDefinition 载入
 
##### XmlBeanFactory
```java
public class XmlBeanFactory extends DefaultListableBeanFactory {

	private final XmlBeanDefinitionReader reader = new XmlBeanDefinitionReader(this);


	public XmlBeanFactory(Resource resource) throws BeansException {
		this(resource, null);
	}

	public XmlBeanFactory(Resource resource, BeanFactory parentBeanFactory) throws BeansException {
		super(parentBeanFactory);
		
		// 主要是通过这里的方法实现bean的加载. 该方法是由BeanDefinitionReader定义，PropertiesBeanDefinitionReader 和 XmlBeanDefinitionReader 分别给出了针对于xml和properties的实现
		this.reader.loadBeanDefinitions(resource);
	}

}

```

##### XmlBeanDefinitionReader

```java
public class XmlBeanDefinitionReader extends AbstractBeanDefinitionReader {

    // 解析单个Resource对象返回BeanDefinition对象
    public int loadBeanDefinitions(Resource resource) throws BeanDefinitionStoreException {
        // 将 Resource 包装成为 EncodedResource 为后面的bean解析做准备
        EncodedResource encodedResource = new EncodedResource(resource);
        return loadBeanDefinitions(encodedResource);
    }


     public int loadBeanDefinitions(EncodedResource encodedResource) throws BeanDefinitionStoreException {
        Assert.notNull(encodedResource, "EncodedResource must not be null");
        if (logger.isInfoEnabled()) {
            logger.info("Loading XML bean definitions from " + encodedResource.getResource());
        }

        // resourcesCurrentlyBeingLoaded是一个ThreadLocal，里面存放Resource包装类的set集合
        Set<EncodedResource> currentResources = this.resourcesCurrentlyBeingLoaded.get();
        if (currentResources == null) {
            currentResources = new HashSet<EncodedResource>(4);
            this.resourcesCurrentlyBeingLoaded.set(currentResources);
        }
        
        // 检测到循环加载某个Resource，需要检查导入的definitions
        if (!currentResources.add(encodedResource)) {
            throw new BeanDefinitionStoreException(
                    "Detected cyclic loading of " + encodedResource + " - check your import definitions!");
        }
        try {
            InputStream inputStream = encodedResource.getResource().getInputStream();
            try {
                // 将xml的输入流进行包装
                InputSource inputSource = new InputSource(inputStream);
                
                // 如果指定了编码格式，则使用指定的编码格式
                if (encodedResource.getEncoding() != null) {
                    inputSource.setEncoding(encodedResource.getEncoding());
                }
                // 这里是加载xml并返回放入spring容器中的bean的个数
                return doLoadBeanDefinitions(inputSource, encodedResource.getResource());
            } finally {
                inputStream.close();
            }
        } catch (IOException ex) {
            throw new BeanDefinitionStoreException(
                    "IOException parsing XML document from " + encodedResource.getResource(), ex);
        } finally {
            currentResources.remove(encodedResource);
            if (currentResources.isEmpty()) {
                this.resourcesCurrentlyBeingLoaded.remove();
            }
        }
    }
    
    protected int getValidationModeForResource(Resource resource) {
        // 默认的验证方式 ，自动验证 为 1
        int validationModeToUse = getValidationMode();
        // 如果指定了验证方式则使用指定的验证方式
        if (validationModeToUse != VALIDATION_AUTO) {
            return validationModeToUse;
        }
        
        // 检测验证模式，进入这个方法
        int detectedMode = detectValidationMode(resource);
        if (detectedMode != VALIDATION_AUTO) {
            return detectedMode;
        }
        // Hmm, we didn't get a clear indication... Let's assume XSD,
        // since apparently no DTD declaration has been found up until
        // detection stopped (before finding the document's root tag).
        return VALIDATION_XSD;
    }
    
    protected int detectValidationMode(Resource resource) {
        if (resource.isOpen()) {
            throw new BeanDefinitionStoreException(
                    "Passed-in Resource [" + resource + "] contains an open stream: " +
                            "cannot determine validation mode automatically. Either pass in a Resource " +
                            "that is able to create fresh streams, or explicitly specify the validationMode " +
                            "on your XmlBeanDefinitionReader instance.");
        }

        InputStream inputStream;
        try {
            inputStream = resource.getInputStream();
        } catch (IOException ex) {
            throw new BeanDefinitionStoreException(
                    "Unable to determine validation mode for [" + resource + "]: cannot open InputStream. " +
                            "Did you attempt to load directly from a SAX InputSource without specifying the " +
                            "validationMode on your XmlBeanDefinitionReader instance?", ex);
        }

        try {
            // 验证xml的模式，具体的验证方式是按照行 读取文件流读取第一行的有效数据(有效数据指跳过注释) 是否包含DOCTYPE
            // 如果包含DOCTYPE 则是DTD模式，反之 则是XSD模式
            return this.validationModeDetector.detectValidationMode(inputStream);
        } catch (IOException ex) {
            throw new BeanDefinitionStoreException("Unable to determine validation mode for [" +
                    resource + "]: an error occurred whilst reading from the InputStream.", ex);
        }
    }
    
    protected int doLoadBeanDefinitions(InputSource inputSource, Resource resource)
                throws BeanDefinitionStoreException {
        try {
            // 检测xml的模式 是 XSD,DTO,AUTO
            int validationMode = getValidationModeForResource(resource);
            System.out.println("validationMode: " + validationMode);

                
            // param1 inputSource 由上一层方法传递而来
            // param2 getEntityResolver() XmlBeanDefinitionReader类的 entityResolver属性
            // param3 XmlBeanDefinitionReader 类的 entityResolver 属性
            // param4 xml的模式
            // param5 是否支持命名空间,默认是false
        
            // 这里主要是加载document
            Document doc = this.documentLoader.loadDocument(
                    inputSource, getEntityResolver(), this.errorHandler, validationMode, isNamespaceAware());

            // 这里是将加载出来的bean的放入spring的容器,并返回个数
            return registerBeanDefinitions(doc, resource);
        } catch (BeanDefinitionStoreException ex) {
            throw ex;
        } catch (SAXParseException ex) {
            throw new XmlBeanDefinitionStoreException(resource.getDescription(),
                    "Line " + ex.getLineNumber() + " in XML document from " + resource + " is invalid", ex);
        } catch (SAXException ex) {
            throw new XmlBeanDefinitionStoreException(resource.getDescription(),
                    "XML document from " + resource + " is invalid", ex);
        } catch (ParserConfigurationException ex) {
            throw new BeanDefinitionStoreException(resource.getDescription(),
                    "Parser configuration exception parsing XML from " + resource, ex);
        } catch (IOException ex) {
            throw new BeanDefinitionStoreException(resource.getDescription(),
                    "IOException parsing XML document from " + resource, ex);
        } catch (Throwable ex) {
            throw new BeanDefinitionStoreException(resource.getDescription(),
                    "Unexpected exception parsing XML document from " + resource, ex);
        }
    }


    
}
```

```java
public class DefaultDocumentLoader implements DocumentLoader {
    /**
    	 * 用于配置模式语言以进行验证的 JAXP 属性
    	 */
    	private static final String SCHEMA_LANGUAGE_ATTRIBUTE = "http://java.sun.com/xml/jaxp/properties/schemaLanguage";
    
    	/**
    	 * 指示 XSD 模式语言的 JAXP 属性值。
    	 */
    	private static final String XSD_SCHEMA_LANGUAGE = "http://www.w3.org/2001/XMLSchema";
    
    
    	private static final Log logger = LogFactory.getLog(DefaultDocumentLoader.class);
    
    
    	public Document loadDocument(InputSource inputSource, EntityResolver entityResolver,
    			ErrorHandler errorHandler, int validationMode, boolean namespaceAware) throws Exception {
    
    		DocumentBuilderFactory factory = createDocumentBuilderFactory(validationMode, namespaceAware);
    		if (logger.isDebugEnabled()) {
    			logger.debug("Using JAXP provider [" + factory.getClass().getName() + "]");
    		}
    		DocumentBuilder builder = createDocumentBuilder(factory, entityResolver, errorHandler);
    		return builder.parse(inputSource);
    	}
    
    	protected DocumentBuilderFactory createDocumentBuilderFactory(int validationMode, boolean namespaceAware)
    			throws ParserConfigurationException {
    
    	    // 此处设置 namespaceAware,而 namespaceAware 默认为false
    		DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
    		factory.setNamespaceAware(namespaceAware);
    
    		if (validationMode != XmlValidationModeDetector.VALIDATION_NONE) {
    		    // 设置校验标识
    			factory.setValidating(true);
    
    			if (validationMode == XmlValidationModeDetector.VALIDATION_XSD) {
    			    //如果 校验模式为 VALIDATION_XSD 则强制设置 namespace aware生效
    				factory.setNamespaceAware(true);
    				try {
    					factory.setAttribute(SCHEMA_LANGUAGE_ATTRIBUTE, XSD_SCHEMA_LANGUAGE);
    				}
    				catch (IllegalArgumentException ex) {
    					ParserConfigurationException pcex = new ParserConfigurationException(
    							"Unable to validate using XSD: Your JAXP provider [" + factory +
    							"] does not support XML Schema. Are you running on Java 1.4 with Apache Crimson? " +
    							"Upgrade to Apache Xerces (or Java 1.5) for full XSD support.");
    					pcex.initCause(ex);
    					throw pcex;
    				}
    			}
    		}
    
    		return factory;
    	}
    
    	// 给 factory设置 entityResolver(主要是设置 schemaResolver 进行校验) 和 errorHandler
    	protected DocumentBuilder createDocumentBuilder(
    			DocumentBuilderFactory factory, EntityResolver entityResolver, ErrorHandler errorHandler)
    			throws ParserConfigurationException {
    
    		DocumentBuilder docBuilder = factory.newDocumentBuilder();
    		if (entityResolver != null) {
    			docBuilder.setEntityResolver(entityResolver);
    		}
    		if (errorHandler != null) {
    			docBuilder.setErrorHandler(errorHandler);
    		}
    		return docBuilder;
    	}
}
```