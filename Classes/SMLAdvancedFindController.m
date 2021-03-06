/*
Textron
		
Find the latest version at http://vijaykiran.com/textron

Copyright 2004-2009 Peter Borg
 
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 
http://www.apache.org/licenses/LICENSE-2.0
 
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
*/

#import "SMLStandardHeader.h"

#import "SMLAdvancedFindController.h"

#import "SMLExtraInterfaceController.h"
#import "SMLProjectsController.h"
#import "SMLBasicPerformer.h"
#import "SMLApplicationDelegate.h"
#import "SMLInterfacePerformer.h"
#import "SMLLineNumbers.h"
#import "SMLProject.h"
#import "SMLTextPerformer.h"

@implementation SMLAdvancedFindController

@synthesize currentlyDisplayedDocumentInAdvancedFind, advancedFindWindow, findResultsOutlineView;

static id sharedInstance = nil;

+ (SMLAdvancedFindController *)sharedInstance
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


- (IBAction)findAction:(id)sender
{
	NSString *searchString = [findSearchField stringValue];
	
	[findResultsOutlineView setDelegate:nil];
	
	[findResultsTreeController setContent:nil];
	[findResultsTreeController setContent:[NSMutableArray array]];
	
	NSMutableArray *recentSearches = [[NSMutableArray alloc] initWithArray:[findSearchField recentSearches]];
	if ([recentSearches indexOfObject:searchString] != NSNotFound) {
		[recentSearches removeObject:searchString];
	}
	[recentSearches insertObject:searchString atIndex:0];
	if ([recentSearches count] > 15) {
		[recentSearches removeLastObject];
	}
	[findSearchField setRecentSearches:recentSearches];
	
	NSInteger searchStringLength = [searchString length];
	if (!searchStringLength > 0 || SMLCurrentDocument == nil || SMLCurrentProject == nil) {
		NSBeep();
		return;
	}
	
	NSString *completeString;
	NSInteger completeStringLength; 
	NSInteger startLocation;
	NSInteger resultsInThisDocument = 0;
	NSInteger lineNumber;
	NSInteger index;
	NSInteger numberOfResults = 0;
	NSRange foundRange;
	NSRange searchRange;
	NSIndexPath *folderIndexPath;
	NSMutableDictionary *node;
	
	NSEnumerator *enumerator = [self scopeEnumerator];

	NSInteger documentIndex = 0;
	for (id document in enumerator) {
		node = [NSMutableDictionary dictionary];
		if ([[SMLDefaults valueForKey:@"ShowFullPathInWindowTitle"] boolValue] == YES) {
			[node setValue:[document valueForKey:@"nameWithPath"] forKey:@"displayString"];
		} else {
			[node setValue:[document valueForKey:@"name"] forKey:@"displayString"];
		}
		[node setValue:[NSNumber numberWithBool:NO] forKey:@"isLeaf"];
		[node setValue:[SMLBasic uriFromObject:document] forKey:@"document"];
		folderIndexPath = [[NSIndexPath alloc] initWithIndex:documentIndex];
		[findResultsTreeController insertObject:node atArrangedObjectIndexPath:folderIndexPath];
		
		documentIndex++;
		
		completeString = [[document valueForKey:@"firstTextView"] string];
		searchRange = [[document valueForKey:@"firstTextView"] selectedRange];
		completeStringLength = [completeString length];
		if ([[SMLDefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
			searchRange = NSMakeRange(0, completeStringLength);
		}
		startLocation = searchRange.location;
		resultsInThisDocument = 0;
		
		if ([[SMLDefaults valueForKey:@"UseRegularExpressionsAdvancedFind"] boolValue] == YES) {
			ICUPattern *pattern;
			@try {
				if ([[SMLDefaults valueForKey:@"IgnoreCaseAdvancedFind"] boolValue] == YES) {
					pattern = [[ICUPattern alloc] initWithString:searchString flags:(ICUCaseInsensitiveMatching | ICUMultiline)];
				} else {
					pattern = [[ICUPattern alloc] initWithString:searchString flags:ICUMultiline];
				}
			}
			@catch (NSException *exception) {
				[self alertThatThisIsNotAValidRegularExpression:searchString];
				return;
			}
			@finally {
			}
			
			if ([completeString length] > 0) { // Otherwise ICU throws an exception
				ICUMatcher *matcher;
				if ([[SMLDefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
					matcher = [[ICUMatcher alloc] initWithPattern:pattern overString:completeString];
				} else {
					matcher = [[ICUMatcher alloc] initWithPattern:pattern overString:[completeString substringWithRange:searchRange]];
				}
				
				NSInteger indexTemp;
				while ([matcher findNext]) {
					NSInteger foundLocation = [matcher rangeOfMatch].location + startLocation;
					for (index = 0, lineNumber = 0; index <= foundLocation; lineNumber++) {
						indexTemp = index;
						index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
						if (indexTemp == index) {
							index++; // Make sure it moves forward if it is stuck when searching e.g. for [ \t\n]*
						}
					}
					
					NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
					NSRange rangeMatch = NSMakeRange([matcher rangeOfMatch].location + searchRange.location, [matcher rangeOfMatch].length);
					[findResultsTreeController insertObject:[self preparedResultDictionaryFromString:completeString searchStringLength:searchStringLength range:rangeMatch lineNumber:lineNumber document:document] atArrangedObjectIndexPath:[folderIndexPath indexPathByAddingIndex:resultsInThisDocument]];
					[pool drain];
					
					resultsInThisDocument++;
				}
			}
			
		} else {			
			while (startLocation < completeStringLength) {
				if ([[SMLDefaults valueForKey:@"IgnoreCaseAdvancedFind"] boolValue] == YES) {
					foundRange = [completeString rangeOfString:searchString options:NSCaseInsensitiveSearch range:NSMakeRange(startLocation, NSMaxRange(searchRange) - startLocation)];
				} else {
					foundRange = [completeString rangeOfString:searchString options:NSLiteralSearch range:NSMakeRange(startLocation, NSMaxRange(searchRange) - startLocation)];
				}

				if (foundRange.location == NSNotFound) {
					break;
				}
				for (index = 0, lineNumber = 0; index <= foundRange.location; lineNumber++) {
					index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);	
				}
			
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				[findResultsTreeController insertObject:[self preparedResultDictionaryFromString:completeString searchStringLength:searchStringLength range:foundRange lineNumber:lineNumber document:document] atArrangedObjectIndexPath:[folderIndexPath indexPathByAddingIndex:resultsInThisDocument]];
				[pool drain];
				
				resultsInThisDocument++;
				startLocation = NSMaxRange(foundRange);
			}
		}
		if (resultsInThisDocument == 0) {
			[findResultsTreeController removeObjectAtArrangedObjectIndexPath:folderIndexPath];
			documentIndex--;
		} else {
			numberOfResults += resultsInThisDocument;
		}
			
	}
	
	NSString *searchResultString;
	if (numberOfResults == 0) {
		searchResultString = [NSString stringWithFormat:NSLocalizedString(@"Could not find a match for search-string %@", @"Could not find a match for search-string %@ in Advanced Find"), searchString];
	} else if (numberOfResults == 1) {
		searchResultString = [NSString stringWithFormat:NSLocalizedString(@"Found one match for search-string %@", @"Found one match for search-string %@ in Advanced Find"), searchString];
	} else {
		searchResultString = [NSString stringWithFormat:NSLocalizedString(@"Found %i matches for search-string %@", @"Found %i matches for search-string %@ in Advanced Find"), numberOfResults, searchString];
	}
	
	[findResultTextField setStringValue:searchResultString];
	
	NSArray *nodes = [[findResultsTreeController arrangedObjects] childNodes];
	for (id item in nodes) {
		[findResultsOutlineView expandItem:item expandChildren:NO];
	}
	
	[findResultsOutlineView setDelegate:self];
	
	[[NSGarbageCollector defaultCollector] collectIfNeeded];
}


- (IBAction)replaceAction:(id)sender
{	
	NSString *searchString = [findSearchField stringValue];
	NSString *replaceString = [replaceSearchField stringValue];
	
	NSMutableArray *recentSearches = [[NSMutableArray alloc] initWithArray:[findSearchField recentSearches]];
	if ([recentSearches indexOfObject:searchString] != NSNotFound) {
		[recentSearches removeObject:searchString];
	}
	[recentSearches insertObject:searchString atIndex:0];
	if ([recentSearches count] > 15) {
		[recentSearches removeLastObject];
	}
	[findSearchField setRecentSearches:recentSearches];
	
	NSMutableArray *recentReplaces = [[NSMutableArray alloc] initWithArray:[replaceSearchField recentSearches]];
	if ([recentReplaces indexOfObject:replaceString] != NSNotFound) {
		[recentReplaces removeObject:replaceString];
	}
	[recentReplaces insertObject:replaceString atIndex:0];
	if ([recentReplaces count] > 15) {
		[recentReplaces removeLastObject];
	}
	[replaceSearchField setRecentSearches:recentReplaces];
	
	NSInteger searchStringLength = [searchString length];
	if (!searchStringLength > 0 || SMLCurrentDocument == nil || SMLCurrentProject == nil) {
		NSBeep();
		return;
	}
	
	NSString *completeString;
	NSInteger completeStringLength; 
	NSInteger startLocation;
	NSInteger resultsInThisDocument = 0;
	NSInteger numberOfResults = 0;
	NSRange foundRange;
	NSRange searchRange;
	
	NSEnumerator *enumerator = [self scopeEnumerator];
	for (id document in enumerator) {
		completeString = [[[document valueForKey:@"firstTextScrollView"] documentView] string];
		searchRange = [[[document valueForKey:@"firstTextScrollView"] documentView] selectedRange];
		completeStringLength = [completeString length];
		if ([[SMLDefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
			searchRange = NSMakeRange(0, completeStringLength);
		}
		
		startLocation = searchRange.location;
		resultsInThisDocument = 0;
		
		if ([[SMLDefaults valueForKey:@"UseRegularExpressionsAdvancedFind"] boolValue] == YES) {
			ICUPattern *pattern;
			@try { 
				if ([[SMLDefaults valueForKey:@"IgnoreCaseAdvancedFind"] boolValue] == YES) {
					pattern = [[ICUPattern alloc] initWithString:searchString flags:(ICUCaseInsensitiveMatching | ICUMultiline)];
				} else {
					pattern = [[ICUPattern alloc] initWithString:searchString flags:ICUMultiline];
				}
			}
			@catch (NSException *exception) {
				[self alertThatThisIsNotAValidRegularExpression:searchString];
				return;
			}
			@finally {
			}
			
			ICUMatcher *matcher;
			if ([[SMLDefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
				matcher = [[ICUMatcher alloc] initWithPattern:pattern overString:completeString];
			} else {
				matcher = [[ICUMatcher alloc] initWithPattern:pattern overString:[completeString substringWithRange:searchRange]];
			}
			

			while ([matcher findNext]) {
				resultsInThisDocument++;
			}
	
			
		} else {
			NSInteger searchLength;
			if ([[SMLDefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
				searchLength = completeStringLength;
			} else {
				searchLength = NSMaxRange(searchRange);
			}
			while (startLocation < searchLength) {
				if ([[SMLDefaults valueForKey:@"IgnoreCaseAdvancedFind"] boolValue] == YES) {
					foundRange = [completeString rangeOfString:searchString options:NSCaseInsensitiveSearch range:NSMakeRange(startLocation, NSMaxRange(searchRange) - startLocation)];
				} else {
					foundRange = [completeString rangeOfString:searchString options:NSLiteralSearch range:NSMakeRange(startLocation, NSMaxRange(searchRange) - startLocation)];
				}
				
				if (foundRange.location == NSNotFound) {
					break;
				}
				resultsInThisDocument++;
				startLocation = NSMaxRange(foundRange);
			}
		}
		numberOfResults += resultsInThisDocument;
	}
	
	if (numberOfResults == 0) {
		[findResultTextField setObjectValue:[NSString stringWithFormat:NSLocalizedString(@"Could not find a match for search-string %@", @"Could not find a match for search-string %@ in Advanced Find"), searchString]];
		NSBeep();
		return;
	}
	
	if ([[SMLDefaults valueForKey:@"SuppressReplaceWarning"] boolValue] == YES) {
		[self performNumberOfReplaces:numberOfResults];
	} else {
		NSString *title;
		NSString *defaultButton;
		if ([replaceString length] > 0) {
			if (numberOfResults != 1) {
				title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure that you want to replace %i occurrences of %@ with %@?", @"Ask if you are sure that you want to replace %i occurrences of %@ with %@ in ask-if-sure-you-want-to-replace-in-advanced-find-sheet"), numberOfResults, searchString, replaceString];
			} else {
				title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure that you want to replace one occurrence of %@ with %@?", @"Ask if you are sure that you want to replace one occurrence of %@ with %@ in ask-if-sure-you-want-to-replace-in-advanced-find-sheet"), searchString, replaceString];
			}
			defaultButton = NSLocalizedString(@"Replace", @"Replace-button in ask-if-sure-you-want-to-replace-in-advanced-find-sheet");
		} else {
			if (numberOfResults != 1) {
				title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure that you want to delete %i occurrences of %@?", @"Ask if you are sure that you want to delete %i occurrences of %@ in ask-if-sure-you-want-to-replace-in-advanced-find-sheet"), numberOfResults, searchString, replaceString];
			} else {
				title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure that you want to delete the one occurrence of %@?", @"Ask if you are sure that you want to delete the one occurrence of %@ in ask-if-sure-you-want-to-replace-in-advanced-find-sheet"), searchString, replaceString];
			}
			defaultButton = DELETE_BUTTON;
		}

		NSBeginAlertSheet(title,
						  defaultButton,
						  nil,
						  NSLocalizedString(@"Cancel", @"Cancel-button"),
						  advancedFindWindow,
						  self,
						  @selector(replaceSheetDidEnd:returnCode:contextInfo:),
						  nil,
						  (void *)numberOfResults,
						  NSLocalizedString(@"Remember that you can always Undo any changes", @"Remember that you can always Undo any changes in ask-if-sure-you-want-to-replace-in-advanced-find-sheet"));
	}
}


- (void)replaceSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet close];
    if (returnCode == NSAlertDefaultReturn) { // Replace
		[self performNumberOfReplaces:(NSInteger)contextInfo];
	}
}


- (void)performNumberOfReplaces:(NSInteger)numberOfReplaces
{
	NSString *searchString = [findSearchField stringValue];
	NSString *replaceString = [replaceSearchField stringValue];
	NSRange searchRange;
	
	NSEnumerator *enumerator = [self scopeEnumerator];
	for (id document in enumerator) {
		NSTextView *textView = [[document valueForKey:@"firstTextScrollView"] documentView];
		NSString *originalString = [NSString stringWithString:[textView string]];
		NSMutableString *completeString = [NSMutableString stringWithString:[textView string]];
		searchRange = [[[document valueForKey:@"firstTextScrollView"] documentView] selectedRange];
		if ([[SMLDefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
			searchRange = NSMakeRange(0, [[[[document valueForKey:@"firstTextScrollView"] documentView] string] length]);
		}
		
		if ([[SMLDefaults valueForKey:@"UseRegularExpressionsAdvancedFind"] boolValue] == YES) {		
			ICUPattern *pattern;
			@try {
				if ([[SMLDefaults valueForKey:@"IgnoreCaseAdvancedFind"] boolValue] == YES) {
					pattern = [[ICUPattern alloc] initWithString:searchString flags:(ICUCaseInsensitiveMatching | ICUMultiline)];
				} else {
					pattern = [[ICUPattern alloc] initWithString:searchString flags:ICUMultiline];
				}
			}
			@catch (NSException *exception) {
				[self alertThatThisIsNotAValidRegularExpression:searchString];
				return;
			}
			@finally {
			}
			ICUMatcher *matcher;
			if ([[SMLDefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO) {
				matcher = [[ICUMatcher alloc] initWithPattern:pattern overString:completeString];
			} else {
				matcher = [[ICUMatcher alloc] initWithPattern:pattern overString:[completeString substringWithRange:searchRange]];
			}

			NSMutableString *regularExpressionReplaceString = [NSMutableString stringWithString:replaceString];
			[regularExpressionReplaceString replaceOccurrencesOfString:@"\\n" withString:[NSString stringWithFormat:@"%C", 0x000A] options:NSLiteralSearch range:NSMakeRange(0, [regularExpressionReplaceString length])]; // It doesn't seem to work without this workaround
			[regularExpressionReplaceString replaceOccurrencesOfString:@"\\r" withString:[NSString stringWithFormat:@"%C", 0x000D] options:NSLiteralSearch range:NSMakeRange(0, [regularExpressionReplaceString length])];
			[regularExpressionReplaceString replaceOccurrencesOfString:@"\\t" withString:[NSString stringWithFormat:@"%C", 0x0009] options:NSLiteralSearch range:NSMakeRange(0, [regularExpressionReplaceString length])];
			
			if ([[SMLDefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO) {
				[completeString setString:[matcher replaceAllWithString:regularExpressionReplaceString]];
			} else {
				[completeString replaceCharactersInRange:searchRange withString:[matcher replaceAllWithString:regularExpressionReplaceString]];
			}
			

		} else {
			
			if ([[SMLDefaults valueForKey:@"IgnoreCaseAdvancedFind"] boolValue] == YES) {
				[completeString replaceOccurrencesOfString:searchString withString:replaceString options:NSCaseInsensitiveSearch range:searchRange];
			} else {
				[completeString replaceOccurrencesOfString:searchString withString:replaceString options:NSLiteralSearch range:searchRange];
			}
		}
		
		NSRange selectedRange = [textView selectedRange];
		if (![originalString isEqualToString:completeString] && [originalString length] != 0) {
			if ([textView shouldChangeTextInRange:NSMakeRange(0, [[textView string] length]) replacementString:completeString]) { // Do it this way to mark it as an Undo
				[textView replaceCharactersInRange:NSMakeRange(0, [[textView string] length]) withString:completeString];
				[textView didChangeText];
				[document setValue:[NSNumber numberWithBool:YES] forKey:@"isEdited"];
			}
		}		
		
		if (selectedRange.location <= [[textView string] length]) {
			[textView setSelectedRange:NSMakeRange(selectedRange.location, 0)];
		}
	}
	
	if (numberOfReplaces != 1) {
		[findResultTextField setObjectValue:[NSString stringWithFormat:NSLocalizedString(@"Replaced %i occurrences of %@ with %@", @"Indicate that we replaced %i occurrences of %@ with %@ in update-search-textField-after-replace"), numberOfReplaces, searchString, replaceString]];
	} else {
		[findResultTextField setObjectValue:[NSString stringWithFormat:NSLocalizedString(@"Replaced one occurrence of %@ with %@", @"Indicate that we replaced one occurrence of %@ with %@ in update-search-textField-after-replace"), searchString, replaceString]];
	}
	
	[findResultsTreeController setContent:nil];
	[findResultsTreeController setContent:[NSArray array]];
	[self removeCurrentlyDisplayedDocumentInAdvancedFind];
	[advancedFindWindow makeKeyAndOrderFront:self];
}


- (void)showAdvancedFindWindow
{
	if (advancedFindWindow == nil) {
		[NSBundle loadNibNamed:@"SMLAdvancedFind.nib" owner:self];
	
		[[findResultTextField cell] setBackgroundStyle:NSBackgroundStyleRaised];
				
		[findResultsOutlineView setBackgroundColor:[[NSColor controlAlternatingRowBackgroundColors] objectAtIndex:1]];
		
		[findResultsOutlineView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
		
		SMLAdvancedFindScope searchScope = [[SMLDefaults valueForKey:@"AdvancedFindScope"] integerValue];
		
		if (searchScope == SMLCurrentDocumentScope) {
			[currentDocumentScope setState:NSOnState];
		} else if (searchScope == SMLCurrentProjectScope) {
			[currentProjectScope setState:NSOnState];
		} else if (searchScope == SMLAllDocumentsScope) {
			[allDocumentsScope setState:NSOnState];
		}
		
		[findResultsTreeController setContent:nil];
		[findResultsTreeController setContent:[NSArray array]];
	}
	
	[advancedFindWindow makeKeyAndOrderFront:self];
}


- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification
{
	if ([[findResultsTreeController arrangedObjects] count] == 0) {
		return;
	}
	
	id object = [[findResultsTreeController selectedObjects] objectAtIndex:0];
	if ([[object valueForKey:@"isLeaf"] boolValue] == NO) {
		return;
	}
	
	id document = [SMLBasic objectFromURI:[object valueForKey:@"document"]];
	
	if (document == nil) {
		NSString *title = [NSString stringWithFormat:NSLocalizedString(@"The document %@ is no longer open", @"Indicate that the document %@ is no longer open in Document-is-no-longer-opened-after-selection-in-advanced-find-sheet"), [document valueForKey:@"name"]];
		NSBeginAlertSheet(title,
						  OK_BUTTON,
						  nil,
						  nil,
						  advancedFindWindow,
						  self,
						  nil,
						  NULL,
						  nil,
						  @"");
		return;
	}
	
	currentlyDisplayedDocumentInAdvancedFind = document;
	
	if ([document valueForKey:@"fourthTextView"] == nil) {
		[SMLInterface insertDocumentIntoFourthContentView:document];
	}
	
	[self removeCurrentlyDisplayedDocumentInAdvancedFind];
	[resultDocumentContentView addSubview:[document valueForKey:@"fourthTextScrollView"]];
	if ([[document valueForKey:@"showLineNumberGutter"] boolValue] == YES) {
		[resultDocumentContentView addSubview:[document valueForKey:@"fourthGutterScrollView"]];
	}

	[[document valueForKey:@"lineNumbers"] updateLineNumbersForClipView:[[document valueForKey:@"fourthTextScrollView"] contentView] checkWidth:YES recolour:YES]; // If the window has changed since the view was last visible
		
	NSRange selectRange = NSRangeFromString([[[findResultsTreeController selectedObjects] objectAtIndex:0] valueForKey:@"range"]);
	NSString *completeString = [[document valueForKey:@"fourthTextView"] string];
	if (NSMaxRange(selectRange) > [completeString length]) {
		NSBeep();
		return;
	}
	
	[[document valueForKey:@"fourthTextView"] setSelectedRange:selectRange];
	[[document valueForKey:@"fourthTextView"] scrollRangeToVisible:selectRange];
	[[document valueForKey:@"fourthTextView"] showFindIndicatorForRange:selectRange];
	[findResultsOutlineView setNextKeyView:[document valueForKey:@"fourthTextView"]];
	
	if ([[SMLDefaults valueForKey:@"FocusOnTextInAdvancedFind"] boolValue] == YES) {
		[advancedFindWindow makeFirstResponder:[document valueForKey:@"fourthTextView"]];
	}
}



- (NSEnumerator *)scopeEnumerator
{
	SMLAdvancedFindScope searchScope = [[SMLDefaults valueForKey:@"AdvancedFindScope"] integerValue];
	
	NSEnumerator *enumerator;
	if (searchScope == SMLCurrentProjectScope) {
		enumerator = [[[SMLCurrentProject documentsArrayController] arrangedObjects] reverseObjectEnumerator];
	} else if (searchScope == SMLAllDocumentsScope) {
		enumerator = [[SMLBasic fetchAll:@"DocumentSortKeyName"] reverseObjectEnumerator];
	} else {
		enumerator = [[NSArray arrayWithObject:SMLCurrentDocument] objectEnumerator];
	}
	
	return enumerator;
}


- (id)currentlyDisplayedDocumentInAdvancedFind
{
    return currentlyDisplayedDocumentInAdvancedFind; 
}


- (void)removeCurrentlyDisplayedDocumentInAdvancedFind
{
	[SMLInterface removeAllSubviewsFromView:resultDocumentContentView];
}


- (NSView *)resultDocumentContentView
{
	return resultDocumentContentView;
}


- (NSManagedObjectContext *)managedObjectContext
{
	return SMLManagedObjectContext;
}


- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([[SMLDefaults valueForKey:@"SizeOfDocumentsListTextPopUp"] integerValue] == 0) {
		[cell setFont:[NSFont systemFontOfSize:11.0]];
	} else {
		[cell setFont:[NSFont systemFontOfSize:13.0]];
	}
}	


- (NSMutableDictionary *)preparedResultDictionaryFromString:(NSString *)completeString searchStringLength:(NSInteger)searchStringLength range:(NSRange)foundRange lineNumber:(NSInteger)lineNumber document:(id)document
{
	NSMutableString *displayString = [[NSMutableString alloc] init];
	NSString *lineNumberString = [NSString stringWithFormat:@"%d\t", lineNumber];
	[displayString appendString:lineNumberString];
	NSRange linesRange = [completeString lineRangeForRange:foundRange];
	[displayString appendString:[SMLText replaceAllNewLineCharactersWithSymbolInString:[completeString substringWithRange:linesRange]]];
	
	NSMutableDictionary *node = [NSMutableDictionary dictionary];
	[node setValue:[NSNumber numberWithBool:YES] forKey:@"isLeaf"];
	[node setValue:NSStringFromRange(foundRange) forKey:@"range"];
	[node setValue:[SMLBasic uriFromObject:document] forKey:@"document"];
	NSInteger fontSize;
	if ([[SMLDefaults valueForKey:@"SizeOfDocumentsListTextPopUp"] integerValue] == 0) {
		fontSize = 11;
	} else {
		fontSize = 13;
	}
	NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:displayString attributes:[NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:fontSize] forKey:NSFontAttributeName]];
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[attributedString addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, [displayString length])];
	[attributedString applyFontTraits:NSBoldFontMask range:NSMakeRange(foundRange.location - linesRange.location + [lineNumberString length], foundRange.length)];
	[node setValue:attributedString forKey:@"displayString"];
	
	return node;
}


- (void)alertThatThisIsNotAValidRegularExpression:(NSString *)string
{
	NSString *title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ is not a valid regular expression", @"Localizable3", @"%@ is not a valid regular expression"), string];
	NSBeginAlertSheet(title,
					  OK_BUTTON,
					  nil,
					  nil,
					  advancedFindWindow,
					  self,
					  @selector(notAValidRegularExpressionSheetDidEnd:returnCode:contextInfo:),
					  nil,
					  nil,
					  @"");
}


- (void)notAValidRegularExpressionSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet close];
	[findResultsTreeController setContent:nil];
	[findResultsTreeController setContent:[NSArray array]];
	[advancedFindWindow makeKeyAndOrderFront:nil];
}


- (IBAction)searchScopeChanged:(id)sender
{
	SMLAdvancedFindScope searchScope = [sender tag];

	if (searchScope == SMLCurrentDocumentScope) {
		[currentProjectScope setState:NSOffState];
		[allDocumentsScope setState:NSOffState];
		[currentDocumentScope setState:NSOnState]; // If the user has clicked an already clicked button make sure it is on and not turned off
	} else if (searchScope == SMLCurrentProjectScope) {
		[currentDocumentScope setState:NSOffState];
		[allDocumentsScope setState:NSOffState];
		[currentProjectScope setState:NSOnState];
	} else if (searchScope == SMLAllDocumentsScope) {
		[currentDocumentScope setState:NSOffState];
		[currentProjectScope setState:NSOffState];
		[allDocumentsScope setState:NSOnState];
	}
	
	[SMLDefaults setValue:[NSNumber numberWithInteger:searchScope] forKey:@"AdvancedFindScope"];
	
	if (![[findSearchField stringValue] isEqualToString:@""]) {
		[self findAction:nil];
	}	
}


- (IBAction)showRegularExpressionsHelpPanelAction:(id)sender
{
	[[SMLExtraInterfaceController sharedInstance] showRegularExpressionsHelpPanel];
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	if ([item isLeaf] == NO) {
		return YES;
	} else {
		return NO;
	}
}

@end
