#ifndef RLOS_BOOT_INFO_H
#define RLOS_BOOT_INFO_H

#include "stdint.h"

typedef enum {
    MEMORY_TYPE_RESERVED         = 0,
    MEMORY_TYPE_LOADER_CODE      = 1,
    MEMORY_TYPE_LOADER_DATA      = 2,
    MEMORY_TYPE_BOOT_CODE        = 3,
    MEMORY_TYPE_BOOT_DATA        = 4,
    MEMORY_TYPE_RUNTIME_CODE     = 5,
    MEMORY_TYPE_RUNTIME_DATA     = 6,
    MEMORY_TYPE_CONVENTIONAL     = 7,
    MEMORY_TYPE_UNUSABLE         = 8,
    MEMORY_TYPE_ACPI_RECLAIM     = 9,
    MEMORY_TYPE_ACPI_NVS         = 10,
    MEMORY_TYPE_MMIO             = 11,
    MEMORY_TYPE_MMIO_PORT_SPACE  = 12,
    MEMORY_TYPE_PAL_CODE         = 13,
    MEMORY_TYPE_PERSISTENT       = 14,
    MEMORY_TYPE_MAX              = 15
} memory_type_t;

#define MEMORY_ATTR_UC           0x0000000000000001
#define MEMORY_ATTR_WC           0x0000000000000002
#define MEMORY_ATTR_WT           0x0000000000000004
#define MEMORY_ATTR_WB           0x0000000000000008
#define MEMORY_ATTR_UCE          0x0000000000000010
#define MEMORY_ATTR_WP           0x0000000000001000
#define MEMORY_ATTR_RP           0x0000000000002000
#define MEMORY_ATTR_XP           0x0000000000004000
#define MEMORY_ATTR_NV           0x0000000000008000
#define MEMORY_ATTR_MORE_RELIABLE 0x0000000000010000
#define MEMORY_ATTR_RO           0x0000000000020000
#define MEMORY_ATTR_SP           0x0000000000040000
#define MEMORY_ATTR_CPU_CRYPTO   0x0000000000080000
#define MEMORY_ATTR_RUNTIME      0x8000000000000000

typedef struct {
    uint32_t type;
    uint32_t pad;
    uint64_t physical_start;
    uint64_t virtual_start;
    uint64_t number_of_pages;
    uint64_t attribute;
} memory_descriptor_t;

typedef struct {
    memory_descriptor_t *memory_map_base;
    uintn_t memory_map_size;
    uintn_t memory_map_desc_size;
    uintn_t memory_map_desc_count;
} boot_info_t;

#endif /* RLOS_BOOT_INFO_H */
