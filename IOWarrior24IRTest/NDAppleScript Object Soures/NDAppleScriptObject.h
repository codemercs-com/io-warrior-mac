/*
 *  NDAppleScriptObject.h
 *  NDAppleScriptObjectProject
 *
 *  Created by nathan on Thu Nov 29 2001.
 *  Copyright (c) 2001 Nathan Day. All rights reserved.
 */

/*!
@header NDAppleScriptObject
	NDAppleScriptObject is used to represent compiled AppleScripts within Cocoa.
	The only restriction for use of this code is that you keep the comments with the
	head files especial my name. Use of this code is at your own risk yada yada yada...
 */


#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>
#import "NDAppleScriptObject_Protocols.h"

@interface NDAppleScriptObject : NSObject <NDAppleScriptObjectSendEvent, NDAppleScriptObjectActive>
{
@private
	OSAID										compiledScriptID,
												resultingValueID;
	NDAppleScriptObject					* contextAppleScriptObject;
	id<NDAppleScriptObjectSendEvent>	sendAppleEventTarget;
	id<NDAppleScriptObjectActive>		activeTarget;
	ComponentInstance						osaComponent;

	long										executionModeFlags;
}

/*!
@method compileExecuteString:
	@abstract compiles and executes the apple script within the passed string.
	@discussion Executes the script by calling it's run handler.
	@param aString  A string that contains the  AppleScipt source to be compiled and executed.
	@result  Returns the result of executing the AppleScript as a Objective-C object, see resultObject for more details.
 */
+ (id)compileExecuteString:(NSString *) aString;

/*!
@method findNextComponent:
	@abstract Finds the next OSA component.
	@discussion Can be used by init methods that take a component parameter so that
		a script can be connected to it own OSA component. This is useful if you want
		to execute AppleScripts within separate threads as each OSA component is not thread safe. 
	@result  Returns the OSA component.
 */
+ (Component)findNextComponent;

/*!
	@method appleScriptObjectWithString:
	@abstract returns an NDAppleScriptObject compiled from passed string.
	@discussion An autorelease version of initWithString: with modeFlags: set to kOSAModeCompileIntoContext.
	@param aString  A string that contains the AppleScipt source to be compiled.
	@result  Returns the NDAppleScriptObject instance.
 */
+ (id)appleScriptObjectWithString:(NSString *) aString;

/*!
@method appleScriptObjectWithData:
	 @abstract returns an NDAppleScriptObject from the NSData containing a compiled AppleScript.
	 @discussion An autorelease version of initWithData:.
	 @param aString  A string that contains the AppleScipt source to be compiled.
	 @result  Returns the NDAppleScriptObject instance.
 */
+ (id)appleScriptObjectWithData:(NSData *) aData;

/*!
@method appleScriptObjectWithContentsOfFile:
	 @abstract returns an NDAppleScriptObject by reading in the compiled AppleScipt at passed path.
	 @discussion An autorelease version of initWithContentsOfFile:.
	 @param aPath  A path to the compiled AppleScipt file.
	 @result  Returns the NDAppleScriptObject instance.
 */
+ (id)appleScriptObjectWithContentsOfFile:(NSString *) aPath;

/*!
@method appleScriptObjectWithContentsOfURL:
	 @abstract returns an NDAppleScriptObject by reading in the compiled AppleScipt at passed file URL.
	 @discussion An autorelease version of initWithContentsOfURL:.
	 @param aURL  A file url to the compiled AppleScipt file.
	 @result  Returns the NDAppleScriptObject instance.
 */
+ (id)appleScriptObjectWithContentsOfURL:(NSURL *) aURL;

/*!
@method initWithString:modeFlags:
	@abstract returns an NDAppleScriptObject compiled from passed string.
	@discussion initWithString:modeFlags:component: with the default component.
	@param aString  A string that contains the AppleScipt source to be compiled.
	@param aModeFlags  Mode flags passed to OSACompile (see Apple OSA documentation).
	@result  Returns the NDAppleScriptObject instance.
 */
- (id)initWithString:(NSString *)aString modeFlags:(long)aModeFlags;
- (id)initWithContentsOfFile:(NSString *)aPath;
- (id)initWithContentsOfFile:(NSString *)aPath component:(Component)aComponent;
- (id)initWithContentsOfURL:(NSURL *)anURL;
- (id)initWithContentsOfURL:(NSURL *)aURL component:(Component)aComponent;
- (id)initWithData:(NSData *)aData;

/*!
@method initWithString:modeFlags:component:
	 @abstract returns an NDAppleScriptObject compiled from passed string.
	 @discussion Uses OSACompile to compile the AppleScript.
	 @param aURL  A file url to the compiled AppleScipt file.
	 @result  Returns the NDAppleScriptObject instance.
 */
- (id)initWithString:(NSString *)aString modeFlags:(long)aModeFlags component:(Component)aComponent;
- (id)initWithData:(NSData *)aData component:(Component)aComponent;

/*!
	@method data
	 @abstract returns the compiled script within a NSData instance.
	 @discussion the returned NSData instance contains a compiled script which can be
				passed to the initWithData:component: method.
	 @result  Returns an NSData instance.
 */
- (NSData *)data;

/*!
	@method execute
	 @abstract executes the script.
	 @discussion executes the script by calling it run handler.
	 @result  returns YES if execution was successful.
 */
- (BOOL)execute;
/*!
	@method executeOpen
	 @abstract sends an open event.
	 @discussion executes the script by calling it open handler passing an alias list creaed from aParameters.
	 @param aParameters  an NSArray containing paths (NSString) or NSURL's which is
			converted into an alias list.
	 @result  returns YES if execution was successful.
 */
