# 数组
---

## 线性结构和非线性结构
* 线性结构：是一个有序数据元素的集合    
 - 集合中必存在唯一的一个“第一个元素”
 - 集合中必存在唯一的一个“最后的元素”
 - 除最后一元素之外，其它数据元素均有唯一的“后继”
 - 除第一个元素之外，其它数据元素均有唯一的“前驱”

**符合条件的数据结构有 栈 队列 其他**
* 非线性结构：其逻辑特征是一个节点元素可以有多个直接前驱或多个直接后继。

**符合条件的数据结构就有图、树和其它**

## 数组
### 基本定义
> 数组是一种线性结构
- 优点
 - 存储多个元素，比较常用
 - 访问便捷，使用下标[index]即可访问
- 缺点
 - 数组的创建通常需要申请一段连续的内存空间，并且大小是固定的（大多数的编程语言数组都是固定的），所以在进行扩容的时候难以掌控。
 - 一般情况下，申请一个更大的数组，会是之前数组的倍数，比如两倍。然后，再将原数组中的元素复制过去
 - 插入数据越是靠前，其成本很高，因为需要进行大量元素的位移。

### 数组的时间复杂度
> o(1) 与数据规模无关, o(n), o(logn), o(nlogn)
> 描述的是算法的运行时间和输入数据之间的关系（渐进时间复杂度，描述n趋近于无穷的情况，通常情况下时间复杂度考虑的是最坏的情况

操作|时间复杂度|操作|时间复杂度
-|-|-|-
addLast(e)|$O(1)$|removeLast(e)|$O(1)$
addFirst(e)|$O(n)$|removeFirst(e)|$O(n)$
add(index, e)|$O(n/2) = O(n)$|remove(index, e)|O(n/2) = O(n)
set(index, e)|$O(1)$|-|-
get(index) |$O(1)$| contains(e) |$O(n)$
find(e)|$O(n)$|-|-

总结:
- 增：O(n)
- 删：O(n)
- 改：已知索引O(1)；未知索引O(n)
- 查：已知索引O(1)；未知索引O(n)

#### resize 时间复杂度分析
> 假设 capital 为 8 ，9次 addLast操作，触发17次基本操作，平均每次处罚两次基本操作
> 假设 capital 为 n，n+1次addLast，触发resize ，总共进行 2n+1次基本操作，平均每次addLast操作，进行两次基本操作
> 因此均摊时间复杂度为 O(1)

### 复杂度震荡
**复杂度震荡问题**：当我们的数组容量满的时候，再次添加一个元素，会触发扩容机制，然后再将这个元素删除，又会触发缩减容量的机制，明显这样对我们系统的资源是很大的浪费
**原因**： removeLast时resize过于着急（Eager）
**解决方法**：当 size == capacity / 4 时，才将capacity减半（Lazy），另外还要判断 capacity/4 的长度 != 0;

### 源码
``` java
package array;

public class Array<E> {

    private E[] data;
    private int size;

    // 构造函数，传入数组的容量capacity构造Array
    public Array(int capacity){
        data = (E[])new Object[capacity];
        size = 0;
    }
    // 无参数的构造函数，默认数组的容量capacity=10
    public Array(){
        this(10);
    }
    // 获取数组的容量
    public int getCapacity(){
        return data.length;
    }
    // 获取数组中的元素个数
    public int getSize(){
        return size;
    }
    // 返回数组是否为空
    public boolean isEmpty(){
        return size == 0;
    }
    // 在index索引的位置插入一个新元素e
    public void add(int index, E e){
        if(index < 0 || index > size)
            throw new IllegalArgumentException("Add failed. Require index >= 0 and index <= size.");
        if(size == data.length)
            resize(2 * data.length);
        for(int i = size - 1; i >= index ; i --)
            data[i + 1] = data[i];
        data[index] = e;
        size ++;
    }

    // 向所有元素后添加一个新元素
    public void addLast(E e){
        add(size, e);
    }
    // 在所有元素前添加一个新元素
    public void addFirst(E e){
        add(0, e);
    }
    // 获取index索引位置的元素
    public E get(int index){
        if(index < 0 || index >= size)
            throw new IllegalArgumentException("Get failed. Index is illegal.");
        return data[index];
    }
    public E getLast()
    {
        return data[size-1];
    }
    public E getFirst()
    {
        return data[0];
    }
    // 修改index索引位置的元素为e
    public void set(int index, E e){
        if(index < 0 || index >= size)
            throw new IllegalArgumentException("Set failed. Index is illegal.");
        data[index] = e;
    }
    // 查找数组中是否有元素e
    public boolean contains(E e){
        for(int i = 0 ; i < size ; i ++){
            if(data[i].equals(e))
                return true;
        }
        return false;
    }
    // 查找数组中元素e所在的索引，如果不存在元素e，则返回-1
    public int find(E e){
        for(int i = 0 ; i < size ; i ++){
            if(data[i].equals(e))
                return i;
        }
        return -1;
    }
    // 从数组中删除index位置的元素, 返回删除的元素
    public E remove(int index){
        if(index < 0 || index >= size)
            throw new IllegalArgumentException("Remove failed. Index is illegal.");

        E ret = data[index];
        for(int i = index + 1 ; i < size ; i ++)
            data[i - 1] = data[i];
        size --;
        data[size] = null; // loitering objects != memory leak

        if(size == data.length / 2)
            resize(data.length / 2);
        return ret;
    }
    // 从数组中删除第一个元素, 返回删除的元素
    public E removeFirst(){
        return remove(0);
    }
    // 从数组中删除最后一个元素, 返回删除的元素
    public E removeLast(){
        return remove(size - 1);
    }
    // 从数组中删除元素e
    public void removeElement(E e){
        int index = find(e);
        if(index != -1)
            remove(index);
    }
    public void swap(int i,int j)
    {
        if(i<0 || i>=size || j<0 || j>=size)
            throw new RuntimeException("error");

        E temp = data[i];
        data[i] = data[j];
        data[j] = temp;
    }
    @Override
    public String toString(){

        StringBuilder res = new StringBuilder();
        res.append(String.format("Array: size = %d , capacity = %d\n", size, data.length));
        res.append('[');
        for(int i = 0 ; i < size ; i ++){
            res.append(data[i]);
            if(i != size - 1)
                res.append(", ");
        }
        res.append(']');
        return res.toString();
    }
    // 将数组空间的容量变成newCapacity大小
    private void resize(int newCapacity){

        E[] newData = (E[])new Object[newCapacity];
        for(int i = 0 ; i < size ; i ++)
            newData[i] = data[i];
        data = newData;
    }
}

```
