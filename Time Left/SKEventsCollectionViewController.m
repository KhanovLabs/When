//
//  SKEventsCollectionViewController.m
//  Time Left
//
//  Created by Salavat Khanov on 1/23/14.
//  Copyright (c) 2014 Salavat Khanov. All rights reserved.
//

#import "SKEventsCollectionViewController.h"
#import "SKEventCell.h"
#import "SKEventDetailsViewController.h"
#import "SKCustomCollectionViewFlowLayout.h"
#import "SKAddEventTableViewController.h"
#import "SKAppDelegate.h"
#import "GAIDictionaryBuilder.h"

static NSInteger kMarginTopBottomiPhone = 12;
static NSInteger kMarginTopBottomiPad = 30;
static NSInteger kMarginLeftRightiPhone = 10;
static NSInteger kMarginLeftRightiPad = 10;

static CGFloat kCollectionViewContentOffsetiPhone = -64.0f;
static CGFloat kCollectionViewContentOffsetiPad = 0.0f;

static CGFloat kAddButtonHiddenOffset = 40.f;

static NSInteger kCellWeightHeightiPhone = 145;
static NSInteger kCellWeightHeightiPad = 242;
static NSString *kEventsScreenName = @"Events Grid";

@interface SKEventsCollectionViewController ()

@property (strong, nonatomic) NSTimer *timer;
@property (nonatomic,strong) NSMutableArray *fetchedEventsArray;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *addBarButtonItem;
@property (strong, nonatomic) IBOutlet UIButton *addButton;
@property (assign, nonatomic) BOOL shouldBeHidingStatusBar;
@property (assign, nonatomic) BOOL shouldBeHidingAddButton;
@property (strong, nonatomic) UIDynamicAnimator *animator;

- (IBAction)deleteButton:(UIButton *)sender;

@end

@implementation SKEventsCollectionViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

    }
    return self;
}

#pragma mark - Configure View

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupColors];
    [self registerForNotifications];
    
    // Allocate and configure the layout
    SKCustomCollectionViewFlowLayout *layout = [[SKCustomCollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 10.f;
    layout.minimumLineSpacing = 10.f;
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.sectionInset = UIEdgeInsetsMake(0.f, 0.f, 0.f, 0.f);
    self.collectionView.collectionViewLayout = layout;
    
    // Motion effects
    UIInterpolatingMotionEffect *xAxis = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    xAxis.minimumRelativeValue = @-20;
    xAxis.maximumRelativeValue = @20;
    
    UIInterpolatingMotionEffect *yAxis = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    yAxis.minimumRelativeValue = @-20;
    yAxis.maximumRelativeValue = @20;
    
    UIMotionEffectGroup *group = [[UIMotionEffectGroup alloc] init];
    group.motionEffects = @[xAxis, yAxis];
    [self.collectionView addMotionEffect:group];
    
    // Set navigation bar font
    UIFont *backButtonFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:17.0f];
    [[UIBarButtonItem appearance] setTitleTextAttributes:@{NSFontAttributeName : backButtonFont} forState:UIControlStateNormal];

    // Long press gesture recognizer
    UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGesture:)];
    longPressGestureRecognizer.minimumPressDuration = 0.5; //seconds
    longPressGestureRecognizer.delegate = self;
    longPressGestureRecognizer.delaysTouchesBegan = YES;
    [self.collectionView addGestureRecognizer:longPressGestureRecognizer];
    
    // Tap gesture recognizer
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
    tapGestureRecognizer.delegate = self;
    tapGestureRecognizer.delaysTouchesBegan = YES;
    [self.collectionView addGestureRecognizer:tapGestureRecognizer];
}

- (void)setupColors
{
    SKAppDelegate *delegate = [UIApplication sharedApplication].delegate;
    NSDictionary *colors = [delegate currentTheme];
    self.view.backgroundColor = [colors objectForKey:@"background"];
    self.collectionView.backgroundColor = [colors objectForKey:@"background"];
    // Transparent nav bar
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    self.navigationController.navigationBar.translucent = YES;
    // Light status bar
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
}


#pragma mark Notifications

- (void)registerForNotifications
{
    // Model Changed Notification: event added
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(eventAdded:)
                                                 name:@"EventAdded"
                                               object:nil];
    
    // Stop edit mode after loosing focus
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResign)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
}

- (void)eventAdded:(NSNotification *)addedNotification
{
    if ([[addedNotification.userInfo allKeys][0] isEqual:@"added"]) {
        SKEvent *eventToAdd = [addedNotification.userInfo objectForKey:@"added"];
        self.fetchedEventsArray = [NSMutableArray arrayWithArray:[[SKDataManager sharedManager] getAllEvents]];
        NSInteger index = [self.fetchedEventsArray indexOfObject:eventToAdd];
        [self.collectionView insertItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:index inSection:0]]];
    }
}

