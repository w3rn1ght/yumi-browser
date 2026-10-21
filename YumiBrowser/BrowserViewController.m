#import "BrowserViewController.h"
#import "YumiSettings.h"
#import "YumiAdBlocker.h"
#import "YumiIcons.h"
#import "YumiPlayer.h"
#import "YumiBridge.h"
#import "YumiScripts.h"
#import "TabsViewController.h"
#import "SettingsViewController.h"

static NSString *const kYumiSessionURLs = @"YumiSessionURLs";
static NSString *const kYumiSessionIndex = @"YumiSessionIndex";

@interface BrowserViewController () <TabsViewControllerDelegate, SettingsViewControllerDelegate, WKUIDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) NSMutableArray<YumiTab *> *tabs;
@property (nonatomic, assign) NSInteger activeIndex;

@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, strong) UIProgressView *progressView;

@property (nonatomic, strong) UIBarButtonItem *backItem;
@property (nonatomic, strong) UIBarButtonItem *forwardItem;
@property (nonatomic, strong) UIBarButtonItem *reloadItem;
@property (nonatomic, strong) UIBarButtonItem *menuItem;
@property (nonatomic, strong) UIBarButtonItem *tabsItem;
@property (nonatomic, strong) UIBarButtonItem *homeItem;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *streams;
@property (nonatomic, strong) NSDictionary *streamInfo;
@property (nonatomic, strong) UIView *streamBanner;
@property (nonatomic, strong) UILabel *streamLabel;
@property (nonatomic, strong) UILabel *streamSubLabel;

@end

@implementation BrowserViewController

- (instancetype)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _tabs = [NSMutableArray array];
        _streams = [NSMutableArray array];
        _activeIndex = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    [self setupAddressField];
    [self setupBarButtons];
    [self setupProgressView];
    [self setupStreamBanner];
    [self setupBridge];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveSession)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveSession)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];

    [self restoreSession];
    [self updateChrome];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = NO;
    [self updateChrome];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat navWidth = self.navigationController.navigationBar.bounds.size.width;
    if (navWidth <= 0) navWidth = self.view.bounds.size.width;
    CGFloat fieldWidth = MAX(120.0, navWidth - 170.0);
    self.addressField.frame = CGRectMake(0, 0, fieldWidth, 32);

    for (YumiTab *tab in self.tabs) {
        tab.webView.frame = self.view.bounds;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI

- (void)setupAddressField {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 200, 32)];
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    field.font = [UIFont systemFontOfSize:15];
    field.placeholder = @"Поиск или адрес";
    field.keyboardType = UIKeyboardTypeURL;
    field.returnKeyType = UIReturnKeyGo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.spellCheckingType = UITextSpellCheckingTypeNo;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.delegate = self;
    field.textContentType = UITextContentTypeURL;
    self.addressField = field;
    self.navigationItem.titleView = field;
}

- (UIBarButtonItem *)itemWithImage:(UIImage *)image action:(SEL)action label:(NSString *)label {
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:image
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:action];
    item.accessibilityLabel = label;
    return item;
}

- (void)setupBarButtons {
    self.reloadItem = [self itemWithImage:[YumiIcons reload] action:@selector(reloadTapped) label:@"Обновить"];
    self.menuItem = [self itemWithImage:[YumiIcons ellipsis] action:@selector(menuTapped) label:@"Меню"];
    self.navigationItem.rightBarButtonItems = @[self.menuItem, self.reloadItem];

    self.backItem = [self itemWithImage:[YumiIcons chevronLeft] action:@selector(goBackTapped) label:@"Назад"];
    self.forwardItem = [self itemWithImage:[YumiIcons chevronRight] action:@selector(goForwardTapped) label:@"Вперёд"];
    self.tabsItem = [self itemWithImage:[YumiIcons tabs] action:@selector(showTabs) label:@"Вкладки"];
    self.homeItem = [self itemWithImage:[YumiIcons home] action:@selector(goHomeTapped) label:@"Начало"];

    UIBarButtonItem *(^flex)(void) = ^{
        return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                             target:nil
                                                             action:nil];
    };

    self.toolbarItems = @[self.backItem, flex(), self.forwardItem, flex(),
                          self.tabsItem, flex(), self.homeItem];
}

