//
//  SWTableViewCell.m
//  SWTableViewCell
//
//  Created by Chris Wendel on 9/10/13.
//  Copyright (c) 2013 Chris Wendel. All rights reserved.
//

#import "SWTableViewCell.h"
#import "SWUtilityView.h"

static NSString * const kTableViewCellContentView = @"UITableViewCellContentView";

#define kSectionIndexWidth 15
#define kAccessoryTrailingSpace 15
#define kLongPressMinimumDuration 0.16f

@interface SWTableViewCell () <UIScrollViewDelegate,  UIGestureRecognizerDelegate>

@property (nonatomic, weak) UITableView *containingTableView;

@property (nonatomic, strong) UIPanGestureRecognizer *tableViewPanGestureRecognizer;

@property (nonatomic, assign) SWCellState cellState; // The state of the cell within the scroll view, can be left, right or middle
@property (nonatomic, assign) CGFloat additionalRightPadding;

@property (nonatomic, strong) UIScrollView *cellScrollView;
@property (nonatomic, strong) SWUtilityView *leftUtilityViewsView, *rightUtilityViewsView;
@property (nonatomic, strong) UIView *leftUtilityClipView, *rightUtilityClipView;
@property (nonatomic, strong) NSLayoutConstraint *leftUtilityClipConstraint, *rightUtilityClipConstraint;

@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

- (CGFloat)leftUtilityViewsWidth;
- (CGFloat)rightUtilityViewsWidth;
- (CGFloat)utilityButtonsPadding;

- (CGPoint)contentOffsetForCellState:(SWCellState)state;
- (void)updateCellState;

- (BOOL)shouldHighlight;

@end

@implementation SWTableViewCell {
    UIView *_contentCellView;
    BOOL layoutUpdating;
}

#pragma mark Initializers

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self)
    {
        [self initializer];
    }
    
    return self;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (self)
    {
        [self initializer];
    }
    
    return self;
}

