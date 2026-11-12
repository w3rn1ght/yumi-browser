#import "YummyEpisodesViewController.h"
#import "YumiResumeStore.h"

@interface YummyEpisodesViewController ()
@property (nonatomic, copy) NSString *pageID;
@property (nonatomic, copy) NSString *pageTitle;
@property (nonatomic, copy) NSDictionary *resumeInfo;
@property (nonatomic, copy) YumiEpisodesFetchBlock fetchBlock;
@property (nonatomic, copy) YumiEpisodeResolveBlock resolveBlock;

@property (nonatomic, copy) NSArray<NSString *> *episodeNumbers;
@property (nonatomic, copy) NSDictionary<NSString *, NSArray<NSDictionary *> *> *voices;
@property (nonatomic, copy) NSString *selectedEpisode;
@property (nonatomic, copy) NSString *selectedVoice;

@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *episodeValueLabel;
@property (nonatomic, strong) UILabel *voiceValueLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIView *episodeRow;
@property (nonatomic, strong) UIView *voiceRow;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIView *busyOverlay;
@property (nonatomic, assign) NSInteger episodeShift;
@property (nonatomic, assign) NSInteger titleTaps;
@end

@implementation YummyEpisodesViewController

- (instancetype)initWithPageID:(NSString *)pageID
                     pageTitle:(NSString *)pageTitle
                        resume:(NSDictionary *)resume
                    fetchBlock:(YumiEpisodesFetchBlock)fetchBlock
                  resolveBlock:(YumiEpisodeResolveBlock)resolveBlock {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _pageID = [pageID copy];
        _pageTitle = [pageTitle copy];
        _resumeInfo = [resume copy];
        _fetchBlock = [fetchBlock copy];
        _resolveBlock = [resolveBlock copy];
        _episodeNumbers = @[];
        _voices = @{};
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Серии";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(close)];

    // Ручной сдвиг нумерации: если у конкретного тайтла серии всё равно
    // съезжают на одну, это правится здесь и запоминается для тайтла.
    self.episodeShift = [[NSUserDefaults standardUserDefaults] integerForKey:[self shiftKey]];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Сдвиг"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(chooseShift)];

    [self setupViews];
    [self loadEpisodes];
}

