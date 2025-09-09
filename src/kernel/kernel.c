//==================================================================================================================================
//  RLOS: Simple ARM64 UEFI Kernel
//==================================================================================================================================
//
// A simple "Hello, Kernel!" program that runs as a UEFI application on ARM64.
// Based on the Simple UEFI Bootloader project structure.
//

#include <efi.h>
#include <efilib.h>
#include "kernel.h"

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

    // Print our hello message
    Print(L"\r\n");
    Print(L"==============================================\r\n");
    Print(L"  ____  _     ___  ____                       \r\n");
    Print(L" |  _ \\| |   / _ \\/ ___|                    \r\n");
    Print(L" | |_) | |  | | | \\___ \\                    \r\n");
    Print(L" |  _ <| |__| |_| |___) |                     \r\n");
    Print(L" |_| \\_\\_____\\___/|____/                   \r\n");
    Print(L"                                              \r\n");
    Print(L"==============================================\r\n");
    Print(L"\r\n");

    // Print system information
    Print(L"System Information:\r\n");
    Print(L"  UEFI Revision: %u.%u", ST->Hdr.Revision >> 16, (ST->Hdr.Revision & 0xFFFF) / 10);
    if((ST->Hdr.Revision & 0xFFFF) % 10)
    {
        Print(L".%u\r\n", (ST->Hdr.Revision & 0xFFFF) % 10);
    }
    else
    {
        Print(L"\r\n");
    }
    Print(L"  Firmware Vendor: %s\r\n", ST->FirmwareVendor);
    Print(L"  Firmware Revision: 0x%08x\r\n", ST->FirmwareRevision);

    // Get current time
    EFI_TIME Now;
    Status = RT->GetTime(&Now, NULL);
    if(!EFI_ERROR(Status))
    {
        Print(L"  Current Time: %02hhu/%02hhu/%04hu - %02hhu:%02hhu:%02hhu\r\n", 
              Now.Month, Now.Day, Now.Year, Now.Hour, Now.Minute, Now.Second);
    }

    Print(L"\r\n");
    Print(L"Kernel initialization completed successfully!\r\n");
    Print(L"RLOS is now running...\r\n");
    Print(L"\r\n");
    Print(L"System Status: ACTIVE\r\n");
    Print(L"Kernel Mode: Running\r\n");
    Print(L"Boot Services: Available\r\n");
    Print(L"\r\n");
    Print(L"=== RLOS Kernel Main Loop Started ===\r\n");
    Print(L"(Press Ctrl+C or close QEMU to exit)\r\n");
    Print(L"\r\n");

    while(1)
    {   
        
        // In a real kernel, this is where we would:
        // - Handle interrupts
        // - Process scheduler
        // - Memory management
        // - I/O operations
        // - System calls
    }

    // This line should never be reached in normal operation
    return EFI_SUCCESS;
}