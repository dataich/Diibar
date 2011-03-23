//
//  DiibarAppDelegate.h
//  Diibar
//
//  Created by Taichiro Yoshida on 11/03/17.
//  Copyright 2011 Taichiro Yoshida. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DiibarAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *window;
    NSPanel *_preferencesPanel;
    NSStatusItem *_statusItem;
    IBOutlet NSMenu *_menu;
    IBOutlet NSMenuItem *_recentItem;
    IBOutlet NSMenuItem *_preferenceItem;
    IBOutlet NSTextField *_applicationName;
    IBOutlet NSTextField *_version;
    NSMutableData *_data;
    NSMutableDictionary *_tagsDictionary;
    NSMutableArray *_jsonArray;
    NSInteger _start;
    NSInteger _triedCount;
    Boolean _syncInProgress;
    
    NSMutableArray *_browsers;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSPanel *_preferencesPanel;

- (void)getBookmarks;
- (void)fetchBookmarks;
- (void)getBrowsers;
- (NSMenuItem*)createBookmarkItem:(NSString*)title url:(NSString*)url;
- (void)createBookmarkItems;
- (void)savePlist;
- (IBAction)showPreferencesPanel;
- (IBAction)toggleLoginItem:(id)sender;
- (void)addLoginItem:(LSSharedFileListRef )loginItems ForPath:(NSString *)applicationPath;
- (void)removeLoginItem:(LSSharedFileListRef )loginItems ForPath:(NSString *)applicationPath;
- (NSString*)getPlistDirectory;
- (NSString*)getPlistPath;

@end
