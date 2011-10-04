//
//  CommandPanelController.m
//  IOWarrior24IRTest
//
//  Created by ilja on Sun Oct 12 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "CommandPanelController.h"
#import "Command.h"
#import "MainController.h"

@implementation CommandPanelController

+ (BOOL) runCommandPanelForWindow:(NSWindow*) inWindow command:(Command*) inCommand scripts:(NSArray*)inScripts delegate:(id) inDelegate
{
    CommandPanelController* controller;
    int                     response;
    
    controller = [[CommandPanelController alloc] initWithCommmand:inCommand];
    
    [controller setScripts:inScripts];
    [controller setDelegate:inDelegate];
    
    [NSApp beginSheet:[controller window]
       modalForWindow:inWindow
        modalDelegate:nil
       didEndSelector:nil
          contextInfo:nil];
    response = [NSApp runModalForWindow:[controller window]];
    [NSApp endSheet: [controller window]];
    [[controller window] orderOut: self];
    [controller autorelease];
    return (NSRunStoppedResponse == response);
}

- (id) initWithCommmand:(Command*) inCommand
{
    self = [super initWithWindowNibName:@"CommandPanel"];
    if (self)
    {
        [self setCommand:inCommand];
    }
    return self;
}

- (void) dealloc
{
    [self setCommand: nil];
    
    [super dealloc];
}

- (void) awakeFromNib
{
    int i;
    
    [devicePopup removeAllItems];
    for (i = 0; i < kMaxDeviceCount; i++)
    {
        [devicePopup addItemWithTitle:[NSString stringWithFormat:@"%@(%d)", [MainController deviceNameForAddress:i], i]];   
    }
    [devicePopup selectItemAtIndex:[command device]];
    
    [commandPopup removeAllItems];
    for (i = 0; i < kMaxCommandCount; i++)
    {
        [commandPopup addItemWithTitle:[NSString stringWithFormat:@"%@(%d)", [MainController nameForCommand:i], i]];   
    }
    [commandPopup selectItemAtIndex:[command IRCommand]];
    
    [scriptPopup removeAllItems];
    [scriptPopup addItemsWithTitles:scripts];
    if ([scripts containsObject:[command script]])
    {
        [scriptPopup selectItemAtIndex:[scripts indexOfObject:[command script]]];
    }
    
    [repeatsCheckBox setState:[command repeats]];
    [thresholdField setIntValue:[command repetitionThreshold]];
}

- (void) setScripts:(NSArray*) inScripts
{
    [scripts autorelease];
    scripts = [inScripts retain];
    
}

- (void) setDelegate:(id) inDelegate
{
    [delegate autorelease];
    delegate = [inDelegate retain];
}


- (Command *) command { return command; }

- (void) setCommand: (Command *) inCommand
{
    [command autorelease];
    command = [inCommand retain];
}

- (IBAction) doOK:(id) sender
{
    if ([delegate shouldAcceptCommand:[Command commandWithDevice:[devicePopup indexOfSelectedItem]
                                                       IRCommand:[commandPopup indexOfSelectedItem]
                                                          script:[scriptPopup titleOfSelectedItem]
                                                         repeats:[repeatsCheckBox state]
                                             repetitionThreshold:[thresholdField intValue]]])
    {
        [command setDevice:[devicePopup indexOfSelectedItem]];
        [command setIRCommand:[commandPopup indexOfSelectedItem]];
        [command setScript:[scriptPopup titleOfSelectedItem]];
        [command setRepeats:[repeatsCheckBox state]];
        [command setRepetitionThreshold:[thresholdField intValue]];
        [NSApp stopModal];
    }
}

- (IBAction) doCancel:sender
{
    [NSApp abortModal];
}

@end
