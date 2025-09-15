/*
 * RLOS - UEFI Bootloader for ARM64
 */

#include <efi.h>
#include <efilib.h>
#include <efiprot.h>
#include "stdint.h"
#include "boot_info.h"

// EFI_PAGE_SIZE is already defined in gnu-efi library

typedef void (*kernel_entry_t)(boot_info_t* boot_info);

EFI_STATUS LoadKernelFile(EFI_HANDLE ImageHandle, void** kernel_entry, UINTN* kernel_size, kernel_load_info_t* kernel_info);
EFI_STATUS GetFinalMemoryMap(EFI_MEMORY_DESCRIPTOR** MemoryMap, UINTN* MapSize, UINTN* MapKey, UINTN* DescriptorSize);
EFI_STATUS ConvertMemoryMap(EFI_MEMORY_DESCRIPTOR* EfiMemoryMap, UINTN EfiMapSize, UINTN EfiDescSize, boot_info_t* boot_info);

void jump_to_kernel(void* entry, boot_info_t* boot_info)
{
    kernel_entry_t kernel_entry = (kernel_entry_t)entry;

    __asm__ volatile ("msr daifset, #0xf" ::: "memory");
    __asm__ volatile ("ic iallu" ::: "memory");
    __asm__ volatile ("dsb sy" ::: "memory");
    __asm__ volatile ("isb" ::: "memory");

    __asm__ volatile ("mov x0, %0; br %1" :: "r" (boot_info), "r" (kernel_entry) : "x0");

    while (1) {
        __asm__ volatile("wfi");
    }
}

