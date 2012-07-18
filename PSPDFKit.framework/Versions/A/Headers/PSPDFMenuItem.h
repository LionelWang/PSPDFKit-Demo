//
//  PSPDFMenuItem.h
//  PSPDFKit
//
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import "PSPDFKitGlobal.h"

// Oh UIMenuItem, why don't you have a target action pattern? Well, lets make one with blocks!
// Note: This has one flaw, it doesn't work if the titles are equal inside on UIMenuController.
//       (but that would be a weird use case anyway)
@interface PSPDFMenuItem : UIMenuItem

// Initialize UIMenuItem with a block.
// If you use PSPDFMenuItem but the classic initWithTitle:selector initializer, this will work and be handled just like a UIMenuItem.
- (id)initWithTitle:(NSString *)title block:(PSPDFBasicBlock)block;

// Menu Item can be enabled/disabled. (disable will hide it from the UIMenuController)
@property(nonatomic, assign, getter=isEnabled) BOOL enabled;

// Install menu handler to an object. Can be called multiple times.
+ (void)installMenuHandlerForObject:(id)object;

@end