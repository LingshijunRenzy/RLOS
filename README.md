# RLOS

A simple x86_64 hobby OS (UEFI + GRUB(multiboot2) bootstrap) by Lingshi & Rjay9

## 功能阶段 (当前)

- 使用 GRUB (multiboot2) 引导 x86_64 内核
- VGA 文本模式输出: `Hello, Kernel!`
- 生成可启动 ISO: `RLOS.iso`
- 提供 QEMU 运行与 GDB 调试目标

## 目录结构

```text
linker.ld                # 内核链接脚本
Makefile                 # 构建脚本
src/boot/multiboot2_header.S
src/kernel/kernel.c      # 内核入口与输出
iso_root/boot/grub/grub.cfg
RLOS.iso (构建后生成)
```

## 先决条件 (macOS)

已安装交叉工具链:

- x86_64-elf-binutils
- x86_64-elf-gcc
- x86_64-elf-grub
- x86_64-elf-gdb (调试用)

另外需要:

- xorriso
- mtools
- qemu-system-x86_64

如缺失可通过 Homebrew 安装 (示例):

```bash
brew install xorriso mtools qemu
```

## 构建

```bash
make
```

生成 `RLOS.iso`。

## 运行

```bash
make run
```

在 QEMU 窗口/serial stdio 中看到输出: `Hello, Kernel!`

### 运行模式说明

Makefile 会自动探测 OVMF (UEFI 固件)。

- 若找到 `OVMF_CODE.fd` : `make run` 使用 UEFI (`-bios OVMF_CODE.fd`)
- 否则回退到 BIOS (SeaBIOS) 模式

手动指定：

```bash
make run-bios   # 强制 BIOS
make run-uefi   # 强制 UEFI (需已安装 OVMF)
```

安装 OVMF (macOS/Homebrew)：

```bash
brew install edk2-ovmf
```

## 调试 (GDB)

1. 启动暂停等待 gdb:

   ```bash
   make debug
   ```

2. 新终端运行 (示例):

   ```bash
   x86_64-elf-gdb build/kernel.elf \
     -ex 'target remote localhost:1234' \
     -ex 'set disassemble-next-line on'
   ```

## 清理

```bash
make clean     # 清理对象文件与内核
make distclean # 额外删除 RLOS.iso
```

## 后续计划 (非当前实现)

- 内存地图解析 & 物理内存管理
- 中断 & IDT / IRQ & 定时器
- GDT / TSS / 上下文切换
- 分页与 内核虚拟内存
- 串口输出 / 日志子系统
- ACPI / SMP 启动
