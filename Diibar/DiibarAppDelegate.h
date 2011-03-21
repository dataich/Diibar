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
    IBOutlet NSMenuItem *_tagsItem;
    IBOutlet NSMenuItem *_preferenceItem;
    NSMutableData *_data;
    NSMutableDictionary *_tagsDictionary;
    NSMutableArray *_jsonArray;
    NSInteger _start;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSPanel *_preferencesPanel;
@property (nonatomic, retain) NSMutableData *_data;
@property (nonatomic, retain) NSMutableDictionary *_tagsDictionary;
@property (nonatomic, retain) NSMutableArray *_jsonArray;

- (void)getBookmarks;
- (void)fetchBookmarks;
- (void)createBookmarkItems;
- (IBAction)showPreferencesPanel;
- (NSString*)getPlistDirectory;
- (NSString*)getPlistPath;

@end