EFI_STATUS efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    InitializeLib(ImageHandle, SystemTable);

    EFI_STATUS Status;

    Status = BS->SetWatchdogTimer(0, 0, 0, NULL);
    if(EFI_ERROR(Status))
    {
        Print(L"Error stopping watchdog, timeout still counting down...\r\n");
    }

    Status = ST->ConOut->ClearScreen(ST->ConOut);
    if(EFI_ERROR(Status))
    {
        Print(L"Error clearing screen...\r\n");
    }

    Print(L"==============================================\r\n");
    Print(L"Start Detecting Memory...\r\n");
    Print(L"==============================================\r\n");
    Print(L"\r\n");
    
    UINTN MemoryMapSize = 0;
    EFI_MEMORY_DESCRIPTOR *MemoryMap = NULL;
    UINTN MapKey = 0;
    UINTN DescriptorSize = 0;
    UINT32 DescriptorVersion = 0;

    Status = BS->GetMemoryMap(&MemoryMapSize, MemoryMap, &MapKey, &DescriptorSize, &DescriptorVersion);
    if (Status != EFI_BUFFER_TOO_SMALL) {
        Print(L"Unexpected error getting memory map size: %r\r\n", Status);
        return Status;
    }

    MemoryMapSize += 2 * DescriptorSize;

    Status = BS->AllocatePool(EfiLoaderData, MemoryMapSize, (void**)&MemoryMap);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate memory for memory map: %r\r\n", Status);
        return Status;
    }

    Status = BS->GetMemoryMap(&MemoryMapSize, MemoryMap, &MapKey, &DescriptorSize, &DescriptorVersion);
    if (EFI_ERROR(Status)) {
        Print(L"Error getting memory map: %r\r\n", Status);
        BS->FreePool(MemoryMap);
        return Status;
    }

    Print(L"Memory Map Size: %u\r\n", MemoryMapSize);
    Print(L"Descriptor Size: %u\r\n", DescriptorSize);

    UINTN EntryCount = MemoryMapSize / DescriptorSize;
    for(UINTN i = 0; i < EntryCount; i++){
        EFI_MEMORY_DESCRIPTOR *Desc = (EFI_MEMORY_DESCRIPTOR *)((UINT8*)MemoryMap + i * DescriptorSize);

        if (Desc->Type == EfiConventionalMemory){
            UINT64 Start = Desc->PhysicalStart;
            UINT64 End = Start + Desc->NumberOfPages * EFI_PAGE_SIZE;
            Print(L"Available Memory: %llu - %llu\r\n", Start, End);
        }
    }

    EFI_PHYSICAL_ADDRESS PageAddr = 0;
    UINTN Pages = 1;
    Status = uefi_call_wrapper(
        SystemTable->BootServices->AllocatePages,
        4,
        AllocateAnyPages,
        EfiLoaderData,
        Pages,
        &PageAddr
    );

    if(EFI_ERROR(Status)){
        Print(L"Error allocating pages...\r\n");
        return Status;
    }

    Print(L"Allocated one page at %llu\r\n", PageAddr);

    Print(L"RLOS Bootloader - Loading kernel...\r\n");

    void* kernel_entry = NULL;
    UINTN kernel_size = 0;
    kernel_load_info_t temp_kernel_info = {0}; // 临时结构
    Print(L"Loading kernel...\r\n");
    Status = LoadKernelFile(ImageHandle, &kernel_entry, &kernel_size, &temp_kernel_info);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to load kernel: %r\r\n", Status);
        return Status;
    }
    Print(L"Kernel loaded at: 0x%lx, size: %lu bytes\r\n", (UINT64)kernel_entry, kernel_size);
    Print(L"Physical base: 0x%lx, entry offset: 0x%lx\r\n", 
          temp_kernel_info.physical_base, temp_kernel_info.entry_offset);

    EFI_MEMORY_DESCRIPTOR* FinalMemoryMap = NULL;
    UINTN FinalMapSize = 0;
    UINTN FinalMapKey = 0;
    UINTN FinalDescriptorSize = 0;
    Print(L"Getting final memory map...\r\n");
    Status = GetFinalMemoryMap(&FinalMemoryMap, &FinalMapSize, &FinalMapKey, &FinalDescriptorSize);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get final memory map: %r\r\n", Status);
        return Status;
    }

    boot_info_t boot_info = {0};
    boot_info.kernel_info = temp_kernel_info; // 复制内核加载信息
    Print(L"Converting memory map for kernel...\r\n");
    Status = ConvertMemoryMap(FinalMemoryMap, FinalMapSize, FinalDescriptorSize, &boot_info);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to convert memory map: %r\r\n", Status);
        return Status;
    }

    Print(L"Exiting UEFI Boot Services...\r\n");
    Status = BS->ExitBootServices(ImageHandle, FinalMapKey);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to exit boot services: %r\r\n", Status);
        return Status;
    }

    jump_to_kernel(kernel_entry, &boot_info);

    return EFI_SUCCESS;
}

