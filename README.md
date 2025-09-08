# RLOS - ARM64 UEFI Kernel

一个简单的ARM64 UEFI内核项目，演示如何在UEFI环境下运行"Hello, Kernel!"程序。

## 项目重构说明

这个项目已经从原始的"直接内核"方法完全重构为标准的UEFI应用程序。主要变化：

### ✅ 已完成的重构

1. **使用GNU-EFI库** - 集成了完整的GNU-EFI 3.0.9库
2. **标准UEFI入口点** - 使用`efi_main()`而不是`kernel_main()`
3. **PE/COFF格式** - 生成正确的`.EFI`可执行文件
4. **完整的UEFI服务** - 可以使用所有UEFI Boot Services和Runtime Services
5. **正确的构建系统** - 使用专门的链接脚本和构建流程

### 🏗️ 项目结构

```
RLOS/
├── src/kernel/kernel.c          # UEFI应用程序主代码
├── gnu-efi-3.0.9/             # GNU-EFI库（完整副本）
├── build/                      # 构建输出目录
├── esp/                        # EFI系统分区模拟目录
├── Makefile                    # 主构建文件
├── test.sh                     # 测试运行脚本
└── README.md                   # 项目文档
```

## 构建要求

### 系统依赖

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install gcc-aarch64-linux-gnu
sudo apt install qemu-system-aarch64
sudo apt install qemu-efi-aarch64
```

### 构建命令

```bash
# 清理构建
make clean

# 构建UEFI应用程序
make all

# 构建并运行（后台模式）
make run
```

## 测试运行

### 方法1：使用测试脚本（推荐）

```bash
./test.sh
```

这个脚本会：
- 清理和构建项目
- 验证生成的EFI文件
- 设置EFI系统分区
- 提供多种运行选项

### 方法2：手动运行

```bash
# 构建项目
make all

# 设置ESP目录
mkdir -p esp/EFI/BOOT
cp build/RLOS.efi esp/EFI/BOOT/BOOTAA64.EFI

# 运行QEMU
qemu-system-aarch64 \
    -machine virt,gic-version=3 \
    -cpu cortex-a57 \
    -m 512 \
    -drive if=pflash,format=raw,file=/usr/share/AAVMF/AAVMF_CODE.fd,readonly=on \
    -drive if=pflash,format=raw,file=./AAVMF_VARS_copy.fd \
    -drive file=fat:rw:esp,format=raw \
    -nographic
```

## 功能特性

当前的UEFI应用程序包含：

- ✅ 标准UEFI应用程序入口点
- ✅ UEFI服务初始化
- ✅ 屏幕清理和文本输出
- ✅ 系统信息显示（UEFI版本、固件信息、时间）
- ✅ 用户交互（按键等待）
- ✅ 优雅的程序退出

### 程序输出示例

```
==============================================
         RLOS - ARM64 UEFI Kernel            
==============================================

Hello, Kernel!

System Information:
  UEFI Revision: 2.7
  Firmware Vendor: EDK II
  Firmware Revision: 0x00010000
  Current Time: 09/08/2024 - 13:50:25

Kernel is running successfully!
This demonstrates that UEFI boot services are working.

Press any key to continue, or wait 10 seconds for automatic shutdown...
Shutdown in 10 seconds...
```

## 技术细节

### UEFI vs 直接内核启动

**之前的问题：**
- 使用直接内核启动（`-kernel kernel.elf`）
- 生成普通ELF文件而不是PE/COFF格式
- 缺少UEFI服务和初始化

**现在的解决方案：**
- 完整的UEFI应用程序架构
- PE/COFF格式的EFI可执行文件
- 通过UEFI固件正确引导
- 完整的UEFI服务支持

### 构建流程

1. **编译** - 使用GNU-EFI头文件编译C代码
2. **链接** - 使用专门的EFI链接脚本和启动代码
3. **转换** - 将ELF格式转换为PE/COFF EFI格式
4. **部署** - 复制到EFI系统分区的标准位置

### 文件格式验证

```bash
$ file build/RLOS.efi
build/RLOS.efi: PE Unknown PE signature 0x742e Aarch64 (stripped to external PDB), for MS Windows
```

这是正确的PE/COFF格式，ARM64架构的UEFI应用程序。

## 下一步开发

这个项目现在提供了一个完整的UEFI开发基础。可以在此基础上：

1. **添加更多UEFI服务** - 文件系统、网络、图形等
2. **实现内存管理** - 退出Boot Services后的内存管理
3. **硬件初始化** - 直接硬件访问和驱动开发
4. **操作系统功能** - 任务调度、中断处理等

## 故障排除

### 常见问题

1. **找不到交叉编译器**
   ```bash
   sudo apt install gcc-aarch64-linux-gnu
   ```

2. **找不到UEFI固件**
   ```bash
   sudo apt install qemu-efi-aarch64
   ```

3. **QEMU启动但看不到输出**
   - 使用`-nographic`确保输出到终端
   - 或使用VNC模式：`-vnc :1`然后连接`localhost:5901`

4. **权限问题**
   ```bash
   chmod +x test.sh
   ```

## 许可证

本项目使用与GNU-EFI相同的许可证条款。详见GNU-EFI库的相关文档。