- (NSString *)shiftKey {
    NSString *pageID = self.pageID ?: @"";
    return [@"YumiEpisodeShift_" stringByAppendingString:pageID];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UI

- (void)setupViews {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:scroll];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 18.0;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.10;
    card.layer.shadowRadius = 18.0;
    card.layer.shadowOffset = CGSizeMake(0, 6);
    [content addSubview:card];
    self.card = card;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    title.numberOfLines = 2;
    title.text = self.pageTitle.length ? self.pageTitle : @"Выбор серии";
    [card addSubview:title];
    self.titleLabel = title;
    title.userInteractionEnabled = YES;
    [title addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(titleTapped)]];

    self.episodeRow = [self rowWithCaption:@"СЕРИЯ"
                                valueLabel:&_episodeValueLabel
                                    action:@selector(chooseEpisode)];
    [card addSubview:self.episodeRow];

    self.voiceRow = [self rowWithCaption:@"ОЗВУЧКА"
                              valueLabel:&_voiceValueLabel
                                  action:@selector(chooseVoice)];
    [card addSubview:self.voiceRow];

    UILabel *detail = [[UILabel alloc] init];
    detail.translatesAutoresizingMaskIntoConstraints = NO;
    detail.font = [UIFont systemFontOfSize:12.5];
    detail.textColor = [UIColor grayColor];
    detail.numberOfLines = 1;
    [card addSubview:detail];
    self.detailLabel = detail;

    UIButton *play = [UIButton buttonWithType:UIButtonTypeSystem];
    play.translatesAutoresizingMaskIntoConstraints = NO;
    play.backgroundColor = [UIColor colorWithRed:0.18 green:0.44 blue:0.94 alpha:1.0];
    play.tintColor = [UIColor whiteColor];
    play.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    play.layer.cornerRadius = 14.0;
    [play setTitle:@"Смотреть" forState:UIControlStateNormal];
    [play addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:play];
    self.playButton = play;

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.hidesWhenStopped = YES;
    [card addSubview:spinner];
    self.spinner = spinner;

    UILabel *error = [[UILabel alloc] init];
    error.translatesAutoresizingMaskIntoConstraints = NO;
    error.font = [UIFont systemFontOfSize:14];
    error.textColor = [UIColor grayColor];
    error.textAlignment = NSTextAlignmentCenter;
    error.numberOfLines = 0;
    error.hidden = YES;
    [card addSubview:error];
    self.errorLabel = error;

    UIButton *retry = [UIButton buttonWithType:UIButtonTypeSystem];
    retry.translatesAutoresizingMaskIntoConstraints = NO;
    retry.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [retry setTitle:@"Повторить" forState:UIControlStateNormal];
    retry.hidden = YES;
    [retry addTarget:self action:@selector(loadEpisodes) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:retry];
    self.retryButton = retry;

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],

        [card.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
        [card.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-28],
        [card.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [card.leadingAnchor constraintGreaterThanOrEqualToAnchor:content.leadingAnchor constant:18],
        [card.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor constant:-18],
        [card.widthAnchor constraintLessThanOrEqualToConstant:520],

        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:22],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],

        [self.episodeRow.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:18],
        [self.episodeRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [self.episodeRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [self.episodeRow.heightAnchor constraintEqualToConstant:58],

        [self.voiceRow.topAnchor constraintEqualToAnchor:self.episodeRow.bottomAnchor constant:10],
        [self.voiceRow.leadingAnchor constraintEqualToAnchor:self.episodeRow.leadingAnchor],
        [self.voiceRow.trailingAnchor constraintEqualToAnchor:self.episodeRow.trailingAnchor],
        [self.voiceRow.heightAnchor constraintEqualToConstant:58],

        [detail.topAnchor constraintEqualToAnchor:self.voiceRow.bottomAnchor constant:11],
        [detail.leadingAnchor constraintEqualToAnchor:self.episodeRow.leadingAnchor],
        [detail.trailingAnchor constraintEqualToAnchor:self.episodeRow.trailingAnchor],

        [play.topAnchor constraintEqualToAnchor:detail.bottomAnchor constant:16],
        [play.leadingAnchor constraintEqualToAnchor:self.episodeRow.leadingAnchor],
        [play.trailingAnchor constraintEqualToAnchor:self.episodeRow.trailingAnchor],
        [play.heightAnchor constraintEqualToConstant:52],
        [play.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20],

        [spinner.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],

        [error.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:24],
        [error.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [error.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],

        [retry.topAnchor constraintEqualToAnchor:error.bottomAnchor constant:10],
        [retry.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [retry.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-30]
    ]];

    // Карточка не должна растягиваться на всю ширину iPad.
    NSLayoutConstraint *wide = [card.widthAnchor constraintEqualToAnchor:content.widthAnchor constant:-36];
    wide.priority = 750;
    wide.active = YES;

    NSLayoutConstraint *maxWidth = [card.widthAnchor constraintEqualToConstant:520.0];
    maxWidth.priority = 749;
    maxWidth.active = YES;

    [self showLoading:YES];
}

- (UIView *)rowWithCaption:(NSString *)caption
                valueLabel:(UILabel *__strong *)valueLabel
                    action:(SEL)action {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [UIColor colorWithWhite:0.955 alpha:1.0];
    row.layer.cornerRadius = 12.0;
    row.userInteractionEnabled = YES;
    [row addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:action]];

    UILabel *cap = [[UILabel alloc] init];
    cap.translatesAutoresizingMaskIntoConstraints = NO;
    cap.text = caption;
    cap.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    cap.textColor = [UIColor grayColor];
    [row addSubview:cap];

    UILabel *value = [[UILabel alloc] init];
    value.translatesAutoresizingMaskIntoConstraints = NO;
    value.font = [UIFont systemFontOfSize:16.5 weight:UIFontWeightSemibold];
    value.textColor = [UIColor darkTextColor];
    value.lineBreakMode = NSLineBreakByTruncatingTail;
    [row addSubview:value];
    if (valueLabel) *valueLabel = value;

    UILabel *chevron = [[UILabel alloc] init];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.text = @"▾";
    chevron.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    chevron.textColor = [UIColor grayColor];
    [row addSubview:chevron];

    [NSLayoutConstraint activateConstraints:@[
        [cap.topAnchor constraintEqualToAnchor:row.topAnchor constant:9],
        [cap.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14],
        [cap.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-8],

        [value.topAnchor constraintEqualToAnchor:cap.bottomAnchor constant:1],
        [value.leadingAnchor constraintEqualToAnchor:cap.leadingAnchor],
        [value.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-8],

        [chevron.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-14],
        [chevron.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];

    return row;
}

- (void)showLoading:(BOOL)loading {
    self.spinner.hidden = NO;
    if (loading) [self.spinner startAnimating];
    else [self.spinner stopAnimating];

    BOOL showContent = !loading;
    self.episodeRow.hidden = !showContent;
    self.voiceRow.hidden = !showContent;
    self.detailLabel.hidden = !showContent;
    self.playButton.hidden = !showContent;
    self.errorLabel.hidden = YES;
    self.retryButton.hidden = YES;
}

- (void)showError:(NSString *)message {
    [self.spinner stopAnimating];
    self.spinner.hidden = YES;
    self.episodeRow.hidden = YES;
    self.voiceRow.hidden = YES;
    self.detailLabel.hidden = YES;
    self.playButton.hidden = YES;
    self.errorLabel.text = message.length ? message : @"Не удалось загрузить список серий.";
    self.errorLabel.hidden = NO;
    self.retryButton.hidden = NO;
}

#pragma mark - Data

- (void)loadEpisodes {
    [self showLoading:YES];

    __weak typeof(self) weakSelf = self;
    if (!self.fetchBlock) {
        [self showError:@"Источник не настроен."];
        return;
    }
    self.fetchBlock(^(NSArray<NSDictionary *> *episodes, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (error) {
            [self showError:error.localizedDescription];
            return;
        }
        if (!episodes.count) {
            [self showError:@"Для этого тайтла нет доступных серий."];
            return;
        }

        [self buildVoicesFromEpisodes:episodes];
        if (!self.episodeNumbers.count) {
            [self showError:@"Для этого тайтла нет доступных озвучек."];
            return;
        }

        [self selectDefaults];
        [self showLoading:NO];
        [self updateUI];
    });
}

- (void)buildVoicesFromEpisodes:(NSArray<NSDictionary *> *)episodes {
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *byEpisode = [NSMutableDictionary dictionary];

    for (NSDictionary *item in episodes) {
        // Показываем номер серии (number), а не служебный параметр плеера сайта:
        // именно он совпадает с тем, что видит пользователь на сайте.
        NSString *episode = [item[@"number"] description];
        if (!episode.length) episode = [item[@"episode"] description];
        if (!episode.length) continue;

        NSMutableArray *rows = byEpisode[episode];
        if (!rows) {
            rows = [NSMutableArray array];
            byEpisode[episode] = rows;
        }

        NSString *dubbing = [item[@"dubbing"] description] ?: @"";
        BOOL duplicate = NO;
        for (NSDictionary *existing in rows) {
            if ([[existing[@"dubbing"] description] isEqualToString:dubbing]) {
                duplicate = YES;
                break;
            }
        }
        if (!duplicate) [rows addObject:item];
    }

    NSArray<NSString *> *sorted = [byEpisode.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSInteger ia = a.integerValue;
        NSInteger ib = b.integerValue;
        if (ia < ib) return NSOrderedAscending;
        if (ia > ib) return NSOrderedDescending;
        return [a compare:b];
    }];

    NSMutableDictionary *voices = [NSMutableDictionary dictionary];
    for (NSString *key in sorted) {
        NSArray *rows = [byEpisode[key] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [[a[@"dubbing"] description] compare:[b[@"dubbing"] description]
                                                options:NSCaseInsensitiveSearch];
        }];
        voices[key] = rows;
    }

    self.episodeNumbers = sorted;
    self.voices = voices;
}