- (void)setupProgressView {
    UIProgressView *p = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    p.translatesAutoresizingMaskIntoConstraints = NO;
    p.progressTintColor = self.view.tintColor ?: [UIColor colorWithRed:0.18 green:0.45 blue:0.94 alpha:1];
    p.trackTintColor = [UIColor clearColor];
    p.progress = 0;
    p.hidden = YES;
    [self.view addSubview:p];
    self.progressView = p;

    [NSLayoutConstraint activateConstraints:@[
        [p.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [p.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [p.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [p.heightAnchor constraintEqualToConstant:2]
    ]];
}

- (void)setupStreamBanner {
    UIView *banner = [[UIView alloc] init];
    banner.translatesAutoresizingMaskIntoConstraints = NO;
    banner.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.94];
    banner.layer.cornerRadius = 13.0;
    banner.layer.shadowColor = [UIColor blackColor].CGColor;
    banner.layer.shadowOpacity = 0.25;
    banner.layer.shadowRadius = 10;
    banner.layer.shadowOffset = CGSizeMake(0, 3);
    banner.hidden = YES;
    banner.alpha = 0;
    [self.view addSubview:banner];
    self.streamBanner = banner;

    UIButton *play = [UIButton buttonWithType:UIButtonTypeSystem];
    play.translatesAutoresizingMaskIntoConstraints = NO;
    play.backgroundColor = [UIColor colorWithRed:0.18 green:0.45 blue:0.94 alpha:1.0];
    play.tintColor = [UIColor whiteColor];
    play.layer.cornerRadius = 18.0;
    [play setImage:[YumiIcons play] forState:UIControlStateNormal];
    [play addTarget:self action:@selector(playBannerTapped) forControlEvents:UIControlEventTouchUpInside];
    [banner addSubview:play];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    label.text = @"Поток найден";
    [banner addSubview:label];
    self.streamLabel = label;

    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
    sub.font = [UIFont systemFontOfSize:11.5];
    sub.text = @"Нажми, чтобы открыть в системном плеере";
    [banner addSubview:sub];
    self.streamSubLabel = sub;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    close.tintColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    [close setImage:[YumiIcons close] forState:UIControlStateNormal];
    [close addTarget:self action:@selector(closeBannerTapped) forControlEvents:UIControlEventTouchUpInside];
    [banner addSubview:close];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playBannerTapped)];
    tap.delegate = self;
    [banner addGestureRecognizer:tap];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [banner.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:10],
        [banner.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-10],
        [banner.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10],
        [banner.heightAnchor constraintEqualToConstant:56],

        [play.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:10],
        [play.centerYAnchor constraintEqualToAnchor:banner.centerYAnchor],
        [play.widthAnchor constraintEqualToConstant:36],
        [play.heightAnchor constraintEqualToConstant:36],

        [label.leadingAnchor constraintEqualToAnchor:play.trailingAnchor constant:10],
        [label.topAnchor constraintEqualToAnchor:banner.topAnchor constant:10],
        [label.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-8],

        [sub.leadingAnchor constraintEqualToAnchor:label.leadingAnchor],
        [sub.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:1],
        [sub.trailingAnchor constraintEqualToAnchor:label.trailingAnchor],

        [close.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-4],
        [close.centerYAnchor constraintEqualToAnchor:banner.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:36],
        [close.heightAnchor constraintEqualToAnchor:36]
    ]];
}

#pragma mark - Баннер потока

- (void)showStreamBannerWithInfo:(NSDictionary *)info {
    self.streamInfo = info;
    NSString *kind = [info[@"kind"] isKindOfClass:[NSString class]] ? [info[@"kind"] uppercaseString] : @"STREAM";
    NSString *urlString = info[@"url"];
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *host = url.host ?: @"";
    NSString *title = info[@"title"];
    if ([title isKindOfClass:[NSString class]] && title.length > 48) {
        title = [[title substringToIndex:48] stringByAppendingString:@"…"];
    }
    self.streamLabel.text = title.length ? title : @"Поток найден";
    self.streamSubLabel.text = [NSString stringWithFormat:@"%@ · %@", kind, host];

    self.streamBanner.hidden = NO;
    self.streamBanner.transform = CGAffineTransformMakeTranslation(0, 14);
    [UIView animateWithDuration:0.22 animations:^{
        self.streamBanner.alpha = 1.0;
        self.streamBanner.transform = CGAffineTransformIdentity;
    }];
}

