//
//  SplitTableViewController.m
//  PSPDFCatalog
//
//  Copyright (c) 2011-2012 Peter Steinberger. All rights reserved.
//

#import "PSCSplitDocumentSelectorController.h"
#import "PSCSplitPDFViewController.h"
#import "PSCAppDelegate.h"

@implementation PSCSplitDocumentSelectorController

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
    if ((self = [super initWithDelegate:self])) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.f, 600.f);

        UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Catalog" style:UIBarButtonItemStyleBordered target:self action:@selector(backToCatalog)];

        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cycle", @"") style:UIBarButtonItemStylePlain target:self action:@selector(cycleAction)];

        PSPDF_IF_IOS5_OR_GREATER(self.navigationItem.leftBarButtonItems = @[backBarButtonItem, [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Deselect", @"") style:UIBarButtonItemStylePlain target:self action:@selector(deselectAction)]];);
        PSPDF_IF_PRE_IOS5(self.navigationItem.leftBarButtonItem = backBarButtonItem;);

    }
    return self;
}

- (void)dealloc {
    _masterVC = nil;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)backToCatalog {
    UIWindow *window = self.view.window;
    // ensure popover is dismissed or we'll crash
    [self.masterVC.masterPopoverController dismissPopoverAnimated:NO];
    window.rootViewController = ((PSCAppDelegate *)[UIApplication sharedApplication].delegate).catalog;
}

// tests fast cycling through the pdf elements
- (void)cycleAction {
    [[PSPDFCache sharedCache] clearCache];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        for (int i = 0; i < [self.content count]; i++) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:i inSection:0];
                [self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle];
                [self tableView:self.tableView didSelectRowAtIndexPath:selectedIndexPath];
            });
            //[NSThread sleepForTimeInterval:0.1];
        }

        // and back up!
        for (int i = [self.content count]-1; i >= 0; i--) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:i inSection:0];
                [self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle];
                [self tableView:self.tableView didSelectRowAtIndexPath:selectedIndexPath];
            });
           // [NSThread sleepForTimeInterval:0.05];
        }
    });
}

- (void)deselectAction {
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    [self.masterVC displayDocument:nil];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSCDocumentSelectorControllerDelegate

- (void)documentSelectorController:(PSCDocumentSelectorController *)controller didSelectDocument:(PSPDFDocument *)document {
    [self.masterVC displayDocument:document];
}

@end
