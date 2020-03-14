# 链表 双向链表
---
## 链表
> 动态数组，栈，队列 底层依托静态数组，依靠resize 方法解决固定容量的问题。而链表 则是一种真正的动态数据结构
### 链表的定义
> 链表是一种数据结构，在内存中通过节点记录内存地址而相互链接形成一条链的储存方式。相比数组而言，链表在内存中不需要连续的区域，只需要每一个节点都能够记录下一个节点的内存地址，通过引用进行查找，这样的特点也就造就了链表增删操作时间消耗很小，而查找遍历时间消耗很大的特点。
> 二者主要差别在于内部的Node类。单链表只需要一个指向下一个节点的引用Next，而双向链表则需要指向前一个Node的prev和下一个Node的Next。
### 链表 和 数组
- 数组
    - 数组最好用于索引有语义的情况，scores[2]
    - 数组最大的优点是支持随机访问
- 链表
    - 链表不支持索引有语义的情况
    - 最大的优点是动态

### LinkedList
#### 特殊处理头节点
``` java
package LinkedList;

public class LinkedList<E> {
    private Node head;
    private int size;
    /**
     * LinkedList 构造函数
     */
    public LinkedList()
    {
        this.head = null;
        this.size = 0;
    }
    /**
     * 获取链表 个数
     * @return
     */
    public int getSize()
    {
        return size;
    }
    public boolean isEmpty()
    {
        return size == 0;
    }
    public void addFirst(E e)
    {
        Node node = new Node(e);
        node.next = head;
        head = node;
        size ++;
    }
    public void add(int index,E e)
    {
        if(index < 0 || index > size)
        {
            throw new IllegalArgumentException("add fail,index is error");
        }

        if(index == 0)
        {
            addFirst(e);
        }
        else
        {
            Node prev = head;
            for (int i=0;i<index-1;i++)
            {
                prev = prev.next;
            }
            Node node = new Node(e);
            node.next = prev.next;
            prev.next = node;

            size++;
        }
    }

    public void addLast(E e)
    {
        add(size,e);
    }

    private class Node
    {
        public E e;
        public Node next;
        public Node(E e,Node next)
        {
            this.e = e;
            this.next = next;
        }
        public Node(E e)
        {
            this(e,null);
        }
        public Node()
        {
            this(null,null);
        }
        @Override
        public String toString() {
            return "Node{" + "e=" + e + '}';
        }
    }
}
```
#### 使用虚拟节点
> 在对链表进行操作的时候后，需要特殊处理 链表头节点，因为头节点没有上一个元素，使用虚拟头节点可以处理

