//
//  main.m
//  IOWarriorAppleScriptGateway
//
//  Created by ilja on Fri Jan 17 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IOWarriorLib.h"

int main(int argc, const char *argv[])
{
    // initialize the IOWarrior library before losing control to NSApplication
    IOWarriorInit ();
    return NSApplicationMain(argc, argv);
}
