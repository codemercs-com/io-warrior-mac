//
//  NSApplicationScriptingAdditions.h
//  IOWarriorAppleScriptGateway
//
//  Created by ilja on Fri Jan 17 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSApplication (ScriptingAdditions)

-(id) handleIsIOWarriorPresentCommand:(NSScriptCommand *) command;

/*" Interface 0 handling "*/
-(id) handleWriteInterface0Command:(NSScriptCommand *) command;
-(id) handleReadInterface0Command:(NSScriptCommand *) command;
- (id) handleReadInterface1Command:(NSScriptCommand *) command;

/*" Interface 0 pin handling "*/
- (NSArray*) buildPinArray;
- (void) readPinArrayValues;

- (void) writeBack:(NSTimer*) inTimer;

- (int) portForPinIndex:(int) pinIndex reportSize:(int) reportSize;
- (int) portPinForPinIndex:(int) pinIndex;

/*" Buffer handling "*/
- (id) startBufferedReading:(NSScriptCommand *) command;
- (id) stopBufferedReading:(NSScriptCommand *) command;
- (id) handleReadBufferSize:(NSScriptCommand*) command;

@end
