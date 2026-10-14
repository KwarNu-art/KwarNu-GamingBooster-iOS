#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface KwarNuBoosterOverlay : NSObject
+ (instancetype)sharedInstance;
- (void)showOverlay;
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIView *floatingButton;
@property (nonatomic, strong) UIView *dashboardPanel;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) UILabel *fpsLabel;
@property (nonatomic, strong) UILabel *ramLabel;
@property (nonatomic, strong) UILabel *batteryLabel;
@property (nonatomic, strong) UILabel *thermalLabel;
@property (nonatomic, assign) NSInteger targetFPS;
@property (nonatomic, assign) BOOL isBatterySaverActive;
@property (nonatomic, assign) BOOL isPerformanceModeActive;
@end

@implementation KwarNuBoosterOverlay {
    CFTimeInterval _lastTimestamp;
    NSUInteger _frameCount;
    CGFloat _currentFPS;
}
+ (instancetype)sharedInstance {
    static KwarNuBoosterOverlay *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _targetFPS = 60;
        _isBatterySaverActive = NO;
        _isPerformanceModeActive = NO;
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }
    return self;
}
- (void)showOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow) return;
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        self.overlayWindow = [[UIWindow alloc] initWithFrame:screenBounds];
        self.overlayWindow.windowLevel = UIWindowLevelStatusBar + 100.0;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.userInteractionEnabled = YES;
        self.overlayWindow.hidden = NO;
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        rootVC.view.userInteractionEnabled = YES;
        self.overlayWindow.rootViewController = rootVC;
        [self setupFloatingButton:rootVC.view];
        [self setupDashboardPanel:rootVC.view];
        [self startMonitoring];
    });
}
- (void)setupFloatingButton:(UIView *)parentView {
    CGFloat btnSize = 60.0;
    self.floatingButton = [[UIView alloc] initWithFrame:CGRectMake(20, 100, btnSize, btnSize)];
    self.floatingButton.layer.cornerRadius = btnSize / 2.0;
    self.floatingButton.layer.masksToBounds = YES;
    self.floatingButton.layer.borderWidth = 1.5;
    self.floatingButton.layer.borderColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:0.8].CGColor;
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.floatingButton.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.floatingButton addSubview:blurView];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:self.floatingButton.bounds];
    titleLabel.text = @"Kwar\nNu";
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0];
    titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.floatingButton addSubview:titleLabel];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatingButton addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleDashboard)];
    [self.floatingButton addGestureRecognizer:tap];
    [parentView addSubview:self.floatingButton];
}
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *btn = pan.view;
    CGPoint translation = [pan translationInView:btn.superview];
    btn.center = CGPointMake(btn.center.x + translation.x, btn.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:btn.superview];
    if (pan.state == UIGestureRecognizerStateEnded) {
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat targetX = (btn.center.x > screenWidth / 2.0) ? (screenWidth - btn.frame.size.width / 2.0 - 10) : (btn.frame.size.width / 2.0 + 10);
        [UIView animateWithDuration:0.25 animations:^{
            btn.center = CGPointMake(targetX, btn.center.y);
        }];
    }
}
- (void)setupDashboardPanel:(UIView *)parentView {
    CGFloat panelWidth = 280.0;
    CGFloat panelHeight = 360.0;
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    self.dashboardPanel = [[UIView alloc] initWithFrame:CGRectMake((screenW - panelWidth) / 2.0, (screenH - panelHeight) / 2.0, panelWidth, panelHeight)];
    self.dashboardPanel.layer.cornerRadius = 20.0;
    self.dashboardPanel.layer.masksToBounds = YES;
    self.dashboardPanel.layer.borderWidth = 1.0;
    self.dashboardPanel.layer.borderColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.5 alpha:0.5].CGColor;
    self.dashboardPanel.hidden = YES;
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.dashboardPanel.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.dashboardPanel addSubview:blurView];
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, panelWidth - 30, 24)];
    header.text = @"⚡ Kwar Nu Booster";
    header.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.5 alpha:1.0];
    header.font = [UIFont boldSystemFontOfSize:16];
    [self.dashboardPanel addSubview:header];
    self.fpsLabel = [self createMetricLabelAtY:45 title:@"📊 FPS: --"];
    self.ramLabel = [self createMetricLabelAtY:70 title:@"🧠 RAM: -- MB"];
    self.batteryLabel = [self createMetricLabelAtY:95 title:@"🔋 Battery: --%"];
    self.thermalLabel = [self createMetricLabelAtY:120 title:@"🌡️ Thermal: Nominal"];
    [parentView addSubview:self.dashboardPanel];
}
- (UILabel *)createMetricLabelAtY:(CGFloat)y title:(NSString *)title {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(15, y, 250, 20)];
    lbl.text = title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.dashboardPanel addSubview:lbl];
    return lbl;
}
- (void)toggleDashboard {
    self.dashboardPanel.hidden = !self.dashboardPanel.hidden;
}
- (void)startMonitoring {
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onTick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}
- (void)onTick:(CADisplayLink *)link {
    if (_lastTimestamp == 0) {
        _lastTimestamp = link.timestamp;
        return;
    }
    _frameCount++;
    CFTimeInterval delta = link.timestamp - _lastTimestamp;
    if (delta >= 1.0) {
        _currentFPS = _frameCount / delta;
        _frameCount = 0;
        _lastTimestamp = link.timestamp;
    }
}
@end

__attribute__((constructor))
static void initializeKwarNuBooster(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[KwarNuBoosterOverlay sharedInstance] showOverlay];
    });
}
