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
#import "Yolo.h"


NSString* DYLIB_PATH;

#define DYLIB_CURRENT_VER 0x10000
#define DYLIB_COMPATIBILITY_VERSION 0x10000

#define ARMV7 9
#define ARMV6 6



int main(int argc, const char * argv[])
{
    // must have at least two arguments to run this program (first argument is the command which ran the program)
    if (argc < 3) {
        NSLog(@"usage: %s <binary> <dylib file>", argv[0]);
        return 1;
    }
              
    NSString* binary = [NSString stringWithUTF8String:argv[1]];
    NSString* dylib = [NSString stringWithUTF8String:argv[2]];
    
    Yolo *yolo = [[Yolo alloc] initWithBinaryPath:binary andDylibPath:dylib];
    
    NSLog(@"binary path %@", yolo.binaryPath);
    NSLog(@"dylib path %@", yolo.dylibPath);
    
    [yolo inject];
    
    return 0;
}

