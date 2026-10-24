#import "BrowserViewController.h"
#import "YumiSettings.h"
#import "YumiAdBlocker.h"
#import "YumiIcons.h"
#import "YumiPlayer.h"
#import "YumiBridge.h"
#import "YumiScripts.h"
#import "TabsViewController.h"
#import "SettingsViewController.h"
#import "GitHubSearchViewController.h"
#import "YumiYummyResolver.h"
#import "YummyEpisodesViewController.h"
#import "YumiSiteStore.h"
#import "YumiResumeStore.h"
#import "YumiAnilibriaResolver.h"

static NSString *const kYumiSessionURLs = @"YumiSessionURLs";
static NSString *const kYumiSessionIndex = @"YumiSessionIndex";

@interface BrowserViewController () <TabsViewControllerDelegate, SettingsViewControllerDelegate, WKUIDelegate, UIGestureRecognizerDelegate, YummyEpisodesViewControllerDelegate, GitHubSearchViewControllerDelegate>

@property (nonatomic, strong) NSMutableArray<YumiTab *> *tabs;
@property (nonatomic, assign) NSInteger activeIndex;
@property (nonatomic, assign) BOOL incognito;
@property (nonatomic, strong) WKWebsiteDataStore *incognitoDataStore;

@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, strong) UIProgressView *progressView;

@property (nonatomic, strong) UIBarButtonItem *backItem;
@property (nonatomic, strong) UIBarButtonItem *forwardItem;
@property (nonatomic, strong) UIBarButtonItem *reloadItem;
@property (nonatomic, strong) UIBarButtonItem *menuItem;
@property (nonatomic, strong) UIBarButtonItem *tabsItem;
@property (nonatomic, strong) UIBarButtonItem *homeItem;
@property (nonatomic, strong) UIBarButtonItem *streamsItem;
@property (nonatomic, strong) UIBarButtonItem *downloadsItem;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *streams;
@property (nonatomic, strong) NSDictionary *streamInfo;
@property (nonatomic, strong) UIView *streamBanner;
@property (nonatomic, strong) UILabel *streamLabel;
@property (nonatomic, strong) UILabel *streamSubLabel;

@property (nonatomic, strong) UIButton *yummyButton;
@property (nonatomic, strong) UIButton *resumeButton;
@property (nonatomic, copy) NSString *yummyPageID;
@property (nonatomic, copy) NSString *anilibriaPageID;
@property (nonatomic, copy) NSDictionary *resumeInfo;

@property (nonatomic, strong) UIAlertController *downloadAlert;
@property (nonatomic, strong) NSURLSession *downloadSession;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;
@property (nonatomic, strong) NSTimer *downloadTimer;
@property (nonatomic, assign) BOOL downloadCancelled;
@property (nonatomic, assign) NSUInteger downloadGeneration;

- (void)installAnilibriaWebPSupportForTab:(YumiTab *)tab;
- (void)installCompatibilityStyleForTab:(YumiTab *)tab;
- (void)downloadURL:(NSURL *)url suggestedFilename:(NSString *)filename;
- (void)promptDownloadURL;
- (void)openGitHubReleases;
- (void)openGitHubRepositories;
- (void)showGitHubSearch;
- (void)promptGitHubProfileWithLogin:(NSString *)login;
- (void)openDownloadsInFilza;
- (void)scanPageForDownloads;
- (void)handleGitHubAssetsMessage:(NSDictionary *)message fromWebView:(WKWebView *)webView;
- (void)startDownloadURL:(NSURL *)url
               filename:(NSString *)filename
                 pageURL:(NSURL *)pageURL
                  cookie:(NSString *)cookie
               userAgent:(NSString *)userAgent;
- (void)presentDownloadAlertIfCurrent:(UIAlertController *)alert;
- (void)dismissDownloadUIWithCompletion:(void (^)(void))completion;
- (void)cancelDownload;
- (void)updateDownloadProgress:(NSTimer *)timer;
- (void)presentDownloadError:(NSError *)error url:(NSURL *)url filename:(NSString *)filename;
- (void)updateIncognitoAppearance;
- (void)setIncognitoMode:(BOOL)enable;

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
    [self setupYummyButton];
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
    [self updateIncognitoAppearance];
    [self updateChrome];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = NO;
    [self updateIncognitoAppearance];
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
    field.keyboardType = UIKeyboardTypeWebSearch;
    field.returnKeyType = UIReturnKeyGo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.spellCheckingType = UITextSpellCheckingTypeNo;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.delegate = self;
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
    self.streamsItem = [self itemWithImage:[YumiIcons streams] action:@selector(showStreamsList) label:@"Потоки"];
    self.downloadsItem = [self itemWithImage:[YumiIcons download] action:@selector(openDownloadsInFilza) label:@"Загрузки"];

    UIBarButtonItem *(^flex)(void) = ^{
        return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                             target:nil
                                                             action:nil];
    };

    // Keep the streams button centered: the invisible fixed space balances the
    // new downloads button on the opposite side of the flexible layout.
    UIBarButtonItem *balance =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                       target:nil
                                                       action:nil];
    balance.width = 30.0;
    self.toolbarItems = @[self.backItem, flex(), self.forwardItem, flex(),
                          balance, flex(), self.streamsItem, flex(),
                          self.downloadsItem, flex(), self.tabsItem, flex(), self.homeItem];
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
        [close.heightAnchor constraintEqualToConstant:36]
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

- (WKWebsiteDataStore *)incognitoDataStore {
    if (!_incognitoDataStore) {
        _incognitoDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    }
    return _incognitoDataStore;
}

