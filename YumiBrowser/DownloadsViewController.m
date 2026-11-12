#import "DownloadsViewController.h"
#import "YumiDownloadManager.h"

/** Открывает папку загрузок в Filza, а если её нет — в «Файлах». */
static void YumiOpenDownloadsFolderInFilza(void) {
    NSString *directory = [[YumiDownloadManager shared] downloadsDirectory];
    if (!directory.length) return;

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

    NSURL *filesURL = [NSURL URLWithString:@"shareddocuments://"];
    if (filesURL && [[UIApplication sharedApplication] canOpenURL:filesURL]) {
        [[UIApplication sharedApplication] openURL:filesURL];
        return;
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Filza не найдена"
                                            message:directory
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Скопировать путь"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = directory;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Закрыть"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    UIViewController *presenter = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    [presenter presentViewController:alert animated:YES completion:nil];
}

@implementation DownloadsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Загрузки";
    self.tableView.rowHeight = 60.0;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Filza"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(openFolderTapped)];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(doneTapped)];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reload)
                                                 name:YumiDownloadsDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)doneTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openFolderTapped {
    YumiOpenDownloadsFolderInFilza();
}

- (void)reload {
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateEmptyState];
}

- (void)updateEmptyState {
    if ([YumiDownloadManager shared].items.count) {
        self.tableView.backgroundView = nil;
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Пока ничего не скачано.\nСсылки на файлы ловятся на страницах сайтов.";
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor grayColor];
    label.font = [UIFont systemFontOfSize:15];
    self.tableView.backgroundView = label;
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [YumiDownloadManager shared].items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"YumiDownloadCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
    }

    NSArray<YumiDownloadItem *> *items = [YumiDownloadManager shared].items;
    if (indexPath.row >= items.count) return cell;

    YumiDownloadItem *item = items[indexPath.row];
    cell.textLabel.text = item.filename ?: @"Файл";
    cell.textLabel.font = [UIFont systemFontOfSize:16];

    NSString *detail = [item stateText];
    if (item.finished && item.destinationPath.length) {
        detail = [NSString stringWithFormat:@"%@ · %@", detail, item.destinationPath.lastPathComponent];
    } else if (item.errorMessage.length) {
        detail = [NSString stringWithFormat:@"Ошибка: %@", item.errorMessage];
    }
    cell.detailTextLabel.text = detail;
    cell.detailTextLabel.textColor = item.errorMessage.length
        ? [UIColor colorWithRed:0.85 green:0.22 blue:0.18 alpha:1]
        : [UIColor grayColor];

    BOOL active = item.started && !item.finished && !item.cancelled && !item.errorMessage.length;
    UIProgressView *progress = nil;
    if (active) {
        progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        progress.frame = CGRectMake(0, 0, 70, 4);
        progress.progress = (float)MAX(0.02, item.progress);
        cell.accessoryView = progress;
    } else {
        UILabel *mark = [[UILabel alloc] init];
        mark.text = item.finished ? @"✓" : (item.cancelled ? @"–" : @"!");
        mark.textColor = item.finished ? [UIColor colorWithRed:0.18 green:0.62 blue:0.31 alpha:1]
                                       : [UIColor colorWithWhite:0.6 alpha:1];
        mark.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
        [mark sizeToFit];
        cell.accessoryView = mark;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSArray<YumiDownloadItem *> *items = [YumiDownloadManager shared].items;
    if (indexPath.row >= items.count) return;
    YumiDownloadItem *item = items[indexPath.row];

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:item.filename
                                            message:[item stateText]
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    BOOL active = item.started && !item.finished && !item.cancelled && !item.errorMessage.length;
    if (active) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Отменить загрузку"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(__unused UIAlertAction *action) {
            [[YumiDownloadManager shared] cancelItem:item];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Открыть папку загрузок"
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        YumiOpenDownloadsFolderInFilza();
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Удалить из списка"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        [[YumiDownloadManager shared] removeItem:item];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = tableView;
    sheet.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
