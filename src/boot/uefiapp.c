//==================================================================================================================================
//  RLOS: Simple ARM64 UEFI Kernel
//==================================================================================================================================
//
// A simple "Hello, Kernel!" program that runs as a UEFI application on ARM64.
// Based on the Simple UEFI Bootloader project structure.
//

#include <efi.h>
#include <efilib.h>
#include <efiprot.h>
#include "stdint.h"

// EFI_PAGE_SIZE is already defined in gnu-efi library

typedef void (*kernel_entry_t)(void* fdt);

// Kernel loading functions
EFI_STATUS LoadKernelFile(EFI_HANDLE ImageHandle, void** kernel_entry, UINTN* kernel_size);
EFI_STATUS GetFinalMemoryMap(EFI_MEMORY_DESCRIPTOR** MemoryMap, UINTN* MapSize, UINTN* MapKey, UINTN* DescriptorSize);

void jump_to_kernel(void* entry, void* fdt)
{
    kernel_entry_t kernel_entry = (kernel_entry_t)entry;

    // Disable interrupts
    __asm__ volatile ("msr daifset, #0xf" ::: "memory");
    
    // Clean and invalidate caches
    __asm__ volatile ("ic iallu" ::: "memory");  // Invalidate instruction cache
    __asm__ volatile ("dsb sy" ::: "memory");    // Data synchronization barrier
    __asm__ volatile ("isb" ::: "memory");       // Instruction synchronization barrier

    // Jump to kernel with FDT in x0
    __asm__ volatile ("mov x0, %0; br %1" :: "r" (fdt), "r" (kernel_entry) : "x0");

    // Should never reach here
    while (1) {
        __asm__ volatile("wfi");
    }
}

//==================================================================================================================================
//  efi_main: UEFI Application Entry Point
//==================================================================================================================================
//
// This is the standard UEFI application entry point. UEFI firmware will call this function
// when our application is loaded.
//

EFI_STATUS efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    // ImageHandle is this program's own EFI_HANDLE
    // SystemTable is the EFI system table of the machine

    // Initialize the GNU-EFI library
    InitializeLib(ImageHandle, SystemTable);
    /*
    From InitializeLib:
    ST = SystemTable;
    BS = SystemTable->BootServices;
    RT = SystemTable->RuntimeServices;
    */

    EFI_STATUS Status;

    // Disable watchdog timer to prevent automatic reboot during debugging
    Status = BS->SetWatchdogTimer(0, 0, 0, NULL);
    if(EFI_ERROR(Status))
    {
        Print(L"Error stopping watchdog, timeout still counting down...\r\n");
    }

    // Clear the screen
    Status = ST->ConOut->ClearScreen(ST->ConOut);
    if(EFI_ERROR(Status))
    {
        Print(L"Error clearing screen...\r\n");
    }

    // Get memory map
    Print(L"==============================================\r\n");
    Print(L"Start Detecting Memory...\r\n");
    Print(L"==============================================\r\n");
    Print(L"\r\n");
    
    UINTN MemoryMapSize = 0;
    EFI_MEMORY_DESCRIPTOR *MemoryMap = NULL;
    UINTN MapKey = 0;
    UINTN DescriptorSize = 0;
    UINT32 DescriptorVersion = 0;

    // First call to get required size
    Status = BS->GetMemoryMap(&MemoryMapSize, MemoryMap, &MapKey, &DescriptorSize, &DescriptorVersion);
    if (Status != EFI_BUFFER_TOO_SMALL) {
        Print(L"Unexpected error getting memory map size: %r\r\n", Status);
        return Status;
    }

    // Add extra space for potential changes during allocation
    MemoryMapSize += 2 * DescriptorSize;

    // Allocate memory for the map
    Status = BS->AllocatePool(EfiLoaderData, MemoryMapSize, (void**)&MemoryMap);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate memory for memory map: %r\r\n", Status);
        return Status;
    }

    // Get the actual memory map
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

    // Allocate pages
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


    // Bootloader initialization complete - kernel will handle output
    Print(L"RLOS Bootloader - Loading kernel...\r\n");

    // Load kernel from file system
    void* kernel_entry = NULL;
    UINTN kernel_size = 0;
    Print(L"Loading kernel...\r\n");
    Status = LoadKernelFile(ImageHandle, &kernel_entry, &kernel_size);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to load kernel: %r\r\n", Status);
        return Status;
    }
    Print(L"Kernel loaded at: 0x%lx, size: %lu bytes\r\n", (UINT64)kernel_entry, kernel_size);

    // Get final memory map before exiting boot services
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

    // Exit boot services - point of no return!
    Print(L"Exiting UEFI Boot Services...\r\n");
    Status = BS->ExitBootServices(ImageHandle, FinalMapKey);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to exit boot services: %r\r\n", Status);
        return Status;
    }

    // Jump to kernel - pass memory map as device tree substitute
    jump_to_kernel(kernel_entry, FinalMemoryMap);

    // Should never reach here
    return EFI_SUCCESS;
}

