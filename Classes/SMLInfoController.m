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

#import "NSString+Textron.h"
#import "SMLInfoController.h"
#import "SMLProjectsController.h"
#import "SMLBasicPerformer.h"
#import "SMLInterfacePerformer.h"
#import "SMLTextView.h"
#import "SMLVariousPerformer.h"


@implementation SMLInfoController

@synthesize infoWindow;

static id sharedInstance = nil;

+ (SMLInfoController *)sharedInstance
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
		
    }
    return sharedInstance;
}


- (void)openInfoWindow
{
	if (infoWindow == nil) {
		[NSBundle loadNibNamed:@"SMLInfo.nib" owner:self];
		
	}
	
	if ([infoWindow isVisible] == NO) {
		[self refreshInfo];
		[infoWindow makeKeyAndOrderFront:self];
	} else {
		[infoWindow orderOut:nil];
	}
}


- (void)refreshInfo
{
	id document = SMLCurrentDocument;
	if (document == nil) {
		NSBeep();
		return;			
	}
	
	[titleTextField setStringValue:[document valueForKey:@"name"]];
	if ([[document valueForKey:@"isNewDocument"] boolValue] == YES || [document valueForKey:@"path"] == nil) {
		NSImage *image = [NSImage imageNamed:@"SMLDocumentIcon"];
		[image setSize:NSMakeSize(64.0, 64.0)];
		NSArray *array = [image representations];
		for (id item in array) {
			[(NSImageRep *)item setSize:NSMakeSize(64.0, 64.0)];
		}
		[iconImageView setImage:image];
		
	} else {
		[iconImageView setImage:[[NSWorkspace sharedWorkspace] iconForFile:[document valueForKey:@"path"]]];
	}
	
	NSDictionary *fileAttributes = [document valueForKey:@"fileAttributes"];
	
	if (fileAttributes != nil) {
		[fileSizeTextField setStringValue:[NSString stringWithFormat:@"%@ %@", [SMLBasic thousandFormatedStringFromNumber:[NSNumber numberWithLongLong:[fileAttributes fileSize]]], NSLocalizedString(@"bytes", @"The name for bytes in the info window")]];
		[whereTextField setStringValue:[[document valueForKey:@"path"] stringByDeletingLastPathComponent]];
		[createdTextField setStringValue:[NSString dateStringForDate:(NSCalendarDate *)[fileAttributes fileCreationDate] formatIndex:[[SMLDefaults valueForKey:@"StatusBarLastSavedFormatPopUp"] integerValue]]];
		[modifiedTextField setStringValue:[NSString dateStringForDate:(NSCalendarDate *)[fileAttributes fileModificationDate] formatIndex:[[SMLDefaults valueForKey:@"StatusBarLastSavedFormatPopUp"] integerValue]]];
		[creatorTextField setStringValue:NSFileTypeForHFSTypeCode([fileAttributes fileHFSCreatorCode])];
		[typeTextField setStringValue:NSFileTypeForHFSTypeCode([fileAttributes fileHFSTypeCode])];
		[ownerTextField setStringValue:[fileAttributes fileOwnerAccountName]];
		[groupTextField setStringValue:[fileAttributes fileGroupOwnerAccountName]];
        [permissionsTextField setStringValue:[self stringFromPermissions:[fileAttributes filePosixPermissions]]];
    }
	
	
	SMLTextView *textView = SMLCurrentTextView;
	if (textView == nil) {
		textView = [document valueForKey:@"firstTextView"];
	}
	NSString *text = [textView string];;
	
	[lengthTextField setStringValue:[SMLBasic thousandFormatedStringFromNumber:[NSNumber numberWithUnsignedInteger:[text length]]]];
	
	NSArray *array = [textView selectedRanges];
	
	NSInteger selection = 0;
	for (id item in array) {
		selection = selection + [item rangeValue].length;
	}
	if (selection == 0) {
		[selectionTextField setStringValue:@""];
	} else {
		[selectionTextField setStringValue:[SMLBasic thousandFormatedStringFromNumber:[NSNumber numberWithInteger:selection]]];
	}
	
	NSRange selectionRange;
	if (textView == nil) {
		selectionRange = NSMakeRange(0,0);
	} else {
		selectionRange = [textView selectedRange];
	}
	[positionTextField setStringValue:[NSString stringWithFormat:@"%@\\%@", [SMLBasic thousandFormatedStringFromNumber:[NSNumber numberWithInteger:(selectionRange.location - [text lineRangeForRange:selectionRange].location)]], [SMLBasic thousandFormatedStringFromNumber:[NSNumber numberWithInteger:selectionRange.location]]]];
	
	NSInteger index;
	NSInteger lineNumber;
	NSInteger lastCharacter = [text length];
	for (index = 0, lineNumber = 0; index < lastCharacter; lineNumber++) {
		index = NSMaxRange([text lineRangeForRange:NSMakeRange(index, 0)]);
	}
	if (lastCharacter > 0) {
		unichar lastGlyph = [text characterAtIndex:lastCharacter - 1];
		if (lastGlyph == '\n' || lastGlyph == '\r') {
			lineNumber++;
		}
	}


	[linesTextField setStringValue:[NSString stringWithFormat:@"%d/%d", [SMLInterface currentLineNumber], lineNumber]];

	NSArray *functions = [SMLInterface allFunctions];
	
	if ([functions count] == 0) {
		[functionTextField setStringValue:@""];
	} else {
		index = [SMLInterface currentFunctionIndexForFunctions:functions];
		if (index == -1) {
			[functionTextField setStringValue:@""];
		} else {
			[functionTextField setStringValue:[[functions objectAtIndex:index] valueForKey:@"name"]];
		}
	}
	
	if (selection > 1) {
		[wordsTextField setStringValue:[NSString stringWithFormat:@"%@ (%@)", [SMLBasic thousandFormatedStringFromNumber:[NSNumber numberWithInteger:[[NSSpellChecker sharedSpellChecker] countWordsInString:[text substringWithRange:selectionRange] language:nil]]], [SMLBasic thousandFormatedStringFromNumber:[NSNumber numberWithInteger:[[NSSpellChecker sharedSpellChecker] countWordsInString:text language:nil]]]]];
	} else {
		[wordsTextField setStringValue:[NSString stringWithFormat:@"%@", [SMLBasic thousandFormatedStringFromNumber:[NSNumber numberWithInteger:[[NSSpellChecker sharedSpellChecker] countWordsInString:text language:nil]]]]];
	}

	[encodingTextField setStringValue:[document valueForKey:@"encodingName"]];
	
	[syntaxTextField setStringValue:[document valueForKey:@"syntaxDefinition"]];

}



- (NSString *)stringFromPermissions:(unsigned long)permissions 
{
    char permissionsString[10] = "---------\0";
    strmode(permissions, permissionsString);
    
	NSMutableString *returnString = [[NSMutableString stringWithUTF8String:permissionsString] retain];
    [returnString deleteCharactersInRange:NSMakeRange(0, 1)];
    [returnString insertString:@" " atIndex:3];
    [returnString insertString:@" " atIndex:7];
    [returnString insertString:@" " atIndex:11];
    
    
    return returnString;
}


@end
