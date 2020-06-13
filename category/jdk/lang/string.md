# String
---
> String 类用来代表字符串，实际上 String 对象的值是一个常量，一旦创建后不能被改变。正式因为其不可变，所以它是线程安全地，可以多个线程共享。

## 继承关系
```java
public final class String implements java.io.Serializable, Comparable<String>, CharSequence{}
```
> String类被final所修饰,表示该类不可被继承，同时实现java.io.Serializable,Comparable<String>,CharSequence接口.
- java.io.Serializable 表示该类支持序列化和反序列化
- Comparable<String> 表示该类可以实现自定义的字符串比较规则，具体在compareTo方法中实现
- CharSequence是一个描述字符串结构的接口，这个接口一般有三个常用的子类，String，StringBuffer，StringBuilder

## 重要变量
```java
// String字符串所使用的数据结构，由于该char数组被final所修饰,一旦复制就不可更改，因此也决定了String的特性，一旦复制就不能更改
private final char value[];
//缓存字符串的hashCode,优化字符串比较每次都计算hashCode，比如HashMap就可以直接根据该属性进行比较
private int hash;
//用于序列化和反序列化
private static final long serialVersionUID = -6849794470754667710L;
//类中没有使用
private static final ObjectStreamField[] serialPersistentFields = new ObjectStreamField[0];
//其根本就是持有一个静态内部类，用于忽略大小写得比较两个字符串
public static final Comparator<String> CASE_INSENSITIVE_ORDER = new CaseInsensitiveComparator();
```

### 内部类
```java
private static class CaseInsensitiveComparator
        implements Comparator<String>, java.io.Serializable {
    // use serialVersionUID from JDK 1.2.2 for interoperability
    private static final long serialVersionUID = 8575799808933029326L;

    public int compare(String s1, String s2) {
        int n1 = s1.length();
        int n2 = s2.length();
        int min = Math.min(n1, n2);
        for (int i = 0; i < min; i++) {
            char c1 = s1.charAt(i);
            char c2 = s2.charAt(i);
            if (c1 != c2) {
                c1 = Character.toUpperCase(c1);
                c2 = Character.toUpperCase(c2);
                if (c1 != c2) {
                    c1 = Character.toLowerCase(c1);
                    c2 = Character.toLowerCase(c2);
                    if (c1 != c2) {
                        // No overflow because of numeric promotion
                        return c1 - c2;
                    }
                }
            }
        }
        return n1 - n2;
    }

    /** Replaces the de-serialized object. */
    private Object readResolve() { return CASE_INSENSITIVE_ORDER; }
}
```
> 该类的主要作用是忽略大小写比较,其比较思路是比较逐个比较两个字符串中共有长度的字符的ASIIC码大小，然后返回差值。如果两个字符串共有长度的字符串相同，返回字符串差值，该类主要提供给compareToIgnoreCase方法使用

## 构造函数
### 空参数构造函数
```java
public String() {
    this.value = "".value;
}
```
### 字符串构造
```java
public String(String original) {
    this.value = original.value;
    this.hash = original.hash;
}
```
### 字符数组构造
```java
public String(char value[]) {
    this.value = Arrays.copyOf(value, value.length);
}
public String(char value[], int offset, int count) {
    if (offset < 0) {
        throw new StringIndexOutOfBoundsException(offset);
    }
    if (count <= 0) {
        if (count < 0) {
            throw new StringIndexOutOfBoundsException(count);
        }
        if (offset <= value.length) {
            this.value = "".value;
            return;
        }
    }
    // Note: offset or count might be near -1>>>1.
    if (offset > value.length - count) {
        throw new StringIndexOutOfBoundsException(offset + count);
    }
    this.value = Arrays.copyOfRange(value, offset, offset+count);
}
```
> 使用字符数组构造String其底层使用的Arrays.copyOf，Arrays.copyOfRange两个方法，将字符数组进行复制，然后赋值给value