- (void)hideStreamBanner {
    self.streamInfo = nil;
    [UIView animateWithDuration:0.18 animations:^{
        self.streamBanner.alpha = 0.0;
        self.streamBanner.transform = CGAffineTransformMakeTranslation(0, 14);
    } completion:^(BOOL finished) {
        self.streamBanner.hidden = YES;
    }];
}

- (void)playBannerTapped {
    if (self.streamInfo) [self playStreamInfo:self.streamInfo];
}

- (void)closeBannerTapped {
    [self hideStreamBanner];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIControl class]]) return NO;
    return YES;
}

#pragma mark - Режимы

- (YumiTab *)activeTab {
    if (self.activeIndex < 0 || self.activeIndex >= (NSInteger)self.tabs.count) {
        return self.tabs.firstObject;
    }
    return self.tabs[(NSUInteger)self.activeIndex];
}

- (void)updateChrome {
    YumiTab *tab = self.activeTab;
    self.backItem.enabled = tab.canGoBack;
    self.forwardItem.enabled = tab.canGoForward;
    self.reloadItem.image = tab.isLoading ? [YumiIcons stop] : [YumiIcons reload];
    self.reloadItem.accessibilityLabel = tab.isLoading ? @"Остановить" : @"Обновить";
    self.tabsItem.accessibilityLabel = [NSString stringWithFormat:@"Вкладки: %lu", (unsigned long)self.tabs.count];
    if (!self.addressField.isFirstResponder) {
        self.addressField.text = tab.displayURLString ?: @"";
    }
}

#pragma mark - Вкладки

- (YumiTab *)createTab {
    return [[YumiTab alloc] initWithConfiguration:nil delegate:self];
}

- (YumiTab *)createTabWithConfiguration:(WKWebViewConfiguration *)configuration {
    return [[YumiTab alloc] initWithConfiguration:configuration delegate:self];
}

- (void)addHomeTab {
    YumiTab *tab = [self createTab];
    [self.tabs addObject:tab];
    [self selectTabAtIndex:(NSInteger)self.tabs.count - 1];
    [tab loadHome];
    [self saveSession];
}

- (void)addTabWithURLString:(NSString *)string {
    YumiTab *tab = [self createTab];
    if (string.length) tab.pendingURLString = string;
    [self.tabs addObject:tab];
    [self selectTabAtIndex:(NSInteger)self.tabs.count - 1];
    [self saveSession];
}

- (void)selectTabAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count) return;

    if (self.activeIndex != index && self.activeIndex >= 0 &&
        self.activeIndex < (NSInteger)self.tabs.count) {
        YumiTab *old = self.tabs[(NSUInteger)self.activeIndex];
        [old.webView removeFromSuperview];
    }

    self.activeIndex = index;
    YumiTab *tab = self.tabs[(NSUInteger)index];
    tab.delegate = self;
    if (tab.webView.superview != self.view) {
        tab.webView.frame = self.view.bounds;
        tab.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view insertSubview:tab.webView atIndex:0];
    }

    if (tab.pendingURLString.length) {
        NSString *pending = tab.pendingURLString;
        tab.pendingURLString = nil;
        NSURL *url = [NSURL URLWithString:pending];
        if (url) [tab loadURL:url];
        else [tab loadHome];
    }

    [self.view bringSubviewToFront:self.progressView];
    [self.view bringSubviewToFront:self.streamBanner];
    [self updateChrome];
    [self saveSession];
}

- (void)closeTabAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count) return;

    if (self.tabs.count == 1) {
        [self.tabs.firstObject loadHome];
        return;
    }

    YumiTab *tab = self.tabs[(NSUInteger)index];
    BOOL wasActive = (index == self.activeIndex);
    tab.delegate = nil;
    [tab.webView stopLoading];
    [tab.webView removeFromSuperview];
    [self.tabs removeObjectAtIndex:(NSUInteger)index];

    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *entry in self.streams) {
        if (entry[@"tab"] != tab) [filtered addObject:entry];
    }
    self.streams = filtered;

    if (wasActive) {
        NSInteger newIndex = MIN(index, (NSInteger)self.tabs.count - 1);
        self.activeIndex = -1;
        [self selectTabAtIndex:newIndex];
    } else if (index < self.activeIndex) {
        self.activeIndex -= 1;
    }
    [self updateChrome];
    [self saveSession];
}