EFI_STATUS LoadKernelFile(EFI_HANDLE ImageHandle, void** kernel_entry, UINTN* kernel_size, kernel_load_info_t* kernel_info)
{
    EFI_STATUS Status;
    EFI_LOADED_IMAGE_PROTOCOL* LoadedImage = NULL;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL* FileSystem = NULL;
    EFI_FILE_PROTOCOL* RootDir = NULL;
    EFI_FILE_PROTOCOL* KernelFile = NULL;
    EFI_PHYSICAL_ADDRESS TempBuffer = 0;
    UINTN TempPages = 0;
    EFI_PHYSICAL_ADDRESS kernel_physical_base = 0;
    
    Status = BS->HandleProtocol(ImageHandle, &LoadedImageProtocol, (void**)&LoadedImage);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get LoadedImageProtocol: %r\\r\\n", Status);
        return Status;
    }
    
    Status = BS->HandleProtocol(LoadedImage->DeviceHandle, &FileSystemProtocol, (void**)&FileSystem);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get FileSystemProtocol: %r\\r\\n", Status);
        return Status;
    }
    
    Status = FileSystem->OpenVolume(FileSystem, &RootDir);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to open root directory: %r\\r\\n", Status);
        return Status;
    }
    
    Status = RootDir->Open(RootDir, &KernelFile, L"kernel.elf", EFI_FILE_MODE_READ, 0);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to open kernel.elf: %r\\r\\n", Status);
        RootDir->Close(RootDir);
        return Status;
    }
    
    EFI_FILE_INFO* FileInfo = NULL;
    UINTN FileInfoSize = sizeof(EFI_FILE_INFO) + 256;
    Status = BS->AllocatePool(EfiLoaderData, FileInfoSize, (void**)&FileInfo);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate memory for file info: %r\\r\\n", Status);
        goto cleanup;
    }
    
    Status = KernelFile->GetInfo(KernelFile, &GenericFileInfo, &FileInfoSize, FileInfo);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get kernel file info: %r\\r\\n", Status);
        goto cleanup;
    }
    
    *kernel_size = FileInfo->FileSize;
    Print(L"Kernel file size: %lu bytes\\r\\n", *kernel_size);
    
    TempPages = (*kernel_size + EFI_PAGE_SIZE - 1) / EFI_PAGE_SIZE;
    
    Status = BS->AllocatePages(AllocateAnyPages, EfiLoaderData, TempPages, &TempBuffer);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate temporary buffer for ELF: %r\\r\\n", Status);
        goto cleanup;
    }
    
    EFI_PHYSICAL_ADDRESS KernelAddress = TempBuffer;
    
    UINTN ReadSize = *kernel_size;
    Status = KernelFile->Read(KernelFile, &ReadSize, (void*)KernelAddress);
    if (EFI_ERROR(Status) || ReadSize != *kernel_size) {
        Print(L"Failed to read kernel file: %r\\r\\n", Status);
        goto cleanup;
    }
    
    typedef struct {
        UINT8  e_ident[16];
        UINT16 e_type;
        UINT16 e_machine;
        UINT32 e_version;
        UINT64 e_entry;
        UINT64 e_phoff;
        UINT64 e_shoff;
        UINT32 e_flags;
        UINT16 e_ehsize;
        UINT16 e_phentsize;
        UINT16 e_phnum;
        UINT16 e_shentsize;
        UINT16 e_shnum;
        UINT16 e_shstrndx;
    } ELF64_Ehdr;

    typedef struct {
        UINT32 p_type;
        UINT32 p_flags;
        UINT64 p_offset;
        UINT64 p_vaddr;
        UINT64 p_paddr;
        UINT64 p_filesz;
        UINT64 p_memsz;
        UINT64 p_align;
    } ELF64_Phdr;

    #define PT_LOAD 1
    
    ELF64_Ehdr* elf_header = (ELF64_Ehdr*)KernelAddress;
    
    if (elf_header->e_ident[0] != 0x7F || 
        elf_header->e_ident[1] != 'E' || 
        elf_header->e_ident[2] != 'L' || 
        elf_header->e_ident[3] != 'F') {
        Print(L"Invalid ELF magic number\r\n");
        Status = EFI_INVALID_PARAMETER;
        goto cleanup;
    }
    
    Print(L"Valid ELF file detected\r\n");
    Print(L"Entry point: 0x%lx\r\n", elf_header->e_entry);
    Print(L"Program headers: %u at offset 0x%lx\r\n", elf_header->e_phnum, elf_header->e_phoff);
    
    ELF64_Phdr* phdrs = (ELF64_Phdr*)((UINT8*)KernelAddress + elf_header->e_phoff);
    
    UINT64 kernel_min_addr = UINT64_MAX;
    UINT64 kernel_max_addr = 0;
    
    for (UINT16 i = 0; i < elf_header->e_phnum; i++) {
        if (phdrs[i].p_type == PT_LOAD) {
            UINT64 seg_start = phdrs[i].p_vaddr;
            UINT64 seg_end = seg_start + phdrs[i].p_memsz;
            
            if (seg_start < kernel_min_addr) kernel_min_addr = seg_start;
            if (seg_end > kernel_max_addr) kernel_max_addr = seg_end;
        }
    }
    
    UINT64 total_kernel_size = kernel_max_addr - kernel_min_addr;
    UINTN total_pages = (total_kernel_size + EFI_PAGE_SIZE - 1) / EFI_PAGE_SIZE;
    
    Print(L"Kernel address range: 0x%lx - 0x%lx (size: 0x%lx)\r\n", 
          kernel_min_addr, kernel_max_addr, total_kernel_size);
    
    Status = BS->AllocatePages(AllocateAnyPages, EfiLoaderCode, total_pages, &kernel_physical_base);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate kernel memory: %r\r\n", Status);
        goto cleanup;
    }
    
    Print(L"Kernel allocated at physical: 0x%lx, size: 0x%lx\r\n", kernel_physical_base, total_kernel_size);
    
    for (UINT16 i = 0; i < elf_header->e_phnum; i++) {
        if (phdrs[i].p_type == PT_LOAD) {
            Print(L"Loading segment %u: vaddr=0x%lx, filesz=0x%lx, memsz=0x%lx\r\n", 
                  i, phdrs[i].p_vaddr, phdrs[i].p_filesz, phdrs[i].p_memsz);
            
            UINT64 segment_offset = phdrs[i].p_vaddr - kernel_min_addr;
            UINT8* physical_dst = (UINT8*)(kernel_physical_base + segment_offset);
            UINT8* src = (UINT8*)KernelAddress + phdrs[i].p_offset;
            
            for (UINT64 j = 0; j < phdrs[i].p_filesz; j++) {
                physical_dst[j] = src[j];
            }
            
            for (UINT64 j = phdrs[i].p_filesz; j < phdrs[i].p_memsz; j++) {
                physical_dst[j] = 0;
            }
            
            Print(L"Segment %u loaded at physical: 0x%lx\r\n", i, (UINT64)physical_dst);
        }
    }
    
    kernel_info->physical_base = kernel_physical_base;
    kernel_info->size = total_kernel_size;
    kernel_info->entry_offset = elf_header->e_entry - kernel_min_addr;
    kernel_info->segments_count = elf_header->e_phnum;
    
    *kernel_entry = (void*)(kernel_physical_base + kernel_info->entry_offset);
    
    Print(L"Kernel loaded successfully at 0x%lx\r\n", KernelAddress);
    Status = EFI_SUCCESS;
    