### 字节数组构造
```java
public String(byte bytes[], int offset, int length, String charsetName)
        throws UnsupportedEncodingException {
    if (charsetName == null)
        throw new NullPointerException("charsetName");
    checkBounds(bytes, offset, length);
    this.value = StringCoding.decode(charsetName, bytes, offset, length);
}
public String(byte bytes[], int offset, int length, Charset charset) {
    if (charset == null)
        throw new NullPointerException("charset");
    checkBounds(bytes, offset, length);
    this.value =  StringCoding.decode(charset, bytes, offset, length);
}
public String(byte bytes[], String charsetName)
        throws UnsupportedEncodingException {
    this(bytes, 0, bytes.length, charsetName);
}
public String(byte bytes[], Charset charset) {
    this(bytes, 0, bytes.length, charset);
}
public String(byte bytes[], int offset, int length) {
    checkBounds(bytes, offset, length);
    this.value = StringCoding.decode(bytes, offset, length);
}
public String(byte bytes[]) {
    this(bytes, 0, bytes.length);
}
```
```java
static char[] decode(byte[] ba, int off, int len) {
    String csn = Charset.defaultCharset().name();
    try {
        // use charset name decode() variant which provides caching.
        return decode(csn, ba, off, len);
    } catch (UnsupportedEncodingException x) {
        warnUnsupportedCharset(csn);
    }
    try {
        return decode("ISO-8859-1", ba, off, len);
    } catch (UnsupportedEncodingException x) {
        // If this code is hit during VM initialization, MessageUtils is
        // the only way we will be able to get any kind of error message.
        MessageUtils.err("ISO-8859-1 charset not available: "
                         + x.toString());
        // If we can not find ISO-8859-1 (a required encoding) then things
        // are seriously wrong with the installation.
        System.exit(1);
        return null;
    }
}
static char[] decode(String charsetName, byte[] ba, int off, int len)
    throws UnsupportedEncodingException
{
    StringDecoder sd = deref(decoder);
    String csn = (charsetName == null) ? "ISO-8859-1" : charsetName;
    if ((sd == null) || !(csn.equals(sd.requestedCharsetName())
                          || csn.equals(sd.charsetName()))) {
        sd = null;
        try {
            Charset cs = lookupCharset(csn);
            if (cs != null)
                sd = new StringDecoder(cs, csn);
        } catch (IllegalCharsetNameException x) {}
        if (sd == null)
            throw new UnsupportedEncodingException(csn);
        set(decoder, sd);
    }
    return sd.decode(ba, off, len);
}
```
> 在使用byte数组构造字符串的时候,都涉及到了编码和解码的操作，可以看出编码和解码操作的主要方法是在StringCoding.decode中完成的。使用的解码的字符集就是我们指定的charsetName或者charset。 我们在使用byte[]构造String的时候，如果没有指明解码使用的字符集的话，那么StringCoding的decode方法首先调用系统的默认编码格式，如果没有指定编码格式则默认使用ISO-8859-1编码格式进行编码操作

## StringBuffer或StringBuilder构造字符串
```java
public String(StringBuffer buffer) {
    synchronized(buffer) {
        this.value = Arrays.copyOf(buffer.getValue(), buffer.length());
    }
}
public String(StringBuilder builder) {
    this.value = Arrays.copyOf(builder.getValue(), builder.length());
}
```
> 从这里可以看出StringBuffer是线程不安全的,在构造字符串的时候也使用了synchronized关键字进行保护

## codePoint构造字符串
```java
public String(int[] codePoints, int offset, int count) {
    if (offset < 0) {
        throw new StringIndexOutOfBoundsException(offset);
    }
    if (count <= 0) {
        if (count < 0) {
            throw new StringIndexOutOfBoundsException(count);
        }
        if (offset <= codePoints.length) {
            this.value = "".value;
            return;
        }
    }
    // Note: offset or count might be near -1>>>1.
    if (offset > codePoints.length - count) {
        throw new StringIndexOutOfBoundsException(offset + count);
    }

    final int end = offset + count;

    // Pass 1: Compute precise size of char[]
    int n = count;
    for (int i = offset; i < end; i++) {
        int c = codePoints[i];
        if (Character.isBmpCodePoint(c))
            continue;
        else if (Character.isValidCodePoint(c))
            n++;
        else throw new IllegalArgumentException(Integer.toString(c));
    }

    // Pass 2: Allocate and fill in char[]
    final char[] v = new char[n];

    for (int i = offset, j = 0; i < end; i++, j++) {
        int c = codePoints[i];
        if (Character.isBmpCodePoint(c))
            v[j] = (char)c;
        else
            Character.toSurrogates(c, v, j++);
    }

    this.value = v;
}
```
> 代码点转换为字符，然后构造字符串，不过其中牵扯到了关于代码点的校验看不懂

