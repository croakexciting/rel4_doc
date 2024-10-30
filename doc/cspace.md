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