- (void)selectDefaults {
    NSString *resumeEpisode = [self.resumeInfo[@"episode"] description];
    NSString *episode = nil;
    if (resumeEpisode.length && [self.episodeNumbers containsObject:resumeEpisode]) {
        episode = resumeEpisode;
    } else {
        episode = self.episodeNumbers.firstObject;
    }
    self.selectedEpisode = episode;

    NSArray<NSDictionary *> *rows = self.voices[episode] ?: @[];
    NSString *resumeVoice = [self.resumeInfo[@"dubbing"] description];
    NSString *voice = nil;
    for (NSDictionary *row in rows) {
        if (resumeVoice.length && [[row[@"dubbing"] description] isEqualToString:resumeVoice]) {
            voice = resumeVoice;
            break;
        }
    }
    if (!voice.length) voice = [rows.firstObject[@"dubbing"] description];
    self.selectedVoice = voice ?: @"";
}

- (NSDictionary *)currentSource {
    for (NSDictionary *row in self.voices[self.selectedEpisode] ?: @[]) {
        if ([[row[@"dubbing"] description] isEqualToString:self.selectedVoice]) return row;
    }
    return nil;
}

- (NSTimeInterval)startTimeForSelection {
    if (!self.resumeInfo) return 0;
    NSString *resumeEpisode = [self.resumeInfo[@"episode"] description];
    NSString *resumeDubbing = [self.resumeInfo[@"dubbing"] description] ?: @"";
    if (![resumeEpisode isEqualToString:self.selectedEpisode ?: @""]) return 0;
    if (![resumeDubbing isEqualToString:self.selectedVoice ?: @""]) return 0;
    NSTimeInterval time = [self.resumeInfo[@"time"] doubleValue];
    return time > 5.0 ? time : 0;
}

