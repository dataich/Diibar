//
//  DiibarAppDelegate.m
//  Diibar
//
//  Created by Taichiro Yoshida on 11/03/17.
//  Copyright 2011 Taichiro Yoshida. All rights reserved.
//

#import "DiibarAppDelegate.h"
#import <JSON/JSON.h>
#import "Config.h"

@implementation DiibarAppDelegate

@synthesize window;
@synthesize _preferencesPanel;

static const NSString *applicationName = @"Diibar";
static const NSInteger count = 100;
static const NSInteger maxRecent = 100;
static const NSInteger defaultBrowser = 999;
static const NSInteger retryCount = 10;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [_applicationName setTitleWithMnemonic:[NSString stringWithFormat:@"%@", applicationName]];
    [_version setTitleWithMnemonic:[NSString stringWithFormat:@"Version %@", version]];

    _statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [_statusItem setHighlightMode:YES];
    [_statusItem setTitle:@"Diibar"]; 
    //    [statusItem setImage:[NSImage imageNamed:@"example.png"]];
    [_statusItem setMenu:_menu];
    [_statusItem setEnabled:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getBookmarks) name:NSWindowWillCloseNotification object:_preferencesPanel];
    [_preferenceItem setAction:@selector(showPreferencesPanel)];
    _syncInProgress = NO;
    
    [self getBrowsers];
    [self createBookmarkItems];
    [self getBookmarks];    
}

- (void)getBrowsers {
    _triedCount = 0;
    
    NSArray *identifiers = (NSArray*)LSCopyAllHandlersForURLScheme((CFStringRef)@"http");
    _browsers = [[NSMutableArray alloc] initWithCapacity:[identifiers count]];
    
    NSArray *browsers = [NSArray arrayWithObjects:
                         @"org.mozilla.firefox",
                         @"com.rockmelt.RockMelt",
                         @"com.apple.Safari",
                         @"com.google.chrome",
                         @"com.operasoftware.Opera",
                         nil];
    for (NSString *identifier in identifiers) {
        for (NSString *browserIdentifier in browsers) {   
            if ([identifier compare:browserIdentifier] == NSOrderedSame) {
                [_browsers addObject:identifier];
                break;
            }    
        }
    }
    [identifiers release];
}

- (void)getBookmarks {
    if(_syncInProgress) {
        return;
    }
    
    _syncInProgress = YES;
    [_preferencesPanel setIsVisible:NO];

    NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"values.username"];
    NSString *password = [[NSUserDefaults standardUserDefaults] stringForKey:@"values.password"];

    if (!(username && password)) {
        _syncInProgress = NO;
        NSRunAlertPanel(@"Set your Diigo's account", 
                        @"Your username and password are required to get bookmarks",
                        @"Preferences", nil, nil);
        [self showPreferencesPanel];
        return;
    }
    
    _jsonArray = [[NSMutableArray alloc] init];
    _start = 0;
    [self fetchBookmarks];
}

- (void)fetchBookmarks {
    NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"values.username"];

    NSString *uri = [NSString stringWithFormat:@"https://secure.diigo.com/api/v2/bookmarks?filter=all&count=%d&key=%@&user=%@&start=%d", count, kKey, username, _start];
    NSLog(@"%@", uri);
    
    NSURL *url = [NSURL URLWithString:uri];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
    
    [connection start];
}

- (void)openBrowser:(NSMenuItem*)item {
    NSURL *url = [NSURL URLWithString:[item toolTip]];
    
    if([item tag] == defaultBrowser) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    } else {
        [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url]
                        withAppBundleIdentifier:[_browsers objectAtIndex:[item tag]]
                                        options:NSWorkspaceLaunchDefault
                 additionalEventParamDescriptor:nil
                              launchIdentifiers:nil];
    }
}