- (void)showTabs {
    TabsViewController *vc = [[TabsViewController alloc] initWithTabs:self.tabs activeIndex:self.activeIndex];
    vc.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentController:nav];
}

#pragma mark - TabsViewControllerDelegate

- (void)tabsController:(TabsViewController *)controller didSelectTabAtIndex:(NSInteger)index {
    [self selectTabAtIndex:index];
}

- (void)tabsController:(TabsViewController *)controller didCloseTabAtIndex:(NSInteger)index {
    [self closeTabAtIndex:index];
}

- (void)tabsControllerDidRequestNewTab:(TabsViewController *)controller {
    [self addHomeTab];
}

#pragma mark - Навигация

- (void)goBackTapped { [self.activeTab goBack]; [self updateChrome]; }
- (void)goForwardTapped { [self.activeTab goForward]; [self updateChrome]; }
- (void)goHomeTapped { [self.activeTab loadHome]; [self hideStreamBanner]; [self updateChrome]; }

- (void)reloadTapped {
    if (self.activeTab.isLoading) [self.activeTab stopLoading];
    else [self.activeTab reload];
    [self updateChrome];
}

- (BOOL)looksLikeURL:(NSString *)input {
    if (!input.length) return NO;
    if ([input containsString:@" "]) return NO;
    if ([input rangeOfString:@"."].location == NSNotFound) return NO;
    return YES;
}

- (void)navigateToInput:(NSString *)raw {
    NSString *input = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!input.length) return;

    NSURL *url = nil;
    if ([input containsString:@"://"]) {
        url = [NSURL URLWithString:input];
    } else if ([input hasPrefix:@"about:"]) {
        url = [NSURL URLWithString:input];
    } else if ([self looksLikeURL:input]) {
        url = [NSURL URLWithString:[@"https://" stringByAppendingString:input]];
    }

    if (url) {
        [self.activeTab loadURL:url];
    } else {
        NSString *encoded = [input stringByAddingPercentEncodingWithAllowedCharacters:
                             [NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *search = [NSString stringWithFormat:@"https://yandex.ru/search/?text=%@", encoded ?: @""];
        [self.activeTab loadURL:[NSURL URLWithString:search]];
    }
    [self hideStreamBanner];
}

- (void)openURLString:(NSString *)string {
    if (!string.length) return;
    if (!self.activeTab) {
        [self addTabWithURLString:string];
        return;
    }
    if (self.activeTab.displayURLString.length == 0) {
        [self.activeTab loadURL:[NSURL URLWithString:string]];
        return;
    }
    [self addTabWithURLString:string];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self navigateToInput:textField.text];
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    dispatch_async(dispatch_get_main_queue(), ^{
        UITextPosition *start = textField.beginningOfDocument;
        UITextPosition *end = textField.endOfDocument;
        if (start && end) textField.selectedTextRange = [textField textRangeFromPosition:start toPosition:end];
    });
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self updateChrome];
}

#pragma mark - Меню

- (void)menuTapped {
    YumiTab *tab = self.activeTab;
    NSString *host = tab.webView.URL.host ?: tab.url.host;
    BOOL desktop = host.length ? [[YumiSettings shared] isDesktopForHost:host] : NO;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Новая вкладка"
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *a) { [self addHomeTab]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Вкладки (%lu)", (unsigned long)self.tabs.count]
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *a) { [self showTabs]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Обновить"
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *a) { [self reloadTapped]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:(desktop ? @"Мобильная версия сайта" : @"Полная версия сайта")
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *a) { [self toggleDesktop]; }]];

    if (self.streams.count) {
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Потоки (%lu)", (unsigned long)self.streams.count]
                                                 style:UIAlertActionStyleDefault
                                               handler:^(__unused UIAlertAction *a) { [self showStreamsList]; }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Поделиться ссылкой"
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *a) { [self shareTapped]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Открыть в Safari"
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *a) { [self openInSafari]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Настройки"
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *a) { [self showSettings]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];

    sheet.popoverPresentationController.barButtonItem = self.menuItem;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)toggleDesktop {
    YumiTab *tab = self.activeTab;
    NSString *host = tab.webView.URL.host ?: tab.url.host;
    if (!host.length) {
        [self showToast:@"Сначала открой сайт"];
        return;
    }
    BOOL desktop = [[YumiSettings shared] isDesktopForHost:host];
    [[YumiSettings shared] setDesktop:!desktop forHost:host];
    [tab applyUserAgent];
    [tab reload];
    [self showToast:desktop ? @"Мобильная версия" : @"Полная версия"];
}

