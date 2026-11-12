#import "TabsViewController.h"
#import "YumiTab.h"

/* Палитра Material 3 (фиолетовая схема). */
static UIColor *YumiM3Primary(void) {
    return [UIColor colorWithRed:0.404 green:0.314 blue:0.643 alpha:1.0];   // #6750A4
}
static UIColor *YumiM3Surface(void) {
    return [UIColor colorWithRed:0.996 green:0.969 blue:1.0 alpha:1.0];     // #FEF7FF
}
static UIColor *YumiM3SurfaceContainer(void) {
    return [UIColor colorWithRed:0.953 green:0.929 blue:0.980 alpha:1.0];   // #F3EDFA
}
static UIColor *YumiM3PrimaryContainer(void) {
    return [UIColor colorWithRed:0.910 green:0.878 blue:0.945 alpha:1.0];   // #E8E0F1
}
static UIColor *YumiM3OnSurface(void) {
    return [UIColor colorWithRed:0.110 green:0.098 blue:0.129 alpha:1.0];
}
static UIColor *YumiM3OnSurfaceVariant(void) {
    return [UIColor colorWithRed:0.286 green:0.267 blue:0.310 alpha:1.0];
}

#pragma mark - Карточка вкладки

@interface YumiTabCardCell : UICollectionViewCell
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIImageView *preview;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *hostLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, copy) NSString *representedKey;
@property (nonatomic, copy) void (^onClose)(void);
@end

@implementation YumiTabCardCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _card = [[UIView alloc] init];
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        _card.backgroundColor = [UIColor whiteColor];
        _card.layer.cornerRadius = 22.0;
        _card.layer.masksToBounds = YES;
        [self.contentView addSubview:_card];

        _preview = [[UIImageView alloc] init];
        _preview.translatesAutoresizingMaskIntoConstraints = NO;
        _preview.contentMode = UIViewContentModeScaleAspectFill;
        _preview.clipsToBounds = YES;
        _preview.backgroundColor = YumiM3SurfaceContainer();
        [_card addSubview:_preview];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
        _titleLabel.textColor = YumiM3OnSurface();
        _titleLabel.numberOfLines = 2;
        [_card addSubview:_titleLabel];

        _hostLabel = [[UILabel alloc] init];
        _hostLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _hostLabel.font = [UIFont systemFontOfSize:11.0];
        _hostLabel.textColor = YumiM3OnSurfaceVariant();
        _hostLabel.numberOfLines = 1;
        [_card addSubview:_hostLabel];

        _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_closeButton setTitle:@"✕" forState:UIControlStateNormal];
        [_closeButton setTitleColor:YumiM3OnSurfaceVariant() forState:UIControlStateNormal];
        _closeButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        _closeButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.92];
        _closeButton.layer.cornerRadius = 13.0;
        [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [_card addSubview:_closeButton];

        [NSLayoutConstraint activateConstraints:@[
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

            [_preview.topAnchor constraintEqualToAnchor:_card.topAnchor],
            [_preview.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
            [_preview.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
            [_preview.heightAnchor constraintEqualToAnchor:_card.heightAnchor multiplier:0.68],

            [_titleLabel.topAnchor constraintEqualToAnchor:_preview.bottomAnchor constant:8],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:12],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],

            [_hostLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_hostLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_hostLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_hostLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_card.bottomAnchor constant:-8],

            [_closeButton.topAnchor constraintEqualToAnchor:_card.topAnchor constant:8],
            [_closeButton.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-8],
            [_closeButton.widthAnchor constraintEqualToConstant:26],
            [_closeButton.heightAnchor constraintEqualToConstant:26]
        ]];
    }
    return self;
}

- (void)closeTapped {
    if (self.onClose) self.onClose();
}

- (void)setActive:(BOOL)active {
    self.card.layer.borderWidth = active ? 2.5 : 0.0;
    self.card.layer.borderColor = YumiM3Primary().CGColor;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.preview.image = nil;
    self.representedKey = nil;
    self.onClose = nil;
    [self setActive:NO];
}

@end

#pragma mark - Экран вкладок

@interface TabsViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) NSMutableArray<YumiTab *> *tabs;
@property (nonatomic, assign) NSInteger activeIndex;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIImage *> *snapshots;
@property (nonatomic, strong) NSMutableSet<NSString *> *requestedSnapshots;
@property (nonatomic, strong) UILabel *countLabel;
@end

@implementation TabsViewController