- (void)createBookmarkItems {
    _tagsDictionary = [[NSMutableDictionary alloc] init];
    [[_recentItem submenu] removeAllItems];
    while (4 < [[_menu itemArray] count]) {
        [_menu removeItemAtIndex:4];
    }
    [_menu addItem:[NSMenuItem separatorItem]];

    NSArray *bookmarks = [NSArray arrayWithContentsOfFile:[self getPlistPath]];
    
    NSInteger count = 0;
    for (NSDictionary *bookmark in bookmarks) {
        NSMenuItem *itemInRecent = [self createBookmarkItem:[bookmark valueForKey:@"title"] url:[bookmark valueForKey:@"url"]];
        [[_recentItem submenu] addItem:itemInRecent];
        
        count++;
        
        if(maxRecent <= count) {
            break;
        }
    }
    
    NSSortDescriptor *sortDescripter = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
    NSArray *sortDescripters = [NSArray arrayWithObject:sortDescripter];
    NSArray *sortedBookmarks = [[NSArray arrayWithArray:bookmarks] sortedArrayUsingDescriptors:sortDescripters];
        
    for (NSDictionary *bookmark in sortedBookmarks) {
        NSArray *tags = [[bookmark valueForKey:@"tags"] componentsSeparatedByString:@"'"];

        for(NSString *tag in tags) {
            if([tag compare:@"no_tag"] == NSOrderedSame) {
                tag = @"No Tag";
            }
            NSMenuItem *tagItem = [_tagsDictionary valueForKey:tag];
            if(!tagItem) {
                NSMenu *menu = [[NSMenu alloc] init];
                tagItem = [[[NSMenuItem alloc] initWithTitle:tag action:nil keyEquivalent:@""] autorelease];
                [tagItem setSubmenu:menu];
                [_tagsDictionary setObject:tagItem forKey:tag];
                
                [menu release];
            }
            
            NSMenuItem *itemInTag = [self createBookmarkItem:[bookmark valueForKey:@"title"] url:[bookmark valueForKey:@"url"]];
            [[tagItem submenu] addItem:itemInTag];
        }
    }
    
    NSArray *sortedKeys = [[_tagsDictionary allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSInteger tagItemIndex = 5;
    for(NSString *key in sortedKeys) {
        NSMenuItem *tagItem = [_tagsDictionary valueForKey:key];
        
        if([key compare:@"No Tag"] == NSOrderedSame) {
            [_menu insertItem:tagItem atIndex:4];
        } else {
            [_menu insertItem:tagItem atIndex:tagItemIndex];
        }
        tagItemIndex++;
        
    }
    
    _syncInProgress = NO;
}

- (NSMenuItem*)createBookmarkItem:(NSString*)title url:(NSString*)url {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openBrowser:) keyEquivalent:@""];
    NSMenu *menu = [[NSMenu alloc] init];
    [item setSubmenu:menu];
    [item setToolTip:url];
    [item setTag:defaultBrowser];
    [menu release];
    
    NSInteger index = 0;
    for(NSString *identifier in _browsers) {
        NSArray *separatedArray = [identifier componentsSeparatedByString:@"."];
        NSString *browserName = [separatedArray objectAtIndex:[separatedArray count] - 1];
        NSRange range = NSMakeRange(0, 1);
        browserName = [browserName stringByReplacingCharactersInRange:range
                                                           withString:[[browserName substringWithRange:range] uppercaseString]];
        
        NSMenuItem *itemInBookmark = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Open in %@", browserName] action:@selector(openBrowser:) keyEquivalent:@""];
        [itemInBookmark setToolTip:url];
        [itemInBookmark setTag:index];
        [[item submenu] addItem:itemInBookmark];
        [itemInBookmark release];
        index++;
    }
    
    return [item autorelease];
    
}

- (IBAction)showPreferencesPanel {
    NSRect screenFrame = [[NSScreen mainScreen] frame];
    NSRect panelFrame = [_preferencesPanel frame];
    
    NSPoint point;
    point.x = screenFrame.size.width / 2 - panelFrame.size.width / 2;
    point.y = screenFrame.size.height - 200;
    
    [_preferencesPanel setFrameTopLeftPoint:point];
    [_preferencesPanel setIsVisible:YES];
    [_preferencesPanel orderFrontRegardless];
    
    NSLog(@"%f", screenFrame.size.width);
    NSLog(@"%f", [_preferencesPanel frame].size.width);
}