- (void)shareTapped {
    NSURL *url = self.activeTab.url ?: [NSURL URLWithString:self.activeTab.displayURLString];
    if (!url) {
        [self showToast:@"Нечего отправить"];
        return;
    }
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                          applicationActivities:nil];
    activity.popoverPresentationController.barButtonItem = self.menuItem;
    [self presentController:activity];
}

- (void)openInSafari {
    NSURL *url = self.activeTab.url ?: [NSURL URLWithString:self.activeTab.displayURLString];
    if (!url) return;
    [[UIApplication sharedApplication] openURL:url];
}

- (void)showSettings {
    SettingsViewController *vc = [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    vc.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentController:nav];
}

#pragma mark - Потоки

- (void)showStreamsList {
    if (!self.streams.count) {
        [self showToast:@"Потоки пока не найдены"];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Найденные потоки"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    NSInteger max = MIN(8, (NSInteger)self.streams.count);
    for (NSInteger i = 0; i < max; i++) {
        NSDictionary *info = self.streams[(NSUInteger)i];
        NSURL *url = [NSURL URLWithString:info[@"url"]];
        NSString *kind = [info[@"kind"] isKindOfClass:[NSString class]] ? [info[@"kind"] uppercaseString] : @"?";
        NSString *title = [NSString stringWithFormat:@"%@ · %@", kind, url.host ?: @"ссылка"];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(__unused UIAlertAction *a) {
            [self playStreamInfo:info];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Очистить список"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(__unused UIAlertAction *a) {
        [self.streams removeAllObjects];
        [self hideStreamBanner];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height - 60, 1, 1);
    [self presentController:sheet];
}

- (void)playStreamInfo:(NSDictionary *)info {
    NSString *urlString = info[@"url"];
    if (![urlString isKindOfClass:[NSString class]] || !urlString.length) return;
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;

    YumiTab *tab = info[@"tab"];
    if (![tab isKindOfClass:[YumiTab class]]) tab = self.activeTab;
    if (!tab) tab = self.activeTab;

    NSURL *page = nil;
    NSString *pageString = info[@"page"];
    if ([pageString isKindOfClass:[NSString class]] && pageString.length) {
        page = [NSURL URLWithString:pageString];
    }
    if (!page) page = tab.webView.URL ?: tab.url;
    NSString *title = [info[@"title"] isKindOfClass:[NSString class]] ? info[@"title"] : @"";

    [tab pauseMedia];

    NSString *ua = [[YumiSettings shared] userAgentForHost:page.host];
    __weak typeof(self) weakSelf = self;

    [tab cookieHeaderForURL:url completion:^(NSString *cookie) {
        NSMutableDictionary *headers = [NSMutableDictionary dictionary];
        if (page.absoluteString.length) {
            headers[@"Referer"] = page.absoluteString;
            if (page.host.length) {
                headers[@"Origin"] = [NSString stringWithFormat:@"%@://%@",
                                      page.scheme.length ? page.scheme : @"https", page.host];
            }
        }
        if (ua.length) headers[@"User-Agent"] = ua;
        if (cookie.length) headers[@"Cookie"] = cookie;

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf presentPlayerWithURL:url headers:headers title:title];
        });
    }];
}

- (void)presentPlayerWithURL:(NSURL *)url
                     headers:(NSDictionary *)headers
                       title:(NSString *)title {
    if ([self.presentedViewController isKindOfClass:[YumiPlayerViewController class]]) return;

    YumiPlayerViewController *player = [[YumiPlayerViewController alloc] initWithURL:url
                                                                            headers:headers
                                                                              title:title];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentController:player];
}

