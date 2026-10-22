#import "YummyEpisodesViewController.h"
#import "YumiYummyResolver.h"

@interface YummyEpisodesViewController ()
@property (nonatomic, copy) NSString *pageID;
@property (nonatomic, copy) NSString *pageTitle;
@property (nonatomic, copy) NSArray<NSDictionary *> *sections;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UIView *busyOverlay;
@property (nonatomic, strong) UIActivityIndicatorView *busySpinner;
@end

@implementation YummyEpisodesViewController

- (instancetype)initWithPageID:(NSString *)pageID pageTitle:(NSString *)pageTitle {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _pageID = [pageID copy];
        _pageTitle = [pageTitle copy];
        _sections = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Серии";
    self.tableView.rowHeight = 56.0;
    self.tableView.tableFooterView = [[UIView alloc] init];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(close)];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.spinner startAnimating];
    self.tableView.backgroundView = self.spinner;

    [self loadEpisodes];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadEpisodes {
    __weak typeof(self) weakSelf = self;
    [YumiYummyResolver fetchEpisodesWithPageID:self.pageID
                                    completion:^(NSArray<NSDictionary *> *episodes, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self.spinner stopAnimating];
        self.tableView.backgroundView = nil;

        if (error) {
            [self showState:[NSString stringWithFormat:@"Не удалось загрузить серии.\n%@", error.localizedDescription]];
            return;
        }
        if (!episodes.count) {
            [self showState:@"Для этого тайтла нет доступных серий."];
            return;
        }

        [self buildSectionsFromEpisodes:episodes];
        [self.tableView reloadData];
    }];
}

- (void)showState:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    label.text = text;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.textColor = [UIColor grayColor];
    label.font = [UIFont systemFontOfSize:15.0];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundView = label;
}

- (void)buildSectionsFromEpisodes:(NSArray<NSDictionary *> *)episodes {
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *byEpisode = [NSMutableDictionary dictionary];

    for (NSDictionary *item in episodes) {
        NSString *episode = [item[@"episode"] description];
        if (!episode.length) continue;

        NSMutableArray *rows = byEpisode[episode];
        if (!rows) {
            rows = [NSMutableArray array];
            byEpisode[episode] = rows;
        }

        // Одна и та же озвучка может встречаться несколько раз (разные плееры).
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

    NSArray<NSString *> *sortedKeys =
        [byEpisode.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            NSInteger ia = a.integerValue;
            NSInteger ib = b.integerValue;
            if (ia < ib) return NSOrderedAscending;
            if (ia > ib) return NSOrderedDescending;
            return [a compare:b];
        }];

    NSMutableArray *sections = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        NSArray *rows = [byEpisode[key] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [[a[@"dubbing"] description] compare:[b[@"dubbing"] description]
                                                options:NSCaseInsensitiveSearch];
        }];
        [sections addObject:@{ @"episode": key, @"items": rows }];
    }
    self.sections = sections;
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self.sections[(NSUInteger)section][@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"Серия %@", self.sections[(NSUInteger)section][@"episode"]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"YummyEpisodeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }

    NSDictionary *item = self.sections[(NSUInteger)indexPath.section][@"items"][(NSUInteger)indexPath.row];
    NSString *dubbing = [item[@"dubbing"] description];
    cell.textLabel.text = dubbing.length ? dubbing : @"Без озвучки";

    NSString *player = [item[@"player"] description];
    NSNumber *duration = [item[@"duration"] isKindOfClass:[NSNumber class]] ? item[@"duration"] : nil;
    NSString *durationText = @"";
    if (duration.integerValue > 0) {
        NSInteger total = duration.integerValue;
        durationText = [NSString stringWithFormat:@"%ld:%02ld", (long)(total / 60), (long)(total % 60)];
    }
    NSMutableArray *details = [NSMutableArray array];
    if (player.length) [details addObject:player];
    if (durationText.length) [details addObject:durationText];
    cell.detailTextLabel.text = [details componentsJoinedByString:@" · "];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = self.sections[(NSUInteger)indexPath.section][@"items"][(NSUInteger)indexPath.row];
    [self resolveAndPlay:item];
}

#pragma mark - Resolve

- (void)resolveAndPlay:(NSDictionary *)item {
    [self setBusy:YES];

    __weak typeof(self) weakSelf = self;
    [YumiYummyResolver resolveStreamWithAnimeID:[item[@"animeID"] description]
                                        episode:[item[@"episode"] description]
                                        dubbing:[item[@"dubbing"] description]
                                     completion:^(NSURL *url, NSDictionary<NSString *,NSString *> *headers, NSString *title, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self setBusy:NO];

        if (error || !url) {
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"Не удалось открыть видео"
                                 message:error.localizedDescription ?: @"Неизвестная ошибка"
                          preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        NSString *finalTitle = title;
        if (self.pageTitle.length) {
            finalTitle = [NSString stringWithFormat:@"%@ — %@", self.pageTitle, title];
        }
        [self.delegate yummyEpisodesController:self
                                 playStreamURL:url
                                       headers:headers
                                         title:finalTitle];
    }];
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
