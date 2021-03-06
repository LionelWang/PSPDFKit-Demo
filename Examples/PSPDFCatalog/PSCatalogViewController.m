//
//  PSCatalogViewController.m
//  PSPDFCatalog
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSCatalogViewController.h"
#import "PSCSectionDescriptor.h"
#import "PSCGridController.h"
#import "PSCTabbedExampleViewController.h"
#import "PSCDocumentSelectorController.h"
#import "PSCEmbeddedTestController.h"
#import "PSCustomToolbarController.h"
#import "PSCAnnotationTestController.h"
#import "PSCSplitDocumentSelectorController.h"
#import "PSCSplitPDFViewController.h"
#import "PSCBookmarkParser.h"
#import "PSCSettingsBarButtonItem.h"
#import "PSCKioskPDFViewController.h"
#import "PSCEmbeddedAnnotationTestViewController.h"
#import "PSCustomTextSelectionMenuController.h"
#import "PSCExampleAnnotationViewController.h"
#import "PSCCustomDrawingViewController.h"
#import "PSCBookViewController.h"

// set to auto-choose a section; debugging aid.
//#define kPSPDFAutoSelectCellNumber [NSIndexPath indexPathForRow:5 inSection:1]

@interface PSCatalogViewController () <PSPDFViewControllerDelegate, PSPDFDocumentDelegate, PSCDocumentSelectorControllerDelegate> {
    BOOL _firstShown;
    NSArray *_content;
}
@end

