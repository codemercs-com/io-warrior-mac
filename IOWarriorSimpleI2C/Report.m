//
//  Report.m
//  IOWarriorSimpleI2C
//
//  Created by ilja on 21.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "Report.h"
#import "AppController.h"

@implementation Report


- (void) dealloc
{
    [self setReportData: nil];
	
    [super dealloc];
}

- (NSArray *) reportData
{
    return reportData; 
}

- (void) setReportData: (NSArray *) inReportData
{
    if (reportData != inReportData) {
        [reportData autorelease];
        reportData = [inReportData retain];
    }
}

- (NSString*) displayString
{
	NSEnumerator	*e = [[self reportData] objectEnumerator];
	NSNumber		*number;
	NSString		*result = @"";
	AppController	*controller = [[NSApplication sharedApplication] delegate];
	
	while (nil != (number = [ e nextObject ]))
	{
		if ([controller useHex])
		{
			result = [result stringByAppendingFormat:@"%02X ", [number unsignedCharValue]];
		}
		else
		{
			result = [result stringByAppendingFormat:@"%d ", [number unsignedCharValue]];
		}
	}
	return result;
}

- (NSString*) reportIDString
{
	return [[[self displayString] componentsSeparatedByString:@" "] objectAtIndex:0];
}

- (NSString*) byteCountString
{
	return [[[self displayString] componentsSeparatedByString:@" "] objectAtIndex:1];
}

- (NSString*) payloadString
{
	return [[[[self displayString] componentsSeparatedByString:@" "] subarrayWithRange:NSMakeRange (2, 6)] componentsJoinedByString:@" "];
}

- (NSArray*) reportStrings
{
	return nil;
}

- (void) setReportStrings:(NSArray*) ignored
{
}

@end