cleanup:
    if (FileInfo) BS->FreePool(FileInfo);
    if (KernelFile) KernelFile->Close(KernelFile);
    if (RootDir) RootDir->Close(RootDir);
    
    if (TempBuffer) {
        BS->FreePages(TempBuffer, TempPages);
    }
    
    if (EFI_ERROR(Status) && kernel_physical_base) {
        UINTN pages_to_free = (kernel_info->size + EFI_PAGE_SIZE - 1) / EFI_PAGE_SIZE;
        BS->FreePages(kernel_physical_base, pages_to_free);
    }
    
    return Status;
}

EFI_STATUS GetFinalMemoryMap(EFI_MEMORY_DESCRIPTOR** MemoryMap, UINTN* MapSize, UINTN* MapKey, UINTN* DescriptorSize)
{
    EFI_STATUS Status;
    UINT32 DescriptorVersion;
    
    *MapSize = 0;
    *MemoryMap = NULL;
    
    Status = BS->GetMemoryMap(MapSize, *MemoryMap, MapKey, DescriptorSize, &DescriptorVersion);
    if (Status != EFI_BUFFER_TOO_SMALL) {
        return Status;
    }
    
    *MapSize += 2 * *DescriptorSize;
    
    Status = BS->AllocatePool(EfiLoaderData, *MapSize, (void**)MemoryMap);
    if (EFI_ERROR(Status)) {
        return Status;
    }
    
    Status = BS->GetMemoryMap(MapSize, *MemoryMap, MapKey, DescriptorSize, &DescriptorVersion);
    if (EFI_ERROR(Status)) {
        BS->FreePool(*MemoryMap);
        *MemoryMap = NULL;
    }
    
    return Status;
}

