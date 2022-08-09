# final和不变性
--- 

## 不变性

> **如果对象被创建后，状态(自身的引用，字段的引用)就不能被修改，那么它就是不可变的。**  
> **具有不变性的对象一定是线程安全的，我们不需要对其采取任何额外的安全措施，也能保证线程的安全**

## final作用

- 修饰一个类防止被继承，修饰一个方法防止被重写，修饰一个变量防止被修改
- 天生是线程安全的，而不需要额外的同步开销

### final修饰变量

> 被final修饰的变量，意味着值不能改变。如果变量是对象的时候，那么对象的引用是不能改变的，但是对象自身的内容依然可变。

- final instance variable(类中的final属性)
- final static variable(类中的static final属性)
- final local variable(方法中的final变量)

> 上面三种被final所修饰的变量，本质上是赋值时机的不同.
> - 类中的final属性：**声明的时候在等号右边赋值，构造函数中赋值，类的初始化代码中赋值**。java语法规定， 如果不采用第一种赋值方式，就不需要在第二种或第三种方式赋值。
> - 类中的 static final属性：**声明的时候在等号右边赋值，static初始化代码中赋值**,无法使用普通初始化代码块赋值
> - 方法中的 final属性： **final local variable不规定赋值时机，只要求在使用前必须赋值，这和方法中的非final变量的要求是一样的**，

> **final变量如果在初始化的时候不赋值，后续赋值，就是从null变成你的赋值，这就违反了final不变的原则**

### final 修饰方法

- final不允许修饰构造方法
- final所修饰的方法不可被重写，也就是不能被override
- static方法不能被重写，但是可以写重名的方法。final修饰父类的方法，子类中不能出现同名的方法。原因是static是静态绑定，绑定到类中，同名的方法是完成不同的方法.

### final修饰类不可被继承

- final修饰对象的时候，只是对象的引用不可变，而对象本身的属性是可变的.

## 不变性和final的关系

> **不变性并不意味着，简单的使用final修饰就是不可变**
> - 对于基本数据类型而言，确实被final修饰后就有不变性
> - **对于对象类型而言**，需要该对象保证自身被创建后，状态永远不可变才可以.

```java
// 该类被的充当成员变量并被final所修饰具体不变性
public class Person {
    final int age = 18;
    final String name = "alice";
}

// 该类被的充当成员变量并被final所修饰不具体不变性
public class Person {
    final int age = 18;
    final String name = "alice";
    String address = "";
}
```

### 利用 final保证不变性

- 所有的属性都是final，包括所有对象类型的成员变量都是不可变的。

```java
public class ImmutableDemo {

    private final Set<String> students = new HashSet<>();

    public ImmutableDemo() {
        students.add("student-1");
        students.add("student-2");
        students.add("student-3");
    }

    public boolean isStudent(String name) {
        return students.contains(name);
    }
}
```

#### 对象不可变的条件

- 对象创建后，其状态就不能被修改
- 所有的属性都是final修饰的
- 对象创建过程中没有逸出

### 将变量写在线程内部-栈封闭

> 在每个方法中新建局部变量，实际上是存储在每个线程私有的栈空间，而每个线程的栈空间是不能被其他线程访问的。  
> 所以不会有线程安全的问题，这就是**栈封闭**技术，是线程封闭技术的一种实现。

```java
public class StackConfinement implements Runnable {
    int index = 0;

    public void inThread() {
        int neverGoOut = 0;
        for (int i = 0; i < 10000; i++) {
            neverGoOut++;
        }
        System.out.println(Thread.currentThread().getName() + " 栈内保护的数字是线程安全的: " + neverGoOut);
    }


    @Override
    public void run() {
        for (int i = 0; i < 10000; i++) {
            index++;
        }

        inThread();
    }

    public static void main(String[] args) throws InterruptedException {
        StackConfinement r = new StackConfinement();
        Thread t1 = new Thread(r);
        Thread t2 = new Thread(r);
        t1.start();
        t2.start();
        t1.join();
        t2.join();
        System.out.println("index : " + r.index);

        //Thread-1 栈内保护的数字是线程安全的: 10000
        //Thread-0 栈内保护的数字是线程安全的: 10000
        //index : 15376
    }
}
```

### 面试题

```java
public class FinalDemo {
    public static void main(String[] args) {
        String a = "test2";  // 指向常量池
        final String b = "test"; // 指向常量池
        String c = b + 2;  // 指向常量池

        String d = "test"; // 指向常量池
        String e = d + 2;  // 运行时确定，指定到堆上

        System.out.println(d == b); // true
        System.out.println((a == c)); // true
        System.out.println((a == e));// false
    }
}
```

```java
public class FinalStringDemo2 {
    public static void main(String[] args) {
        String a = "test2"; // 指向常量池
        final String b = getTest(); // 通过方法获取到的，只有在运行时确定，是指向堆的，而不是常量池
        String c = b + 2;
        System.out.println(a == c); // false

    }

    private static String getTest() {
        return "test";
    }
}
```

### final的三种用法是什么？
> Final 用在变量、方法或者类上时，其含义是截然不同的：修饰变量意味着一旦被赋值就不能被修改；修饰方法意味着不能被重写；修饰类意味着不能被继承。