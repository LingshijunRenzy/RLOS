# RLOS - ARM64 Separated Bootloader + Kernel System

**RLOS** stands for **Rjay9 & Lingshi's Operating System** - A complete ARM64 operating system implementation featuring a separated UEFI bootloader and bare-metal kernel architecture.

## 项目架构

RLOS 采用现代化的分离架构设计：

### 🏗️ 系统组件

- **UEFI Bootloader** (`src/boot/uefiapp.c`) - 负责系统初始化、内存管理、ELF加载和内核跳转
- **Bare Metal Kernel** (`src/kernel/kernel.c`) - 独立的裸机内核，包含UART驱动和系统服务
- **GNU-EFI Library** (`gnu-efi-3.0.9/`) - 完整的UEFI开发库
- **Separated Build System** - 独立构建bootloader.efi和kernel.elf

### 📁 项目结构

```
RLOS/
├── src/
│   ├── boot/uefiapp.c          # UEFI Bootloader
│   ├── kernel/kernel.c         # Bare Metal Kernel  
│   └── include/                # 共享头文件
├── gnu-efi-3.0.9/             # GNU-EFI库
├── build/                      # 构建输出
├── esp/                        # EFI系统分区
├── Makefile                    # 分离构建系统
├── run.sh                      # 运行脚本
└── README.md                   # 项目文档
```

## 构建要求

### 系统依赖

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install build-essential cmake ninja-build gdb gdb-multiarch qemu-system-arm qemu-efi-aarch64
```

### ARM64 交叉编译工具链

需要手动下载 `aarch64-linux-gnu-` 工具链：

**下载地址**: https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads

选择适合您系统的版本：
- **Linux x86_64**: `arm-gnu-toolchain-*-x86_64-aarch64-none-linux-gnu.tar.xz`
- **Linux AArch64**: `arm-gnu-toolchain-*-aarch64-aarch64-none-linux-gnu.tar.xz`

安装步骤：
```bash
# 下载并解压工具链
tar -xJf arm-gnu-toolchain-*-x86_64-aarch64-none-linux-gnu.tar.xz -C /opt/
# 添加到PATH（建议添加到 ~/.bashrc）
export PATH="/opt/arm-gnu-toolchain-*/bin:$PATH"
```

### 构建命令

使用提供的运行脚本（推荐）：

```bash
# 显示帮助信息
./run.sh help

# 构建项目
./run.sh build

# 构建并运行（VNC模式）
./run.sh run

# 构建并运行（控制台模式）
./run.sh console

# 快速测试（30秒超时）
./run.sh test
```

或使用Makefile：

```bash
# 构建bootloader
make bootloader

# 构建kernel
make kernel

# 构建所有组件
make all

# 清理构建文件
make clean
```

## 技术细节

RLOS 采用完全分离的双阶段引导架构：

### 🚀 引导流程

1. **UEFI固件启动** - 系统启动，UEFI固件初始化
2. **Bootloader加载** - UEFI加载 `bootloader.efi`
3. **系统初始化** - Bootloader执行内存映射、文件系统访问
4. **内核加载** - 从ESP读取并解析 `kernel.elf`
5. **ELF段加载** - 正确加载内核代码段到指定内存地址
6. **退出UEFI服务** - 调用 `ExitBootServices()` 
7. **内核跳转** - 跳转到内核入口点 `_start()`
8. **裸机内核** - 内核接管系统，初始化UART并运行主循环

### 💾 内存布局

- **Bootloader**: 由UEFI在任意地址加载
- **Kernel**: 固定加载到 `0x40080000` 
- **Entry Point**: `0x40080400` (`_start` 函数)
- **UART Base**: `0x09000000` (QEMU virt机器)

### 🔧 构建系统特性

- **分离编译**: bootloader和kernel使用不同的编译标志
- **ELF解析**: bootloader包含完整的ELF64加载器
- **缓存管理**: 正确的指令缓存失效和内存屏障
- **错误处理**: 完整的错误检查和调试输出