//==================================================================================================================================
//  Kernel Loading Implementation
//==================================================================================================================================

EFI_STATUS LoadKernelFile(EFI_HANDLE ImageHandle, void** kernel_entry, UINTN* kernel_size)
{
    EFI_STATUS Status;
    EFI_LOADED_IMAGE_PROTOCOL* LoadedImage = NULL;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL* FileSystem = NULL;
    EFI_FILE_PROTOCOL* RootDir = NULL;
    EFI_FILE_PROTOCOL* KernelFile = NULL;
    EFI_PHYSICAL_ADDRESS TempBuffer = 0;
    UINTN TempPages = 0;
    
    // Get loaded image protocol to access the device we booted from
    Status = BS->HandleProtocol(ImageHandle, &LoadedImageProtocol, (void**)&LoadedImage);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get LoadedImageProtocol: %r\\r\\n", Status);
        return Status;
    }
    
    // Get file system protocol from the same device
    Status = BS->HandleProtocol(LoadedImage->DeviceHandle, &FileSystemProtocol, (void**)&FileSystem);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get FileSystemProtocol: %r\\r\\n", Status);
        return Status;
    }
    
    // Open root directory
    Status = FileSystem->OpenVolume(FileSystem, &RootDir);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to open root directory: %r\\r\\n", Status);
        return Status;
    }
    
    // Open kernel.elf file
    Status = RootDir->Open(RootDir, &KernelFile, L"kernel.elf", EFI_FILE_MODE_READ, 0);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to open kernel.elf: %r\\r\\n", Status);
        RootDir->Close(RootDir);
        return Status;
    }
    
    // Get file size
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
    
    // Allocate a temporary buffer to read the ELF file
    TempPages = (*kernel_size + EFI_PAGE_SIZE - 1) / EFI_PAGE_SIZE;
    
    Status = BS->AllocatePages(AllocateAnyPages, EfiLoaderData, TempPages, &TempBuffer);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate temporary buffer for ELF: %r\\r\\n", Status);
        goto cleanup;
    }
    
    EFI_PHYSICAL_ADDRESS KernelAddress = TempBuffer;
    
    // Read kernel file into memory
    UINTN ReadSize = *kernel_size;
    Status = KernelFile->Read(KernelFile, &ReadSize, (void*)KernelAddress);
    if (EFI_ERROR(Status) || ReadSize != *kernel_size) {
        Print(L"Failed to read kernel file: %r\\r\\n", Status);
        goto cleanup;
    }
    
    // Complete ELF64 header structure
    typedef struct {
        UINT8  e_ident[16];     // ELF identification
        UINT16 e_type;          // Object file type
        UINT16 e_machine;       // Architecture
        UINT32 e_version;       // Object file version
        UINT64 e_entry;         // Entry point virtual address
        UINT64 e_phoff;         // Program header table offset
        UINT64 e_shoff;         // Section header table offset
        UINT32 e_flags;         // Processor-specific flags
        UINT16 e_ehsize;        // ELF header size
        UINT16 e_phentsize;     // Program header entry size
        UINT16 e_phnum;         // Number of program header entries
        UINT16 e_shentsize;     // Section header entry size
        UINT16 e_shnum;         // Number of section header entries
        UINT16 e_shstrndx;      // Section header string table index
    } ELF64_Ehdr;

    // ELF64 Program header
    typedef struct {
        UINT32 p_type;          // Segment type
        UINT32 p_flags;         // Segment flags
        UINT64 p_offset;        // Segment file offset
        UINT64 p_vaddr;         // Segment virtual address
        UINT64 p_paddr;         // Segment physical address
        UINT64 p_filesz;        // Segment size in file
        UINT64 p_memsz;         // Segment size in memory
        UINT64 p_align;         // Segment alignment
    } ELF64_Phdr;

    // ELF constants
    #define PT_LOAD 1
    
    // Parse ELF header
    ELF64_Ehdr* elf_header = (ELF64_Ehdr*)KernelAddress;
    
    // Validate ELF magic number
    if (elf_header->e_ident[0] != 0x7F || 
        elf_header->e_ident[1] != 'E' || 
        elf_header->e_ident[2] != 'L' || 
        elf_header->e_ident[3] != 'F') {
        Print(L"Invalid ELF magic number\\r\\n");
        Status = EFI_INVALID_PARAMETER;
        goto cleanup;
    }
    
    Print(L"Valid ELF file detected\\r\\n");
    Print(L"Entry point: 0x%lx\\r\\n", elf_header->e_entry);
    Print(L"Program headers: %u at offset 0x%lx\\r\\n", elf_header->e_phnum, elf_header->e_phoff);
    
    // Process program headers to load segments
    ELF64_Phdr* phdrs = (ELF64_Phdr*)((UINT8*)KernelAddress + elf_header->e_phoff);
    
    for (UINT16 i = 0; i < elf_header->e_phnum; i++) {
        if (phdrs[i].p_type == PT_LOAD) {
            Print(L"Loading segment %u: vaddr=0x%lx, filesz=0x%lx, memsz=0x%lx\\r\\n", 
                  i, phdrs[i].p_vaddr, phdrs[i].p_filesz, phdrs[i].p_memsz);
            
            // Allocate memory for this segment at its virtual address
            EFI_PHYSICAL_ADDRESS SegmentAddr = phdrs[i].p_vaddr;
            UINTN SegmentPages = (phdrs[i].p_memsz + EFI_PAGE_SIZE - 1) / EFI_PAGE_SIZE;
            
            Status = BS->AllocatePages(AllocateAddress, EfiLoaderCode, SegmentPages, &SegmentAddr);
            if (EFI_ERROR(Status)) {
                Print(L"Failed to allocate memory for segment at 0x%lx: %r\\r\\n", phdrs[i].p_vaddr, Status);
                goto cleanup;
            }
            
            // Copy segment data from ELF file to virtual address
            UINT8* src = (UINT8*)KernelAddress + phdrs[i].p_offset;
            UINT8* dst = (UINT8*)phdrs[i].p_vaddr;
            
            // Copy file data
            for (UINT64 j = 0; j < phdrs[i].p_filesz; j++) {
                dst[j] = src[j];
            }
            
            // Zero out remaining memory if memsz > filesz (for .bss section)
            for (UINT64 j = phdrs[i].p_filesz; j < phdrs[i].p_memsz; j++) {
                dst[j] = 0;
            }
            
            Print(L"Segment %u loaded at 0x%lx\\r\\n", i, phdrs[i].p_vaddr);
        }
    }
    
    *kernel_entry = (void*)elf_header->e_entry;
    
    Print(L"Kernel loaded successfully at 0x%lx\\r\\n", KernelAddress);
    Status = EFI_SUCCESS;
    
