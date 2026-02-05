//
//  Tag.m
//  Tag
//
//  Created by James Berry on 10/25/13.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2013-2019 James Berry
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//


/*
 FUTURE POTENTIALS:
 
    Potential simple boolean tag query:
 
        foo OR bar
        foo,bar         -- comma same as AND
        foo AND bar
        NOT foo
        foo,bar AND baz
        foo,bar OR baz
        foo,bar AND NOT biz,baz
        *               -- Some tag
        <empty expr>    -- No tag
        
        support glob patterns?
        support queries for both match and find?
 
        Use NSPredicate for both find and match?
 */

#import "ObjCTag.h"
#import "TagName.h"

// This constant doesn't seem to be defined in MDItem.h, so we define it here
NSString* const kMDItemUserTags = @"kMDItemUserTags";


@interface ObjCTag ()

@end



@implementation ObjCTag

- (void)performOperation
{
    switch (self.operationMode)
    {
        case OperationModeSet:
            [self doSet];
            break;
            
        case OperationModeAdd:
            [self doAdd];
            break;
            
        case OperationModeRemove:
            [self doRemove];
            break;
            
        case OperationModeMatch:
            [self doMatch];
            break;
            
        case OperationModeFind:
            [self doFind];
            break;

        case OperationModeUsage:
            [self doUsage];
            break;
            
        case OperationModeList:
            [self doList];
            break;
            
        case OperationModeNone:
        case OperationModeUnknown:
            break;
    }
}


- (BOOL)wildcardInTagSet:(NSSet*)set
{
    TagName* wildcard = [[TagName alloc] initWithTag:@"*"];
    return [set containsObject:wildcard];
}


- (NSMutableSet*)tagSetFromTagArray:(NSArray*)tagArray
{
    NSMutableSet* set = [[NSMutableSet alloc] initWithCapacity:[tagArray count]];
    for (NSString* tag in tagArray)
        [set addObject:[[TagName alloc] initWithTag:tag]];
    return set;
}


- (NSArray*)tagArrayFromTagSet:(NSSet*)tagSet
{
    NSMutableArray* array = [[NSMutableArray alloc] initWithCapacity:[tagSet count]];
    for (TagName* tag in tagSet)
        [array addObject:tag.visibleName];
    return array;
}


- (void)enumerateDirectory:(NSURL*)directoryURL withBlock:(void (^)(NSURL *URL))block
{
    NSURL* baseURL = directoryURL;
    
    NSInteger enumerationOptions = 0;
    if (!_displayAllFiles)
        enumerationOptions |= NSDirectoryEnumerationSkipsHiddenFiles;
    if (!_recurseDirectories)
        enumerationOptions |= NSDirectoryEnumerationSkipsSubdirectoryDescendants;
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator* enumerator = [fileManager enumeratorAtURL:baseURL
                                          includingPropertiesForKeys:@[NSURLTagNamesKey]
                                                             options:enumerationOptions
                                                        errorHandler:nil];
    
    NSString* baseURLString = [baseURL absoluteString];
    for (NSObject* obj in enumerator)
    {
        @autoreleasepool {
            NSURL* fullURL = (NSURL*)obj;
            
            // The directory enumerator returns full URLs, not partial URLs, which are what we really want.
            // So remake the URL as a partial URL if possible
            NSURL* URL = fullURL;
            NSString* fullURLString = [fullURL absoluteString];
            if ([fullURLString hasPrefix:baseURLString])
            {
                NSString* relativePart = [fullURLString substringFromIndex:[baseURLString length]];
                URL = [NSURL URLWithString:relativePart relativeToURL:baseURL];
            }
            
            block(URL);
        }
    }
}


