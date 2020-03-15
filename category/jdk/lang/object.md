# Object
---
> object类在java中是所有类的直接或间接父类，因此object类的所有共有方法也被所有的类所继承，java本身是单根继承的，所有object类相当于root类

## 继承关系
> 无

## 重要变量
> 无

## 构造函数
> 系统在编译时会默认创建一个无参构造

## 重要函数
### equals()
```java
public boolean equals(Object obj) {
    return (this == obj);
}
```
> 在Object类中，equals()方法其实是和==等价的.所以在Object中两个对象的引用相同，那么一定就是相同的。<br/>
> 在Java规范中，对 equals 方法的使用必须遵循以下几个原则：<br/>
> **自反性**：对于任何非空引用值 x，x.equals(x) 都应返回 true。<br/>
> **对称性**：对于任何非空引用值 x 和 y，当且仅当 y.equals(x) 返回 true 时，x.equals(y) 才应返回 true。<br/>
> **传递性**：对于任何非空引用值 x、y 和 z，如果 x.equals(y) 返回 true，并且 y.equals(z) 返回 true，那么 x.equals(z) 应返回 true。<br/>
> **一致性**：对于任何非空引用值 x 和 y，多次调用 x.equals(y) 始终返回 true 或始终返回 false，前提是对象上 equals 比较中所用的信息没有被修改<br/>
> 对于任何非空引用值 x，x.equals(null) 都应返回 false<br/>

### hashCode()
```java
public native int hashCode();
```
> hashCode()是一个被native修饰的本地方法,根据注释是**返回对象的哈希码值**

### getClass()
```java
public final native Class<?> getClass();
```
> getClass()是一个被native修饰的本地方法,根据注释是返回对象运行时候的类，并且该类被final修饰，说明此方法不能被重写。

### clone()
```java
protected native Object clone() throws CloneNotSupportedException;
```
> clone()被native所修饰,当我们在自定义类中使用该方法的时候，需要继承一个Cloneable接口，否则会抛出CloneNotSupportedException异常。该方法是一个**浅复制，不是深复制**

### finalize()
```java
protected void finalize() throws Throwable { }
```
> 当垃圾回收器确定不再有对该对象的引用时，由垃圾回收器在对象上调用。

### toString()
```java
public String toString() {
    return getClass().getName() + "@" + Integer.toHexString(hashCode());
}
```
> 返回字节码文件的对应全路径名和对象哈希值转成16进制数格式的字符串

### notify() notifyAll() wait()
> 请参考多线程部分