- (void)updateUI {
    self.episodeValueLabel.text = [NSString stringWithFormat:@"Серия %@", self.selectedEpisode ?: @"—"];
    self.voiceValueLabel.text = self.selectedVoice.length ? self.selectedVoice : @"Не выбрана";

    NSDictionary *source = [self currentSource];
    NSString *player = [source[@"player"] description] ?: @"";
    NSNumber *duration = [source[@"duration"] isKindOfClass:[NSNumber class]] ? source[@"duration"] : nil;
    NSString *durationText = @"";
    if (duration.integerValue > 0) {
        NSInteger total = duration.integerValue;
        durationText = [NSString stringWithFormat:@"%ld:%02ld", (long)(total / 60), (long)(total % 60)];
    }
    NSMutableArray *parts = [NSMutableArray array];
    if (durationText.length) [parts addObject:durationText];
    if (player.length) [parts addObject:player];
    if (self.episodeShift != 0) {
        [parts addObject:[NSString stringWithFormat:@"сдвиг %+ld", (long)self.episodeShift]];
    }
    self.detailLabel.text = [parts componentsJoinedByString:@" · "];

    NSTimeInterval start = [self startTimeForSelection];
    NSString *title = start > 0
        ? [NSString stringWithFormat:@"Продолжить с %@", [YumiResumeStore timeStringForSeconds:start]]
        : @"Смотреть";
    [self.playButton setTitle:title forState:UIControlStateNormal];
    self.playButton.enabled = (source != nil);
    self.playButton.alpha = source ? 1.0 : 0.5;
}

#pragma mark - Pickers

