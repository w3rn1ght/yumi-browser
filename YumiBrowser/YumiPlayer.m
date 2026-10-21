#import "YumiPlayer.h"
#import "YumiIcons.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <math.h>

static NSString *YumiEncode(NSString *s) {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: s;
}

@interface YumiPlayerViewController () <AVPlayerViewControllerDelegate>
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy) NSString *streamTitle;

@property (nonatomic, strong) AVPlayerViewController *playerVC;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *item;

@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIView *errorView;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) NSLayoutConstraint *panelWidthConstraint;
@end

@implementation YumiPlayerViewController

- (instancetype)initWithURL:(NSURL *)url
                    headers:(NSDictionary<NSString *, NSString *> *)headers
                      title:(NSString *)title {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _url = url;
        _headers = [headers copy] ?: @{};
        _streamTitle = [title copy];
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    self.playerVC = [[AVPlayerViewController alloc] init];
    self.playerVC.view.backgroundColor = [UIColor blackColor];
    self.playerVC.showsPlaybackControls = YES;
    self.playerVC.delegate = self;
    [self addChildViewController:self.playerVC];
    self.playerVC.view.frame = self.view.bounds;
    self.playerVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.playerVC.view];
    [self.playerVC didMoveToParentViewController:self];

    [self setupCloseButton];
    [self setupErrorView];
    [self startPlayback];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = MIN(460.0, MAX(240.0, self.view.bounds.size.width - 40.0));
    if (self.panelWidthConstraint && fabs(self.panelWidthConstraint.constant - width) > 0.5) {
        self.panelWidthConstraint.constant = width;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self configureAudioSession];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.player pause];
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)configureAudioSession {
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    [session setActive:YES error:&error];
    if (error) NSLog(@"[Yumi] audio session: %@", error);
}

#pragma mark - UI

- (void)setupCloseButton {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    b.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    b.tintColor = [UIColor whiteColor];
    b.layer.cornerRadius = 20.0;
    [b setImage:[YumiIcons close] forState:UIControlStateNormal];
    [b addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:b];
    self.closeButton = b;

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [b.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10],
        [b.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
        [b.widthAnchor constraintEqualToConstant:40],
        [b.heightAnchor constraintEqualToConstant:40]
    ]];
}

- (UIButton *)panelButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    b.tintColor = [UIColor whiteColor];
    b.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    b.layer.cornerRadius = 9.0;
    b.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [b.heightAnchor constraintEqualToConstant:36].active = YES;
    return b;
}