![](https://img-blog.csdnimg.cn/20190130173231114.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3UwMTIyOTI3NTQ=,size_16,color_FFFFFF,t_70)
``` java
package LinkedList;
public class LinkedList<E> {
    private Node dummyHead;
    private int size;
    /**
     * LinkedList 构造函数
     */
    public LinkedList()
    {
        this.dummyHead = new Node(null,null);
        this.size = 0;
    }
    /**
     * 获取链表 个数
     * @return
     */
    public int getSize()
    {
        return size;
    }
    public boolean isEmpty()
    {
        return size == 0;
    }
    public void addFirst(E e)
    {
        add(0,e);
    }
    public void addLast(E e)
    {
        add(size,e);
    }
    public void add(int index,E e)
    {
        if(index < 0 || index > size)
        {
            throw new IllegalArgumentException("add fail,index is error");
        }
        Node prev = dummyHead;
        for (int i=0;i<index-1;i++)
        {
            prev = prev.next;
        }
        Node node = new Node(e);
        node.next = prev.next;
        prev.next = node;
        size++;
    }

    private class Node
    {
        public E e;
        public Node next;
        public Node(E e,Node next)
        {
            this.e = e;
            this.next = next;
        }
        public Node(E e)
        {
            this(e,null);
        }
        public Node()
        {
            this(null,null);
        }
        @Override
        public String toString() {
            return "Node{" + "e=" + e + '}';
        }
    }
}
```
#### 完整链表
``` java
package LinkedList;

public class LinkedList<E> {
    private Node dummyHead;
    private int size;
    /**
     * LinkedList 构造函数
     */
    public LinkedList()
    {
        this.dummyHead = new Node(null,null);
        this.size = 0;
    }
    /**
     * 获取链表 个数
     * @return
     */
    public int getSize()
    {
        return size;
    }
    public boolean isEmpty()
    {
        return size == 0;
    }
    public void addFirst(E e)
    {
        add(0,e);
    }
    public void addLast(E e)
    {
        add(size,e);
    }
    public void add(int index,E e)
    {
        if(index < 0 || index > size)
        {
            throw new IllegalArgumentException("add fail,index is error");
        }

        Node prev = dummyHead;
        for (int i=0;i<index-1;i++)
        {
            prev = prev.next;
        }

        Node node = new Node(e);
        node.next = prev.next;
        prev.next = node;

        size++;
    }
    public E getFirst()
    {
        return get(0);
    }
    public E getLast()
    {
        return get(size -1);
    }
    public E get(int index)
    {
        if(index < 0 || index > size)
        {
            throw new IllegalArgumentException("get fail,index is error");
        }

        Node current = dummyHead.next;
        for(int i=0;i<index;i++)
        {
            current = current.next;
        }
        return current.e;
    }

    public void set(int index,E e)
    {
        if(index < 0 || index > size)
        {
            throw new IllegalArgumentException("set fail,index is error");
        }

        Node current = dummyHead.next;
        for(int i=0;i<index;i++)
        {
            current = current.next;
        }
        current.e = e;
    }

    public boolean contains(E e)
    {
        Node current = dummyHead.next;
        while(current != null)
        {
            if(current.e.equals(e))
            {
                return true;
            }

            current = current.next;
        }
        return false;
    }

    public E removeFirst()
    {
        return remove(0);
    }
    public E removeLast()
    {
        return remove(size -1);
    }

    public E remove(int index)
    {

        if(index < 0 || index > size)
        {
            throw new IllegalArgumentException("remove fail,index is error");
        }

        Node prev = dummyHead;
        for(int i=0;i<index;i++)
        {
            prev = prev.next;
        }

        Node resultNode = prev.next;
        prev.next = resultNode.next;
        resultNode.next = null;

        size --;
        return resultNode.e;
    }

    private class Node
    {
        public E e;
        public Node next;

        public Node(E e,Node next)
        {
            this.e = e;
            this.next = next;
        }

        public Node(E e)
        {
            this(e,null);
        }

        public Node()
        {
            this(null,null);
        }

        @Override
        public String toString() {
            return "Node{" + "e=" + e + '}';
        }
    }

    @Override
    public String toString() {
        StringBuffer stringBuffer = new StringBuffer();

        Node current = dummyHead.next;
        while(current != null)
        {
            stringBuffer.append(current + "->");
            current = current.next;
        }
        stringBuffer.append("NULL");

        return stringBuffer.toString();
    }
}

```
#### 链表时间复杂度分析
操作|时间复杂度|操作|时间复杂度
-|-|-|-
addFirst(E e)|$O(1)$|removeFirst()|$O(n)$
addLast(E e) |$O(n)$|removeLast()|$O(1)$
add(index,e) |$O(n/2) = O(n)$|remove(index,e)|$O(n/2) = O(n)$
set(index,e)|$O(n)$|-|-
get(index) |$O(n)$  |-|-
contains(e)  |$O(n)$|-|-

#### 链表栈 和 数组栈 比较
``` java
package stack;

import linked.LinkedList;

public class LinkedListStack<E> implements Stack<E> {

    private LinkedList<E> list;

    public LinkedListStack() {
        list = new LinkedList<>();
    }

    @Override
    public void push(E o) {
        list.addFirst(o);
    }

    @Override
    public E pop() {
        return list.removeFirst();
    }

    @Override
    public E peek() {
        return list.getFirst();
    }

    @Override
    public boolean isEmpty() {
        return list.isEmpty();
    }

    @Override
    public int getSize() {
        return list.getSize();
    }

    @Override
    public String toString() {
        StringBuffer stringBuffer = new StringBuffer();

        stringBuffer.append("Stack: top ");
        stringBuffer.append(list);

        return stringBuffer.toString();
    }

    public static void main(String[] args) {
        LinkedListStack<Integer> listStack = new LinkedListStack<>();
        for(int i=0;i<6;i++)
        {
            listStack.push(i);
            System.out.println(listStack.toString());
        }
        listStack.pop();
        System.out.println(listStack.toString());
    }
}
```

**链表栈要 快于 数组栈，因为 链表属于动态数据结构，而数组属于静态数据结构，需要手动扩容，在一定程度上影响了效率,而链表则是在不停地在内存上开辟空间创建对象**
#### 使用双向链表实现队列
![](https://img1.sycdn.imooc.com/szimg/5ceb86100001136719201080-156-88.jpg)
``` java
package queue;
import linked.LinkedList;
public class LinkedListQueue<E> implements Queue<E>{
    private class Node
    {
    public E e;
    public LinkedListQueue.Node next;

    public Node(E e, LinkedListQueue.Node next)
    {
        this.e = e;
        this.next = next;
    }

    public Node(E e)
    {
        this(e,null);
    }

    public Node()
    {
        this(null,null);
    }

    @Override
    public String toString() {
        return "Node{" + "e=" + e + '}';
    }
}

 private Node head;
 private Node tail;

 private int size;

    public LinkedListQueue()
    {
        tail = null;
        size = 0;
        head = null;
    }

    @Override
    public void enqueue(E e) {
        if(tail == null)
        {
            tail = new Node(e);
            head = tail;
        }
        else
        {
            tail.next = new Node(e);
            tail = tail.next;
        }
        size ++;
    }

    @Override
    public E dequeue() {
        if(isEmpty())
            throw new IllegalArgumentException("cannot dequeue from an empty queue");

        Node retNode = head;
        head = head.next;
        retNode.next = null;

        if(head == null)
            tail = null;
        size --;
        return retNode.e;
    }

    @Override
    public E getFront() {
        if(isEmpty())
            throw new IllegalArgumentException("cannot dequeue from an empty queue");
        return head.e;
    }

    @Override
    public int getSize() {
        return size;
    }

    @Override
    public boolean isEmpty() {
        return size == 0;
    }

    @Override
    public String toString() {
        StringBuffer stringBuffer = new StringBuffer();
        stringBuffer.append("Queue   front  ");
        LinkedListQueue.Node current = head;
        while(current != null)
        {
            stringBuffer.append(current + "->");
            current = current.next;
        }
        stringBuffer.append("NULL  tail");
        return stringBuffer.toString();
    }

    public static void main(String[] args) {
    LinkedListQueue<Object> queue = new LinkedListQueue<>();
        for(int i=0;i<5;i++)
        {
            queue.enqueue(i);
            System.out.println(queue);
        }
        queue.dequeue();
        System.out.println(queue);
    }
}
```
