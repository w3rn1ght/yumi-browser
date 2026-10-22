#import "YumiPlayer.h"
#import "YumiIcons.h"
#import "YumiResumeStore.h"
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
@property (nonatomic, strong) NSURL *currentURL;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy) NSString *streamTitle;

@property (nonatomic, strong) AVPlayerViewController *playerVC;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *item;

@property (nonatomic, strong) UIButton *qualityButton;
@property (nonatomic, copy) NSString *selectedQualityTitle;
@property (nonatomic, assign) BOOL externalQuality;
@property (nonatomic, assign) BOOL didFetchQualities;
@property (nonatomic, assign) BOOL didDismiss;

@property (nonatomic, strong) id timeObserver;
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
        _currentURL = url;
        _headers = [headers copy] ?: @{};
        _streamTitle = [title copy];
        _qualityOptions = @[];
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    if (self.qualityOptions.count) {
        self.externalQuality = YES;
        self.selectedQualityTitle = self.qualityOptions.firstObject[@"title"];
    }

    self.playerVC = [[AVPlayerViewController alloc] init];
    self.playerVC.view.backgroundColor = [UIColor blackColor];
    self.playerVC.showsPlaybackControls = YES;
    self.playerVC.delegate = self;
    [self addChildViewController:self.playerVC];
    self.playerVC.view.frame = self.view.bounds;
    self.playerVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.playerVC.view];
    [self.playerVC didMoveToParentViewController:self];

    [self setupQualityButton];
    [self setupErrorView];
    [self startPlayback];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveProgress)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveProgress)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
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
    [self saveProgress];
    [self.player pause];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self saveProgress];
    if (!self.didDismiss) {
        self.didDismiss = YES;
        if (self.onDismiss) self.onDismiss();
    }
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

- (void)setupQualityButton {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    b.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    b.tintColor = [UIColor whiteColor];
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    b.layer.cornerRadius = 16.0;
    b.contentEdgeInsets = UIEdgeInsetsMake(0, 13, 0, 13);
    b.hidden = YES;
    [b addTarget:self action:@selector(qualityTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:b];
    self.qualityButton = b;

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [b.topAnchor constraintEqualToAnchor:safe.topAnchor constant:56],
        [b.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [b.heightAnchor constraintEqualToConstant:32]
    ]];
    [self updateQualityButton];
}

- (void)updateQualityButton {
    BOOL show = (self.qualityOptions.count >= 2);
    self.qualityButton.hidden = !show;
    if (!show) return;

    NSString *title = self.selectedQualityTitle.length ? self.selectedQualityTitle : @"Авто";
    [self.qualityButton setTitle:[title stringByAppendingString:@" ▾"]
                        forState:UIControlStateNormal];
    [self.view bringSubviewToFront:self.qualityButton];
}