#pragma mark - Настройки

- (void)applySettingsToTabs {
    YumiSettings *settings = [YumiSettings shared];
    WKContentRuleList *rules = [YumiAdBlocker shared].ruleList;

    WKUserScript *poly = nil;
    WKUserScript *hook = nil;
    if (settings.mediaHookEnabled) {
        NSString *polySource = [YumiScripts polyfills];
        NSString *hookSource = [YumiScripts hook];
        if (polySource.length) {
            poly = [[WKUserScript alloc] initWithSource:polySource
                                            injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                         forMainFrameOnly:NO];
        }
        if (hookSource.length) {
            hook = [[WKUserScript alloc] initWithSource:hookSource
                                            injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                         forMainFrameOnly:NO];
        }
    }

    for (YumiTab *tab in self.tabs) {
        WKUserContentController *ucc = tab.webView.configuration.userContentController;
        [ucc removeAllUserScripts];
        if (poly) [ucc addUserScript:poly];
        if (hook) [ucc addUserScript:hook];
        [ucc removeAllContentRuleLists];
        if (settings.adblockEnabled && rules) [ucc addContentRuleList:rules];
        [tab applyUserAgent];
    }
}

- (void)settingsDidChange:(SettingsViewController *)controller {
    [self applySettingsToTabs];
    [self.activeTab reload];
    [self updateChrome];
}

- (void)refreshContentBlocking {
    [self applySettingsToTabs];
    [self.activeTab reload];
}

- (void)settingsDidRequestClearData:(SettingsViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:^{
        [self confirmClearData];
    }];
}

- (void)settingsDidRequestReset:(SettingsViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:^{
        [self confirmReset];
    }];
}

- (void)confirmClearData {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Очистить данные?"
                                                                  message:@"Куки, кэш и localStorage будут удалены. Логин на сайтах слетит."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Очистить" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        [self clearWebsiteData];
    }]];
    [self presentController:alert];
}

- (void)clearWebsiteData {
    NSSet *types = [WKWebsiteDataStore allWebsiteDataTypes];
    __weak typeof(self) weakSelf = self;
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:types
                                               modifiedSince:[NSDate dateWithTimeIntervalSince1970:0]
                                           completionHandler:^{
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        dispatch_async(dispatch_get_main_queue(), ^{
            for (YumiTab *tab in weakSelf.tabs) [tab reload];
            [weakSelf showToast:@"Данные очищены"];
        });
    }];
}

- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Сбросить настройки?"
                                                                  message:@"Вернутся стандартные UA, блокировка рекламы и перехват потоков. Вкладки закроются."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Сбросить" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        [self resetEverything];
    }]];
    [self presentController:alert];
}

- (void)resetEverything {
    [YumiSettings reset];
    for (YumiTab *tab in [self.tabs copy]) {
        tab.delegate = nil;
        [tab.webView stopLoading];
        [tab.webView removeFromSuperview];
    }
    [self.tabs removeAllObjects];
    [self.streams removeAllObjects];
    self.activeIndex = 0;
    [self applySettingsToTabs];
    [self addHomeTab];
    [self showToast:@"Настройки сброшены"];
}

#pragma mark - Сессия

- (void)saveSession {
    NSMutableArray *urls = [NSMutableArray array];
    for (YumiTab *tab in self.tabs) {
        NSString *string = tab.url.absoluteString;
        if (!string.length) string = tab.pendingURLString;
        [urls addObject:string ?: @""];
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:urls forKey:kYumiSessionURLs];
    [defaults setInteger:self.activeIndex forKey:kYumiSessionIndex];
    [defaults synchronize];
}