- (IBAction)toggleLoginItem:(id)sender {
	NSString *applicationPath = [[NSBundle mainBundle] bundlePath];
    
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
	if (loginItems) {
		if ([sender state] == NSOnState)
			[self addLoginItem:loginItems ForPath:applicationPath];
		else
			[self removeLoginItem:loginItems ForPath:applicationPath];
	}

	CFRelease(loginItems);
}

- (void)addLoginItem:(LSSharedFileListRef )loginItems ForPath:(NSString *)applicationPath {
	CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:applicationPath];
	LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);		
	if (item) {
		CFRelease(item);
    }
}

- (void)removeLoginItem:(LSSharedFileListRef )loginItems ForPath:(NSString *)applicationPath {
	UInt32 seedValue;
	CFURLRef pathRef;
    
    CFArrayRef loginItemRefs = LSSharedFileListCopySnapshot(loginItems, &seedValue);
    
	for (id item in (NSArray *)loginItemRefs) {		
		LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
        
		if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &pathRef, NULL) == noErr) {
			if ([[(NSURL *)pathRef path] hasPrefix:applicationPath]) {
				LSSharedFileListItemRemove(loginItems, itemRef);
                CFRelease(pathRef);
                break;
			}

			CFRelease(pathRef);
		}		
	}
    
	CFRelease(loginItemRefs);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"didReceiveResponse");
    _data = [[NSMutableData alloc] initWithData:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSLog(@"didReceiveData");
    [_data appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"didFailWithError:%@", [error description]);

    NSRunAlertPanel(@"Error", [error localizedDescription], @"Quit", nil, nil);
    _syncInProgress = NO;
    
    [[NSApplication sharedApplication] terminate:self];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"connectionDidFinishLoading");
    NSString *jsonString = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
    NSLog(@"%@", jsonString);
    NSArray *json = [jsonString JSONValue];
    [jsonString release];
    
    if([json isKindOfClass:[NSArray class]]) {
        _triedCount = 0;        
        if(0 < [json count]) {
            [_jsonArray addObjectsFromArray:json];
            _start = _start + count;
            [self fetchBookmarks];
        } else {
            [self savePlist];
            [self createBookmarkItems];
        }
    } else if ([json isKindOfClass:[NSDictionary class]]) {
        _triedCount++;
        
        if(retryCount <= _triedCount)
        {
            NSRunAlertPanel(@"API Limit Exceeded", @"Sync bookmarks is not completed.\n", @"Close", nil, nil);
            [self savePlist];
            [self createBookmarkItems];
            
        } else {
            [self fetchBookmarks];
        }

        
    }

}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge proposedCredential]) {
        [connection cancel];
        NSRunAlertPanel(@"Wrong username or password", 
                        @"Set username and password correctly.",
                        @"Preferences", nil, nil);
        [self showPreferencesPanel];
        _syncInProgress = NO;
        return;
        
    } else {
        NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"values.username"];
        NSString *password = [[NSUserDefaults standardUserDefaults] stringForKey:@"values.password"];
        NSURLCredential *credential = [NSURLCredential credentialWithUser:username
                                                                 password:password
                                                              persistence:NSURLCredentialPersistenceNone];
        [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
    }
}

- (void) savePlist {
    NSString *directory = [self getPlistDirectory];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDirectory = YES;
    if(![manager fileExistsAtPath:directory isDirectory:&isDirectory]) {
        NSError *error;
        if(![manager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"%@", [error description]); 
        }
    }
    
    NSString *plistPath = [self getPlistPath];
    if(![_jsonArray writeToFile:plistPath atomically:YES]) {
        NSLog(@"could not write plist file.");
        exit(0);
    }
    _jsonArray = nil;
    [_jsonArray release];
    
}

- (NSString*)getPlistDirectory {
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES); 
    NSString *directory = [NSString stringWithFormat:@"%@/%@", [directories objectAtIndex:0], applicationName];

    return directory;
}

- (NSString*)getPlistPath {
    NSString *directory = [self getPlistDirectory];
    NSString *plistPath = [NSString stringWithFormat:@"%@/%@.plist", directory, applicationName];
    
    return plistPath;
}

- (void)dealloc {
    [super dealloc];

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [window release];
    [_statusItem release];
    [_menu release];
    [_recentItem release];
    [_data release];
    [_tagsDictionary release];
    [_browsers release];
}

@end