- (void)setupErrorView {
    UIView *panel = [[UIView alloc] init];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.96];
    panel.layer.cornerRadius = 14.0;
    panel.hidden = YES;
    [self.view addSubview:panel];
    self.errorView = panel;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Не удалось воспроизвести";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:17];
    title.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:title];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textColor = [UIColor colorWithWhite:0.82 alpha:1.0];
    label.font = [UIFont systemFontOfSize:13];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    [panel addSubview:label];
    self.errorLabel = label;

    UIStackView *row1 = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self panelButtonWithTitle:@"Повторить" action:@selector(retryTapped)],
        [self panelButtonWithTitle:@"Копировать" action:@selector(copyTapped)]
    ]];
    row1.translatesAutoresizingMaskIntoConstraints = NO;
    row1.axis = UILayoutConstraintAxisHorizontal;
    row1.spacing = 8;
    row1.distribution = UIStackViewDistributionFillEqually;
    [panel addSubview:row1];

    NSMutableArray *extButtons = [NSMutableArray array];
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"vlc-x-callback://"]]) {
        [extButtons addObject:[self panelButtonWithTitle:@"VLC" action:@selector(vlcTapped)]];
    }
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"nplayer-http://"]]) {
        [extButtons addObject:[self panelButtonWithTitle:@"nPlayer" action:@selector(nplayerTapped)]];
    }
    UIStackView *row2 = nil;
    if (extButtons.count) {
        row2 = [[UIStackView alloc] initWithArrangedSubviews:extButtons];
        row2.translatesAutoresizingMaskIntoConstraints = NO;
        row2.axis = UILayoutConstraintAxisHorizontal;
        row2.spacing = 8;
        row2.distribution = UIStackViewDistributionFillEqually;
        [panel addSubview:row2];
    }

    UILabel *hint = [[UILabel alloc] init];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.text = extButtons.count
        ? @"Если не играет — открой во внешнем плеере."
        : @"Поставь VLC или nPlayer из Cydia, чтобы открывать такие потоки внешне.";
    hint.textColor = [UIColor colorWithWhite:0.62 alpha:1.0];
    hint.font = [UIFont systemFontOfSize:11.5];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.numberOfLines = 0;
    [panel addSubview:hint];
    self.hintLabel = hint;

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    self.panelWidthConstraint = [panel.widthAnchor constraintEqualToConstant:
                                 MIN(460.0, MAX(240.0, self.view.bounds.size.width - 40.0))];
    NSMutableArray *c = [NSMutableArray array];
    [c addObjectsFromArray:@[
        [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [panel.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor constant:20],
        [panel.trailingAnchor constraintLessThanOrEqualToAnchor:safe.trailingAnchor constant:-20],
        self.panelWidthConstraint,

        [title.topAnchor constraintEqualToAnchor:panel.topAnchor constant:18],
        [title.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:16],
        [title.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-16],

        [label.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [label.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:16],
        [label.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-16],

        [row1.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:16],
        [row1.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:16],
        [row1.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-16],

        [hint.topAnchor constraintEqualToAnchor:(row2 ? row2.bottomAnchor : row1.bottomAnchor) constant:12],
        [hint.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:16],
        [hint.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-16],
        [hint.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-16]
    ]];
    if (row2) {
        [c addObjectsFromArray:@[
            [row2.topAnchor constraintEqualToAnchor:row1.bottomAnchor constant:8],
            [row2.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:16],
            [row2.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-16]
        ]];
    }
    [NSLayoutConstraint activateConstraints:c];
}

#pragma mark - Playback

- (void)startPlayback {
    if (self.item) {
        @try { [self.item removeObserver:self forKeyPath:@"status"]; } @catch (__unused NSException *e) {}
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:self.item];
    }

    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    options[AVURLAssetAllowsCellularAccessKey] = @YES;
    if (self.headers.count) options[@"AVURLAssetHTTPHeaderFieldsKey"] = self.headers;

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.url options:options];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset automaticallyLoadedAssetKeys:@[@"playable"]];
    [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemFailedToPlayToEnd:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:item];
    self.item = item;

    self.player = [AVPlayer playerWithPlayerItem:item];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    self.playerVC.player = self.player;
    self.errorView.hidden = YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (object == self.item && [keyPath isEqualToString:@"status"]) {
        if (self.item.status == AVPlayerItemStatusReadyToPlay) {
            self.errorView.hidden = YES;
            [self.player play];
        } else if (self.item.status == AVPlayerItemStatusFailed) {
            [self showError:self.item.error.localizedDescription];
        }
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)itemFailedToPlayToEnd:(NSNotification *)note {
    NSError *error = note.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
    [self showError:error.localizedDescription];
}

- (void)showError:(NSString *)message {
    self.errorLabel.text = message.length ? message : @"Поток не открылся. Возможно, нужен Referer, другой UA или внешний плеер.";
    self.errorView.hidden = NO;
    [self.view bringSubviewToFront:self.errorView];
    [self.view bringSubviewToFront:self.closeButton];
}

- (void)dealloc {
    @try { [self.item removeObserver:self forKeyPath:@"status"]; } @catch (__unused NSException *e) {}
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

- (void)closeTapped {
    [self.player pause];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)retryTapped {
    self.errorView.hidden = YES;
    [self startPlayback];
}

- (void)copyTapped {
    [UIPasteboard generalPasteboard].string = self.url.absoluteString ?: @"";
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ссылка скопирована"
                                                              message:nil
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Ок" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)vlcTapped {
    NSString *enc = YumiEncode(self.url.absoluteString ?: @"");
    NSURL *u = [NSURL URLWithString:[@"vlc-x-callback://x-callback-url/stream?url=" stringByAppendingString:enc]];
    if (u) [[UIApplication sharedApplication] openURL:u];
}

- (void)nplayerTapped {
    NSString *s = self.url.absoluteString ?: @"";
    NSString *url = nil;
    if ([s hasPrefix:@"https://"]) url = [@"nplayer-https://" stringByAppendingString:[s substringFromIndex:8]];
    else if ([s hasPrefix:@"http://"]) url = [@"nplayer-http://" stringByAppendingString:[s substringFromIndex:7]];
    if (url.length) [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

#pragma mark - AVPlayerViewControllerDelegate

- (void)playerViewControllerDidStopPictureInPicture:(AVPlayerViewController *)playerViewController {
    // ничего: остаёмся в плеере
}

@end