#define MAX_MEMORY_DESCRIPTORS 512
static memory_descriptor_t static_memory_descriptors[MAX_MEMORY_DESCRIPTORS];

EFI_STATUS ConvertMemoryMap(EFI_MEMORY_DESCRIPTOR* EfiMemoryMap, UINTN EfiMapSize, UINTN EfiDescSize, boot_info_t* boot_info)
{
    UINTN NumDescriptors;
    UINTN i;
    EFI_MEMORY_DESCRIPTOR* EfiDesc;
    memory_descriptor_t* KernelDesc;
    
    if (!EfiMemoryMap || !boot_info) {
        return EFI_INVALID_PARAMETER;
    }
    
    NumDescriptors = EfiMapSize / EfiDescSize;
    
    if (NumDescriptors > MAX_MEMORY_DESCRIPTORS) {
        return EFI_OUT_OF_RESOURCES;
    }
    
    KernelDesc = static_memory_descriptors;
    
    EfiDesc = EfiMemoryMap;
    for (i = 0; i < NumDescriptors; i++) {
        switch (EfiDesc->Type) {
            case EfiReservedMemoryType:
                KernelDesc[i].type = MEMORY_TYPE_RESERVED;
                break;
            case EfiLoaderCode:
                KernelDesc[i].type = MEMORY_TYPE_LOADER_CODE;
                break;
            case EfiLoaderData:
                KernelDesc[i].type = MEMORY_TYPE_LOADER_DATA;
                break;
            case EfiBootServicesCode:
                KernelDesc[i].type = MEMORY_TYPE_BOOT_CODE;
                break;
            case EfiBootServicesData:
                KernelDesc[i].type = MEMORY_TYPE_BOOT_DATA;
                break;
            case EfiRuntimeServicesCode:
                KernelDesc[i].type = MEMORY_TYPE_RUNTIME_CODE;
                break;
            case EfiRuntimeServicesData:
                KernelDesc[i].type = MEMORY_TYPE_RUNTIME_DATA;
                break;
            case EfiConventionalMemory:
                KernelDesc[i].type = MEMORY_TYPE_CONVENTIONAL;
                break;
            case EfiUnusableMemory:
                KernelDesc[i].type = MEMORY_TYPE_UNUSABLE;
                break;
            case EfiACPIReclaimMemory:
                KernelDesc[i].type = MEMORY_TYPE_ACPI_RECLAIM;
                break;
            case EfiACPIMemoryNVS:
                KernelDesc[i].type = MEMORY_TYPE_ACPI_NVS;
                break;
            case EfiMemoryMappedIO:
                KernelDesc[i].type = MEMORY_TYPE_MMIO;
                break;
            case EfiMemoryMappedIOPortSpace:
                KernelDesc[i].type = MEMORY_TYPE_MMIO_PORT_SPACE;
                break;
            case EfiPalCode:
                KernelDesc[i].type = MEMORY_TYPE_PAL_CODE;
                break;
            case EfiPersistentMemory:
                KernelDesc[i].type = MEMORY_TYPE_PERSISTENT;
                break;
            default:
                KernelDesc[i].type = MEMORY_TYPE_RESERVED;
                break;
        }
        
        KernelDesc[i].pad = 0;
        KernelDesc[i].physical_start = EfiDesc->PhysicalStart;
        KernelDesc[i].virtual_start = EfiDesc->VirtualStart;
        KernelDesc[i].number_of_pages = EfiDesc->NumberOfPages;
        KernelDesc[i].attribute = EfiDesc->Attribute;
        
        EfiDesc = (EFI_MEMORY_DESCRIPTOR*)((UINT8*)EfiDesc + EfiDescSize);
    }
    
    boot_info->memory_map_base = KernelDesc;
    boot_info->memory_map_size = NumDescriptors * sizeof(memory_descriptor_t);
    boot_info->memory_map_desc_size = sizeof(memory_descriptor_t);
    boot_info->memory_map_desc_count = NumDescriptors;
    
    return EFI_SUCCESS;
}