- (void)initializer
{
    layoutUpdating = NO;
    // Set up scroll view that will host our cell content
    self.cellScrollView = [[SWCellScrollView alloc] init];
    self.cellScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cellScrollView.delegate = self;
    self.cellScrollView.showsHorizontalScrollIndicator = NO;
    self.cellScrollView.scrollsToTop = NO;
    self.cellScrollView.scrollEnabled = YES;
    
    _contentCellView = [[UIView alloc] init];
    [self.cellScrollView addSubview:_contentCellView];
    
    // Add the cell scroll view to the cell
    UIView *contentViewParent = self;
    UIView *clipViewParent = self.cellScrollView;
    if (![NSStringFromClass([[self.subviews objectAtIndex:0] class]) isEqualToString:kTableViewCellContentView])
    {
        // iOS 7
        contentViewParent = [self.subviews objectAtIndex:0];
        clipViewParent = self;
    }
    NSArray *cellSubviews = [contentViewParent subviews];
    [self insertSubview:self.cellScrollView atIndex:0];
    for (UIView *subview in cellSubviews)
    {
        [_contentCellView addSubview:subview];
    }
    
    // Set scroll view to perpetually have same frame as self. Specifying relative to superview doesn't work, since the latter UITableViewCellScrollView has different behaviour.
    [self addConstraints:@[
                           [NSLayoutConstraint constraintWithItem:self.cellScrollView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0],
                           [NSLayoutConstraint constraintWithItem:self.cellScrollView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0],
                           [NSLayoutConstraint constraintWithItem:self.cellScrollView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0],
                           [NSLayoutConstraint constraintWithItem:self.cellScrollView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0 constant:0.0],
                           ]];
    
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewTapped:)];
    self.tapGestureRecognizer.cancelsTouchesInView = NO;
    self.tapGestureRecognizer.delegate             = self;
    [self.cellScrollView addGestureRecognizer:self.tapGestureRecognizer];

    self.longPressGestureRecognizer = [[SWLongPressGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewPressed:)];
    self.longPressGestureRecognizer.cancelsTouchesInView = NO;
    self.longPressGestureRecognizer.minimumPressDuration = kLongPressMinimumDuration;
    self.longPressGestureRecognizer.delegate = self;
    [self.cellScrollView addGestureRecognizer:self.longPressGestureRecognizer];

    // Create the left and right utility button views, as well as vanilla UIViews in which to embed them.  We can manipulate the latter in order to effect clipping according to scroll position.
    // Such an approach is necessary in order for the utility views to sit on top to get taps, as well as allow the backgroundColor (and private UITableViewCellBackgroundView) to work properly.

    self.leftUtilityClipView = [[UIView alloc] init];
    self.leftUtilityClipConstraint = [NSLayoutConstraint constraintWithItem:self.leftUtilityClipView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0];
    self.leftUtilityViewsView = [[SWUtilityView alloc] initWithUtilityViews:nil
                                                                   parentCell:self];

    self.rightUtilityClipView = [[UIView alloc] initWithFrame:self.bounds];
    self.rightUtilityClipConstraint = [NSLayoutConstraint constraintWithItem:self.rightUtilityClipView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0 constant:0.0];
    self.rightUtilityViewsView = [[SWUtilityView alloc] initWithUtilityViews:nil
                                                                    parentCell:self];

    
    UIView *clipViews[] = { self.rightUtilityClipView, self.leftUtilityClipView };
    NSLayoutConstraint *clipConstraints[] = { self.rightUtilityClipConstraint, self.leftUtilityClipConstraint };
    UIView *buttonViews[] = { self.rightUtilityViewsView, self.leftUtilityViewsView };
    NSLayoutAttribute alignmentAttributes[] = { NSLayoutAttributeRight, NSLayoutAttributeLeft };
    
    for (NSUInteger i = 0; i < 2; ++i)
    {
        UIView *clipView = clipViews[i];
        NSLayoutConstraint *clipConstraint = clipConstraints[i];
        UIView *buttonView = buttonViews[i];
        NSLayoutAttribute alignmentAttribute = alignmentAttributes[i];
        
        clipConstraint.priority = UILayoutPriorityDefaultHigh;
        
        clipView.translatesAutoresizingMaskIntoConstraints = NO;
        clipView.clipsToBounds = YES;
        
        [clipViewParent addSubview:clipView];
        [self addConstraints:@[
                               // Pin the clipping view to the appropriate outer edges of the cell.
                               [NSLayoutConstraint constraintWithItem:clipView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0],
                               [NSLayoutConstraint constraintWithItem:clipView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0],
                               [NSLayoutConstraint constraintWithItem:clipView attribute:alignmentAttribute relatedBy:NSLayoutRelationEqual toItem:self attribute:alignmentAttribute multiplier:1.0 constant:0.0],
                               clipConstraint,
                               ]];
        
        [clipView addSubview:buttonView];
        [self addConstraints:@[
                               // Pin the button view to the appropriate outer edges of its clipping view.
                               [NSLayoutConstraint constraintWithItem:buttonView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:clipView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0],
                               [NSLayoutConstraint constraintWithItem:buttonView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:clipView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0],
                               [NSLayoutConstraint constraintWithItem:buttonView attribute:alignmentAttribute relatedBy:NSLayoutRelationEqual toItem:clipView attribute:alignmentAttribute multiplier:1.0 constant:0.0],
                               
                               // Constrain the maximum button width so that at least a button's worth of contentView is left visible. (The button view will shrink accordingly.)
                               [NSLayoutConstraint constraintWithItem:buttonView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationLessThanOrEqual toItem:self.contentView attribute:NSLayoutAttributeWidth multiplier:1.0 constant:-kUtilityButtonWidthDefault],
                               ]];
    }
}

static NSString * const kTableViewPanState = @"state";

- (void)removeOldTableViewPanObserver
{
    [_tableViewPanGestureRecognizer removeObserver:self forKeyPath:kTableViewPanState];
}

- (void)dealloc
{
    _cellScrollView.delegate = nil;
    [self removeOldTableViewPanObserver];
}