- (YumiTab *)createTab {
    WKWebViewConfiguration *configuration = nil;
    if (self.incognito) {
        configuration = [YumiTab configurationWithDataStore:[self incognitoDataStore]];
    }
    return [[YumiTab alloc] initWithConfiguration:configuration delegate:self];
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
    [self.view bringSubviewToFront:self.yummyButton];
    [self.view bringSubviewToFront:self.resumeButton];
    [self refreshYummyAvailabilityForTab:tab];
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
- (void)goHomeTapped { [self.activeTab loadHome]; [self hideStreamBanner]; self.yummyPageID = nil; self.anilibriaPageID = nil; self.resumeInfo = nil; self.yummyButton.hidden = YES; self.resumeButton.hidden = YES; [self updateChrome]; }

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
        NSURL *searchURL = [[YumiSettings shared] searchURLForQuery:input];
        if (searchURL) [self.activeTab loadURL:searchURL];
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
    [sheet addAction:[UIAlertAction actionWithTitle:(self.incognito ? @"Выйти из инкогнито" : @"Инкогнито")
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *a) { [self toggleIncognito]; }]];
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
    [sheet addAction:[UIAlertAction actionWithTitle:@"Скачать файл по ссылке…"
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *a) { [self promptDownloadURL]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Скачать с этой страницы…"
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *a) { [self scanPageForDownloads]; }]];
    if ([host isEqualToString:@"github.com"] || [host isEqualToString:@"www.github.com"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Мои репозитории GitHub"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(__unused UIAlertAction *a) { [self openGitHubRepositories]; }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Поиск на GitHub…"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(__unused UIAlertAction *a) { [self showGitHubSearch]; }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Открыть профиль GitHub…"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(__unused UIAlertAction *a) { [self promptGitHubProfileWithLogin:nil]; }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Релизы GitHub"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(__unused UIAlertAction *a) { [self openGitHubReleases]; }]];
    }
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

- (void)toggleIncognito {
    if (self.incognito) {
        [self setIncognitoMode:NO];
        return;
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Включить инкогнито?"
                                            message:@"Текущие вкладки закроются. Cookies, кэш и история не сохранятся на устройстве."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Включить" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        [self setIncognitoMode:YES];
    }]];
    dispatch_async(dispatch_get_main_queue(), ^{ [self presentController:alert]; });
}

- (void)setIncognitoMode:(BOOL)enable {
    if (self.incognito == enable) return;
    self.incognito = enable;

    for (YumiTab *tab in [self.tabs copy]) {
        tab.delegate = nil;
        [tab.webView stopLoading];
        [tab.webView removeFromSuperview];
    }
    [self.tabs removeAllObjects];
    [self.streams removeAllObjects];
    [self hideStreamBanner];

    self.yummyPageID = nil;
    self.anilibriaPageID = nil;
    self.resumeInfo = nil;
    self.yummyButton.hidden = YES;
    self.resumeButton.hidden = YES;
    self.activeIndex = 0;

    if (!enable) {
        // Non-persistent store: releasing it drops all private cookies/cache.
        _incognitoDataStore = nil;
    }

    [self addHomeTab];
    [self updateIncognitoAppearance];
    [self showToast:(enable ? @"Режим инкогнито" : @"Обычный режим")];
}

- (void)updateIncognitoAppearance {
    UIColor *normalTint = [UIColor colorWithRed:0.18 green:0.45 blue:0.94 alpha:1.0];
    UIColor *privateTint = [UIColor colorWithRed:0.45 green:0.26 blue:0.76 alpha:1.0];
    UIColor *tint = self.incognito ? privateTint : normalTint;

    self.view.tintColor = tint;
    self.navigationController.navigationBar.tintColor = tint;
    self.navigationController.toolbar.tintColor = tint;
    self.addressField.placeholder = self.incognito ? @"Инкогнито — поиск или адрес" : @"Поиск или адрес";
    self.addressField.backgroundColor = self.incognito
        ? [UIColor colorWithRed:0.945 green:0.918 blue:1.0 alpha:1.0]
        : [UIColor colorWithWhite:0.94 alpha:1.0];
    self.addressField.textColor = self.incognito ? privateTint : [UIColor blackColor];
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

- (void)openGitHubRepositories {
    YumiTab *tab = self.activeTab;
    NSURL *url = tab.webView.URL ?: tab.url;
    NSString *host = url.host.lowercaseString;
    if (![host isEqualToString:@"github.com"] && ![host isEqualToString:@"www.github.com"]) {
        [self showToast:@"Открой страницу GitHub"];
        return;
    }

    [tab.webView evaluateJavaScript:
        @"(function(){var m=document.querySelector('meta[name=\"user-login\"]');"
         "return m?(m.getAttribute('content')||''):'';})()"
                  completionHandler:^(id result, __unused NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *login = [result isKindOfClass:[NSString class]] ? result : @"";
            NSString *target = login.length
                ? [NSString stringWithFormat:@"https://github.com/%@?tab=repositories", login]
                : @"https://github.com/settings/repositories";
            [tab loadURL:[NSURL URLWithString:target]];
        });
    }];
}

- (void)scanPageForDownloads {
    YumiTab *tab = self.activeTab;
    NSString *script = [YumiScripts downloadLinks];
    if (!tab || !script.length) {
        [self showToast:@"Нет активной страницы"];
        return;
    }

    [tab.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || ![result isKindOfClass:[NSString class]]) {
                [self showToast:@"Не удалось прочитать страницу"];
                return;
            }
            NSData *data = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
            id root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if (![root isKindOfClass:[NSArray class]] || ![root count]) {
                [self showToast:@"Ссылки для скачивания не найдены"];
                return;
            }

            NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
            for (id raw in (NSArray *)root) {
                if (![raw isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *dict = (NSDictionary *)raw;
                NSString *urlString = dict[@"url"];
                if (![urlString isKindOfClass:[NSString class]]) continue;
                NSURL *url = [NSURL URLWithString:urlString];
                if (!url) continue;
                NSString *scheme = url.scheme.lowercaseString;
                if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) continue;
                NSString *name = dict[@"name"];
                if (![name isKindOfClass:[NSString class]] || !name.length) name = url.lastPathComponent;
                BOOL isFile = [dict[@"file"] boolValue];
                [items addObject:@{@"url": url, @"name": name, @"file": @(isFile)}];
            }

            if (!items.count) {
                [self showToast:@"Ссылки для скачивания не найдены"];
                return;
            }

            UIAlertController *sheet =
                [UIAlertController alertControllerWithTitle:@"Скачать с этой страницы"
                                                    message:@"Выбери файл или страницу загрузки"
                                             preferredStyle:UIAlertControllerStyleActionSheet];
            for (NSDictionary *item in items) {
                NSDictionary *captured = item;
                NSString *title = item[@"name"];
                if (title.length > 72) title = [[title substringToIndex:69] stringByAppendingString:@"…"];
                if (![item[@"file"] boolValue]) title = [title stringByAppendingString:@" — открыть страницу"];
                [sheet addAction:[UIAlertAction actionWithTitle:title
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(__unused UIAlertAction *action) {
                    if ([captured[@"file"] boolValue]) {
                        [self tab:tab downloadURL:captured[@"url"]
                                suggestedFilename:captured[@"name"]];
                    } else {
                        [self addTabWithURLString:[captured[@"url"] absoluteString]];
                    }
                }]];
            }
            [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена"
                                                      style:UIAlertActionStyleCancel
                                                    handler:nil]];
            sheet.popoverPresentationController.sourceView = self.view;
            sheet.popoverPresentationController.sourceRect =
                CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
            [self presentController:sheet];
        });
    }];
}