@implementation PSCatalogViewController

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        self.title = PSPDFLocalize(@"PSPDFKit Catalog");
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Catalog" style:UIBarButtonItemStylePlain target:nil action:nil];

        // common paths
        NSURL *samplesURL = [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:@"Samples"];
        NSURL *hackerMagURL = [samplesURL URLByAppendingPathComponent:kHackerMagazineExample];

        NSMutableArray *content = [NSMutableArray array];

        // Full Apps
        PSCSectionDescriptor *appSection = [[PSCSectionDescriptor alloc] initWithTitle:@"Full Example Apps" footer:@"Can be used as a template for your own apps."];

        [appSection addContent:[[PSContent alloc] initWithTitle:@"PSPDFViewController playground" block:^{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];
            PSPDFViewController *controller = [[PSCKioskPDFViewController alloc] initWithDocument:document];
            return controller;
        }]];

        [appSection addContent:[[PSContent alloc] initWithTitle:@"PSPDFKit Kiosk" class:[PSCGridController class]]];

        // the tabbed browser needs iOS5 or greater.
        PSPDF_IF_IOS5_OR_GREATER(
        [appSection addContent:[[PSContent alloc] initWithTitle:@"Tabbed Browser" block:^{
            if (PSIsIpad()) {
                return (UIViewController *)[PSCTabbedExampleViewController new];
            }else {
                // on iPhone, we do things a bit different, and push/pull the controller.
                return (UIViewController *)[[PSCDocumentSelectorController alloc] initWithDelegate:self];
            }
        }]];
        );
        
        [content addObject:appSection];

        PSPDFDocument *hcakerMagDoc = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];

        // pre-cache whole document
        [[PSPDFCache sharedCache] cacheDocument:hcakerMagDoc startAtPage:0 size:PSPDFSizeNative];

        [appSection addContent:[[PSContent alloc] initWithTitle:@"Fast single PDF" block:^{
            PSPDFViewController *controller = [[PSCKioskPDFViewController alloc] initWithDocument:hcakerMagDoc];
            // don't use thumbnails if the PDF is not rendered.
            controller.renderingMode = PSPDFPageRenderingModeFullPageBlocking;
            return controller;
        }]];

        // PSPDFDocument data provider test
        PSCSectionDescriptor *documentTests = [[PSCSectionDescriptor alloc] initWithTitle:@"PSPDFDocument data providers" footer:@"PSPDFDocument is highly flexible."];

        /// PSPDFDocument works with a NSURL
        [documentTests addContent:[[PSContent alloc] initWithTitle:@"NSURL" block:^{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];
            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            controller.rightBarButtonItems = @[controller.emailButtonItem, controller.searchButtonItem, controller.outlineButtonItem, controller.viewModeButtonItem];
            return controller;
        }]];

        /// A NSData (both memory-mapped and full)
        [documentTests addContent:[[PSContent alloc] initWithTitle:@"NSData" block:^{
            NSData *data = [NSData dataWithContentsOfMappedFile:[hackerMagURL path]];
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithData:data];
            document.title = @"NSData PDF";
            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            controller.rightBarButtonItems = @[controller.emailButtonItem, controller.searchButtonItem, controller.outlineButtonItem, controller.viewModeButtonItem];
            return controller;
        }]];

        /// And even a CGDocumentProvider (can be used for encryption)
        [documentTests addContent:[[PSContent alloc] initWithTitle:@"CGDocumentProvider" block:^{
            NSData *data = [NSData dataWithContentsOfURL:hackerMagURL options:NSDataReadingMappedIfSafe error:NULL];
            CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(data));
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithDataProvider:dataProvider];
            document.title = @"CGDataProviderRef PDF";
            CGDataProviderRelease(dataProvider);
            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            controller.rightBarButtonItems = @[controller.emailButtonItem, controller.searchButtonItem, controller.outlineButtonItem, controller.viewModeButtonItem];
            return controller;
        }]];
        [content addObject:documentTests];

        /// PSPDFDocument works with multiple NSURLs
        [documentTests addContent:[[PSContent alloc] initWithTitle:@"Multiple files" block:^{
            NSArray *files = @[@"A.pdf", @"B.pdf", @"C.pdf", @"D.pdf"];
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithBaseURL:samplesURL files:files];
            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            controller.rightBarButtonItems = @[controller.emailButtonItem, controller.searchButtonItem, controller.outlineButtonItem, controller.viewModeButtonItem];
            return controller;
        }]];

        [documentTests addContent:[[PSContent alloc] initWithTitle:@"Multiple NSData objects (memory mapped)" block:^{

            static PSPDFDocument *document = nil;
            if (!document) {
                NSURL *file1 = [samplesURL URLByAppendingPathComponent:@"A.pdf"];
                NSURL *file2 = [samplesURL URLByAppendingPathComponent:@"B.pdf"];
                NSURL *file3 = [samplesURL URLByAppendingPathComponent:@"C.pdf"];
                NSData *data1 = [NSData dataWithContentsOfURL:file1 options:NSDataReadingMappedIfSafe error:NULL];
                NSData *data2 = [NSData dataWithContentsOfURL:file2 options:NSDataReadingMappedIfSafe error:NULL];
                NSData *data3 = [NSData dataWithContentsOfURL:file3 options:NSDataReadingMappedIfSafe error:NULL];
                document = [PSPDFDocument PDFDocumentWithDataArray:@[data1, data2, data3]];
            }else {
                // this is not needed, just an example how to use the changed dataArray (the data will be changed when annotations are written back)
                document = [PSPDFDocument PDFDocumentWithDataArray:document.dataArray];
            }

            // make sure your NSData objects are either small or memory mapped; else you're getting into memory troubles.
            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            controller.rightBarButtonItems = @[controller.annotationButtonItem, controller.emailButtonItem, controller.searchButtonItem, controller.outlineButtonItem, controller.viewModeButtonItem];
            return controller;
        }]];

        [documentTests addContent:[[PSContent alloc] initWithTitle:@"Multiple NSData objects" block:^{
            // make data document static in this example, so that the annotations will be saved (the NSData array will get changed)
            static PSPDFDocument *document = nil;
            if (!document) {
                NSURL *file1 = [samplesURL URLByAppendingPathComponent:@"A.pdf"];
                NSURL *file2 = [samplesURL URLByAppendingPathComponent:@"B.pdf"];
                NSURL *file3 = [samplesURL URLByAppendingPathComponent:@"C.pdf"];
                NSData *data1 = [NSData dataWithContentsOfURL:file1];
                NSData *data2 = [NSData dataWithContentsOfURL:file2];
                NSData *data3 = [NSData dataWithContentsOfURL:file3];
                document = [PSPDFDocument PDFDocumentWithDataArray:@[data1, data2, data3]];
            }

            // make sure your NSData objects are either small or memory mapped; else you're getting into memory troubles.
            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            controller.rightBarButtonItems = @[controller.annotationButtonItem, controller.emailButtonItem, controller.searchButtonItem, controller.outlineButtonItem, controller.viewModeButtonItem];
            return controller;
        }]];

        PSCSectionDescriptor *annotationSection = [[PSCSectionDescriptor alloc] initWithTitle:@"Annotation Tests" footer:@"PSPDFKit supports all common PDF annotations, including Highlighing, Underscore, Strikeout, Comment and Ink."];

        [annotationSection addContent:[[PSContent alloc] initWithTitle:@"Test PDF annotation writing" block:^{

            NSString *docsFolder = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
            NSString *newPath = [docsFolder stringByAppendingPathComponent:[hackerMagURL lastPathComponent]];
            NSError *error;
            if(![[NSFileManager new] fileExistsAtPath:newPath] &&
               ![[NSFileManager new] copyItemAtPath:[hackerMagURL path] toPath:newPath error:&error]) {
                NSLog(@"Error while copying %@: %@", [hackerMagURL path], error);
            }
            PSPDFDocument *hackerDocument = [PSPDFDocument PDFDocumentWithURL:[NSURL fileURLWithPath:newPath]];
            return [[PSCEmbeddedAnnotationTestViewController alloc] initWithDocument:hackerDocument];
        }]];

        [annotationSection addContent:[[PSContent alloc] initWithTitle:@"Add custom image annotation" block:^{
            PSPDFDocument *hackerDocument = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];
            return [[PSCAnnotationTestController alloc] initWithDocument:hackerDocument];
        }]];

        [annotationSection addContent:[[PSContent alloc] initWithTitle:@"Custom annotations with multiple files" block:^{
            NSArray *files = @[@"A.pdf", @"B.pdf", @"C.pdf", @"D.pdf"];
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithBaseURL:samplesURL files:files];

            // We're lazy here. 2 = UIViewContentModeScaleAspectFill
            PSPDFLinkAnnotation *aVideo = [[PSPDFLinkAnnotation alloc] initWithSiteLinkTarget:@"pspdfkit://[contentMode=2]localhost/Bundle/big_buck_bunny.mp4"];
            aVideo.boundingBox = [document pageInfoForPage:5].pageRect;
            [document addAnnotations:@[aVideo ] forPage:5];

            PSPDFLinkAnnotation *anImage = [[PSPDFLinkAnnotation alloc] initWithSiteLinkTarget:@"pspdfkit://[contentMode=2]localhost/Bundle/exampleImage.jpg"];
            anImage.boundingBox = [document pageInfoForPage:2].pageRect;
            [document addAnnotations:@[anImage] forPage:2];

            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            return controller;
        }]];

        [annotationSection addContent:[[PSContent alloc] initWithTitle:@"Programmatically create annotations" block:^{
            // we use a NSData document here but it'll work even better with a file-based variant.
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithData:[NSData dataWithContentsOfURL:hackerMagURL options:NSDataReadingMappedIfSafe error:NULL]];
            document.title = @"Programmatically create annotations";

            NSMutableArray *annotations = [NSMutableArray array];
            CGFloat maxHeight = [document pageInfoForPage:0].pageRect.size.height;
            for (int i=0; i<5; i++) {
                PSPDFNoteAnnotation *noteAnnotation = [PSPDFNoteAnnotation new];
                // width/height will be ignored for note annotations.
                noteAnnotation.boundingBox = CGRectMake(100, 50 + i*maxHeight/5, 50, 50);
                [annotations addObject:noteAnnotation];
            }
            [document addAnnotations:annotations forPage:0];

            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            return controller;
        }]];

        [content addObject:annotationSection];

        PSCSectionDescriptor *storyboardSection = [[PSCSectionDescriptor alloc] initWithTitle:@"Storyboards" footer:@""];
        [storyboardSection addContent:[[PSContent alloc] initWithTitle:@"Init with Storyboard" block:^UIViewController *{
            UIViewController *controller = nil;
            @try {
                // will throw an exception if the file MainStoryboard.storyboard is missing
                controller = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil] instantiateInitialViewController];
            }
            @catch (NSException *exception) {
                [[[UIAlertView alloc] initWithTitle:@"Warning" message:@"You need to manually add the file MainStoryboard.storyboard and increase the deployment target to iOS5 - since PSPDFKit is compatible with iOS 4.3 upwards, we removed that file to be able to compile." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }
            return controller;
        }]];
        [content addObject:storyboardSection];

        // PSPDFViewController customization examples
        PSCSectionDescriptor *customizationSection = [[PSCSectionDescriptor alloc] initWithTitle:@"PSPDFViewController customization" footer:@""];

        [customizationSection addContent:[[PSContent alloc] initWithTitle:@"Using a NIB" block:^{
            return [[PSCEmbeddedTestController alloc] initWithNibName:@"EmbeddedNib" bundle:nil];
        }]];

        [customizationSection addContent:[[PSContent alloc] initWithTitle:@"Custom Toolbar" block:^{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];
            return [[PSCustomToolbarController alloc] initWithDocument:document];
        }]];

        [customizationSection addContent:[[PSContent alloc] initWithTitle:@"Disable Toolbar" block:^{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];

            PSPDFViewController *pdfController = [[PSPDFViewController alloc] initWithDocument:document];
            self.navigationController.navigationBarHidden = YES;

            // pop back after 5 seconds.
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 5.f * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self.navigationController popViewControllerAnimated:YES];
            });

            // sample settings
            pdfController.pageTransition = PSPDFPageCurlTransition;
            pdfController.toolbarEnabled = NO;
            pdfController.fitToWidthEnabled = NO;

            return pdfController;
        }]];

        [customizationSection addContent:[[PSContent alloc] initWithTitle:@"Custom Text Selection Menu" block:^{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];
            return [[PSCustomTextSelectionMenuController alloc] initWithDocument:document];
        }]];

        [customizationSection addContent:[[PSContent alloc] initWithTitle:@"Custom Background Color" block:^{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];
            PSPDFViewController *pdfController = [[PSPDFViewController alloc] initWithDocument:document];
            pdfController.backgroundColor = [UIColor brownColor];
            return pdfController;
        }]];

        [content addObject:customizationSection];

        PSCSectionDescriptor *encryptedSection = [[PSCSectionDescriptor alloc] initWithTitle:@"Passwords" footer:@"Password is test123"];

        // Bookmarks
        NSURL *protectedPDFURL = [samplesURL URLByAppendingPathComponent:@"protected.pdf"];

        [encryptedSection addContent:[[PSContent alloc] initWithTitle:@"Password preset" block:^UIViewController *{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:protectedPDFURL];
            [document unlockWithPassword:@"test123"];
            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            return controller;
        }]];

        [encryptedSection addContent:[[PSContent alloc] initWithTitle:@"Password not preset; dialog" block:^UIViewController *{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:protectedPDFURL];
            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            return controller;
        }]];

        [content addObject:encryptedSection];


        PSCSectionDescriptor *subclassingSection = [[PSCSectionDescriptor alloc] initWithTitle:@"Subclassing" footer:@"Examples how to subclass PSPDFKit"];

        // Bookmarks
        [subclassingSection addContent:[[PSContent alloc] initWithTitle:@"Capture Bookmarks" block:^UIViewController *{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];
            document.overrideClassNames = @{(id)[PSPDFBookmarkParser class] : [PSCBookmarkParser class]};
            PSPDFViewController *controller = [[PSPDFViewController alloc] initWithDocument:document];
            controller.rightBarButtonItems = @[controller.bookmarkButtonItem, controller.searchButtonItem, controller.outlineButtonItem, controller.viewModeButtonItem];
            return controller;
        }]];

        // Vertical always-visible annotation bar
        [subclassingSection addContent:[[PSContent alloc] initWithTitle:@"Vertical always-visible annotation bar" block:^UIViewController *{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];
            PSPDFViewController *controller = [[PSCExampleAnnotationViewController alloc] initWithDocument:document];
            return controller;
        }]];

        // uses pageCurl which is a iOS5+ feature.
        PSPDF_IF_IOS5_OR_GREATER(
        [subclassingSection addContent:[[PSContent alloc] initWithTitle:@"Book example" block:^UIViewController *{
            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];
            PSPDFViewController *controller = [[PSCBookViewController alloc] initWithDocument:document];
            return controller;
        }]];
        );

        [content addObject:subclassingSection];


        PSCSectionDescriptor *delegateSection = [[PSCSectionDescriptor alloc] initWithTitle:@"Delegate" footer:@"How to use PSPDFViewControllerDelegate"];
        [delegateSection addContent:[[PSContent alloc] initWithTitle:@"Custom drawing" block:^UIViewController *{

            PSPDFDocument *document = [PSPDFDocument PDFDocumentWithURL:hackerMagURL];
            document.title = @"Custom drawing";
            PSPDFViewController *controller = [[PSCCustomDrawingViewController alloc] initWithDocument:document];
            return controller;
        }]];
        [content addObject:delegateSection];


        // iPad only examples
        if (PSIsIpad()) {
            PSCSectionDescriptor *iPadTests = [[PSCSectionDescriptor alloc] initWithTitle:@"iPad only" footer:@""];
            [iPadTests addContent:[[PSContent alloc] initWithTitle:@"SplitView" block:^{
                UISplitViewController *splitVC = [[UISplitViewController alloc] init];
                splitVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Split" image:[UIImage imageNamed:@"shoebox"] tag:3];
                PSCSplitDocumentSelectorController *tableVC = [[PSCSplitDocumentSelectorController alloc] init];
                UINavigationController *tableNavVC = [[UINavigationController alloc] initWithRootViewController:tableVC];
                PSCSplitPDFViewController *hostVC = [[PSCSplitPDFViewController alloc] init];
                UINavigationController *hostNavVC = [[UINavigationController alloc] initWithRootViewController:hostVC];
                tableVC.masterVC = hostVC;
                splitVC.delegate = hostVC;
                splitVC.viewControllers = @[tableNavVC, hostNavVC];
                // Splitview controllers can't just be added to a UINavigationController
                self.view.window.rootViewController = splitVC;
                return (UIViewController *)nil;
            }]];
            [content addObject:iPadTests];
        }

        _content = content;
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