- (void)restoreSession {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *urls = [defaults arrayForKey:kYumiSessionURLs];

    if (urls.count) {
        for (id item in urls) {
            YumiTab *tab = [self createTab];
            if ([item isKindOfClass:[NSString class]] && [item length] &&
                ![item isEqualToString:@"about:blank"]) {
                tab.pendingURLString = item;
            }
            [self.tabs addObject:tab];
        }

        NSInteger index = [defaults integerForKey:kYumiSessionIndex];
        if (index < 0 || index >= (NSInteger)self.tabs.count) index = 0;
        [self selectTabAtIndex:index];

        YumiTab *active = self.activeTab;
        if (!active.pendingURLString.length &&
            (!active.webView.URL || [active.webView.URL.absoluteString isEqualToString:@"about:blank"])) {
            [active loadHome];
        }
    } else {
        [self addHomeTab];
    }
}

#pragma mark - Мост из JS

- (void)setupBridge {
    __weak typeof(self) weakSelf = self;
    [YumiBridge shared].handler = ^(WKWebView *webView, NSDictionary *message) {
        [weakSelf handleBridgeMessage:message fromWebView:webView];
    };
}

- (YumiTab *)tabForWebView:(WKWebView *)webView {
    for (YumiTab *tab in self.tabs) {
        if (tab.webView == webView) return tab;
    }
    return nil;
}

- (void)handleBridgeMessage:(NSDictionary *)message fromWebView:(WKWebView *)webView {
    NSString *type = message[@"type"];
    if (![type isKindOfClass:[NSString class]]) return;

    if ([type isEqualToString:@"stream"]) {
        YumiTab *tab = [self tabForWebView:webView] ?: self.activeTab;
        if (tab) [self tab:tab didFindStreamInfo:message];
    } else if ([type isEqualToString:@"open"]) {
        NSString *string = message[@"url"];
        if (![string isKindOfClass:[NSString class]] || !string.length) return;
        NSURL *url = [NSURL URLWithString:string];
        if ([YumiSettings shared].adblockEnabled && [YumiAdBlocker isAdHost:url.host]) return;
        [self addTabWithURLString:string];
    }
}

#pragma mark - YumiTabDelegate

- (void)tabDidStartLoading:(YumiTab *)tab {
    if (tab != self.activeTab) return;
    self.progressView.hidden = NO;
    self.progressView.progress = 0.08;
    [self updateChrome];
}

- (void)tabDidFinishLoading:(YumiTab *)tab {
    if (tab != self.activeTab) return;
    self.progressView.progress = 1.0;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!weakSelf.activeTab.isLoading) {
            weakSelf.progressView.hidden = YES;
            weakSelf.progressView.progress = 0.0;
        }
    });
    [self updateChrome];
}

- (void)tab:(YumiTab *)tab didUpdateTitle:(NSString *)title {
    if (tab == self.activeTab) [self updateChrome];
}

- (void)tab:(YumiTab *)tab didUpdateURL:(NSURL *)url {
    if (tab != self.activeTab) return;
    if (!self.addressField.isFirstResponder) {
        self.addressField.text = [tab displayURLString] ?: @"";
    }
    [self updateChrome];
}

- (void)tab:(YumiTab *)tab didUpdateProgress:(double)progress {
    if (tab != self.activeTab) return;
    self.progressView.hidden = NO;
    self.progressView.progress = (float)MAX(0.05, MIN(1.0, progress));
    if (progress >= 1.0) {
        self.progressView.progress = 1.0;
    }
}

- (void)tab:(YumiTab *)tab didFailWithError:(NSError *)error {
    if (tab != self.activeTab) return;
    if (error.code == NSURLErrorCancelled || error.code == 102) return;
    if ([self.presentedViewController isKindOfClass:[YumiPlayerViewController class]]) return;

    NSString *message = error.localizedDescription ?: @"Не удалось загрузить страницу";
    __weak typeof(self) weakSelf = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ошибка загрузки"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Обновить" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        [weakSelf.activeTab reload];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ок" style:UIAlertActionStyleCancel handler:nil]];
    [self presentController:alert];
}