- (void)handleGitHubAssetsMessage:(NSDictionary *)message fromWebView:(WKWebView *)webView {
    YumiTab *tab = [self tabForWebView:webView] ?: self.activeTab;
    if (!tab) return;

    NSArray *rawAssets = message[@"assets"];
    NSMutableArray<NSDictionary *> *assets = [NSMutableArray array];
    if ([rawAssets isKindOfClass:[NSArray class]]) {
        for (id item in rawAssets) {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *dict = (NSDictionary *)item;
            NSString *urlString = dict[@"url"];
            if (![urlString isKindOfClass:[NSString class]] || !urlString.length) continue;
            NSURL *url = [NSURL URLWithString:urlString];
            if (!url) continue;
            NSString *scheme = url.scheme.lowercaseString;
            if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) continue;
            NSString *name = dict[@"name"];
            if (![name isKindOfClass:[NSString class]] || !name.length) {
                name = url.lastPathComponent.length ? url.lastPathComponent : @"asset";
            }
            [assets addObject:@{@"url": url, @"name": name}];
        }
    }

    if (!assets.count) {
        NSString *error = message[@"error"];
        [self showToast:([error isKindOfClass:[NSString class]] && error.length)
            ? error : @"Ассеты не найдены"];
        return;
    }

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:@"Ассеты релиза"
                                            message:@"Что скачать?"
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *asset in assets) {
        NSDictionary *captured = asset;
        NSString *title = asset[@"name"];
        if (title.length > 72) {
            title = [[title substringToIndex:69] stringByAppendingString:@"…"];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [self tab:tab downloadURL:captured[@"url"] suggestedFilename:captured[@"name"]];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    [self presentController:sheet];
}

- (void)openDownloadsInFilza {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                               NSUserDomainMask, YES) firstObject];
    if (!documents.length) {
        [self showToast:@"Не удалось открыть папку загрузок"];
        return;
    }
    NSString *directory = [documents stringByAppendingPathComponent:@"Downloads"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSString *encoded = [directory stringByAddingPercentEncodingWithAllowedCharacters:
                         [NSCharacterSet URLPathAllowedCharacterSet]] ?: directory;
    NSString *withoutLeadingSlash = [encoded hasPrefix:@"/"] ? [encoded substringFromIndex:1] : encoded;
    NSArray<NSString *> *candidates = @[
        [NSString stringWithFormat:@"filza://view%@", encoded],
        [NSString stringWithFormat:@"filza://%@", withoutLeadingSlash],
        @"filza://"
    ];
    for (NSString *candidate in candidates) {
        NSURL *url = [NSURL URLWithString:candidate];
        if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url];
            return;
        }
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Filza не найдена"
                                            message:[NSString stringWithFormat:@"Папка загрузок:\n%@", directory]
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Скопировать путь"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = directory;
        [self showToast:@"Путь скопирован"];
    }]];
    NSURL *filesURL = [NSURL URLWithString:@"shareddocuments://"];
    if (filesURL && [[UIApplication sharedApplication] canOpenURL:filesURL]) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Открыть Файлы"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:filesURL];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentController:alert];
}

- (void)showGitHubSearch {
    GitHubSearchViewController *vc =
        [[GitHubSearchViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentController:nav];
}

- (void)gitHubSearchController:(GitHubSearchViewController *)controller openURL:(NSURL *)url {
    [controller dismissViewControllerAnimated:YES completion:^{
        if (url) [self addTabWithURLString:url.absoluteString];
    }];
}

- (void)promptGitHubProfileWithLogin:(NSString *)login {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Профиль GitHub"
                                            message:@"Имя пользователя или организации"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = login ?: @"";
        field.placeholder = @"например, torvalds";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.keyboardType = UIKeyboardTypeWebSearch;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Открыть"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text ?: @"";
        name = [name stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([name hasPrefix:@"@"]) name = [name substringFromIndex:1];
        NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
            @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._"];
        NSCharacterSet *bad = [allowed invertedSet];
        if (!name.length || [name rangeOfCharacterFromSet:bad].location != NSNotFound) {
            [self showToast:@"Некорректное имя профиля"];
            return;
        }
        NSString *urlString = [NSString stringWithFormat:@"https://github.com/%@", name];
        [self addTabWithURLString:urlString];
    }]];
    [self presentController:alert];
}

- (void)openGitHubReleases {
    NSURL *url = self.activeTab.webView.URL ?: self.activeTab.url;
    NSString *host = url.host.lowercaseString;
    if (![host isEqualToString:@"github.com"] && ![host isEqualToString:@"www.github.com"]) {
        [self showToast:@"Открой страницу GitHub"];
        return;
    }
    NSArray<NSString *> *parts = url.pathComponents;
    if (parts.count < 3) {
        [self showToast:@"Открой страницу репозитория"];
        return;
    }
    static NSSet *reserved = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        reserved = [NSSet setWithArray:@[@"login", @"signup", @"settings", @"notifications",
                                         @"explore", @"topics", @"collections", @"sponsors",
                                         @"marketplace", @"orgs", @"users", @"search", @"new"]];
    });
    if ([reserved containsObject:parts[1].lowercaseString]) {
        [self showToast:@"Открой страницу репозитория"];
        return;
    }
    NSString *releases = [NSString stringWithFormat:@"https://github.com/%@/%@/releases",
                          parts[1], parts[2]];
    [self.activeTab loadURL:[NSURL URLWithString:releases]];
}

#pragma mark - Скачивание

- (void)promptDownloadURL {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Скачать файл"
                                            message:@"Прямая ссылка на .deb, .ipa или другой файл"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"https://…";
        field.keyboardType = UIKeyboardTypeWebSearch;
        field.returnKeyType = UIReturnKeyGo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        NSString *clipboard = [UIPasteboard generalPasteboard].string;
        if ([clipboard hasPrefix:@"http://"] || [clipboard hasPrefix:@"https://"]) {
            field.text = clipboard;
        }
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Скачать"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text ?: @"";
        text = [text stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (![text containsString:@"://"]) text = [@"https://" stringByAppendingString:text];
        NSURL *url = [NSURL URLWithString:text];
        NSString *scheme = url.scheme.lowercaseString;
        if (!url || (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])) {
            [self showToast:@"Нужна http(s)-ссылка"];
            return;
        }
        [self downloadURL:url suggestedFilename:nil];
    }]];
    [self presentController:alert];
}