#ifdef kPSPDFAutoSelectCellNumber
    if (!_firstShown && kPSPDFAutoSelectCellNumber) {
        BOOL success = NO;
        NSUInteger numberOfSections = [self numberOfSectionsInTableView:self.tableView];
        NSUInteger numberOfRowsInSection = 0;
        if (kPSPDFAutoSelectCellNumber.section < numberOfSections) {
            numberOfRowsInSection = [self tableView:self.tableView numberOfRowsInSection:kPSPDFAutoSelectCellNumber.section];
            if (kPSPDFAutoSelectCellNumber.row < numberOfRowsInSection) {
                [self tableView:self.tableView didSelectRowAtIndexPath:kPSPDFAutoSelectCellNumber];
                success = YES;
            }
        }
        if (!success) {
            NSLog(@"Invalid row/section count: %@ (sections: %d, rows:%d)", kPSPDFAutoSelectCellNumber, numberOfSections, numberOfRowsInSection);
        }
    }
    _firstShown = YES;
#endif
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return PSIsIpad() ? YES : toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [_content count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[_content[section] contentDescriptors] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [_content[section] title];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [_content[section] footer];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"PSCatalogCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    PSContent *contentDescriptor = [_content[indexPath.section] contentDescriptors][indexPath.row];
    cell.textLabel.text = contentDescriptor.title;
    return cell;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSContent *contentDescriptor = [_content[indexPath.section] contentDescriptors][indexPath.row];
    UIViewController *controller;
    if (contentDescriptor.classToInvoke) {
        controller = [contentDescriptor.classToInvoke new];
    }else {
        controller = contentDescriptor.block();
    }
    if (controller) {
        if ([controller isKindOfClass:[UINavigationController class]]) {
            controller = [((UINavigationController *)controller) topViewController];
        }
        [self.navigationController pushViewController:controller animated:YES];
    }else {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFDocumentSelectorControllerDelegate

- (void)documentSelectorController:(PSCDocumentSelectorController *)controller didSelectDocument:(PSPDFDocument *)document {
    // create controller and merge new documents with last saved state.
    PSPDFTabbedViewController *tabbedViewController = [PSCTabbedExampleViewController new];
    [tabbedViewController restoreStateAndMergeWithDocuments:@[document]];

    // add fade transition for navigationBar.
    [controller.navigationController.navigationBar.layer addAnimation:PSPDFFadeTransition() forKey:kCATransition];
    [controller.navigationController pushViewController:tabbedViewController animated:YES];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFViewController

@end

@implementation UINavigationController (PSPDFKeyboardDismiss)

// Fixes a behavior of UIModalPresentationFormSheet
// http://stackoverflow.com/questions/3372333/ipad-keyboard-will-not-dismiss-if-modal-view-controller-presentation-style-is-ui
- (BOOL)disablesAutomaticKeyboardDismissal {
    return NO;
}
@end
