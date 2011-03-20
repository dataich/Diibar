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
    [[_recentlyItem submenu] removeAllItems];
    NSArray *bookmarks = [NSArray arrayWithContentsOfFile:[self getPlistPath]];
    for (NSDictionary *bookmark in bookmarks) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[bookmark valueForKey:@"title"] action:@selector(openBrowser:) keyEquivalent:@""];
        [item setToolTip:[bookmark valueForKey:@"url"]];
        [[_recentlyItem submenu] addItem:item];
        [item release];
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
    NSArray *json = [jsonString JSONValue];
    NSLog(@"%@", jsonString); 
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

@end
