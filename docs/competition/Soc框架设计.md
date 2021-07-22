## 总体架构

> 2021/7/22
>
> 此文档是我们小组的处理器实际采用的架构



### 总线接口

> [参考网址](https://github.com/NSCSCC-2020-Fudan/FDU1.1-NSCSCC/tree/master/cache)

#### 指令数据传输

- ICache传来的指令组要8字节对齐，也就是包含两条指令
- 接收到指令时，需要根据PC值来判断第一条指令是否有效，如果PC值只是4字节对齐而没有8字节对齐（如`bfc00004`），那么此时指令组第一条指令应该判定为无效
- 当分支指令为8字节指令组的前四个字节的话（一条指令4个字节），此时延迟槽正好为后四个字节，不会出现问题，所以该指令组的分支预测正常进行
- 当分支指令为指令组后四个字节的话，需要在下个周期把延迟槽取出来，也就是说该分支指令没有预测的必要，始终是顺序取，等到后面的延迟槽来了才应该真正开始分支预测
- 综上，我们发现，分支预测应该是在延迟槽取来的那个周期进行，而不是分支指令本身！！！
- 但是延迟槽本身没有跳转的地址这样的信息，需要上个周期的分支指令的信息，因此需要在decode阶段放置一个branch buffer来存储上个周期的分支指令的信息，在当前周期处理延迟槽的同时利用这个信息进行分支预测的正确性判断



#### AXI接口（参考）

1. 2019 年龙芯杯清华队伍：[“NSCSCC 2019 Final Report”](https://fducslg.github.io/ICS-2021Spring-FDU/misc/external.html#其它)
2. 第四届“龙芯杯” 复旦大学FDU1.1队参赛作品  [CacheBusToAXI.sv](https://github.com/NSCSCC-2020-Fudan/FDU1.1-NSCSCC/blob/master/cache/src/util/CacheBusToAXI.sv)

<br>

### MMU架构

#### 缓存相关指令

见 [支持操作系统的额外指令](https://lxbchong.github.io/long_xin_bei/competition/materials/%E6%94%AF%E6%8C%81%E6%93%8D%E4%BD%9C%E7%B3%BB%E7%BB%9F%E7%9A%84%E9%A2%9D%E5%A4%96%E6%8C%87%E4%BB%A4.html)

#### CACHE

+ vAddr ← GPR[base] + sign_extend(offset) 
+ (pAddr, uncached) ← AddressTranslation(vAddr, DataReadReference) 
+ CacheOp(op, vAddr, pAddr)
+ 待实现

#### pref

+ 待定

<br>

### 权衡与选择

1. 在哪个阶段读取寄存器的数据，需要额外的一个阶段吗？目前是增加了一个读操作数的周期专门用来读寄存器

2. 取指时分支指令与延迟槽怎么处理？（1）ICache给的指令组中分支和延迟槽绑定，问题：分支和延迟槽不在同一个cache line而且延迟槽cache miss（2）译码阶段若发现没有取到分支指令后的延迟槽，需要把分支的信息放在一个缓存中，等到下一周期取来了延迟槽再进行分支预测及其错误判断（3）折中的一个方法：当分支和延迟槽在同一个cache line时确保他们绑定，否则采取（2）中的方法。

3. 发射阶段若发射指令组第二条分支指令是否可以发射的优劣？

   