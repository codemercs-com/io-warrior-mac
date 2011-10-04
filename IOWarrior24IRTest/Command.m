//
//  Command.m
//  IOWarrior24IRTest
//
//  Created by ilja on Sun Oct 12 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "Command.h"
#import "MainController.h"

#define kDeviceKey @"device"
#define kIRCommandKey @"IRCommand"
#define kScriptKey @"script"
#define kRepeatsKey @"repeats"
#define kRepetitionThresholdKey @"repetitionThreshold"

@implementation Command

+ (id) command
{
    return [[[Command alloc] init] autorelease];   
}

- (id) init
{
    return [self  initWithDevice:0
                       IRCommand:0
                          script:nil
                         repeats:NO
             repetitionThreshold:3];  
}

+ (id) commandWithDevice:(int) inDevice IRCommand:(int) inCommand script:(NSString*) inScriptName repeats:(BOOL) inRepeats 
   repetitionThreshold:(int) inThreshold
{
    return [[[Command alloc] initWithDevice:inDevice
                                  IRCommand:inCommand
                                     script:inScriptName
                                    repeats:inRepeats
                        repetitionThreshold:inThreshold] autorelease];   
}

- (id) initWithDevice:(int) inDevice IRCommand:(int) inCommand script:(NSString*) inScriptName repeats:(BOOL) inRepeats 
   repetitionThreshold:(int) inThreshold
{
    self = [super init];
    if (self)
    {
        IRCommand = inCommand;
        device = inDevice;
        [self setScript:inScriptName];
        repeats = inRepeats;
        repetitionThreshold = inThreshold;
    }
    return self;
}

- (id) initWithDescriptionDictionary:(NSDictionary*) inDictionary
{
    return [self initWithDevice:[[inDictionary objectForKey:kDeviceKey] intValue]
                      IRCommand:[[inDictionary objectForKey:kIRCommandKey] intValue]
                         script:[inDictionary objectForKey:kScriptKey]
                        repeats:[[inDictionary objectForKey:kRepeatsKey] boolValue]
            repetitionThreshold:[[inDictionary objectForKey:kRepetitionThresholdKey] intValue]];
    
}

- (NSDictionary*) descriptionDictionary
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:device], kDeviceKey,
        [NSNumber numberWithInt:IRCommand], kIRCommandKey,
        script, kScriptKey,
        [NSNumber numberWithBool:repeats], kRepeatsKey,
        [NSNumber numberWithInt:repetitionThreshold], kRepetitionThresholdKey,
        nil];
}

- (void) dealloc
{
    [self setScript: nil];
    
    [super dealloc];
}

- (int) device { return device; }

- (void) setDevice: (int) inDevice
{
    device = inDevice;
}

- (int) IRCommand { return IRCommand; }

- (void) setIRCommand: (int) inIRcommand
{
    IRCommand = inIRcommand;
}

- (NSString *) script { return script; }

- (void) setScript: (NSString *) inScript
{
    if (script != inScript)
    {
        [script release];
        script = [inScript copy];
    }
}

- (BOOL) repeats { return repeats; }

- (void) setRepeats: (BOOL) flag
{
    repeats = flag;
}

- (int) repetitionThreshold { return repetitionThreshold; }

- (void) setRepetitionThreshold: (int) inRepetitionThreshold
{
    repetitionThreshold = inRepetitionThreshold;
}

- (NSString*) commandName
{
    return [NSString stringWithFormat:@"%@(%d)", [MainController nameForCommand:IRCommand], IRCommand];
}

- (NSString*) deviceName
{
    return [NSString stringWithFormat:@"%@(%d)", [MainController deviceNameForAddress:device], device];

}

@end