- (BOOL)executeOpen:(NSArray *)aParameters;
/*!
	@method executeEvent:
	 @abstract execute an AppleEvent.
	 @discussion sends an AppleEvent to the script.
	 @param anEvent  an NSAppleEventDescriptor containing the apple event.
	 @result  returns YES if execution was successful.
 */
- (BOOL)executeEvent:(NSAppleEventDescriptor *)anEvent;

/*!
	@method arrayOfEventIdentifier
	 @abstract returns all event identifies the script respondes to.
	 @discussion returns and NSArray of NSStrings of the form @"XXXXYYYY" where
				XXXX is the four byte event class and YYYY is the four byte event ID.
				An example is @"aevtodoc" for the open document event.
	 @result  returns an NSArray of event identifier NSStrings.
 */
- (NSArray *)arrayOfEventIdentifier;
/*!
	@method respondsToEventClass:eventID:
	@abstract Tests whether the script responds to an AppleEvent.
	@discussion This method test whether the script responds to the passed event identifier.
	@param aEventClass  the event class.
	@param aEventID  the event identifier.
	@result  returns true if the script reponds to the event identifier.
 */
- (BOOL)respondsToEventClass:(AEEventClass)aEventClass eventID:(AEEventID)aEventID;

/*!
  @method resultAppleEventDescriptor
	 @abstract Returs the result as an AppleEvent type..
	 @discussion returns the result of the last script execution as an AppleEvent type within an NSAppleEventDescriptor.
	 @result  the NSAppleEventDescriptor contains the AppleEvent type result.
 */
- (NSAppleEventDescriptor *)resultAppleEventDescriptor;
/*!
	@method resultObject
	 @abstract Returs the result as an Objective-C object.
	 @discussion converts the AppleEvent type returned from the last script execution into an
				Objective-C object. The types currently supported are
				¥	list						Ñ>		NSArray
				¥	record					Ñ>		NSDictionary
				¥	alias					Ñ>		NSURL
				¥	string					Ñ>		NSString
				¥	real/integers/boolean	Ñ>		NSNumber
				¥	script					Ñ>		NDAppleScriptObject
				¥	anything else			Ñ>		NSData
	 @result  the NSAppleEventDescriptor contains the AppleEvent type result.
 */
- (id)resultObject;
/*!
	@method resultData
	 @abstract Returs the result as an NSData instance.
	 @discussion returns the raw bytes from the result AppleEvent type.
	 @result  the NSData instance.
 */
- (id)resultData;
/*!
	@method resultAsString
	 @abstract returns the result as an OSA formated string.
	 @discussion returns the result as a string by calling OSA's OSADisplay function. The result is
				in the same format as seen in Script Editor's result window.
	 @result  the NSString result.
 */
- (NSString *)resultAsString;

//- (void)setContextAppleScriptObject:(NDAppleScriptObject *)aAppleScriptObject;		// NOT FUNCTIONING YET
/*!
	@method executionModeFlags
	@abstract returns the execution mode flags.
	@discussion see setExecutionModeFlags:
	@result  a long contains the execution mode flag bits.
 */
- (long)executionModeFlags;
/*!
	@method setExecutionModeFlags:
	@abstract sets the execution mode flags.
	@discussion the available flags are
					¥	kOSAModeNeverInteract
					¥	kOSAModeCanInteract
					¥	kOSAModeAlwaysInteract
					¥	kOSAModeCantSwitchLayer
					¥	kOSAModeDontReconnect
					¥	kOSAModeDoRecord
	 @param  a long containing the execution mode flag bits.
 */
- (void)setExecutionModeFlags:(long)aModeFlags;

/*!
	@method setDefaultTarget:
	 @abstract  sets the default target for any AppleEvents.
	 @discussion any AppleEvents not enclosed in a tell statement by default go to the current
				process (your application). With this method you can provide a different default target.
	 @param  an NSAppleEventDescriptor containing the target descriptor
 */
- (void)setDefaultTarget:(NSAppleEventDescriptor *)aDefaultTarget;
/*!
  @method setDefaultTargetAsCreator:
	 @abstract  sets the default target, specified by creator code, for any AppleEvents
	@discussion same as setDefaultTarget: but passing the creator code of an application to specify the
				target process.
	 @param  an OSType creator code of the processes application.
 */
- (void)setDefaultTargetAsCreator:(OSType)aCreator;
/*!
	@method setFinderAsDefaultTarget.
	 @abstract  sets the default target as Finder for any AppleEvents
	 @discussion passes the Finders creator code to setDefaultTarget:.
 */
- (void)setFinderAsDefaultTarget;

/*!
	@method setAppleEventSendTarget:.
	 @abstract  sets the object that any handles any AppleEvent the script atempts to send.
	 @discussion if the send traget is set any AppleEvents are sent to the sned target to be processed otherwise
				NDAppleScriptObject will handle the event itself by utilising OSA default send procedure.
				One use of this is when executing a script in thread any AppleEvents to the current procees need to
				be sent from the main thread.
 */
- (void)setAppleEventSendTarget:(id<NDAppleScriptObjectSendEvent>)aTarget;
- (id<NDAppleScriptObjectSendEvent>)appleEventSendTarget;
- (void)setActiveTarget:(id<NDAppleScriptObjectActive>)aTarget;
- (id<NDAppleScriptObjectActive>)activeTarget;

- (NSAppleEventDescriptor *)targetNoProcess;

- (BOOL)writeToURL:(NSURL *)aURL;
- (BOOL)writeToURL:(NSURL *)aURL Id:(short)anID;
- (BOOL)writeToFile:(NSString *)aPath;
- (BOOL)writeToFile:(NSString *)aPath Id:(short)anID;

@end