## 重要函数
### length()
```java
public int length() {
    return value.length;
}
```
### charAt()
```java
public char charAt(int index) {
    if ((index < 0) || (index >= value.length)) {
        throw new StringIndexOutOfBoundsException(index);
    }
    return value[index];
}
```
### getChars()
```java
public void getChars(int srcBegin, int srcEnd, char dst[], int dstBegin) {
    if (srcBegin < 0) {
        throw new StringIndexOutOfBoundsException(srcBegin);
    }
    if (srcEnd > value.length) {
        throw new StringIndexOutOfBoundsException(srcEnd);
    }
    if (srcBegin > srcEnd) {
        throw new StringIndexOutOfBoundsException(srcEnd - srcBegin);
    }
    System.arraycopy(value, srcBegin, dst, dstBegin, srcEnd - srcBegin);
}
```

### getBytes()
```java
public byte[] getBytes(String charsetName)
        throws UnsupportedEncodingException {
    if (charsetName == null) throw new NullPointerException();
    return StringCoding.encode(charsetName, value, 0, value.length);
}
public byte[] getBytes(Charset charset) {
    if (charset == null) throw new NullPointerException();
    return StringCoding.encode(charset, value, 0, value.length);
}
```

### equals()
```java
public boolean equals(Object anObject) {
	//判断引用是否相同
    if (this == anObject) {
        return true;
    }
    //判断参数的实例
    if (anObject instanceof String) {
        String anotherString = (String)anObject;
        int n = value.length;
        //判断字符串的长度
        if (n == anotherString.value.length) {
            char v1[] = value;
            char v2[] = anotherString.value;
            int i = 0;
            //逐个字符比较
            while (n-- != 0) {
                if (v1[i] != v2[i])
                    return false;
                i++;
            }
            return true;
        }
    }
    return false;
}
```
> 该方法首先通过==的方式判断引用，如果是返回true.如果不是返回false<br/>
> 然后判断anObject是不是String的实例,如果是则继续向下比较,如果不是返回false<br/>
> 最后比较两个字符串底层维护的value长度,如果是则继续向下比较，如果不是返回false<br/>
> 最后逐个比较每个字符

### contentEquals()
```java
public boolean contentEquals(StringBuffer sb) {
	//向上转型成CharSequence,方便比较方法的复用
    return contentEquals((CharSequence)sb);
}
public boolean contentEquals(CharSequence cs) {
    // 参数是 AbstractStringBuilder的实例及为StringBuffer,StringBuilder
    if (cs instanceof AbstractStringBuilder) {
        if (cs instanceof StringBuffer) {
            synchronized(cs) {
               return nonSyncContentEquals((AbstractStringBuilder)cs);
            }
        } else {
            return nonSyncContentEquals((AbstractStringBuilder)cs);
        }
    }
    // 如果参数是String类型的实例,则调用equals方法进行比较
    if (cs instanceof String) {
        return equals(cs);
    }
    // 最后是比较CharSequence，先是比较长度，然后逐个比较字符
    char v1[] = value;
    int n = v1.length;
    if (n != cs.length()) {
        return false;
    }
    for (int i = 0; i < n; i++) {
        if (v1[i] != cs.charAt(i)) {
            return false;
        }
    }
    return true;
}
private boolean nonSyncContentEquals(AbstractStringBuilder sb) {
    char v1[] = value;
    char v2[] = sb.getValue();
    int n = v1.length;
    if (n != sb.length()) {
        return false;
    }
    for (int i = 0; i < n; i++) {
        if (v1[i] != v2[i]) {
            return false;
        }
    }
    return true;
}
```
### compareTo()
```java
public int compareTo(String anotherString) {
    int len1 = value.length;
    int len2 = anotherString.value.length;
    int lim = Math.min(len1, len2);
    char v1[] = value;
    char v2[] = anotherString.value;

    int k = 0;
    // 逐个比较字符的ASSIC码,返回差值
    while (k < lim) {
        char c1 = v1[k];
        char c2 = v2[k];
        if (c1 != c2) {
            return c1 - c2;
        }
        k++;
    }
    // 如果共有字符相同，比较长度，返回长度差值
    return len1 - len2;
}
public int compareToIgnoreCase(String str) {
    return CASE_INSENSITIVE_ORDER.compare(this, str);
}
```



## 扩展
### 代码点
> 代码点：是指可用于编码字符集的数字<br/>
从Unicode标准而来的术语，Unicode标准的核心是一个编码字符集，它为每一个字符分配一个唯一数字。Unicode标准始终使用16进制数字，并且在书写时在前面加上U+，如字符"A"的编码为"U+0041"<br/>
编码字符集定义一个有效的代码点范围，但是并不一定将字符分配给所有这些代码点。有效的Unicode代码点范围是U+0000至U+10FFFF。Unicode4.0将字符分配给一百多万个代码点中的96382个代码点
