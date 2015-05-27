//
//  SWUtilityButtonView.h
//  SWTableViewCell
//
//  Created by Matt Bowman on 11/27/13.
//  Copyright (c) 2013 Chris Wendel. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SWTableViewCell;

#define kUtilityButtonWidthDefault 90

@interface SWUtilityView : UIView

- (id)initWithUtilityViews:(NSArray *)utilityViews parentCell:(SWTableViewCell *)parentCell;
- (id)initWithFrame:(CGRect)frame utilityViews:(NSArray *)utilityViews parentCell:(SWTableViewCell *)parentCell;

@property (nonatomic, weak, readonly) SWTableViewCell *parentCell;
@property (nonatomic, copy) NSArray *utilityViews;

- (void)setUtilityViews:(NSArray *)utilityViews withWidth:(CGFloat)width;
- (void)pushBackgroundColors;
- (void)popBackgroundColors;

@end