- (void)applicationWillResign
{
    [self doneEditing];
}


#pragma mark Update View

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self doneEditing]; // if needed
    [self updateView];
    [self startTimer];
    
    // Fix strange case, when there's extra content offset added after returning from event detail view
    CGPoint offset = self.collectionView.contentOffset;
    if (offset.y < kCollectionViewContentOffsetiPhone) {
        offset.y = kCollectionViewContentOffsetiPhone;
        self.collectionView.contentOffset = offset;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:kEventsScreenName];
    [tracker send:[[GAIDictionaryBuilder createAppView] build]];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self stopTimer];
}

- (void)startTimer
{
    if ([self.fetchedEventsArray count] && self.timer == nil) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateView) userInfo:nil repeats:YES];
    }
}

- (void)stopTimer
{
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)updateView
{
    NSLog(@"----------- update view");
    self.fetchedEventsArray = [NSMutableArray arrayWithArray:[[SKDataManager sharedManager] getAllEvents]];
    [self.collectionView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark - UIScrollView Delegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self stopTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (self.isEditing == NO) {
        [self startTimer];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat statusBarHeight = 20.0f;
    CGFloat scrollOffset = scrollView.contentOffset.y;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        scrollOffset -= kCollectionViewContentOffsetiPhone;
    } else {
        scrollOffset -= kCollectionViewContentOffsetiPad;
    }
    
    if ((scrollOffset / 2) >= statusBarHeight) {
        [self hideStatusBar];
        [self hideAddButton];
    } else {
        [self showStatusBar];
        [self showAddButton];
    }
}


#pragma mark - Status Bar Appearance

- (BOOL)prefersStatusBarHidden
{
    return self.shouldBeHidingStatusBar;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationSlide;
}

- (void)hideStatusBar
{
    if (self.shouldBeHidingStatusBar == NO) {
        self.shouldBeHidingStatusBar = YES;
        [UIView animateWithDuration:0.1 animations:^{
            [self setNeedsStatusBarAppearanceUpdate];
        }];
    }
}

- (void)showStatusBar
{
    if (self.shouldBeHidingStatusBar) {
        self.shouldBeHidingStatusBar = NO;
        [UIView animateWithDuration:0.1 animations:^{
            [self setNeedsStatusBarAppearanceUpdate];
        }];
    }
}


#pragma mark - Add Button Appearance

- (void)hideAddButton
{
    if (self.shouldBeHidingAddButton == NO) {
        self.shouldBeHidingAddButton = YES;
        [UIView animateWithDuration:0.1 animations:^{
            self.addButton.center = CGPointMake(self.addButton.center.x + kAddButtonHiddenOffset, self.addButton.center.y);
        } completion:^(BOOL finished) {
            self.addButton.hidden = YES;
        }];
    }
}

- (void)showAddButton
{
    if (self.shouldBeHidingAddButton) {
        self.shouldBeHidingAddButton = NO;
        self.addButton.center = CGPointMake(self.addButton.center.x + kAddButtonHiddenOffset, self.addButton.center.y);
        self.addButton.hidden = NO;
        
        [UIView animateWithDuration:0.1 animations:^{
            self.addButton.center = CGPointMake(self.addButton.center.x - kAddButtonHiddenOffset, self.addButton.center.y);
        }];
    }
}


#pragma mark - UICollectionView Datasource

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section
{
    return [self.fetchedEventsArray count];
}

- (NSInteger)numberOfSectionsInCollectionView: (UICollectionView *)collectionView
{
    return 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SKEventCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"EventCell" forIndexPath:indexPath];
    
    SKEvent *event = self.fetchedEventsArray[indexPath.row];
    cell.name.text = event.name;
    cell.progressView.percentCircle = [event progress] * 100;
    
    self.isEditing ? [cell startQuivering] : [cell stopQuivering];
    
    NSDictionary *options = [event bestNumberAndText];
    cell.progressView.progressLabel.text = [options valueForKey:@"number"];
    cell.progressView.metaLabel.text = [options valueForKey:@"text"];
    
    // for events that have finished, use special font to display symbol
    [event progress] > 1.0 ? [cell.progressView useFontForSymbol] : [cell.progressView useDefaultFont];
    // for events that haven't yet started, use smaller text
    [event progress] < 0 ? [cell.progressView useSmallerFont] : [cell.progressView useDefaultFont];
    
    [cell.progressView setNeedsDisplay];
    
    return cell;
}


#pragma mark – UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        return CGSizeMake(kCellWeightHeightiPhone, kCellWeightHeightiPhone);
    } else {
        return CGSizeMake(kCellWeightHeightiPad, kCellWeightHeightiPad);
    }
    
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        return UIEdgeInsetsMake(kMarginTopBottomiPhone, kMarginLeftRightiPhone, kMarginTopBottomiPhone, kMarginLeftRightiPhone);
    } else {
        return UIEdgeInsetsMake(kMarginTopBottomiPad, kMarginLeftRightiPad, kMarginTopBottomiPad, kMarginLeftRightiPad);
    }
}


