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

#import "SMLSyntaxDefinitionManagedObject.h"
#import "SMLApplicationDelegate.h"
#import "SMLVariousPerformer.h"

@implementation SMLSyntaxDefinitionManagedObject

- (void)didChangeValueForKey:(NSString *)key
{	
	[super didChangeValueForKey:key];
	
	if ([[SMLApplicationDelegate sharedInstance] hasFinishedLaunching] == NO) {
		return;
	}
	
	if ([SMLVarious isChangingSyntaxDefinitionsProgrammatically] == YES) {
		return;
	}

	NSDictionary *changedObject = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[self valueForKey:@"name"], [self valueForKey:@"extensions"], nil] forKeys:[NSArray arrayWithObjects:@"name", @"extensions", nil]];
	if ([SMLDefaults valueForKey:@"ChangedSyntaxDefinitions"]) {
		NSMutableArray *changedSyntaxDefinitionsArray = [NSMutableArray arrayWithArray:[SMLDefaults valueForKey:@"ChangedSyntaxDefinitions"]];
		NSArray *array = [NSArray arrayWithArray:changedSyntaxDefinitionsArray];
		for (id item in array) {
			if ([[item valueForKey:@"name"] isEqualToString:[self valueForKey:@"name"]]) {
				[changedSyntaxDefinitionsArray removeObject:item];
			}					
		}
		[changedSyntaxDefinitionsArray addObject:changedObject];
		[SMLDefaults setValue:changedSyntaxDefinitionsArray forKey:@"ChangedSyntaxDefinitions"];
	} else {
		[SMLDefaults setValue:[NSArray arrayWithObject:changedObject] forKey:@"ChangedSyntaxDefinitions"];		
	}
}
@end
