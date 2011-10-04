/* AppController */

#import <Cocoa/Cocoa.h>

@interface AppController : NSObject
{
    IBOutlet NSTextField *statusField;
	
	NSMutableArray *slideShowFiles;
	
	NSTimer *currentTimer;
	
	int currentSlideShowIndex;
}
- (IBAction)chooseFile:(id)sender;

- (void) updateStatusField;

- (BOOL) pixelIsSetInImageRep:(NSBitmapImageRep*)inImageRep atRow:(int) inRow column:(int) inColumn;


- (NSMutableArray *) slideShowFiles;
- (void) setSlideShowFiles: (NSMutableArray *) inSlideShowFiles;
- (void) downloadImageAtPath:(NSString*) inImagePath;
- (void) advanceSlideShow:(NSTimer*) ignored;

- (NSTimer *) currentTimer;
- (void) setCurrentTimer: (NSTimer *) inCurrentTimer;



@end