- (void)setContainingTableView:(UITableView *)containingTableView
{
    [self removeOldTableViewPanObserver];
    
    _tableViewPanGestureRecognizer = containingTableView.panGestureRecognizer;
    
    _containingTableView = containingTableView;
    
    if (containingTableView)
    {
        // Check if the UITableView will display Indices on the right. If that's the case, add a padding
        if ([_containingTableView.dataSource respondsToSelector:@selector(sectionIndexTitlesForTableView:)])
        {
            NSArray *indices = [_containingTableView.dataSource sectionIndexTitlesForTableView:_containingTableView];
            self.additionalRightPadding = indices == nil ? 0 : kSectionIndexWidth;
        }
        
        _containingTableView.directionalLockEnabled = YES;
        
        [self.tapGestureRecognizer requireGestureRecognizerToFail:_containingTableView.panGestureRecognizer];
        
        [_tableViewPanGestureRecognizer addObserver:self forKeyPath:kTableViewPanState options:0 context:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:kTableViewPanState] && object == _tableViewPanGestureRecognizer)
    {
        if(_tableViewPanGestureRecognizer.state == UIGestureRecognizerStateBegan)
        {
            CGPoint locationInTableView = [_tableViewPanGestureRecognizer locationInView:_containingTableView];
            
            BOOL inCurrentCell = CGRectContainsPoint(self.frame, locationInTableView);
            if(!inCurrentCell && _cellState != kCellStateCenter)
            {
                if ([self.delegate respondsToSelector:@selector(swipeableTableViewCellShouldHideUtilityViewsOnSwipe:)])
                {
                    if([self.delegate swipeableTableViewCellShouldHideUtilityViewsOnSwipe:self])
                    {
                        [self hideUtilityViewsAnimated:YES];
                    }
                }
            }
        }
    }
}

- (void)setLeftUtilityViews:(NSArray *)leftUtilityViews
{
    if (![_leftUtilityViews sw_isEqualToButtons:leftUtilityViews]) {
        _leftUtilityViews = leftUtilityViews;
        
        self.leftUtilityViewsView.utilityViews = leftUtilityViews;

        [self.leftUtilityViewsView layoutIfNeeded];
        [self layoutIfNeeded];
    }
}

- (void)setLeftUtilityViews:(NSArray *)leftUtilityViews withWidth:(CGFloat) width
{
    _leftUtilityViews = leftUtilityViews;
    
    [self.leftUtilityViewsView setUtilityViews:leftUtilityViews withWidth:width];

    [self.leftUtilityViewsView layoutIfNeeded];
    [self layoutIfNeeded];
}

- (void)setRightUtilityViews:(NSArray *)rightUtilityViews
{
    if (![_rightUtilityViews sw_isEqualToButtons:rightUtilityViews]) {
        _rightUtilityViews = rightUtilityViews;
        
        self.rightUtilityViewsView.utilityViews = rightUtilityViews;

        [self.rightUtilityViewsView layoutIfNeeded];
        [self layoutIfNeeded];
    }
}

- (void)setRightUtilityViews:(NSArray *)rightUtilityViews withWidth:(CGFloat) width
{
    _rightUtilityViews = rightUtilityViews;
    
    [self.rightUtilityViewsView setUtilityViews:rightUtilityViews withWidth:width];

    [self.rightUtilityViewsView layoutIfNeeded];
    [self layoutIfNeeded];
}

#pragma mark - UITableViewCell overrides

- (void)didMoveToSuperview
{
    self.containingTableView = nil;
    UIView *view = self.superview;
    
    do {
        if ([view isKindOfClass:[UITableView class]])
        {
            self.containingTableView = (UITableView *)view;
            break;
        }
    } while ((view = view.superview));
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Offset the contentView origin so that it appears correctly w/rt the enclosing scroll view (to which we moved it).
    CGRect frame = self.contentView.frame;
    frame.origin.x = [self leftUtilityViewsWidth];
    _contentCellView.frame = frame;
    
    self.cellScrollView.contentSize = CGSizeMake(CGRectGetWidth(self.frame) + [self utilityButtonsPadding], CGRectGetHeight(self.frame));
    
    if (!self.cellScrollView.isTracking && !self.cellScrollView.isDecelerating)
    {
        self.cellScrollView.contentOffset = [self contentOffsetForCellState:_cellState];
    }
    
    [self updateCellState];
}

- (void)setFrame:(CGRect)frame
{
    layoutUpdating = YES;
    // Fix for new screen sizes
    // Initially, the cell is still 320 points wide
    // We need to layout our subviews again when this changes so our constraints clip to the right width
    BOOL widthChanged = (self.frame.size.width != frame.size.width);
    
    [super setFrame:frame];
    
    if (widthChanged)
    {
        [self layoutIfNeeded];
    }
    layoutUpdating = NO;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self hideUtilityViewsAnimated:NO];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    // Work around stupid background-destroying override magic that UITableView seems to perform on contained buttons.
    
    [self.leftUtilityViewsView pushBackgroundColors];
    [self.rightUtilityViewsView pushBackgroundColors];
    
    [super setSelected:selected animated:animated];
    
    [self.leftUtilityViewsView popBackgroundColors];
    [self.rightUtilityViewsView popBackgroundColors];
}

