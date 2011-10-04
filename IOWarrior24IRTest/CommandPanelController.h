//
//  CommandPanelController.h
//  IOWarrior24IRTest
//
//  Created by ilja on Sun Oct 12 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@class Command;

@interface CommandPanelController : NSWindowController {
    Command*                command;
    NSArray*                scripts;
    id                      delegate;
    NSObjectController*     commandController;
    
    IBOutlet NSPopUpButton* devicePopup;
    IBOutlet NSPopUpButton* commandPopup;
    IBOutlet NSPopUpButton* scriptPopup;
    
    IBOutlet NSButton*      repeatsCheckBox;
    IBOutlet NSTextField*   thresholdField;
}

+ (BOOL) runCommandPanelForWindow:(NSWindow*) inWindow command:(Command*) inCommand scripts:(NSArray*)inScripts delegate:(id) inDelegate;

- (id) initWithCommmand:(Command*) inCommand;

- (IBAction) doOK:(id) sender;
- (IBAction) doCancel:sender;

- (Command *) command;
- (void) setCommand: (Command *) inCommand;

- (void) setScripts:(NSArray*) inScripts;
- (void) setDelegate:(id) delegate;

@end

@interface NSObject (CommandPanelDelegate)

- (BOOL) shouldAcceptCommand:(Command*) inCommand;

@end