- (void)tab:(YumiTab *)tab didFindStreamInfo:(NSDictionary *)info {
    if (![YumiSettings shared].mediaHookEnabled) return;

    NSString *urlString = info[@"url"];
    if (![urlString isKindOfClass:[NSString class]] || urlString.length < 8) return;
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return;
    if ([YumiAdBlocker isAdHost:url.host]) return;
    if ([info[@"ad"] boolValue]) return;

    for (NSDictionary *existing in self.streams) {
        if ([existing[@"url"] isEqualToString:urlString]) return;
    }

    NSMutableDictionary *entry = [info mutableCopy];
    entry[@"url"] = urlString;
    if (tab) entry[@"tab"] = tab;
    [self.streams insertObject:entry atIndex:0];
    while (self.streams.count > 12) [self.streams removeLastObject];

    [self showStreamBannerWithInfo:entry];

    if ([YumiSettings shared].autoNativePlayer && [entry[@"kind"] isEqualToString:@"hls"]) {
        [self playStreamInfo:entry];
    }
}

- (void)tab:(YumiTab *)tab openExternalURL:(NSURL *)url {
    if (!url) return;
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url];
    } else {
        [self showToast:@"Нет приложения для этой ссылки"];
    }
}

- (WKWebView *)tab:(YumiTab *)tab
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
                 navigationAction:(WKNavigationAction *)navigationAction {
    NSURL *url = navigationAction.request.URL;
    if ([YumiSettings shared].adblockEnabled && [YumiAdBlocker isAdHost:url.host]) {
        NSLog(@"[Yumi] blocked popup: %@", url.host);
        return nil;
    }

    if ([YumiTab isDirectMediaURL:url]) {
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[@"url"] = url.absoluteString;
        info[@"kind"] = [url.pathExtension.lowercaseString isEqualToString:@"m3u8"] ? @"hls" : @"mp4";
        info[@"page"] = tab.webView.URL.absoluteString ?: (tab.url.absoluteString ?: @"");
        info[@"title"] = tab.title ?: @"";
        [self tab:tab didFindStreamInfo:info];
        return nil;
    }

    if (self.tabs.count >= 12) {
        for (NSInteger i = 0; i < (NSInteger)self.tabs.count; i++) {
            if (i != self.activeIndex) { [self closeTabAtIndex:i]; break; }
        }
    }

    YumiTab *newTab = [self createTabWithConfiguration:configuration];
    [self.tabs addObject:newTab];
    [self selectTabAtIndex:(NSInteger)self.tabs.count - 1];
    return newTab.webView;
}

- (void)tab:(YumiTab *)tab showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ок" style:UIAlertActionStyleDefault handler:nil]];
    [self presentController:alert];
}

- (void)tab:(YumiTab *)tab
    showConfirmWithTitle:(NSString *)title
                 message:(NSString *)message
              completion:(void (^)(BOOL))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *a) {
        if (completion) completion(NO);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ок" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        if (completion) completion(YES);
    }]];
    [self presentController:alert];
}

#pragma mark - Вспомогательное

- (void)presentController:(UIViewController *)controller {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presented = self.presentedViewController;
        if (!presented) {
            [self presentViewController:controller animated:YES completion:nil];
        } else if (![presented isKindOfClass:[YumiPlayerViewController class]] &&
                   ![controller isKindOfClass:[YumiPlayerViewController class]]) {
            [presented dismissViewControllerAnimated:YES completion:^{
                [self presentViewController:controller animated:YES completion:nil];
            }];
        } else if ([controller isKindOfClass:[YumiPlayerViewController class]] &&
                   ![presented isKindOfClass:[YumiPlayerViewController class]]) {
            [presented dismissViewControllerAnimated:YES completion:^{
                [self presentViewController:controller animated:YES completion:nil];
            }];
        }
    });
}

- (void)showToast:(NSString *)text {
    if (!text.length) return;
    UILabel *toast = [[UILabel alloc] init];
    toast.text = text;
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    toast.textColor = [UIColor whiteColor];
    toast.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.numberOfLines = 0;
    toast.layer.cornerRadius = 10.0;
    toast.clipsToBounds = YES;
    CGSize size = [text sizeWithAttributes:@{NSFontAttributeName: toast.font}];
    CGFloat width = MIN(self.view.bounds.size.width - 40, size.width + 32);
    toast.frame = CGRectMake((self.view.bounds.size.width - width) / 2,
                             self.view.bounds.size.height - 120,
                             width, 40);
    toast.alpha = 0;
    toast.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:toast];
    [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 1; } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.25 animations:^{ toast.alpha = 0; } completion:^(BOOL finished2) {
                [toast removeFromSuperview];
            }];
        });
    }];
}

@end