- (void)downloadURL:(NSURL *)url suggestedFilename:(NSString *)filename {
    YumiTab *tab = self.activeTab;
    if (!tab) {
        [self showToast:@"Нет активной вкладки"];
        return;
    }
    [self tab:tab downloadURL:url suggestedFilename:filename];
}

- (void)tab:(YumiTab *)tab downloadURL:(NSURL *)url suggestedFilename:(NSString *)filename {
    if (!url) return;
    if (!tab) tab = self.activeTab;
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
        [self showToast:@"Эта ссылка не поддерживается"];
        return;
    }
    if (!tab) {
        [self showToast:@"Нет активной вкладки"];
        return;
    }

    NSURL *pageURL = tab.webView.URL ?: tab.url;
    NSString *userAgent = [[YumiSettings shared] userAgentForHost:url.host];
    [self showToast:@"Скачивание…"];
    [tab cookieHeaderForURL:url completion:^(NSString *cookie) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startDownloadURL:url
                          filename:filename
                           pageURL:pageURL
                            cookie:cookie
                         userAgent:userAgent];
        });
    }];
}

- (void)startDownloadURL:(NSURL *)url
                filename:(NSString *)filename
                  pageURL:(NSURL *)pageURL
                   cookie:(NSString *)cookie
                userAgent:(NSString *)userAgent {
    self.downloadGeneration += 1;
    NSUInteger generation = self.downloadGeneration;
    if (self.downloadTask) {
        self.downloadCancelled = YES;
        [self.downloadTask cancel];
        [self.downloadSession invalidateAndCancel];
        [self dismissDownloadUIWithCompletion:nil];
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 300.0;
    config.timeoutIntervalForResource = 1800.0;
    config.HTTPShouldSetCookies = NO;
    config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;

    NSString *host = url.host.lowercaseString;
    BOOL github = [host isEqualToString:@"github.com"] ||
                  [host hasSuffix:@".github.com"] ||
                  [host hasSuffix:@"githubusercontent.com"];
    // GitHub's web session may keep serving an iOS-12-specific edge for the
    // asset redirect. A desktop UA is harmless for a signed asset URL.
    NSString *downloadUA = github
        ? @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
           "(KHTML, like Gecko) Version/16.6 Safari/605.1.15"
        : userAgent;

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                            timeoutInterval:300.0];
    [request setValue:(github ? @"application/octet-stream" : @"*/*")
   forHTTPHeaderField:@"Accept"];
    [request setValue:@"ru-RU,ru;q=0.9,en;q=0.8" forHTTPHeaderField:@"Accept-Language"];
    if (downloadUA.length) [request setValue:downloadUA forHTTPHeaderField:@"User-Agent"];
    if (cookie.length) [request setValue:cookie forHTTPHeaderField:@"Cookie"];
    if (pageURL.absoluteString.length) [request setValue:pageURL.absoluteString forHTTPHeaderField:@"Referer"];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                         delegate:nil
                                                    delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionDownloadTask *task =
        [session downloadTaskWithRequest:request
                       completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        [session finishTasksAndInvalidate];
        if (generation != self.downloadGeneration) return;

        [self.downloadTimer invalidate];
        self.downloadTimer = nil;
        if (self.downloadCancelled) {
            [self dismissDownloadUIWithCompletion:nil];
            return;
        }

        if (error || !location) {
            NSError *downloadError = error ?: [NSError errorWithDomain:@"YumiDownload"
                                                                  code:-1
                                                              userInfo:@{NSLocalizedDescriptionKey: @"Не удалось скачать файл"}];
            [self dismissDownloadUIWithCompletion:^{
                [self presentDownloadError:downloadError url:url filename:filename];
            }];
            return;
        }

        NSString *mime = [(response.MIMEType ?: @"") lowercaseString];
        if ([mime containsString:@"text/html"]) {
            NSError *htmlError = [NSError errorWithDomain:@"YumiDownload"
                                                     code:-2
                                                 userInfo:@{NSLocalizedDescriptionKey:
                    @"Сервер вернул страницу вместо файла. Для приватного репозитория GitHub сначала войди в аккаунт."}];
            [self dismissDownloadUIWithCompletion:^{
                [self presentDownloadError:htmlError url:url filename:filename];
            }];
            return;
        }

        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *name = filename.length ? filename : response.suggestedFilename;
        if (!name.length) name = url.lastPathComponent;
        name = [name stringByRemovingPercentEncoding] ?: name;
        name = [name stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
        name = [name stringByReplacingOccurrencesOfString:@"\\" withString:@"_"];
        name = [name stringByReplacingOccurrencesOfString:@":" withString:@"_"];
        name = [name stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!name.length || [name isEqualToString:@"."] || [name isEqualToString:@".."]) {
            name = @"download";
        }
        if (![name pathExtension].length && [url pathExtension].length) {
            name = [name stringByAppendingPathExtension:url.pathExtension];
        }

        NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                                   NSUserDomainMask, YES) firstObject];
        NSString *directory = [documents stringByAppendingPathComponent:@"Downloads"];
        [fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];

        NSString *destination = [directory stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:destination]) {
            NSString *base = [name stringByDeletingPathExtension];
            NSString *extension = [name pathExtension];
            NSInteger index = 1;
            do {
                NSString *candidate = extension.length
                    ? [NSString stringWithFormat:@"%@-%ld.%@", base, (long)index, extension]
                    : [NSString stringWithFormat:@"%@-%ld", base, (long)index];
                destination = [directory stringByAppendingPathComponent:candidate];
                index += 1;
            } while ([fm fileExistsAtPath:destination]);
        }

        NSURL *destinationURL = [NSURL fileURLWithPath:destination];
        NSError *fileError = nil;
        BOOL saved = [fm moveItemAtURL:location toURL:destinationURL error:&fileError];
        if (!saved) {
            saved = [fm copyItemAtURL:location toURL:destinationURL error:&fileError];
        }
        if (!saved) {
            NSError *saveError = fileError ?: [NSError errorWithDomain:@"YumiDownload"
                                                                  code:-3
                                                              userInfo:@{NSLocalizedDescriptionKey: @"Ошибка файловой системы"}];
            [self dismissDownloadUIWithCompletion:^{
                [self presentDownloadError:saveError url:url filename:filename];
            }];
            return;
        }

        [self dismissDownloadUIWithCompletion:^{
            [self showToast:[NSString stringWithFormat:@"Скачано: %@", destinationURL.lastPathComponent]];
        }];
    }];

    self.downloadCancelled = NO;
    self.downloadSession = session;
    self.downloadTask = task;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Скачивание файла"
                                            message:@"Ожидание ответа…"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена"
                                              style:UIAlertActionStyleCancel
                                            handler:^(__unused UIAlertAction *action) {
        [self cancelDownload];
    }]];
    self.downloadAlert = alert;
    // Fast downloads should not flash a modal. Show the progress/cancel alert
    // only if the transfer is still running after a second.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self.downloadTask == task && self.downloadAlert == alert) {
            [self presentDownloadAlertIfCurrent:alert];
        }
    });
    self.downloadTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(updateDownloadProgress:)
                                                       userInfo:nil
                                                        repeats:YES];
    [task resume];
}