- (void)didTransitionToState:(UITableViewCellStateMask)state {
    [super didTransitionToState:state];
    
    if (state == UITableViewCellStateDefaultMask) {
        [self layoutSubviews];
    }
}

#pragma mark - Selection handling

- (BOOL)shouldHighlight
{
    BOOL shouldHighlight = YES;
    
    if ([self.containingTableView.delegate respondsToSelector:@selector(tableView:shouldHighlightRowAtIndexPath:)])
    {
        NSIndexPath *cellIndexPath = [self.containingTableView indexPathForCell:self];
        
        shouldHighlight = [self.containingTableView.delegate tableView:self.containingTableView shouldHighlightRowAtIndexPath:cellIndexPath];
    }
    
    return shouldHighlight;
}

- (void)scrollViewPressed:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan && !self.isHighlighted && self.shouldHighlight)
    {
        [self setHighlighted:YES animated:NO];
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded)
    {
        // Cell is already highlighted; clearing it temporarily seems to address visual anomaly.
        [self setHighlighted:NO animated:NO];
        [self scrollViewTapped:gestureRecognizer];
    }
    
    else if (gestureRecognizer.state == UIGestureRecognizerStateCancelled)
    {
        [self setHighlighted:NO animated:NO];
    }
}

- (void)scrollViewTapped:(UIGestureRecognizer *)gestureRecognizer
{
    if (_cellState == kCellStateCenter)
    {
        if (self.isSelected)
        {
            [self deselectCell];
        }
        else if (self.shouldHighlight) // UITableView refuses selection if highlight is also refused.
        {
            [self selectCell];
        }
    }
    else
    {
        // Scroll back to center
        [self hideUtilityViewsAnimated:YES];
    }
}