- (instancetype)initWithTabs:(NSArray<YumiTab *> *)tabs activeIndex:(NSInteger)activeIndex {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _tabs = [tabs mutableCopy] ?: [NSMutableArray array];
        _activeIndex = activeIndex;
        _snapshots = [NSMutableDictionary dictionary];
        _requestedSnapshots = [NSMutableSet set];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = YumiM3Surface();
    self.title = @"Вкладки";

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 16.0;
    layout.minimumLineSpacing = 18.0;
    layout.sectionInset = UIEdgeInsetsMake(4, 20, 28, 20);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = YumiM3Surface();
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[YumiTabCardCell class] forCellWithReuseIdentifier:@"card"];
    [self.view addSubview:self.collectionView];

    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = YumiM3Surface();
    [self.view addSubview:header];

    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
    done.translatesAutoresizingMaskIntoConstraints = NO;
    [done setTitle:@"Готово" forState:UIControlStateNormal];
    done.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    done.tintColor = YumiM3Primary();
    [done addTarget:self action:@selector(doneTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:done];

    UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
    add.translatesAutoresizingMaskIntoConstraints = NO;
    [add setTitle:@"+" forState:UIControlStateNormal];
    add.titleLabel.font = [UIFont systemFontOfSize:30 weight:UIFontWeightRegular];
    add.tintColor = YumiM3Primary();
    [add addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:add];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Вкладки";
    title.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    title.textColor = YumiM3OnSurface();
    [header addSubview:title];

    self.countLabel = [[UILabel alloc] init];
    self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.countLabel.textColor = YumiM3OnSurfaceVariant();
    [header addSubview:self.countLabel];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:96],

        [done.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [done.topAnchor constraintEqualToAnchor:header.topAnchor constant:4],
        [add.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [add.centerYAnchor constraintEqualToAnchor:done.centerYAnchor],
        [add.widthAnchor constraintEqualToConstant:44],
        [add.heightAnchor constraintEqualToConstant:44],

        [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [title.topAnchor constraintEqualToAnchor:done.bottomAnchor constant:2],
        [title.trailingAnchor constraintEqualToAnchor:add.leadingAnchor constant:-12],

        [self.countLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.countLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],

        [self.collectionView.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self updateCountLabel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    if (![layout isKindOfClass:[UICollectionViewFlowLayout class]]) return;

    CGFloat width = self.collectionView.bounds.size.width;
    if (width < 100) return;

    CGFloat inset = 20.0;
    CGFloat spacing = 16.0;
    NSInteger columns = (width > 720.0) ? 3 : 2;
    CGFloat itemWidth = floor((width - inset * 2 - spacing * (columns - 1)) / columns);
    CGFloat itemHeight = floor(itemWidth * 0.74) + 58.0;

    CGSize size = CGSizeMake(itemWidth, itemHeight);
    if (!CGSizeEqualToSize(layout.itemSize, size)) {
        layout.itemSize = size;
        [layout invalidateLayout];
    }
}

- (void)updateCountLabel {
    self.countLabel.text = [NSString stringWithFormat:@"Открыто: %lu", (unsigned long)self.tabs.count];
}

- (void)doneTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)addTapped {
    [self.delegate tabsControllerDidRequestNewTab:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Данные

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return (NSInteger)self.tabs.count;
}

- (NSString *)keyForTab:(YumiTab *)tab {
    NSString *url = tab.webView.URL.absoluteString;
    if (url.length && ![url isEqualToString:@"about:blank"]) return url;
    if (tab.pendingURLString.length) return tab.pendingURLString;
    return @"home";
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    YumiTabCardCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"card"
                                                                      forIndexPath:indexPath];
    if (indexPath.row >= (NSInteger)self.tabs.count) return cell;

    YumiTab *tab = self.tabs[(NSUInteger)indexPath.row];
    NSString *key = [self keyForTab:tab];

    NSString *title = tab.title.length ? tab.title : nil;
    if (!title.length) title = tab.webView.title;
    if (!title.length) {
        NSURL *url = tab.webView.URL ?: [NSURL URLWithString:tab.pendingURLString ?: @""];
        title = url.host.length ? url.host : @"Начальная страница";
    }
    cell.titleLabel.text = title;

    NSURL *hostURL = tab.webView.URL ?: [NSURL URLWithString:tab.pendingURLString ?: @""];
    cell.hostLabel.text = hostURL.host.length ? hostURL.host : @"yumi://home";
    cell.representedKey = key;
    [cell setActive:(indexPath.row == self.activeIndex)];

    __weak typeof(self) weakSelf = self;
    NSInteger row = indexPath.row;
    cell.onClose = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self closeTabAtIndex:row];
    };

    UIImage *cached = self.snapshots[key];
    if (cached) {
        cell.preview.image = cached;
    } else {
        cell.preview.image = nil;
        [self requestSnapshotForTab:tab key:key];
    }
    return cell;
}

- (void)requestSnapshotForTab:(YumiTab *)tab key:(NSString *)key {
    if ([self.requestedSnapshots containsObject:key]) return;
    WKWebView *webView = tab.webView;
    NSURL *url = webView.URL;
    if (!url || [url.absoluteString isEqualToString:@"about:blank"]) return;

    [self.requestedSnapshots addObject:key];

    WKSnapshotConfiguration *config = [[WKSnapshotConfiguration alloc] init];
    config.snapshotWidth = @(420);

    __weak typeof(self) weakSelf = self;
    [webView takeSnapshotWithConfiguration:config completionHandler:^(UIImage *image, NSError *error) {
        if (!image) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.snapshots[key] = image;
            [self.collectionView reloadData];
        });
    }];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.tabs.count) return;
    [self.delegate tabsController:self didSelectTabAtIndex:indexPath.row];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)closeTabAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count) return;
    if (self.tabs.count <= 1) {
        [self.delegate tabsControllerDidRequestNewTab:self];
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    [self.tabs removeObjectAtIndex:(NSUInteger)index];
    [self.delegate tabsController:self didCloseTabAtIndex:index];

    if (self.activeIndex >= (NSInteger)self.tabs.count) {
        self.activeIndex = (NSInteger)self.tabs.count - 1;
    }
    [self updateCountLabel];
    [self.collectionView reloadData];
}

@end