- (void)presentDownloadAlertIfCurrent:(UIAlertController *)alert {
    if (self.downloadAlert != alert) return;
    UIViewController *presented = self.presentedViewController;
    if (!presented) {
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    if ([presented isKindOfClass:[YumiPlayerViewController class]]) return;
    [presented dismissViewControllerAnimated:YES completion:^{
        if (self.downloadAlert == alert) {
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (void)dismissDownloadUIWithCompletion:(void (^)(void))completion {
    [self.downloadTimer invalidate];
    self.downloadTimer = nil;
    self.downloadTask = nil;
    [self.downloadSession finishTasksAndInvalidate];
    self.downloadSession = nil;

    UIAlertController *alert = self.downloadAlert;
    self.downloadAlert = nil;
    if (alert && alert.presentingViewController) {
        [alert dismissViewControllerAnimated:YES completion:^{
            if (completion) completion();
        }];
    } else if (completion) {
        completion();
    }
}

- (void)cancelDownload {
    self.downloadCancelled = YES;
    [self.downloadTask cancel];
    [self.downloadSession invalidateAndCancel];
    [self dismissDownloadUIWithCompletion:^{
        [self showToast:@"Скачивание отменено"];
    }];
}

- (void)updateDownloadProgress:(NSTimer *)timer {
    if (!timer || !self.downloadTask || !self.downloadAlert) return;
    double progress = self.downloadTask.progress.fractionCompleted;
    if (progress > 0.0 && progress <= 1.0) {
        self.downloadAlert.message = [NSString stringWithFormat:@"Скачано %.0f%%", progress * 100.0];
    } else {
        self.downloadAlert.message = @"Ожидание ответа…";
    }
}

- (void)presentDownloadError:(NSError *)error url:(NSURL *)url filename:(NSString *)filename {
    NSString *message = error.localizedDescription ?: @"Не удалось скачать файл";
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorTimedOut) {
        message = @"Превышен таймаут загрузки. GitHub мог заблокировать release-assets.githubusercontent.com. "
                   "Попробуй VPN, повтори загрузку или скопируй ссылку и скачай файл на ПК.";
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Ошибка скачивания"
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Повторить"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [self downloadURL:url suggestedFilename:filename];
    }]];
    if ([error.domain isEqualToString:@"YumiDownload"] && error.code == -2 && url) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Открыть страницу"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [self addTabWithURLString:url.absoluteString];
        }]];
    }
    if (url.absoluteString.length) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Скопировать ссылку"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [UIPasteboard generalPasteboard].string = url.absoluteString;
            [self showToast:@"Ссылка скопирована"];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentController:alert];
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
    BOOL hasYummy = (self.yummyPageID.length > 0 || self.anilibriaPageID.length > 0);
    NSString *mediaPageID = self.anilibriaPageID.length ? self.anilibriaPageID : self.yummyPageID;
    NSDictionary *resume = (mediaPageID.length && !self.incognito)
        ? [YumiResumeStore resumeForPageID:mediaPageID] : nil;

    if (!self.streams.count && !hasYummy) {
        [self showToast:@"Потоки пока не найдены"];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Видео"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    if (hasYummy) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Серии и озвучки"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *a) {
            [self openYummyEpisodes];
        }]];
    }
    if (resume) {
        NSString *episode = [resume[@"episode"] description] ?: @"";
        NSString *time = [YumiResumeStore timeStringForSeconds:[resume[@"time"] doubleValue]];
        NSString *title = [NSString stringWithFormat:@"Продолжить: серия %@ · %@", episode, time];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *a) {
            [self openYummyResume];
        }]];
    }
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
    if (self.streams.count) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Очистить список потоков"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(__unused UIAlertAction *a) {
            [self.streams removeAllObjects];
            [self hideStreamBanner];
        }]];
    }
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
    [self presentPlayerWithURL:url headers:headers title:title resume:nil];
}

- (void)presentPlayerWithURL:(NSURL *)url
                     headers:(NSDictionary *)headers
                       title:(NSString *)title
                      resume:(NSDictionary *)resume {
    if ([self.presentedViewController isKindOfClass:[YumiPlayerViewController class]]) return;

    YumiPlayerViewController *player = [[YumiPlayerViewController alloc] initWithURL:url
                                                                            headers:headers
                                                                              title:title];
    player.modalPresentationStyle = UIModalPresentationFullScreen;

    if (resume) {
        if (!self.incognito) {
            player.resumeKey = [resume[@"pageID"] description];
            player.animeID = [resume[@"animeID"] description];
            player.episode = [resume[@"episode"] description];
            player.dubbing = [resume[@"dubbing"] description];
            player.startTime = [resume[@"startTime"] doubleValue];
        }
        if ([resume[@"qualities"] isKindOfClass:[NSArray class]]) {
            player.qualityOptions = resume[@"qualities"];
        }

        __weak typeof(self) weakSelf = self;
        player.onDismiss = ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (self) [self refreshYummyAvailabilityForTab:self.activeTab];
        };
    }

    [self presentController:player];
}

#pragma mark - Настройки

