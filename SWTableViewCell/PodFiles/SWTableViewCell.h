//
//  SWTableViewCell.h
//  SWTableViewCell
//
//  Created by Chris Wendel on 9/10/13.
//  Copyright (c) 2013 Chris Wendel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "SWCellScrollView.h"
#import "SWLongPressGestureRecognizer.h"
#import "NSMutableArray+SWUtilityButtons.h"

@class SWTableViewCell;

typedef NS_ENUM(NSInteger, SWCellState)
{
    kCellStateCenter,
    kCellStateLeft,
    kCellStateRight,
};

@protocol SWTableViewCellDelegate <NSObject>

@optional
- (void)swipeableTableViewCell:(SWTableViewCell *)cell scrollingToState:(SWCellState)state;
- (BOOL)swipeableTableViewCellShouldHideUtilityViewsOnSwipe:(SWTableViewCell *)cell;
- (BOOL)swipeableTableViewCell:(SWTableViewCell *)cell canSwipeToState:(SWCellState)state;
- (void)swipeableTableViewCellDidEndScrolling:(SWTableViewCell *)cell;
- (void)swipeableTableViewCell:(SWTableViewCell *)cell didScroll:(UIScrollView *)scrollView;

@end

@interface SWTableViewCell : UITableViewCell

@property (nonatomic, copy) NSArray *leftUtilityViews;
@property (nonatomic, copy) NSArray *rightUtilityViews;

@property (nonatomic, weak) id <SWTableViewCellDelegate> delegate;

- (void)setRightUtilityViews:(NSArray *)rightUtilityViews withWidth:(CGFloat) width;
- (void)setLeftUtilityViews:(NSArray *)leftUtilityViews withWidth:(CGFloat) width;
- (void)hideUtilityViewsAnimated:(BOOL)animated;
- (void)showLeftUtilityViewsAnimated:(BOOL)animated;
- (void)showRightUtilityViewsAnimated:(BOOL)animated;

- (BOOL)isUtilityViewHidden;

@end
