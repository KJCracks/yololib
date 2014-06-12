/* 
 yololib
 Inject dylibs into existing Mach-O binaries


 DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
 Version 2, December 2004
 
 Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
 
 Everyone is permitted to copy and distribute verbatim or modified
 copies of this license document, and changing it is allowed as long
 as the name is changed.
 
 DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
 TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 
 0. You just DO WHAT THE FUCK YOU WANT TO.
 
*/

#include <stdio.h>
#include <string.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#import <Foundation/Foundation.h>

NSString* DYLIB_PATH;

//#define DYLIB_PATH "@executable_path/crack.dylib"
#define DYLIB_CURRENT_VER 0x10000
#define DYLIB_COMPATIBILITY_VERSION 0x10000


#define swap32(value) (((value & 0xFF000000) >> 24) | ((value & 0x00FF0000) >> 8) | ((value & 0x0000FF00) << 8) | ((value & 0x000000FF) << 24) )
#define ARMV7 9
#define ARMV6 6

void inject_dylib(FILE* newFile, uint32_t top) {
    fseek(newFile, top, SEEK_SET);
    struct mach_header mach;
    
    fread(&mach, sizeof(struct mach_header), 1, newFile);
    
    NSData* data = [DYLIB_PATH dataUsingEncoding:NSUTF8StringEncoding];
    
    uint32_t dylib_size = (uint32_t)[data length] + sizeof(struct dylib_command);
    dylib_size += sizeof(long) - (dylib_size % sizeof(long)); // load commands like to be aligned by long
    
    mach.ncmds += 1;
    uint32_t sizeofcmds = mach.sizeofcmds;
    mach.sizeofcmds += dylib_size;
    
    fseek(newFile, -sizeof(struct mach_header), SEEK_CUR);
    fwrite(&mach, sizeof(struct mach_header), 1, newFile);
    printf("Patching mach_header..\n");
    
    fseek(newFile, sizeofcmds, SEEK_CUR);
    
    struct dylib_command dyld;
    fread(&dyld, sizeof(struct dylib_command), 1, newFile);
    
    printf("Attaching dylib..\n\n");
    
    dyld.cmd = LC_LOAD_DYLIB;
    dyld.cmdsize = dylib_size;
    dyld.dylib.compatibility_version = DYLIB_COMPATIBILITY_VERSION;
    dyld.dylib.current_version = DYLIB_CURRENT_VER;
    dyld.dylib.timestamp = 2;
    dyld.dylib.name.offset = sizeof(struct dylib_command);
    fseek(newFile, -sizeof(struct dylib_command), SEEK_CUR);
    
    fwrite(&dyld, sizeof(struct dylib_command), 1, newFile);
    
    fwrite([data bytes], [data length], 1, newFile);
    
}
int main(int argc, const char * argv[])
{
    char buffer[4096], binary[4096], dylib[4096];
    
    strlcpy(binary, argv[1], sizeof(binary));
    strlcpy(dylib, argv[2], sizeof(dylib));
    DYLIB_PATH = [NSString stringWithFormat:@"@executable_path/%@", [NSString stringWithUTF8String:dylib]];
    NSLog(@"dylib path %@", DYLIB_PATH);
    FILE *binaryFile = fopen(binary, "r+");
    printf("Reading binary: %s\n\n", binary);
    fread(&buffer, sizeof(buffer), 1, binaryFile);
    
    struct fat_header* fh = (struct fat_header*) (buffer);
    
    
    if (fh->magic == FAT_CIGAM) {
        struct fat_arch* arch = (struct fat_arch*) &fh[1];
        printf("FAT binary!\n");
        int i;
        for (i = 0; i < swap32(fh->nfat_arch); i++) {
            printf("Injecting to arch %i\n", swap32(arch->cpusubtype));
            inject_dylib(binaryFile, swap32(arch->offset));
            arch++;
        }
    }
    else {
        printf("Thin binary!\n");
        inject_dylib(binaryFile, 0);
    }
    printf("Complete!\n");
    return 0;
}

