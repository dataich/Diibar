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
    NSStatusItem *_statusItem;
    IBOutlet NSMenu *_menu;
    IBOutlet NSMenuItem *_recentlyItem;
    IBOutlet NSMenuItem *_tagsItem;
    NSMutableData *_data;
    NSMutableDictionary *_tagsDictionary;
}

@property (assign) IBOutlet NSWindow *window;
@property (nonatomic, retain) NSMutableData *_data;
@property (nonatomic, retain) NSMutableDictionary *_tagsDictionary;

- (void)getBookmarks;
- (void)createBookmarkItems;
- (NSString*)getPlistDirectory;
- (NSString*)getPlistPath;

@end