#pragma mark - Navigation

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"showEventDetailsView"] && self.editing) {
        return NO;
    }
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{    
    // Pass the selected event to the details view controller.
    if ([segue.identifier isEqualToString:@"showEventDetailsView"]) {
        NSIndexPath *indexPath = [[self.collectionView indexPathsForSelectedItems] objectAtIndex:0];
        SKEventDetailsViewController *eventDetailsViewController = segue.destinationViewController;
        eventDetailsViewController.event = [self.fetchedEventsArray objectAtIndex:indexPath.row];
    } else if ([segue.identifier isEqualToString:@"showAddEventView"] && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UIPopoverController *popover = [(UIStoryboardPopoverSegue *)segue popoverController];
        SKAppDelegate *delegate = [UIApplication sharedApplication].delegate;
        NSDictionary *colors = [delegate currentTheme];
        popover.backgroundColor = [colors objectForKey:@"background"];
        SKAddEventTableViewController *addEventController = (SKAddEventTableViewController *)((UINavigationController *)segue.destinationViewController).topViewController;
        addEventController.popover = popover;
    }
}

- (void)showAddEventView
{
    [self performSegueWithIdentifier:@"showAddEventView" sender:nil];
}


#pragma mark - Edit mode

- (void)longPressGesture:(UIGestureRecognizer *)recognizer
{
    if ([recognizer state] == UIGestureRecognizerStateBegan) {
        
        UICollectionViewCell *cellAtTapPoint = [self collectionViewCellForTapAtPoint:[recognizer locationInView:self.collectionView]];
        
        // If there's cell, where long tap was performed, start editing mode
        if (cellAtTapPoint && !self.editing) {
            // Replace Add button to Done in the navbar
            UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEditing)];
            [self.navigationItem setRightBarButtonItem:done];
            // Start Editing mode
            NSLog(@"Start editing");
            self.editing = YES;
            [self stopTimer];
            [self updateView];
            
            // GA
            id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
            [tracker set:kGAIScreenName value:kEventsScreenName];
            [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"UX"
                                                                  action:@"touch"
                                                                   label:@"Start Editing"
                                                                   value:nil] build]];
            [tracker set:kGAIScreenName value:nil];
        }
        else {
            [self doneEditing];
        }
    }
}

- (void)tapGesture:(UITapGestureRecognizer *)recognizer
{
    if ([recognizer state] == UIGestureRecognizerStateEnded) {
        
        UICollectionViewCell *cellAtTapPoint = [self collectionViewCellForTapAtPoint:[recognizer locationInView:self.collectionView]];
        
        // If there's no cell, where tap was performed, and editing mode is ON, then stop editing mode
        if (!cellAtTapPoint && self.editing) {
            [self doneEditing];
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([gestureRecognizer class] == [UITapGestureRecognizer class] && ![self collectionViewCellForTapAtPoint:[touch locationInView:self.collectionView]]) {
        return YES;
    }
    
    if ([gestureRecognizer class] == [UILongPressGestureRecognizer class]) {
        return YES;
    }
    
    return NO;
}

- (UICollectionViewCell *)collectionViewCellForTapAtPoint:(CGPoint)tapPoint
{
    NSIndexPath *indexPathForTapPoint = [self.collectionView indexPathForItemAtPoint:tapPoint];
    return [self.collectionView cellForItemAtIndexPath:indexPathForTapPoint];
}

- (IBAction)deleteButton:(UIButton *)sender
{
    NSIndexPath *indexPath = [self.collectionView indexPathForCell:(SKEventCell *)sender.superview.superview];
    [[SKDataManager sharedManager] deleteEvent:self.fetchedEventsArray[indexPath.row]];
    [[SKDataManager sharedManager] saveContext];
    self.fetchedEventsArray = [NSMutableArray arrayWithArray:[[SKDataManager sharedManager] getAllEvents]];
    [self.collectionView deleteItemsAtIndexPaths:@[indexPath]];
    
    // GA
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:kEventsScreenName];
    [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"UX"
                                                          action:@"touch"
                                                           label:@"Delete"
                                                           value:nil] build]];
    [tracker set:kGAIScreenName value:nil];
}

- (void)doneEditing
{
    if (self.isEditing) {
        NSLog(@"Done editing");
        // Replace Add button to Done
        [self.navigationItem setRightBarButtonItem:self.addBarButtonItem];
        // Stop Edit mode
        self.editing = NO;
        [self startTimer];
        [self updateView];
        
        // GA
        id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
        [tracker set:kGAIScreenName value:kEventsScreenName];
        [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"UX"
                                                              action:@"touch"
                                                               label:@"Done Editing"
                                                               value:nil] build]];
        [tracker set:kGAIScreenName value:nil];
    }
}

@end
