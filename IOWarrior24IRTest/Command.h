//
//  Command.h
//  IOWarrior24IRTest
//
//  Created by ilja on Sun Oct 12 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Command : NSObject {
    int         device;
    int         IRCommand;
    NSString*   script;
    BOOL        repeats;
    int         repetitionThreshold;
}

+ (id) command;
+ (id) commandWithDevice:(int) inDevice IRCommand:(int) inCommand script:(NSString*) inScriptName repeats:(BOOL) inRepeats 
      repetitionThreshold:(int) inThreshold;

- (id) initWithDevice:(int) inDevice IRCommand:(int) inCommand script:(NSString*) inScriptName repeats:(BOOL) inRepeats 
   repetitionThreshold:(int) inThreshold;

- (int) device;
- (void) setDevice: (int) inDevice;

- (int) IRCommand;
- (void) setIRCommand: (int) inIRcommand;

- (NSString *) script;
- (void) setScript: (NSString *) inScript;

- (BOOL) repeats;
- (void) setRepeats: (BOOL) flag;

- (int) repetitionThreshold;
- (void) setRepetitionThreshold: (int) inRepetitionThreshold;

- (NSDictionary*) descriptionDictionary;
- (id) initWithDescriptionDictionary:(NSDictionary*) inDictionary;

@end
