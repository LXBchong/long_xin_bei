## Cache设计

> 2021/7/24
>
> 此文档是我们小组Cache的具体设计



### 1. Cache与CPU的交互行为

![Cache](资料图片/Cache.png)



​		CPU在Core Top层面通过四个信号与MMU部分进行交互，进行指令与数据的传输。MMU通过对请求的地址等信息进行解析，确定其响应路径为ibus，dbus或者uncached bus。其中L1i Cache实现为ICache，L1d Cache实现为DCache，Uncached实现为Uncached Buffer。

​		上述三条总线均为类SRAM总线，由于比赛要求封装为AXI总线，因此在分别经过ICache，DCache和Uncached Buffer之后均被转换成AXI 4 总线。



### 2. MMU 架构

//TODO

#### 缓存相关指令

见 [支持操作系统的额外指令](https://lxbchong.github.io/long_xin_bei/competition/materials/%E6%94%AF%E6%8C%81%E6%93%8D%E4%BD%9C%E7%B3%BB%E7%BB%9F%E7%9A%84%E9%A2%9D%E5%A4%96%E6%8C%87%E4%BB%A4.html)

#### CACHE

+ vAddr ← GPR[base] + sign_extend(offset) 
+ (pAddr, uncached) ← AddressTranslation(vAddr, DataReadReference) 
+ CacheOp(op, vAddr, pAddr)
+ 待实现

#### pref

+ 待定



### 3. Dcache架构

#### Meta

+ tag 26bits
+ LRU参数 2bits
+ state 3bits

#### 读

+ 接受请求，并且读取对应的 TAG和data(data需要额外一个周期)，判断是否命中（还要查询写缓冲）
+ 命中则处理，miss如果有脏数据送入写缓冲，或访存
+ 给出数据

#### 写

+ 查询TAG和写缓冲，对写缓冲完成写合并
+ 得到Bram一条cache line的data,修改完成待写入；若miss则访存，有脏数据送入写缓冲
+ 完成对标签、数据 RAM 的写入。

#### Skid Buffer

流水线和缓存的交互容易产生非常长的关键路径，例如：

![长关键路径](https://fducslg.github.io/ICS-2021Spring-FDU/asset/lab3/long-path.svg)

上图展示了一种可能的关键路径：

- 访存阶段发出请求。在发请求前需要做一点组合逻辑判断是否需要发出请求（`valid`）。
- 缓存搜索请求的地址是否在缓存中，并由此决定 `addr_ok`。
- 流水线根据 `addr_ok` 决定是否需要阻塞，产生 `stall` 信号。

`stall` 信号需要跨过多个流水线阶段，所以往往走线延时比较长。这里的问题主要出在握手信号（`valid` 和 `addr_ok`）之间有组合逻辑。Skid buffer 可以缓解这个问题。

![skid buffer 接口](https://fducslg.github.io/ICS-2021Spring-FDU/asset/lab3/skid-buffer-interface.svg)

Skid buffer 是插入在总线之间的。它的效果是切断 `valid` 和 `addr_ok` 之间的组合逻辑。实际上 skid buffer 类似于一个长度为 1 的队列。在 skid buffer 内部有一个缓冲区：

![skid buffer 缓冲区](https://fducslg.github.io/ICS-2021Spring-FDU/asset/lab3/skid-buffer-mux.svg)

- 如果缓冲区不为空，发送缓冲区内的请求。否则发送流水线的请求。
- 当流水线的请求在当前周期不能发出时，可以将其缓存。
- 当内部缓冲区被占用时，流水线一侧的 `addr_ok` 设为 0，从而阻塞流水线。
- 当缓存一侧的 `addr_ok` 为 1 时，请求完成，可以清空内部缓存区。

这里最重要的一点是，只要内部缓存区为空（`empty` 信号），skid buffer 就能将流水线一侧的 `addr_ok` 拉起，而不用关心缓存一侧的 `addr_ok` 是否为 1。`empty` 使用一个寄存器存储。这样就能把流水线一侧的 `valid` 和 `addr_ok` 之间的组合逻辑切开。同时，我们可以看到整个过程不需要额外的时钟周期。

参考实现：[RequestBuffer.sv](https://github.com/NSCSCC-2020-Fudan/FDU1.1-NSCSCC/blob/master/cache/src/util/RequestBuffer.sv)

#### Victim Buffer

另外考虑



### 4. ICache 架构

### 5. Uncached Buffer架构

### 6. 类SRAM总线与AXI 4总线转换

//TODO: 突发传输(INCR or WRAP)以及axi_wrap.v