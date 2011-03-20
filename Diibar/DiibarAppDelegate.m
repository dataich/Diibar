//
//  DiibarAppDelegate.m
//  Diibar
//
//  Created by Taichiro Yoshida on 11/03/17.
//  Copyright 2011 Taichiro Yoshida. All rights reserved.
//

#import "DiibarAppDelegate.h"
#import <JSON/JSON.h>
#import "Secret.h"

@implementation DiibarAppDelegate

@synthesize window;
@synthesize _data;
@synthesize _tagsDictionary;

static const NSString *applicationName = @"Diibar";

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [_statusItem setHighlightMode:YES];
    [_statusItem setTitle:@"Diibar"]; 
    //    [statusItem setImage:[NSImage imageNamed:@"example.png"]];
    [_statusItem setMenu:_menu];
    [_statusItem setEnabled:YES];
    
    [self createBookmarkItems];
    [self getBookmarks];
}

- (void)getBookmarks {
    NSString *uri = [NSString stringWithFormat:@"https://secure.diigo.com/api/v2/bookmarks?filter=all&count=100&key=%@&user=%@", kKey, kUser];
    
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
    [[_tagsItem submenu] removeAllItems];

    NSArray *bookmarks = [NSArray arrayWithContentsOfFile:[self getPlistPath]];
    
    for (NSDictionary *bookmark in bookmarks) {
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
            [[tagItem submenu] addItem:itemInTag];
            [itemInTag release];
        }
    }
    
    NSArray *sortedKeys = [[_tagsDictionary allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for(NSString *key in sortedKeys) {
        NSMenuItem *tagItem = [_tagsDictionary valueForKey:key];
        [[_tagsItem submenu] addItem:tagItem];        
    }
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
    NSLog(@"didFailWithError");    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"connectionDidFinishLoading");
    NSString *jsonString = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
    NSLog(@"%@", jsonString);
    [jsonString release];
    NSArray *json = [jsonString JSONValue];
    NSString *directory = [self getPlistDirectory];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDirectory = YES;
    if(![manager fileExistsAtPath:directory isDirectory:&isDirectory]) {
        NSError *error;
        if(![manager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"%@", [error description]); 
        }
    }

    NSSortDescriptor *sortDescripter = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
    NSArray *sortDescripters = [NSArray arrayWithObject:sortDescripter];
    json = [json sortedArrayUsingDescriptors:sortDescripters];
    
    NSString *plistPath = [self getPlistPath];
    if(![json writeToFile:plistPath atomically:YES]) {
        NSLog(@"could not write plist file.");
        exit(0);
    }
    
    [self createBookmarkItems];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge proposedCredential]) {
        [connection cancel];
    } else {
        NSURLCredential *credential = [NSURLCredential credentialWithUser:kUser
                                                                 password:kPassword
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

    [window release];
    [_statusItem release];
    [_menu release];
    [_tagsItem release];
    [_data release];
    [_tagsDictionary release];
}

@end