- (void)chooseEpisode {
    if (!self.episodeNumbers.count) return;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Серия"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *episode in self.episodeNumbers) {
        NSString *title = [NSString stringWithFormat:@"Серия %@", episode];
        if ([episode isEqualToString:self.selectedEpisode]) {
            title = [@"✓ " stringByAppendingString:title];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            self.selectedEpisode = episode;
            NSArray *rows = self.voices[episode] ?: @[];
            BOOL voiceStillExists = NO;
            for (NSDictionary *row in rows) {
                if ([[row[@"dubbing"] description] isEqualToString:self.selectedVoice]) {
                    voiceStillExists = YES;
                    break;
                }
            }
            if (!voiceStillExists) {
                self.selectedVoice = [rows.firstObject[@"dubbing"] description] ?: @"";
            }
            [self updateUI];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.episodeRow;
    sheet.popoverPresentationController.sourceRect = self.episodeRow.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)chooseVoice {
    NSArray<NSDictionary *> *rows = self.voices[self.selectedEpisode] ?: @[];
    if (!rows.count) return;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Озвучка"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *row in rows) {
        NSString *dubbing = [row[@"dubbing"] description] ?: @"Без озвучки";
        NSString *title = dubbing;
        if ([dubbing isEqualToString:self.selectedVoice]) {
            title = [@"✓ " stringByAppendingString:title];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            self.selectedVoice = dubbing;
            [self updateUI];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.voiceRow;
    sheet.popoverPresentationController.sourceRect = self.voiceRow.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Сдвиг нумерации

- (void)chooseShift {
    NSString *title = self.episodeShift == 0
        ? @"Сдвиг нумерации: нет"
        : [NSString stringWithFormat:@"Сдвиг нумерации: %+ld", (long)self.episodeShift];

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:title
                                            message:@"Если сайт и плеер нумеруют серии по-разному, сдвинь номер на ±1. "
                                                    @"Настройка запоминается для этого тайтла."
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSInteger value = -2; value <= 2; value++) {
        NSString *actionTitle = value == 0
            ? @"Без сдвига"
            : [NSString stringWithFormat:@"%+ld", (long)value];
        if (value == self.episodeShift) {
            actionTitle = [@"✓ " stringByAppendingString:actionTitle];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:actionTitle
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            self.episodeShift = value;
            [[NSUserDefaults standardUserDefaults] setInteger:value forKey:[self shiftKey]];
            [self updateUI];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.barButtonItem = self.navigationItem.leftBarButtonItem;
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Диагностика

- (void)titleTapped {
    self.titleTaps += 1;
    if (self.titleTaps < 5) return;
    self.titleTaps = 0;
    [self showRawEpisodes];
}

- (void)showRawEpisodes {
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"pageID: %@\n\n", self.pageID ?: @"—"];

    NSArray<NSString *> *keys = self.episodeNumbers ?: @[];
    for (NSString *key in keys) {
        [text appendFormat:@"— Серия %@\n", key];
        for (NSDictionary *row in self.voices[key] ?: @[]) {
            [text appendFormat:@"   number=%@ param=%@ epParam=%@ dubbing=%@ player=%@\n   iframe=%@\n",
             row[@"number"], row[@"episode"], row[@"epParam"],
             row[@"dubbing"], row[@"player"], row[@"iframe"]];
        }
    }
    if (!keys.count) {
        [text appendString:@"Нет данных: список серий не загрузился."];
    }

    UITextView *view = [[UITextView alloc] initWithFrame:CGRectZero];
    view.editable = NO;
    view.font = [UIFont fontWithName:@"Menlo" size:10.5] ?: [UIFont systemFontOfSize:11];
    view.text = text;

    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = @"Диагностика серий";
    vc.view.backgroundColor = [UIColor whiteColor];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [view.topAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.topAnchor],
        [view.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor],
        [view.bottomAnchor constraintEqualToAnchor:vc.view.bottomAnchor]
    ]];
    vc.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(closeDiagnostics)];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)closeDiagnostics {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Play

- (void)playTapped {
    NSDictionary *source = [self currentSource];
    if (!source) return;

    [self setBusy:YES];

    NSString *episode = self.selectedEpisode;
    NSString *dubbing = self.selectedVoice;
    NSTimeInterval start = [self startTimeForSelection];
    NSString *animeID = [source[@"animeID"] description] ?: @"";
    NSString *episodeParam = [source[@"epParam"] description] ?: episode;

    NSMutableDictionary *requested = [source mutableCopy];
    requested[@"epShift"] = @(self.episodeShift);

    __weak typeof(self) weakSelf = self;
    if (!self.resolveBlock) {
        [self setBusy:NO];
        return;
    }
    self.resolveBlock(requested, episode ?: @"", ^(NSURL *url,
                                                 NSDictionary<NSString *,NSString *> *headers,
                                                 NSArray<NSDictionary<NSString *,NSString *> *> *qualities,
                                                 NSString *title,
                                                 NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self setBusy:NO];

        if (error || !url) {
            UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:@"Не удалось открыть видео"
                                                    message:error.localizedDescription ?: @"Неизвестная ошибка"
                                             preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        NSString *finalTitle = title ?: @"";
        if (self.pageTitle.length && finalTitle.length) {
            finalTitle = [NSString stringWithFormat:@"%@ — %@", self.pageTitle, finalTitle];
        } else if (self.pageTitle.length) {
            finalTitle = self.pageTitle;
        }

        NSMutableDictionary *resume = [@{
            @"pageID": self.pageID ?: @"",
            @"animeID": animeID,
            @"episode": episode ?: @"",
            @"episodeParam": episodeParam ?: @"",
            @"dubbing": dubbing ?: @"",
            @"startTime": @(start)
        } mutableCopy];
        if (qualities.count) resume[@"qualities"] = qualities;

        [self.delegate yummyEpisodesController:self
                                 playStreamURL:url
                                       headers:headers
                                         title:finalTitle
                                        resume:resume];
    });
}

- (void)setBusy:(BOOL)busy {
    if (busy) {
        if (self.busyOverlay) return;
        UIView *overlay = [[UIView alloc] initWithFrame:self.view.bounds];
        overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        UIActivityIndicatorView *spinner =
            [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        spinner.center = overlay.center;
        spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
                                   UIViewAutoresizingFlexibleBottomMargin |
                                   UIViewAutoresizingFlexibleLeftMargin |
                                   UIViewAutoresizingFlexibleRightMargin;
        [spinner startAnimating];
        [overlay addSubview:spinner];

        [self.view addSubview:overlay];
        self.busyOverlay = overlay;
        self.view.userInteractionEnabled = NO;
    } else {
        self.view.userInteractionEnabled = YES;
        [self.busyOverlay removeFromSuperview];
        self.busyOverlay = nil;
    }
}

@end