- (void)selectCell
{
    if (_cellState == kCellStateCenter)
    {
        NSIndexPath *cellIndexPath = [self.containingTableView indexPathForCell:self];
        
        if ([self.containingTableView.delegate respondsToSelector:@selector(tableView:willSelectRowAtIndexPath:)])
        {
            cellIndexPath = [self.containingTableView.delegate tableView:self.containingTableView willSelectRowAtIndexPath:cellIndexPath];
        }
        
        if (cellIndexPath)
        {
            [self.containingTableView selectRowAtIndexPath:cellIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            
            if ([self.containingTableView.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
            {
                [self.containingTableView.delegate tableView:self.containingTableView didSelectRowAtIndexPath:cellIndexPath];
            }
        }
    }
}

- (void)deselectCell
{
    if (_cellState == kCellStateCenter)
    {
        NSIndexPath *cellIndexPath = [self.containingTableView indexPathForCell:self];
        
        if ([self.containingTableView.delegate respondsToSelector:@selector(tableView:willDeselectRowAtIndexPath:)])
        {
            cellIndexPath = [self.containingTableView.delegate tableView:self.containingTableView willDeselectRowAtIndexPath:cellIndexPath];
        }
        
        if (cellIndexPath)
        {
            [self.containingTableView deselectRowAtIndexPath:cellIndexPath animated:NO];
            
            if ([self.containingTableView.delegate respondsToSelector:@selector(tableView:didDeselectRowAtIndexPath:)])
            {
                [self.containingTableView.delegate tableView:self.containingTableView didDeselectRowAtIndexPath:cellIndexPath];
            }
        }
    }
}

#pragma mark - Utility buttons handling

- (void)hideUtilityViewsAnimated:(BOOL)animated
{
    if (_cellState != kCellStateCenter)
    {
        [self.cellScrollView setContentOffset:[self contentOffsetForCellState:kCellStateCenter] animated:animated];
        
        if ([self.delegate respondsToSelector:@selector(swipeableTableViewCell:scrollingToState:)])
        {
            [self.delegate swipeableTableViewCell:self scrollingToState:kCellStateCenter];
        }
    }
}

- (void)showLeftUtilityViewsAnimated:(BOOL)animated {
    if (_cellState != kCellStateLeft)
    {
        [self.cellScrollView setContentOffset:[self contentOffsetForCellState:kCellStateLeft] animated:animated];
        
        if ([self.delegate respondsToSelector:@selector(swipeableTableViewCell:scrollingToState:)])
        {
            [self.delegate swipeableTableViewCell:self scrollingToState:kCellStateLeft];
        }
    }
}

- (void)showRightUtilityViewsAnimated:(BOOL)animated {
    if (_cellState != kCellStateRight)
    {
        [self.cellScrollView setContentOffset:[self contentOffsetForCellState:kCellStateRight] animated:animated];
        
        if ([self.delegate respondsToSelector:@selector(swipeableTableViewCell:scrollingToState:)])
        {
            [self.delegate swipeableTableViewCell:self scrollingToState:kCellStateRight];
        }
    }
}

- (BOOL)isUtilityViewHidden {
    return _cellState == kCellStateCenter;
}


#pragma mark - Geometry helpers

- (CGFloat)leftUtilityViewsWidth
{
#if CGFLOAT_IS_DOUBLE
    return round(CGRectGetWidth(self.leftUtilityViewsView.frame));
#else
    return roundf(CGRectGetWidth(self.leftUtilityViewsView.frame));
#endif
}

- (CGFloat)rightUtilityViewsWidth
{
#if CGFLOAT_IS_DOUBLE
    return round(CGRectGetWidth(self.rightUtilityViewsView.frame) + self.additionalRightPadding);
#else
    return roundf(CGRectGetWidth(self.rightUtilityViewsView.frame) + self.additionalRightPadding);
#endif
}

- (CGFloat)utilityButtonsPadding
{
#if CGFLOAT_IS_DOUBLE
    return round([self leftUtilityViewsWidth] + [self rightUtilityViewsWidth]);
#else
    return roundf([self leftUtilityViewsWidth] + [self rightUtilityViewsWidth]);
#endif
}

- (CGPoint)contentOffsetForCellState:(SWCellState)state
{
    CGPoint scrollPt = CGPointZero;
    
    switch (state)
    {
        case kCellStateCenter:
            scrollPt.x = [self leftUtilityViewsWidth];
            break;
            
        case kCellStateRight:
            scrollPt.x = [self utilityButtonsPadding];
            break;
            
        case kCellStateLeft:
            scrollPt.x = 0;
            break;
    }
    
    return scrollPt;
}

- (void)updateCellState
{
    if(layoutUpdating == NO)
    {
        // Update the cell state according to the current scroll view contentOffset.
        for (NSNumber *numState in @[
                                     @(kCellStateCenter),
                                     @(kCellStateLeft),
                                     @(kCellStateRight),
                                     ])
        {
            SWCellState cellState = numState.integerValue;
            
            if (CGPointEqualToPoint(self.cellScrollView.contentOffset, [self contentOffsetForCellState:cellState]))
            {
                _cellState = cellState;
                break;
            }
        }
        
        // Update the clipping on the utility button views according to the current position.
        CGRect frame = [self.contentView.superview convertRect:self.contentView.frame toView:self];
        frame.size.width = CGRectGetWidth(self.frame);
        
        self.leftUtilityClipConstraint.constant = MAX(0, CGRectGetMinX(frame) - CGRectGetMinX(self.frame));
        self.rightUtilityClipConstraint.constant = MIN(0, CGRectGetMaxX(frame) - CGRectGetMaxX(self.frame));
        
        if (self.isEditing) {
            self.leftUtilityClipConstraint.constant = 0;
            self.cellScrollView.contentOffset = CGPointMake([self leftUtilityViewsWidth], 0);
            _cellState = kCellStateCenter;
        }
        
        self.leftUtilityClipView.hidden = (self.leftUtilityClipConstraint.constant == 0);
        self.rightUtilityClipView.hidden = (self.rightUtilityClipConstraint.constant == 0);
        
        if (self.accessoryType != UITableViewCellAccessoryNone && !self.editing) {
            UIView *accessory = [self.cellScrollView.superview.subviews lastObject];
            
            CGRect accessoryFrame = accessory.frame;
            accessoryFrame.origin.x = CGRectGetWidth(frame) - CGRectGetWidth(accessoryFrame) - kAccessoryTrailingSpace + CGRectGetMinX(frame);
            accessory.frame = accessoryFrame;
        }
        
        // Enable or disable the gesture recognizers according to the current mode.
        if (!self.cellScrollView.isDragging && !self.cellScrollView.isDecelerating)
        {
            self.tapGestureRecognizer.enabled = YES;
            self.longPressGestureRecognizer.enabled = (_cellState == kCellStateCenter);
        }
        else
        {
            self.tapGestureRecognizer.enabled = NO;
            self.longPressGestureRecognizer.enabled = NO;
        }
        
        self.cellScrollView.scrollEnabled = !self.isEditing;
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (velocity.x >= 0.5f)
    {
        if (_cellState == kCellStateLeft || !self.rightUtilityViews || self.rightUtilityViewsWidth == 0.0)
        {
            _cellState = kCellStateCenter;
        }
        else
        {
            _cellState = kCellStateRight;
        }
    }
    else if (velocity.x <= -0.5f)
    {
        if (_cellState == kCellStateRight || !self.leftUtilityViews || self.leftUtilityViewsWidth == 0.0)
        {
            _cellState = kCellStateCenter;
        }
        else
        {
            _cellState = kCellStateLeft;
        }
    }
    else
    {
        CGFloat leftThreshold = [self contentOffsetForCellState:kCellStateLeft].x + (self.leftUtilityViewsWidth / 2);
        CGFloat rightThreshold = [self contentOffsetForCellState:kCellStateRight].x - (self.rightUtilityViewsWidth / 2);
        
        if (targetContentOffset->x > rightThreshold)
        {
            _cellState = kCellStateRight;
        }
        else if (targetContentOffset->x < leftThreshold)
        {
            _cellState = kCellStateLeft;
        }
        else
        {
            _cellState = kCellStateCenter;
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(swipeableTableViewCell:scrollingToState:)])
    {
        [self.delegate swipeableTableViewCell:self scrollingToState:_cellState];
    }
    
    if (_cellState != kCellStateCenter)
    {
        if ([self.delegate respondsToSelector:@selector(swipeableTableViewCellShouldHideUtilityViewsOnSwipe:)])
        {
            for (SWTableViewCell *cell in [self.containingTableView visibleCells]) {
                if (cell != self && [cell isKindOfClass:[SWTableViewCell class]] && [self.delegate swipeableTableViewCellShouldHideUtilityViewsOnSwipe:cell]) {
                    [cell hideUtilityViewsAnimated:YES];
                }
            }
        }
    }
    
    *targetContentOffset = [self contentOffsetForCellState:_cellState];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.x > [self leftUtilityViewsWidth])
    {
        if ([self rightUtilityViewsWidth] > 0)
        {
            if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableTableViewCell:canSwipeToState:)])
            {
                BOOL shouldScroll = [self.delegate swipeableTableViewCell:self canSwipeToState:kCellStateRight];
                if (!shouldScroll)
                {
                    scrollView.contentOffset = CGPointMake([self leftUtilityViewsWidth], 0);
                }
            }
        }
        else
        {
            [scrollView setContentOffset:CGPointMake([self leftUtilityViewsWidth], 0)];
            self.tapGestureRecognizer.enabled = YES;
        }
    }
    else
    {
        // Expose the left button view
        if ([self leftUtilityViewsWidth] > 0)
        {
            if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableTableViewCell:canSwipeToState:)])
            {
                BOOL shouldScroll = [self.delegate swipeableTableViewCell:self canSwipeToState:kCellStateLeft];
                if (!shouldScroll)
                {
                    scrollView.contentOffset = CGPointMake([self leftUtilityViewsWidth], 0);
                }
            }
        }
        else
        {
            [scrollView setContentOffset:CGPointMake(0, 0)];
            self.tapGestureRecognizer.enabled = YES;
        }
    }
    
    [self updateCellState];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableTableViewCell:didScroll:)]) {
        [self.delegate swipeableTableViewCell:self didScroll:scrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self updateCellState];

    if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableTableViewCellDidEndScrolling:)]) {
        [self.delegate swipeableTableViewCellDidEndScrolling:self];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self updateCellState];

    if (self.delegate && [self.delegate respondsToSelector:@selector(swipeableTableViewCellDidEndScrolling:)]) {
        [self.delegate swipeableTableViewCellDidEndScrolling:self];
    }
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
    {
        self.tapGestureRecognizer.enabled = YES;
    }
    
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ((gestureRecognizer == self.containingTableView.panGestureRecognizer && otherGestureRecognizer == self.longPressGestureRecognizer)
        || (gestureRecognizer == self.longPressGestureRecognizer && otherGestureRecognizer == self.containingTableView.panGestureRecognizer))
    {
        // Return YES so the pan gesture of the containing table view is not cancelled by the long press recognizer
        return YES;
    }
    else
    {
        return NO;
    }
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return ![touch.view isKindOfClass:[UIControl class]];
}

@end