cleanup:
    if (FileInfo) BS->FreePool(FileInfo);
    if (KernelFile) KernelFile->Close(KernelFile);
    if (RootDir) RootDir->Close(RootDir);
    
    // Free temporary buffer after loading (keep loaded segments)
    if (TempBuffer) {
        BS->FreePages(TempBuffer, TempPages);
    }
    
    return Status;
}

EFI_STATUS GetFinalMemoryMap(EFI_MEMORY_DESCRIPTOR** MemoryMap, UINTN* MapSize, UINTN* MapKey, UINTN* DescriptorSize)
{
    EFI_STATUS Status;
    UINT32 DescriptorVersion;
    
    *MapSize = 0;
    *MemoryMap = NULL;
    
    // First call to get required size
    Status = BS->GetMemoryMap(MapSize, *MemoryMap, MapKey, DescriptorSize, &DescriptorVersion);
    if (Status != EFI_BUFFER_TOO_SMALL) {
        return Status;
    }
    
    // Add extra space for potential changes
    *MapSize += 2 * *DescriptorSize;
    
    // Allocate memory for map
    Status = BS->AllocatePool(EfiLoaderData, *MapSize, (void**)MemoryMap);
    if (EFI_ERROR(Status)) {
        return Status;
    }
    
    // Get the actual memory map
    Status = BS->GetMemoryMap(MapSize, *MemoryMap, MapKey, DescriptorSize, &DescriptorVersion);
    if (EFI_ERROR(Status)) {
        BS->FreePool(*MemoryMap);
        *MemoryMap = NULL;
    }
    
    return Status;
}