- (void)qualityTapped {
    if (self.qualityOptions.count < 2) return;

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:@"Качество видео"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    if (!self.externalQuality) {
        BOOL autoSelected = !self.selectedQualityTitle.length ||
                            [self.selectedQualityTitle isEqualToString:@"Авто"];
        NSString *title = autoSelected ? @"✓ Авто" : @"Авто";
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *a) {
            [self selectQuality:nil auto:YES];
        }]];
    }

    for (NSDictionary *option in self.qualityOptions) {
        NSString *title = option[@"title"] ?: @"";
        if (!title.length) continue;
        BOOL selected = [title isEqualToString:self.selectedQualityTitle];
        [sheet addAction:[UIAlertAction actionWithTitle:(selected ? [@"✓ " stringByAppendingString:title] : title)
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *a) {
            [self selectQuality:option auto:NO];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    sheet.popoverPresentationController.sourceView = self.qualityButton;
    sheet.popoverPresentationController.sourceRect = self.qualityButton.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)selectQuality:(NSDictionary *)option auto:(BOOL)auto {
    NSString *title = auto ? @"Авто" : (option[@"title"] ?: @"");
    NSURL *target = auto ? self.url : [NSURL URLWithString:option[@"url"] ?: @""];
    if (!target) return;
    if ([target.absoluteString isEqualToString:self.currentURL.absoluteString] &&
        [title isEqualToString:self.selectedQualityTitle ?: @""]) {
        return;
    }

    NSTimeInterval t = CMTimeGetSeconds(self.player.currentTime);
    if (!isfinite(t) || t < 0) t = 0;

    self.selectedQualityTitle = title;
    self.startTime = t;
    [self updateQualityButton];
    [self startPlaybackWithURL:target];
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
    [self startPlaybackWithURL:self.url];
    if (!self.externalQuality && !self.didFetchQualities) {
        self.didFetchQualities = YES;
        [self loadVariantPlaylistForURL:self.url];
    }
}

- (void)startPlaybackWithURL:(NSURL *)url {
    if (!url) return;

    if (self.timeObserver && self.player) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    if (self.item) {
        @try { [self.item removeObserver:self forKeyPath:@"status"]; } @catch (NSException *e) {}
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                      object:self.item];
    }

    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    options[AVURLAssetAllowsCellularAccessKey] = @YES;
    if (self.headers.count) options[@"AVURLAssetHTTPHeaderFieldsKey"] = self.headers;

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:options];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset automaticallyLoadedAssetKeys:@[@"playable"]];
    [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemFailedToPlayToEnd:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:item];
    self.item = item;
    self.currentURL = url;

    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    self.player = player;
    self.playerVC.player = player;
    self.errorView.hidden = YES;

    __weak typeof(self) weakSelf = self;
    self.timeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(5.0, NSEC_PER_SEC)
                                                             queue:dispatch_get_main_queue()
                                                        usingBlock:^(CMTime time) {
        [weakSelf saveProgress];
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (object == self.item && [keyPath isEqualToString:@"status"]) {
        if (self.item.status == AVPlayerItemStatusReadyToPlay) {
            self.errorView.hidden = YES;
            NSTimeInterval seek = self.startTime;
            self.startTime = 0;
            if (seek > 1.0) {
                __weak typeof(self) weakSelf = self;
                [self.player seekToTime:CMTimeMakeWithSeconds(seek, 600)
                        toleranceBefore:kCMTimeZero
                         toleranceAfter:kCMTimeZero
                      completionHandler:^(BOOL finished) {
                    [weakSelf.player play];
                }];
            } else {
                [self.player play];
            }
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
    [self.view bringSubviewToFront:self.qualityButton];
}

#pragma mark - Quality

- (void)loadVariantPlaylistForURL:(NSURL *)url {
    NSString *string = url.absoluteString.lowercaseString;
    if (![string containsString:@"m3u8"]) return;

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                            timeoutInterval:20.0];
    for (NSString *key in self.headers) {
        [request setValue:self.headers[key] forHTTPHeaderField:key];
    }

    __weak typeof(self) weakSelf = self;
    [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data.length) return;
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!text.length) return;

        NSArray *options = [[self class] variantsFromPlaylist:text baseURL:url];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (options.count < 2) return;
            self.qualityOptions = options;
            self.selectedQualityTitle = @"Авто";
            [self updateQualityButton];
        });
    }];
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)variantsFromPlaylist:(NSString *)text
                                                                  baseURL:(NSURL *)baseURL {
    NSArray *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableDictionary<NSNumber *, NSDictionary *> *byHeight = [NSMutableDictionary dictionary];

    for (NSUInteger i = 0; i < lines.count; i++) {
        NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (![line hasPrefix:@"#EXT-X-STREAM-INF"]) continue;

        NSInteger height = 0;
        NSInteger bandwidth = 0;
        NSRange resRange = [line rangeOfString:@"RESOLUTION="];
        if (resRange.location != NSNotFound) {
            NSString *tail = [line substringFromIndex:NSMaxRange(resRange)];
            NSArray *parts = [tail componentsSeparatedByString:@"x"];
            if (parts.count >= 2) {
                height = [parts[1] integerValue];
            }
        }
        NSRange bwRange = [line rangeOfString:@"BANDWIDTH="];
        if (bwRange.location != NSNotFound) {
            NSString *tail = [line substringFromIndex:NSMaxRange(bwRange)];
            bandwidth = [tail integerValue];
        }
        if (height <= 0) continue;

        NSString *uri = nil;
        for (NSUInteger j = i + 1; j < lines.count; j++) {
            NSString *next = [lines[j] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (!next.length) continue;
            if ([next hasPrefix:@"#"]) continue;
            uri = next;
            break;
        }
        if (!uri.length) continue;

        NSURL *variantURL = [NSURL URLWithString:uri relativeToURL:baseURL];
        if (!variantURL) continue;

        NSDictionary *existing = byHeight[@(height)];
        if (!existing || [existing[@"bandwidth"] integerValue] < bandwidth) {
            byHeight[@(height)] = @{
                @"title": [NSString stringWithFormat:@"%ldp", (long)height],
                @"url": variantURL.absoluteString,
                @"bandwidth": [NSString stringWithFormat:@"%ld", (long)bandwidth]
            };
        }
    }

    NSArray *keys = [byHeight.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        return [b compare:a];
    }];
    NSMutableArray *result = [NSMutableArray array];
    for (NSNumber *key in keys) [result addObject:byHeight[key]];
    return result;
}

#pragma mark - Progress

- (void)saveProgress {
    if (!self.resumeKey.length || !self.player) return;

    NSTimeInterval time = CMTimeGetSeconds(self.player.currentTime);
    if (!isfinite(time) || time <= 0) return;

    NSTimeInterval duration = 0;
    CMTime itemDuration = self.item.duration;
    if (CMTIME_IS_NUMERIC(itemDuration)) {
        duration = CMTimeGetSeconds(itemDuration);
        if (!isfinite(duration)) duration = 0;
    }

    [YumiResumeStore saveForPageID:self.resumeKey
                           animeID:self.animeID
                           episode:self.episode
                           dubbing:self.dubbing
                              time:time
                          duration:duration
                             title:self.streamTitle];
}

- (void)dealloc {
    if (self.timeObserver && self.player) {
        @try { [self.player removeTimeObserver:self.timeObserver]; } @catch (NSException *e) {}
    }
    @try { [self.item removeObserver:self forKeyPath:@"status"]; } @catch (NSException *e) {}
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

- (void)retryTapped {
    NSTimeInterval t = CMTimeGetSeconds(self.player.currentTime);
    if (isfinite(t) && t > 1.0) self.startTime = t;
    self.errorView.hidden = YES;
    [self startPlaybackWithURL:self.currentURL ?: self.url];
}

- (void)copyTapped {
    [UIPasteboard generalPasteboard].string = self.currentURL.absoluteString ?: self.url.absoluteString ?: @"";
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ссылка скопирована"
                                                              message:nil
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Ок" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)vlcTapped {
    NSURL *target = self.currentURL ?: self.url;
    NSString *enc = YumiEncode(target.absoluteString ?: @"");
    NSURL *u = [NSURL URLWithString:[@"vlc-x-callback://x-callback-url/stream?url=" stringByAppendingString:enc]];
    if (u) [[UIApplication sharedApplication] openURL:u];
}

- (void)nplayerTapped {
    NSURL *target = self.currentURL ?: self.url;
    NSString *s = target.absoluteString ?: @"";
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