- (void)applySettingsToTabs {
    YumiSettings *settings = [YumiSettings shared];
    WKContentRuleList *rules = [YumiAdBlocker shared].ruleList;
    WKContentRuleList *anilibriaRules = [YumiAdBlocker shared].anilibriaRuleList;

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
        if (anilibriaRules) [ucc addContentRuleList:anilibriaRules];
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
    NSMutableArray<WKWebsiteDataStore *> *stores =
        [NSMutableArray arrayWithObject:[WKWebsiteDataStore defaultDataStore]];
    if (self.incognito && _incognitoDataStore) [stores addObject:_incognitoDataStore];

    __weak typeof(self) weakSelf = self;
    dispatch_group_t group = dispatch_group_create();
    for (WKWebsiteDataStore *store in stores) {
        dispatch_group_enter(group);
        [store removeDataOfTypes:types
                   modifiedSince:[NSDate dateWithTimeIntervalSince1970:0]
               completionHandler:^{
            dispatch_group_leave(group);
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        for (YumiTab *tab in weakSelf.tabs) [tab reload];
        [weakSelf showToast:@"Данные очищены"];
    });
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
    [[YumiSettings shared] reset];
    self.incognito = NO;
    _incognitoDataStore = nil;
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
    [self updateIncognitoAppearance];
    [self showToast:@"Настройки сброшены"];
}

#pragma mark - Сессия

- (void)saveSession {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (self.incognito) {
        // Never write private tab URLs/history to disk.
        [defaults removeObjectForKey:kYumiSessionURLs];
        [defaults removeObjectForKey:kYumiSessionIndex];
        [defaults synchronize];
        return;
    }

    NSMutableArray *urls = [NSMutableArray array];
    for (YumiTab *tab in self.tabs) {
        NSString *string = tab.url.absoluteString;
        if (!string.length) string = tab.pendingURLString;
        [urls addObject:string ?: @""];
    }
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

#pragma mark - YummyAnime

- (void)setupYummyButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithRed:0.86 green:0.22 blue:0.24 alpha:1.0];
    button.tintColor = [UIColor whiteColor];
    button.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 18.0;
    button.layer.shadowColor = [UIColor blackColor].CGColor;
    button.layer.shadowOpacity = 0.25;
    button.layer.shadowRadius = 6;
    button.layer.shadowOffset = CGSizeMake(0, 2);
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    [button setTitle:@"▶ Серии" forState:UIControlStateNormal];
    button.hidden = YES;
    [button addTarget:self action:@selector(openYummyEpisodes) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    self.yummyButton = button;

    UIButton *resume = [UIButton buttonWithType:UIButtonTypeSystem];
    resume.translatesAutoresizingMaskIntoConstraints = NO;
    resume.backgroundColor = [UIColor colorWithRed:0.13 green:0.55 blue:0.36 alpha:1.0];
    resume.tintColor = [UIColor whiteColor];
    resume.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    resume.layer.cornerRadius = 18.0;
    resume.layer.shadowColor = [UIColor blackColor].CGColor;
    resume.layer.shadowOpacity = 0.25;
    resume.layer.shadowRadius = 6;
    resume.layer.shadowOffset = CGSizeMake(0, 2);
    resume.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    [resume setTitle:@"▶ Продолжить" forState:UIControlStateNormal];
    resume.hidden = YES;
    [resume addTarget:self action:@selector(openYummyResume) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:resume];
    self.resumeButton = resume;

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-14],
        [button.bottomAnchor constraintEqualToAnchor:self.streamBanner.topAnchor constant:-8],
        [button.heightAnchor constraintEqualToConstant:36],

        [resume.trailingAnchor constraintEqualToAnchor:button.trailingAnchor],
        [resume.bottomAnchor constraintEqualToAnchor:button.topAnchor constant:-8],
        [resume.heightAnchor constraintEqualToConstant:36]
    ]];
}

- (void)refreshYummyAvailabilityForTab:(YumiTab *)tab {
    if (tab != self.activeTab) return;

    NSURL *url = tab.webView.URL;
    BOOL isYummy = [YumiYummyResolver isItemURL:url];
    BOOL isAnilibria = [YumiAnilibriaResolver isItemURL:url];

    if (!isYummy && !isAnilibria) {
        self.yummyPageID = nil;
        self.anilibriaPageID = nil;
        self.resumeInfo = nil;
        self.yummyButton.hidden = YES;
        self.resumeButton.hidden = YES;
        return;
    }

    __weak typeof(self) weakSelf = self;
    NSString *script = nil;
    if (isAnilibria) {
        script = [YumiAnilibriaResolver pageIDScript];
    } else {
        script = @"(function(){"
                  "var m=document.querySelector('meta#short_link');"
                  "if(m){var r=/a(\\d+)$/.exec(m.getAttribute('content')||'');if(r)return r[1];}"
                  "var el=document.querySelector('.rating-info[data-id]');"
                  "return el?el.getAttribute('data-id'):'';"
                  "})()";
    }

    [tab.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (tab != self.activeTab) return;

            NSString *pageID = [result isKindOfClass:[NSString class]] ? result : nil;
            if (error || !pageID.length) {
                if (isAnilibria) self.anilibriaPageID = nil;
                else self.yummyPageID = nil;
                self.resumeInfo = nil;
                self.yummyButton.hidden = YES;
                self.resumeButton.hidden = YES;
                return;
            }

            if (isAnilibria) {
                self.anilibriaPageID = pageID;
                self.yummyPageID = nil;
            } else {
                self.yummyPageID = pageID;
                self.anilibriaPageID = nil;
            }
            self.yummyButton.hidden = NO;

            NSDictionary *resume = self.incognito ? nil : [YumiResumeStore resumeForPageID:pageID];
            self.resumeInfo = resume;
            if (resume) {
                NSTimeInterval time = [resume[@"time"] doubleValue];
                NSString *title = [NSString stringWithFormat:@"▶ Продолжить %@",
                                   [YumiResumeStore timeStringForSeconds:time]];
                [self.resumeButton setTitle:title forState:UIControlStateNormal];
                self.resumeButton.hidden = NO;
            } else {
                self.resumeButton.hidden = YES;
            }

            [self.view bringSubviewToFront:self.yummyButton];
            [self.view bringSubviewToFront:self.resumeButton];
        });
    }];
}

- (void)installAnilibriaWebPSupportForTab:(YumiTab *)tab {
    NSURL *url = tab.webView.URL;
    if (![YumiAnilibriaResolver isSupportedHost:url.host]) return;
    if (![YumiSettings shared].webpCoversEnabled) return;

    NSString *bundle = [YumiScripts webpHero];
    NSString *boot = [YumiScripts webpImages];
    if (!bundle.length || !boot.length) return;

    // AniLibria serves covers as WebP, which WebKit on iOS 12 cannot decode.
    // The polyfill is injected only here; other sites do not pay this cost.
    // WebAssembly is disabled deliberately: webp-hero then uses its asm.js
    // fallback, which is slower but much more reliable on iOS 12 WebKit.
    NSString *script = [NSString stringWithFormat:
        @"try{window.WebAssembly=undefined;}catch(e){};"
         "if(!window.__yumiWebpBooted){%@\n%@}", bundle, boot];

    [tab.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"[Yumi] WebP polyfill failed: %@", error.localizedDescription);
        }
    }];
}

