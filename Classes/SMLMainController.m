/*
Textron
Based on Smultron Written by Peter Borg, pgw3@mac.com
Find the latest version at http://vijaykiran.com/textron

Copyright 2004-2009 Peter Borg
 
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 
http://www.apache.org/licenses/LICENSE-2.0
 
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
*/

#import "SMLStandardHeader.h"

#import "SMLMainController.h"
#import "SMLPreferencesController.h"
#import "SMLTextMenuController.h"
#import "SMLBasicPerformer.h"
#import "SMLVariousPerformer.h"
#import "SMLFontTransformer.h"

#define THISVERSION 3.60

@implementation SMLMainController

@synthesize isInFullScreenMode, singleDocumentWindowWasOpenBeforeEnteringFullScreen, operationQueue;


static id sharedInstance = nil;

+ (SMLMainController *)sharedInstance
{
	if (sharedInstance == nil) { 
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
} 


- (id)init 
{
	if (sharedInstance == nil) {
        sharedInstance = [super init];
		
		operationQueue = [[NSOperationQueue alloc] init];
    }
    return sharedInstance;
}


+ (void)initialize
{
	SInt32 systemVersion;
	if (Gestalt(gestaltSystemVersion, &systemVersion) == noErr) {
		if (systemVersion < 0x1050) {
			[NSApp activateIgnoringOtherApps:YES];
			[SMLVarious alertWithMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"You need %@ or later to run this version of Textron", @"Localizable3", @"You need %@ or later to run this version of Textron"), @"Mac OS X 10.5 Leopard"] informativeText:NSLocalizedStringFromTable(@"Go to the web site (http://Textron.sourceforge.net) to download another version for an earlier Mac OS X system", @"Localizable3", @"Go to the web site (http://Textron.sourceforge.net) to download another version for an earlier Mac OS X system") defaultButton:OK_BUTTON alternateButton:nil otherButton:nil];
			
			[NSApp terminate:nil];
		}
	}
	
	[SMLBasic insertFetchRequests];
	
	[[SMLPreferencesController sharedInstance] setDefaults];	
	
	NSValueTransformer *fontTransformer = [[SMLFontTransformer alloc] init];
    [NSValueTransformer setValueTransformer:fontTransformer forName:@"FontTransformer"];
	
	
}


- (void)awakeFromNib
{
    
	// If the application crashed so these weren't removed, remove them now
	[SMLBasic removeAllObjectsForEntity:@"Document"];
	[SMLBasic removeAllObjectsForEntity:@"Encoding"];
	[SMLBasic removeAllObjectsForEntity:@"SyntaxDefinition"];
	[SMLBasic removeAllObjectsForEntity:@"Project"];
	
	[SMLVarious insertTextEncodings];
	[SMLVarious insertSyntaxDefinitions];
	[SMLVarious insertDefaultSnippets];
	[SMLVarious insertDefaultCommands];
	
	[[SMLTextMenuController sharedInstance] buildSyntaxDefinitionsMenu];
	[[SMLTextMenuController sharedInstance] buildEncodingsMenus];
	
	isInFullScreenMode = NO;
	
	[SMLVarious updateCheckIfAnotherApplicationHasChangedDocumentsTimer];
}


- (void)checkForUpdate
{	
	if (checkForUpdateTimer != nil) {
		[checkForUpdateTimer invalidate];
		checkForUpdateTimer = nil;
	}
	
	[NSThread detachNewThreadSelector:@selector(checkForUpdateInSeparateThread) toTarget:self withObject:nil];
}


- (void)checkForUpdateInSeparateThread
{

}


- (void)updateInterfaceOnMainThreadAfterCheckForUpdateFoundNewUpdate:(id)sender
{
	if (sender != nil && [sender isKindOfClass:[NSDictionary class]]) {
		NSInteger returnCode = [SMLVarious alertWithMessage:[NSString stringWithFormat:NSLocalizedString(@"A newer version (%@) is available. Do you want to download it?", @"A newer version (%@) is available. Do you want to download it? in checkForUpdate"), [sender valueForKey:@"latestVersionString"]] informativeText:@"" defaultButton:NSLocalizedString(@"Download", @"Download") alternateButton:CANCEL_BUTTON otherButton:nil];
		if (returnCode == NSAlertFirstButtonReturn) {
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[sender valueForKey:@"url"]]];
		}
		
	} else {
		if ([[[SMLPreferencesController sharedInstance] preferencesWindow] isVisible] == YES) {
			[[[SMLPreferencesController sharedInstance] noUpdateAvailableTextField] setHidden:NO];
			hideNoUpdateAvailableTextFieldTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(hideNoUpdateAvailableTextField) userInfo:nil repeats:NO];
		}
	}
	
}


- (void)hideNoUpdateAvailableTextField
{
	if (hideNoUpdateAvailableTextFieldTimer) {
		[hideNoUpdateAvailableTextFieldTimer invalidate];
		hideNoUpdateAvailableTextFieldTimer = nil;
	}
	
	[[[SMLPreferencesController sharedInstance] noUpdateAvailableTextField] setHidden:YES];
}

@end
