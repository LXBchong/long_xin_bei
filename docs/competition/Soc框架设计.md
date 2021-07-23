## Soc框架设计

> 2021/7/24
>
> 此文档是我们小组的Soc设计架构介绍



### 1. 初赛Soc架构

​		由于在初赛中并不要求对于外设等设备的接入，因此初赛Soc设计侧重于对于FPGA上的资源应用，架构如下图。

![Soc_arch](资料图片/Soc_arch.png)

#### 1.1 CPU Top设计

​		初赛部分的重点为CPU Top部分的设计。Core Top部分为设计的CPU主体部分，我们的架构为顺序双发射CPU，具体报告见CPU设计文档。

​		CPU在Core Top层面通过四个信号与MMU部分进行交互，进行指令与数据的传输。MMU通过对请求的地址等信息进行解析，确定其响应路径为ibus，dbus或者uncached bus。其中L1i Cache实现为ICache，L1d Cache实现为DCache，Uncached实现为Uncached Buffer。具体报告见Cache设计文档。

​		上述三条响应总线路径均为自定义类SRAM总线，在经过ICacheDCache，Uncached Buffer后转化成符合AXI 4标准的总线，并从Xilinx Vivado提供的IP核AXI Crossbar的Slave端输入，在Master端输出为符合AXI4标准的总线。另外AXI Crossbar提供仲裁功能，三条Slave总线的优先级顺序为uncached bus > dbus > ibus.

​		上述几个部分被封装为CPU Top层面，通过AXI 4总线与其他FPGA资源交互。

#### 1.2 Memory IPs解释

​		初赛部分提供的测试框架中包含了Memory IPs中展示的所有IP及模块，具体介绍详见发布包文档A11_Trace比对机制使用说明_v1.00.pdf。



### 2. 决赛Soc架构

​		在本部分的设计侧重点主要集中在系统启动和外设接入方面，旨在充分利用开发板上所有资源，架构如下图。