- (void)installCompatibilityStyleForTab:(YumiTab *)tab {
    NSURL *url = tab.webView.URL;
    NSString *host = url.host.lowercaseString;
    if (!host.length) return;

    NSString *script = nil;
    if ([host isEqualToString:@"github.com"] || [host hasSuffix:@".github.com"]) {
        script = [YumiScripts githubCompat];
    } else if ([YumiAnilibriaResolver isSupportedHost:host]) {
        script = [YumiScripts anilibriaCompat];
    }
    if (!script.length) return;

    [tab.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"[Yumi] compatibility style failed on %@: %@", host, error.localizedDescription);
        }
    }];
}

- (void)openYummyEpisodes {
    YumiTab *tab = self.activeTab;
    BOOL isAnilibria = self.anilibriaPageID.length > 0;
    NSString *pageID = isAnilibria ? self.anilibriaPageID : self.yummyPageID;
    if (!pageID.length) {
        [self showToast:@"Не удалось определить id тайтла"];
        return;
    }

    NSDictionary *resume = self.incognito ? nil : [YumiResumeStore resumeForPageID:pageID];
    YumiEpisodesFetchBlock fetchBlock = nil;
    YumiEpisodeResolveBlock resolveBlock = nil;

    if (isAnilibria) {
        WKWebView *webView = tab.webView;
        NSString *alPageID = [pageID copy];
        fetchBlock = ^(void (^done)(NSArray<NSDictionary *> *, NSError *)) {
            [YumiAnilibriaResolver fetchEpisodesFromWebView:webView pageID:alPageID completion:done];
        };
        resolveBlock = ^(NSDictionary *source,
                         NSString *episode,
                         void (^done)(NSURL *, NSDictionary<NSString *,NSString *> *,
                                      NSArray<NSDictionary<NSString *,NSString *> *> *,
                                      NSString *, NSError *)) {
            [YumiAnilibriaResolver resolveSource:source
                                         episode:episode
                                          pageID:alPageID
                                         webView:webView
                                      completion:done];
        };
    } else {
        NSString *yummyPageID = [pageID copy];
        fetchBlock = ^(void (^done)(NSArray<NSDictionary *> *, NSError *)) {
            [YumiYummyResolver fetchEpisodesWithPageID:yummyPageID completion:done];
        };
        resolveBlock = ^(NSDictionary *source,
                         NSString *episode,
                         void (^done)(NSURL *, NSDictionary<NSString *,NSString *> *,
                                      NSArray<NSDictionary<NSString *,NSString *> *> *,
                                      NSString *, NSError *)) {
            [YumiYummyResolver resolveStreamWithAnimeID:[source[@"animeID"] description]
                                                episode:episode
                                                dubbing:[source[@"dubbing"] description]
                                             completion:^(NSURL *url,
                                                          NSDictionary<NSString *,NSString *> *headers,
                                                          NSArray<NSDictionary<NSString *,NSString *> *> *qualities,
                                                          NSString *title,
                                                          NSError *error) {
                done(url, headers, qualities, title, error);
            }];
        };
    }

    YummyEpisodesViewController *vc =
        [[YummyEpisodesViewController alloc] initWithPageID:pageID
                                                  pageTitle:tab.title ?: @""
                                                     resume:resume
                                                 fetchBlock:fetchBlock
                                               resolveBlock:resolveBlock];
    vc.delegate = self;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentController:nav];
}

- (void)openYummyResume {
    if (self.incognito) {
        [self showToast:@"В инкогнито память просмотра не сохраняется"];
        return;
    }
    if (self.anilibriaPageID.length) {
        [self openAnilibriaResume];
        return;
    }

    NSDictionary *resume = [YumiResumeStore resumeForPageID:self.yummyPageID];
    if (!resume) {
        [self showToast:@"Нет сохранённой позиции"];
        return;
    }

    NSString *animeID = [resume[@"animeID"] description];
    NSString *episode = [resume[@"episode"] description];
    NSString *dubbing = [resume[@"dubbing"] description] ?: @"";
    if (!animeID.length || !episode.length) return;

    [self showToast:@"Загружаю видео…"];

    __weak typeof(self) weakSelf = self;
    [YumiYummyResolver resolveStreamWithAnimeID:animeID
                                        episode:episode
                                        dubbing:dubbing
                                     completion:^(NSURL *url,
                                                  NSDictionary<NSString *,NSString *> *headers,
                                                  NSArray<NSDictionary<NSString *,NSString *> *> *qualities,
                                                  NSString *title,
                                                  NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (error || !url) {
            UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:@"Не удалось продолжить"
                                                    message:error.localizedDescription ?: @"Неизвестная ошибка"
                                             preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentController:alert];
            return;
        }

        NSString *pageTitle = self.activeTab.title ?: @"";
        NSString *finalTitle = title ?: @"";
        if (pageTitle.length && finalTitle.length) {
            finalTitle = [NSString stringWithFormat:@"%@ — %@", pageTitle, finalTitle];
        } else if (pageTitle.length) {
            finalTitle = pageTitle;
        }

        NSMutableDictionary *info = [resume mutableCopy];
        info[@"startTime"] = resume[@"time"] ?: @0;
        info[@"pageID"] = self.yummyPageID ?: @"";
        if (qualities.count) info[@"qualities"] = qualities;
        [self presentPlayerWithURL:url headers:headers title:finalTitle resume:info];
    }];
}

