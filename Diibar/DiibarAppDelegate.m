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
    
    [self createBookmarkItems];
    [self getBookmarks];    
}

- (void)getBookmarks {
    [_preferencesPanel setIsVisible:NO];

    NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"values.username"];
    NSString *password = [[NSUserDefaults standardUserDefaults] stringForKey:@"values.password"];

    if (!(username && password)) {
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
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)createBookmarkItems {
    _tagsDictionary = [[NSMutableDictionary alloc] init];
    [[_recentItem submenu] removeAllItems];

    NSArray *bookmarks = [NSArray arrayWithContentsOfFile:[self getPlistPath]];
    
    NSInteger count = 0;
    for (NSDictionary *bookmark in bookmarks) {
        NSMenuItem *itemInRecent = [[NSMenuItem alloc] initWithTitle:[bookmark valueForKey:@"title"] action:@selector(openBrowser:) keyEquivalent:@""];
        [itemInRecent setToolTip:[bookmark valueForKey:@"url"]];
        [[_recentItem submenu] addItem:itemInRecent];
        [itemInRecent release];
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
            NSMenuItem *tagItem = [_tagsDictionary valueForKey:tag];
            if(!tagItem) {
                NSMenu *menu = [[NSMenu alloc] init];
                tagItem = [[[NSMenuItem alloc] initWithTitle:tag action:nil keyEquivalent:@""] autorelease];
                [tagItem setSubmenu:menu];
                [_tagsDictionary setObject:tagItem forKey:tag];
                
                [menu release];
            }
            
            NSMenuItem *itemInTag = [[NSMenuItem alloc] initWithTitle:[bookmark valueForKey:@"title"] action:@selector(openBrowser:) keyEquivalent:@""];
            [itemInTag setToolTip:[bookmark valueForKey:@"url"]];
            [[tagItem submenu] addItem:itemInTag];
            [itemInTag release];
        }
    }
    
    NSArray *sortedKeys = [[_tagsDictionary allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for(NSString *key in sortedKeys) {
        NSMenuItem *tagItem = [_tagsDictionary valueForKey:key];
        [_menu insertItem:tagItem atIndex:5];
    }
}

- (IBAction)showPreferencesPanel {
    CGRect screenFrame = [[NSScreen mainScreen] frame];
    CGRect panelFrame = [_preferencesPanel frame];
    [_preferencesPanel setFrameTopLeftPoint:NSPointFromCGPoint(CGPointMake(screenFrame.size.width / 2 - panelFrame.size.width / 2 , screenFrame.size.height - 200))];
    [_preferencesPanel setIsVisible:YES];
    [_preferencesPanel orderFrontRegardless];
    
    NSLog(@"%f", screenFrame.size.width);
    NSLog(@"%f", [_preferencesPanel frame].size.width);
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
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"connectionDidFinishLoading");
    NSString *jsonString = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
    NSLog(@"%@", jsonString);
    NSArray *json = [jsonString JSONValue];
    [jsonString release];
    
    if([json isKindOfClass:[NSArray class]]) {
        if(0 < [json count]) {
            [_jsonArray addObjectsFromArray:json];
            _start = _start + count;
            [self fetchBookmarks];
        } else {
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
            
            [self createBookmarkItems];
        }
    } else if ([json isKindOfClass:[NSDictionary class]]) {
        [self fetchBookmarks];
    }

}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge proposedCredential]) {
        [connection cancel];
        NSRunAlertPanel(@"Wrong username or password", 
                        @"Set username and password correctly.",
                        @"Preferences", nil, nil);
        [self showPreferencesPanel];
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
}

@end
