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

#import "Yolo.h"
#include <mach-o/fat.h>
#include <mach-o/loader.h>

#define DYLIB_CURRENT_VER 0x10000
#define DYLIB_COMPATIBILITY_VERSION 0x10000

@implementation Yolo

- (instancetype) initWithBinaryPath:(NSString *)binaryPath andDylibPath:(NSString *)dylibPath{
    if (self = [super init]){
        self.binaryPath = binaryPath;
        self.dylibPath = dylibPath;
    }
    
    return self;
}

- (void) setDylibPath:(NSString *)dylibPath{
    _dylibPath = [NSString stringWithFormat:@"@executable_path/%@", dylibPath];
    
}

unsigned long b_round( unsigned long v, unsigned long r){
    r--;
    v += r;
    v &= ~(long)r;
    return(v);
}

- (void) injectDylib32:(FILE *)newFile atOffset:(uint32_t)top {
    fseek(newFile, top, SEEK_SET);
    struct mach_header mach;
    
    fread(&mach, sizeof(struct mach_header), 1, newFile);
    
    NSData* data = [self.dylibPath dataUsingEncoding:NSUTF8StringEncoding];
    
    uint32_t dylib_size = (uint32_t)[data length] + sizeof(struct dylib_command);
    dylib_size += sizeof(long) - (dylib_size % sizeof(long)); // load commands like to be aligned by long
    
    mach.ncmds += 1;
    uint32_t sizeofcmds = mach.sizeofcmds;
    mach.sizeofcmds += dylib_size;
    
    fseek(newFile, -sizeof(struct mach_header), SEEK_CUR);
    fwrite(&mach, sizeof(struct mach_header), 1, newFile);
    NSLog(@"Patching mach_header..\n");
    
    fseek(newFile, sizeofcmds, SEEK_CUR);
    
    struct dylib_command dyld;
    fread(&dyld, sizeof(struct dylib_command), 1, newFile);
    
    NSLog(@"Attaching dylib..\n\n");
    
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

- (void) injectDylib64:(FILE *)newFile atOffset:(uint32_t)top {
    @autoreleasepool {
        fseek(newFile, top, SEEK_SET);
        struct mach_header_64 mach;
        
        
        fread(&mach, sizeof(struct mach_header_64), 1, newFile);
        
        NSData* data = [self.dylibPath dataUsingEncoding:NSUTF8StringEncoding];
        
        
        unsigned long dylib_size = sizeof(struct dylib_command) + b_round(strlen([self.dylibPath UTF8String]) + 1, 8);
        
        
        //round(strlen([DYLIB_PATH UTF8String]) + 1, sizeof(long));
        NSLog(@"dylib size wow %lu", dylib_size);
        /*uint32_t dylib_size2 = (uint32_t)[data length] + sizeof(struct dylib_command);
         dylib_size2 += sizeof(long) - (dylib_size % sizeof(long)); // load commands like to be aligned by long
         
         NSLog(@"dylib size2 wow %u", dylib_size2);
         NSLog(@"dylib size2 wow %u", CFSwapInt32(dylib_size2));*/
        
        NSLog(@"mach.ncmds %u", mach.ncmds);
        
        mach.ncmds += 0x1;
        
        NSLog(@"mach.ncmds %u", mach.ncmds);
        
        uint32_t sizeofcmds = mach.sizeofcmds;
        mach.sizeofcmds += (dylib_size);
        
        fseek(newFile, -sizeof(struct mach_header_64), SEEK_CUR);
        fwrite(&mach, sizeof(struct mach_header_64), 1, newFile);
        NSLog(@"Patching mach_header..\n");
        
        fseek(newFile, sizeofcmds, SEEK_CUR);
        
        struct dylib_command dyld;
        fread(&dyld, sizeof(struct dylib_command), 1, newFile);
        
        NSLog(@"Attaching dylib..\n\n");
        
        dyld.cmd = LC_LOAD_DYLIB;
        dyld.cmdsize = (uint32_t) dylib_size;
        dyld.dylib.compatibility_version = DYLIB_COMPATIBILITY_VERSION;
        dyld.dylib.current_version = DYLIB_CURRENT_VER;
        dyld.dylib.timestamp = 2;
        dyld.dylib.name.offset = sizeof(struct dylib_command);
        fseek(newFile, -sizeof(struct dylib_command), SEEK_CUR);
        
        fwrite(&dyld, sizeof(struct dylib_command), 1, newFile);
        
        fwrite([data bytes], [data length], 1, newFile);
        NSLog(@"size %lu", sizeof(struct dylib_command) + [data length]);
    }
}

- (void) checkFilePathsCorrectness{
    if (self.binaryPath == nil || self.binaryPath.length <= 0) {
        @throw [NSException exceptionWithName:@"InvalidPath" reason:@"Path to binary is null or zero in lenght. A valid path to a binary file should be specified" userInfo:nil];
    }
    
    if (self.dylibPath == nil || self.dylibPath.length <= 0) {
        @throw [NSException exceptionWithName:@"InvalidPath" reason:@"Path to dylib is null or zero in lenght. A valid path to a dylib file should be specified" userInfo:nil];
    }
    
}

- (void) inject{
    // make sure every thing is set up propery
    [self checkFilePathsCorrectness];
    
    char buffer[4096], binary[4096], _dylib[4096];
    
    
    strlcpy(binary, [self.binaryPath UTF8String], sizeof(binary));
    strlcpy(_dylib, [self.dylibPath UTF8String], sizeof(self.dylibPath));
    
    NSLog(@"dylib path %@", self.dylibPath);
    FILE *binaryFile = fopen(binary, "r+");
    printf("Reading binary: %s\n\n", binary);
    fread(&buffer, sizeof(buffer), 1, binaryFile);
    
    struct fat_header* fh = (struct fat_header*) (buffer);
    
    switch (fh->magic) {
        case FAT_CIGAM:
        case FAT_MAGIC:
        {
            struct fat_arch* arch = (struct fat_arch*) &fh[1];
            NSLog(@"FAT binary!\n");
            int i;
            for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
                NSLog(@"Injecting to arch %i\n", CFSwapInt32(arch->cpusubtype));
                if (CFSwapInt32(arch->cputype) == CPU_TYPE_ARM64) {
                    NSLog(@"64bit arch wow");
                    [self injectDylib64:binaryFile atOffset:CFSwapInt32(arch->offset)];
                }
                else {
                    [self injectDylib32:binaryFile atOffset:CFSwapInt32(arch->offset)];
                }
                arch++;
            }
            break;
        }
        case MH_CIGAM_64:
        case MH_MAGIC_64:
        {
            NSLog(@"Thin 64bit binary!\n");
            [self injectDylib64:binaryFile atOffset:0];
            break;
        }
        case MH_CIGAM:
        case MH_MAGIC:
        {
            NSLog(@"Thin 32bit binary!\n");
            [self injectDylib32:binaryFile atOffset:0];
            break;
        }
        default:
        {
            printf("Error: Unknown architecture detected");
            exit(1);
        }
    }
    
    NSLog(@"complete!");
    fclose(binaryFile);
}

@end
