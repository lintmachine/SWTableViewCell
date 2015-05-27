//
//  SWUtilityButtonView.m
//  SWTableViewCell
//
//  Created by Matt Bowman on 11/27/13.
//  Copyright (c) 2013 Chris Wendel. All rights reserved.
//

#import "SWUtilityView.h"

@interface SWUtilityView()

@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;
@property (nonatomic, strong) NSMutableArray *buttonBackgroundColors;

@end

@implementation SWUtilityView

#pragma mark - SWUtilityView initializers

- (id)initWithUtilityViews:(NSArray *)utilityViews parentCell:(SWTableViewCell *)parentCell
{
    self = [self initWithFrame:CGRectZero utilityViews:utilityViews parentCell:parentCell];
    
    return self;
}

- (id)initWithFrame:(CGRect)frame utilityViews:(NSArray *)utilityViews parentCell:(SWTableViewCell *)parentCell
{
    self = [super initWithFrame:frame];
    
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        
        self.widthConstraint = [NSLayoutConstraint constraintWithItem:self
                                                            attribute:NSLayoutAttributeWidth
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:nil
                                                            attribute:NSLayoutAttributeNotAnAttribute
                                                           multiplier:1.0
                                                             constant:0.0]; // constant will be adjusted dynamically in -setUtilityButtons:.
        self.widthConstraint.priority = UILayoutPriorityDefaultHigh;
        [self addConstraint:self.widthConstraint];
        
        _parentCell = parentCell;
        self.utilityViews = utilityViews;
    }
    
    return self;
}

#pragma mark Populating utility buttons

- (void)setUtilityViews:(NSArray *)utilityViews
{
    // if no width specified, use the default width
    [self setUtilityViews:utilityViews withWidth:kUtilityButtonWidthDefault];
}

- (void)setUtilityViews:(NSArray *)utilityViews withWidth:(CGFloat)width
{
    for (UIView *view in _utilityViews)
    {
        [view removeFromSuperview];
    }
    
    _utilityViews = [utilityViews copy];
    
    if (utilityViews.count)
    {
        NSUInteger utilityButtonsCounter = 0;
        UIView *precedingView = nil;
        
        for (UIView *view in _utilityViews)
        {
            [self addSubview:view];
            view.translatesAutoresizingMaskIntoConstraints = NO;
            
            if (!precedingView)
            {
                // First button; pin it to the left edge.
                [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]"
                                                                             options:0L
                                                                             metrics:nil
                                                                               views:NSDictionaryOfVariableBindings(view)]];
            }
            else
            {
                // Subsequent button; pin it to the right edge of the preceding one, with equal width.
                [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[precedingView][view(==precedingView)]"
                                                                             options:0L
                                                                             metrics:nil
                                                                               views:NSDictionaryOfVariableBindings(precedingView, view)]];
            }
            
            [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|"
                                                                         options:0L
                                                                         metrics:nil
                                                                           views:NSDictionaryOfVariableBindings(view)]];
            
            utilityButtonsCounter++;
            precedingView = view;
        }
        
        // Pin the last button to the right edge.
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[precedingView]|"
                                                                     options:0L
                                                                     metrics:nil
                                                                       views:NSDictionaryOfVariableBindings(precedingView)]];
    }
    
    self.widthConstraint.constant = (width * utilityViews.count);
    
    [self setNeedsLayout];
    
    return;
}

#pragma mark -

- (void)pushBackgroundColors
{
    self.buttonBackgroundColors = [[NSMutableArray alloc] init];
    
    for (UIView *view in self.utilityViews)
    {
        [self.buttonBackgroundColors addObject:view.backgroundColor];
    }
}

- (void)popBackgroundColors
{
    NSEnumerator *e = self.utilityViews.objectEnumerator;
    
    for (UIColor *color in self.buttonBackgroundColors)
    {
        UIView *view = [e nextObject];
        view.backgroundColor = color;
    }
    
    self.buttonBackgroundColors = nil;
}

@end