- (void)enumerateURLsWithBlock:(void (^)(NSURL *URL))block
{
    if (!block)
        return;
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    if ([self.URLs count] == 0)
    {
        // No URLs were provided on the command line; enumerate the current directory
        NSURL* currentDirectoryURL = [NSURL fileURLWithPath:[fileManager currentDirectoryPath]];
        [self enumerateDirectory:currentDirectoryURL withBlock:block];
    }
    else
    {
        // Process URLs provided on the command line
        for (NSURL* URL in self.URLs)
        {
            @autoreleasepool {
                // Invoke the block
                block(URL);
                
                // If we want to enter or recurse directories then do so
                // if we have a directory
                if (_enterDirectories || _recurseDirectories)
                {
                    NSNumber* isDir = nil;
                    [URL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
                    if ([isDir boolValue])
                        [self enumerateDirectory:URL withBlock:block];
                }
            }
        }
    }
}


- (void)doSet
{
    // Only perform set on specified URLs
    // (we don't implicitly enumerate the current directory)
    if ([self.URLs count] == 0)
        return;
    
    // Enumerate the provided URLs, setting tags on each
    // --all, --enter, and --recursive apply
    NSArray* tagArray = [self tagArrayFromTagSet:self.tags];
    [self enumerateURLsWithBlock:^(NSURL *URL) {
        NSError* error;
        if (![URL setResourceValue:tagArray forKey:NSURLTagNamesKey error:&error])
             NSLog(@"Error setting tags on %@: %@", URL, error);
    }];
}


- (void)doAdd
{
    // If there are no tags to add, we're done
    if (![self.tags count])
        return;
    
    // Only perform add on specified URLs
    // (we don't implicitly enumerate the current directory)
    if ([self.URLs count] == 0)
        return;

    // Enumerate the provided URLs, adding tags to each
    // --all, --enter, and --recursive apply
    [self enumerateURLsWithBlock:^(NSURL *URL) {
        NSError* error;
        
        // Get the existing tags
        NSArray* existingTags;
        if (![URL getResourceValue:&existingTags forKey:NSURLTagNamesKey error:&error])
             NSLog(@"Error getting tags from %@: %@", URL, error);
        
        // Form the union of the existing tags + new tags.
        NSMutableSet* tagSet = [self tagSetFromTagArray:existingTags];
        [tagSet unionSet:self.tags];
        
        // Set all the new tags onto the item
        if (![URL setResourceValue:[self tagArrayFromTagSet:tagSet] forKey:NSURLTagNamesKey error:&error])
             NSLog(@"Error setting tags on %@: %@", URL, error);
    }];
}


- (void)doRemove
{
    // If there are no tags to remove, we're done
    if (![self.tags count])
        return;
    
    // Only perform remove on specified URLs
    // (we don't implicitly enumerate the current directory)
    if ([self.URLs count] == 0)
        return;
    
    BOOL matchAny = [self wildcardInTagSet:self.tags];
    
    // Enumerate the provided URLs, removing tags from each
    // --all, --enter, and --recursive apply
    [self enumerateURLsWithBlock:^(NSURL *URL) {
        NSError* error;
        
        // Get existing tags from the URL
        NSArray* existingTags;
        if (![URL getResourceValue:&existingTags forKey:NSURLTagNamesKey error:&error])
             NSLog(@"Error getting tags from %@: %@", URL, error);
        
        // Form the revised array of tags
        NSArray* revisedTags;
        if (matchAny)
        {
            // We matched the wildcard, so remove all tags from the item
            revisedTags = [[NSArray alloc] init];
        }
        else
        {
            // Existing tags minus tags to remove
            NSMutableSet* tagSet = [self tagSetFromTagArray:existingTags];
            [tagSet minusSet:self.tags];
            revisedTags = [self tagArrayFromTagSet:tagSet];
        }
        
        // Set the revised tags onto the item
        if (![URL setResourceValue:revisedTags forKey:NSURLTagNamesKey error:&error])
             NSLog(@"Error setting tags on %@: %@", URL, error);
    }];
}


- (void)doMatch
{
    BOOL matchAny = [self wildcardInTagSet:self.tags];
    BOOL matchNone = [self.tags count] == 0;
    
    // Enumerate the provided URLs or current directory, listing all paths that match the specified tags
    // --all, --enter, and --recursive apply
    [self enumerateURLsWithBlock:^(NSURL *URL) {
        NSError* error;
        
        // Get the tags on the URL
        NSArray* tagArray;
        if (![URL getResourceValue:&tagArray forKey:NSURLTagNamesKey error:&error])
             NSLog(@"Error getting tags from %@: %@", URL, error);
        NSUInteger tagCount = [tagArray count];
        
        // If the set of existing tags contains all of the required
        // tags then emit
        if (   (matchAny && tagCount > 0)
            || (matchNone && tagCount == 0)
            || (!matchNone && [self.tags isSubsetOfSet:[self tagSetFromTagArray:tagArray]])
            )
        {
            // Match found
            // append url to self Matched
            [self.Matched addObject:URL];
        }
    }];
}


- (void)doList
{
    // Enumerate the provided URLs or current directory, listing the tags for each path
    // --all, --enter, and --recursive apply
    [self enumerateURLsWithBlock:^(NSURL* URL) {
        // Get the tags
        NSError* error;
        NSArray* tagArray;
        if (![URL getResourceValue:&tagArray forKey:NSURLTagNamesKey error:&error])
             NSLog(@"Error getting tags from %@: %@", URL, error);
        
        // Emit convert tagArray to NSSet
        self.tags = [self tagSetFromTagArray:tagArray];
    }];
}


- (void)doFind
{
    [self findGutsWithUsage:NO];
}


- (void)doUsage
{
    [self findGutsWithUsage:YES];
}


- (void)findGutsWithUsage:(BOOL)usageMode
{
    // Start a metadata search for files containing all of the given tags
    NSMetadataQuery* metadataQuery = [self performMetadataSearchForTags:self.tags usageMode:usageMode];
    
    // Emit the results of the query, either for tags or for usage
    if (usageMode)
    {
        // Print the statistics, ignoring the general query results
        NSDictionary* valueLists = [metadataQuery valueLists];
        NSArray* tagTuples = valueLists[kMDItemUserTags];
        for (NSMetadataQueryAttributeValueTuple* tuple in tagTuples)
        {
            // Usage stats
        }
    }
    else
    {
        // Print the query results
        [metadataQuery enumerateResultsUsingBlock:^(NSMetadataItem* theResult, NSUInteger idx, BOOL * _Nonnull stop) {
            @autoreleasepool {
                NSString* path = [theResult valueForAttribute:(NSString *)kMDItemPath];
                if (path)
                {
                    NSURL* URL = [NSURL fileURLWithPath:path];
                    NSArray* tagArray = [theResult valueForAttribute:kMDItemUserTags];
                    
                    // Result found
                }
            }
        }];
    }
}


- (NSPredicate*)formQueryPredicateForTags:(NSSet*)tagSet
{
    BOOL matchAny = [self wildcardInTagSet:tagSet];
    BOOL matchNone = [tagSet count] == 0;

    NSPredicate* result;
    if (matchAny)
    {
        result = [NSPredicate predicateWithFormat:@"%K LIKE '*'", kMDItemUserTags];
    }
    else if (matchNone)
    {
        result = [NSPredicate predicateWithFormat:@"NOT %K LIKE '*'", kMDItemUserTags];
    }
    else if ([tagSet count] == 1)
    {
        result = [NSPredicate predicateWithFormat:@"%K ==[c] %@", kMDItemUserTags, ((TagName*)tagSet.anyObject).visibleName];
    }
    else // if tagSet count > 0
    {
        NSMutableArray* subpredicates = [NSMutableArray new];
        for (TagName* tag in tagSet)
            [subpredicates addObject:[NSPredicate predicateWithFormat:@"%K ==[c] %@", kMDItemUserTags, tag.visibleName]];
        result = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    }
    
    return result;
}


- (NSArray*)searchScopesFromSearchScope:(SearchScope)scope
{
    NSMutableArray* result = [[NSMutableArray alloc] init];

    // Add URLs in which to explicitly search
    if ([self.URLs count])
        [result addObjectsFromArray:self.URLs];
    
    // Add any specified search scopes
    switch (scope)
    {
        case SearchScopeNone:
            break;
        case SearchScopeHome:
            [result addObject:NSMetadataQueryUserHomeScope];
            break;
        case SearchScopeLocal:
            [result addObject:NSMetadataQueryLocalComputerScope];
            break;
        case SearchScopeNetwork:
            [result addObjectsFromArray:@[NSMetadataQueryLocalComputerScope,NSMetadataQueryNetworkScope]];
            break;
    }
    
    // In the absence of any scope, the search is not scoped
    
    return result;
}


- (NSMetadataQuery*)performMetadataSearchForTags:(NSSet*)tagSet usageMode:(BOOL)usageMode
{
    // Create the metadata query
    NSMetadataQuery* metadataQuery = [[NSMetadataQuery alloc] init];
    
    // Register the notifications for batch and completion updates
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queryComplete:)
                                                 name:NSMetadataQueryDidFinishGatheringNotification
                                               object:metadataQuery];
    
    // Configure the search predicate
    NSPredicate *searchPredicate = [self formQueryPredicateForTags:tagSet];
    [metadataQuery setPredicate:searchPredicate];
    
    // Set the search scope
    NSArray *searchScopes = [self searchScopesFromSearchScope:self.searchScope];
    [metadataQuery setSearchScopes:searchScopes];
    
    // Configure the sorting of the results
    // (note that the query can't sort by the item path, which makes sorting less useful)
    NSSortDescriptor *sortKeys = [[NSSortDescriptor alloc] initWithKey:(id)kMDItemDisplayName
                                                             ascending:YES];
    [metadataQuery setSortDescriptors:[NSArray arrayWithObject:sortKeys]];
    
    // If we're collecting usage stats, request that values be saved for tags
    if (usageMode)
        [metadataQuery setValueListAttributes:@[kMDItemUserTags]];
    
    // Ask the query to send notifications on the main thread, which will
    // ensure we process them on the main thread, and will also ensure that our
    // main thread is kicked so that the run loop will iterate and thus complete.
    [metadataQuery setOperationQueue:[NSOperationQueue mainQueue]];
    
    // Begin the asynchronous query
    [metadataQuery startQuery];

    // Enter the run loop, exiting only when the query is done
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (!metadataQuery.stopped && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
        ;
    
    // Remove the notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSMetadataQueryDidFinishGatheringNotification
                                                  object:metadataQuery];
    
    return metadataQuery;
}


- (void)queryComplete:(NSNotification*)sender
{
    // Stop the query, the single pass is completed.
    // This will cause our runloop loop to terminate.
    NSMetadataQuery* metadataQuery = sender.object;
    [metadataQuery stopQuery];
}


@end
