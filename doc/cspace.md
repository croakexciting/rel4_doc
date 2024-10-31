## 1. 简介

本文记录我学习 seL4 中 cspace 的一些心得和疑问。希望可以帮助初学者更快的理解 seL4 cspace.

Capability Space 是 seL4 中独特的功能，也是其核心功能。由于在传统操作系统中没有此概念，因此相对难以理解。

简单来说，每个 Task 具有一个 cspace，它本质上是一个 capability manager，储存着该 Task 对各种资源的访问权限，确保用户空间正确的访问内核，保证了内核的安全。

> seL4 中没有线程和进程的概念，而是统一为 Task，按照功能来看，每个 Task 都有自己的内存空间，因此更像是进程。

## 2. Cspace 核心概念

### 2.1 cspace

每一个 task 有一个独立的 cspace。类似于内存空间，cspace 不是一个实例，而是一个概念。一个 cspace 由一个或者多个 cnode 实例组成。

### 2.2 cnode

如果拿内存空间类比，cnode 有点像一个页表节点（指放置在一个物理页帧中的页表节点），cnode 中会存储多个 cslot，cslot 可以类比成 pte。但是 cspace 中 cnode 组织结构是很随意的，同一级 cslot 中既可以存储 capability，也可以存储 cnode 以指向下一级能力。这是因为 cspace 寻址过程是一个软件执行过程，因此不需要像内存空间那样严格的结构。

cnode 中按照数组的方式存储 cslot。这样可以降低寻址时的算法复杂度

### 2.3 cslot

cslot 中可以存储 capability，也可以存储下一级 cnode。存储下一级 cnode 较好理解，类似于多级页表。

capability 顾名思义是能力，能力的具体表现是各个 kernel object，比如 TCB，Frame 等等 seL4 object。因此可以简单理解 capability 是各个 kernel object 的实例，cslot 中存储了对应实例的地址。如果某个进程的 cspace 中的一个 cslot 存储了 tcb 实例的地址，那么该进程就可以访问该 tcb 实例，我们称为具有 tcb 访问能力。

> 上面是一个简单理解，当然 cslot 中不会直接存储实例地址，而是有一套加密机制。

## 3. Q & A

目前对于 cspace 了解还很浅薄，因此无法准确描述 cspace 设计实现。目前使用 Q & A 的方式，将学习中产生的疑问和答案都记录下来。 

1. 什么时候会用到 cspace

几乎每一个 syscall 都会用到 cspace，kernel 会判断 task 是否有执行该 syscall 的权限 (因为 syscall 本质上就是访问 kernel 资源)。

在 syscall 处理函数中，会根据提供的 cap index 找到对应的 cap type，再根据 cap type 执行对应调用

```
# rel4_kernel/src/syscall/invocation/mod.rs

pub fn handleInvocation(isCall: bool, isBlocking: bool) -> exception_t {
    ...
    # get cap type by cap index
    let lu_ret = thread.lookup_slot(cptr)

    ...

    # call relative invocation in decode_invocation
    let status = decode_invocation(
        info.get_label(),
        length,
        unsafe {&mut *lu_ret.slot },
        &cap,
        cptr,
        isBlocking,
        isCall,
        buffer
    );
}

# rel4_kernel/src/syscall/invocation/decode/mod.rs
pub fn decode_invocation(label: MessageLabel, length: usize, slot: &mut cte_t, cap: &cap_t, cap_index: usize,
                        block: bool, call: bool, buffer: Option<&seL4_IPCBuffer>) -> exception_t {
    match cap.get_cap_type() {
        ...
        CapTag::CapThreadCap => decode_tcb_invocation(label, length, cap, slot, call, buffer),
        CapTag::CapDomainCap => decode_domain_invocation(label, length, buffer),
        CapTag::CapCNodeCap => decode_cnode_invocation(label, length, cap, buffer),
        CapTag::CapUntypedCap => decode_untyed_invocation(label, length, slot, cap, buffer),
        CapTag::CapIrqControlCap => decode_irq_control_invocation(label, length, slot, buffer),
        CapTag::CapIrqHandlerCap => decode_irq_handler_invocation(label, cap.get_irq_handler()),
        ...
    }
}
```

2. 如何在 cspace 中寻址
   1. cspace 由一个或多个 cnode 组成
   2. cnode 中有多个 cslot，按照数组的方式进行排列
   3. cslot 中可以存储下一级的 cnode，方便多级寻址
   
   上面三点是否让你感觉很熟悉，很像页表。所以寻址过程也很简单，根据 index，在数组中可以方便的找到对应的 cslot

   但是 index 是谁提供的呢，其实是 task 提供的，内核是不会去管理这些 index 的。这就造成 task 需要管理和自己有关的所有能力的 index，这无疑对应用开发是非常不友好的。

   虽然 cspace 看起来结构是很灵活的，但实际上使用时我们必须依赖一些框架去开发，否则应用开发人员会很痛苦。

   > 事实上，kernel 只提供了最基础的功能，运行环境需要用户空间框架定义和补齐，kernel 只负责把 root task 启动，然后就不会主动做任何事情了。

3. 谁创建这些能力对应的实例
   
   正如上面所说，几乎所有的 kernel object 实例都是由用户空间请求创建的。只有具备 untyped memory 能力的 task 才可以为自己和其他进程创建 kernel 实例

    untyped memory 本质上一段连续未使用的物理内存空间，task 通过 seL4_Untyped_Retype 函数请求 kernel 创建一个新的实例。同样，你需要显示的指定这个实例放在那个 cslot 中。

4. 内存动态增加如何处理
   
5. 如何回收，回收后的物理帧如何处理

## 4. 学习感受

1. seL4 kernel 很难使用，几乎所有的参数都要求用户空间显式的提供，大大增加了用户空间对资源的管理使用成本。当然我没法说这种设计是否有改善的空间，但毫无疑问的是，seL4 用户空间开发框架是必要而且很难设计的。

