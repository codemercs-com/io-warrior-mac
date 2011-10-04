//
//  Report.h
//  IOWarriorSimpleI2C
//
//  Created by ilja on 21.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface Report : NSObject {
	NSArray *reportData;
}

- (NSArray *) reportData;
- (void) setReportData: (NSArray *) inReportData;



@end