- (void)openAnilibriaResume {
    NSDictionary *resume = [YumiResumeStore resumeForPageID:self.anilibriaPageID];
    if (!resume) {
        [self showToast:@"Нет сохранённой позиции"];
        return;
    }

    NSString *pageID = self.anilibriaPageID;
    NSString *episode = [resume[@"episode"] description] ?: @"";
    NSString *dubbing = [resume[@"dubbing"] description] ?: @"";
    WKWebView *webView = self.activeTab.webView;

    [self showToast:@"Загружаю видео…"];

    __weak typeof(self) weakSelf = self;
    [YumiAnilibriaResolver fetchEpisodesFromWebView:webView
                                            pageID:pageID
                                        completion:^(NSArray<NSDictionary *> *episodes, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (error) {
            UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:@"Не удалось продолжить"
                                                    message:error.localizedDescription
                                             preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentController:alert];
            return;
        }

        NSDictionary *source = nil;
        for (NSDictionary *item in episodes) {
            if ([[item[@"episode"] description] isEqualToString:episode] &&
                [[item[@"dubbing"] description] isEqualToString:dubbing]) {
                source = item;
                break;
            }
        }
        if (!source) {
            [self openYummyEpisodes];
            return;
        }

        [YumiAnilibriaResolver resolveSource:source
                                     episode:episode
                                      pageID:pageID
                                     webView:webView
                                  completion:^(NSURL *url,
                                               NSDictionary<NSString *,NSString *> *headers,
                                               NSArray<NSDictionary<NSString *,NSString *> *> *qualities,
                                               NSString *title,
                                               NSError *error2) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            if (error2 || !url) {
                UIAlertController *alert =
                    [UIAlertController alertControllerWithTitle:@"Не удалось продолжить"
                                                        message:error2.localizedDescription ?: @"Неизвестная ошибка"
                                                 preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentController:alert];
                return;
            }

            NSString *pageTitle = self.activeTab.title ?: @"";
            NSString *finalTitle = title ?: @"";
            if (pageTitle.length && finalTitle.length) {
                finalTitle = [NSString stringWithFormat:@"%@ — %@", pageTitle, finalTitle];
            } else if (pageTitle.length) {
                finalTitle = pageTitle;
            }

            NSMutableDictionary *info = [resume mutableCopy];
            info[@"startTime"] = resume[@"time"] ?: @0;
            info[@"pageID"] = pageID;
            if (qualities.count) info[@"qualities"] = qualities;
            [self presentPlayerWithURL:url headers:headers title:finalTitle resume:info];
        }];
    }];
}

#pragma mark - YummyEpisodesViewControllerDelegate

- (void)yummyEpisodesController:(YummyEpisodesViewController *)controller
                  playStreamURL:(NSURL *)url
                        headers:(NSDictionary<NSString *,NSString *> *)headers
                          title:(NSString *)title
                         resume:(NSDictionary *)resume {
    [controller dismissViewControllerAnimated:YES completion:^{
        [self presentPlayerWithURL:url headers:headers title:title resume:resume];
    }];
}

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
    } else if ([type isEqualToString:@"add-site"]) {
        [self promptAddSiteFromWebView:webView];
    } else if ([type isEqualToString:@"remove-site"]) {
        NSNumber *index = message[@"index"];
        if (![index isKindOfClass:[NSNumber class]]) return;
        [YumiSiteStore removeSiteAtIndex:index.integerValue];
        YumiTab *tab = [self tabForWebView:webView];
        [tab loadHome];
    } else if ([type isEqualToString:@"github-assets"]) {
        [self handleGitHubAssetsMessage:message fromWebView:webView];
    } else if ([type isEqualToString:@"github-search"]) {
        [self showGitHubSearch];
    } else if ([type isEqualToString:@"github-profile"]) {
        NSString *login = message[@"login"];
        [self promptGitHubProfileWithLogin:[login isKindOfClass:[NSString class]] ? login : nil];
    }
}

- (void)promptAddSiteFromWebView:(WKWebView *)webView {
    YumiTab *tab = [self tabForWebView:webView];
    __weak typeof(self) weakSelf = self;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Добавить сайт"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Название";
        field.autocapitalizationType = UITextAutocapitalizationTypeWords;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Адрес, например example.com";
        field.keyboardType = UIKeyboardTypeURL;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Добавить"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSString *name = alert.textFields.firstObject.text ?: @"";
        NSString *address = alert.textFields.lastObject.text ?: @"";
        if (![YumiSiteStore addSiteWithName:name urlString:address]) {
            [self showToast:@"Проверь адрес сайта"];
            return;
        }
        [tab loadHome];
    }]];

    [self presentController:alert];
}

#pragma mark - YumiTabDelegate

- (void)tabDidStartLoading:(YumiTab *)tab {
    if (tab != self.activeTab) return;
    self.progressView.hidden = NO;
    self.progressView.progress = 0.08;
    [self updateChrome];
}

- (void)tabDidFinishLoading:(YumiTab *)tab {
    [self installCompatibilityStyleForTab:tab];
    if ([YumiAnilibriaResolver isSupportedHost:tab.webView.URL.host]) {
        [self installAnilibriaWebPSupportForTab:tab];
    }
    if (tab != self.activeTab) return;
    self.progressView.progress = 1.0;
    [self refreshYummyAvailabilityForTab:tab];
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
    if (![YumiYummyResolver isItemURL:url] && ![YumiAnilibriaResolver isItemURL:url]) {
        self.yummyPageID = nil;
        self.anilibriaPageID = nil;
        self.resumeInfo = nil;
        self.yummyButton.hidden = YES;
        self.resumeButton.hidden = YES;
    }
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

    NSLog(@"[Yumi] stream %@ %@ (page: %@)", info[@"kind"], urlString, info[@"page"]);

    NSMutableDictionary *entry = [info mutableCopy];
    entry[@"url"] = urlString;
    if (tab) entry[@"tab"] = tab;
    [self.streams insertObject:entry atIndex:0];
    while (self.streams.count > 12) [self.streams removeLastObject];

    BOOL isActiveTab = (tab == nil || tab == self.activeTab);
    if (isActiveTab) {
        [self showStreamBannerWithInfo:entry];
    }

    if (isActiveTab && [YumiSettings shared].autoNativePlayer && [entry[@"kind"] isEqualToString:@"hls"]) {
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

- (void)tab:(YumiTab *)tab didTerminateWithURL:(NSURL *)url {
    if (tab != self.activeTab) return;
    if ([self.presentedViewController isKindOfClass:[YumiPlayerViewController class]]) return;

    BOOL anilibria = [YumiAnilibriaResolver isSupportedHost:url.host];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Страница постоянно падает"
                                            message:@"WebKit не смог её показать. Можно перезагрузить, открыть в Safari или отключить тяжёлое исправление обложек."
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Перезагрузить"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [tab resetCrashGuard];
        [tab reload];
    }]];

    if (anilibria && [YumiSettings shared].webpCoversEnabled && url) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Без WebP-обложек"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [YumiSettings shared].webpCoversEnabled = NO;
            [tab resetCrashGuard];
            [tab reload];
            [self showToast:@"WebP-обложки отключены"];
        }]];
    }

    if (url) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Открыть в Safari"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:url];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentController:alert];
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

    if ([YumiTab isDownloadableURL:url]) {
        [self tab:tab downloadURL:url suggestedFilename:nil];
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

