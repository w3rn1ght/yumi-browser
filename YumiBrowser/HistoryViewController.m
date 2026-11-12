#import "HistoryViewController.h"
#import "YumiHistoryStore.h"

@interface HistoryViewController () <UISearchBarDelegate>
@property (nonatomic, strong) NSArray<YumiHistoryEntry *> *entries;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, copy) NSString *query;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic, strong) NSDateFormatter *dayFormatter;
@end

@implementation HistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"История";
    self.tableView.rowHeight = 58.0;
    self.tableView.backgroundView = nil;

    self.timeFormatter = [[NSDateFormatter alloc] init];
    self.timeFormatter.dateFormat = @"HH:mm";

    self.dayFormatter = [[NSDateFormatter alloc] init];
    self.dayFormatter.dateFormat = @"d MMMM";
    self.dayFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"ru_RU"];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Очистить"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(clearTapped)];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(doneTapped)];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
    self.searchBar.placeholder = @"Поиск по истории";
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.tableView.tableHeaderView = self.searchBar;

    [self reload];
}

- (void)doneTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearTapped {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Очистить историю?"
                                            message:@"Ссылки и заголовки посещений будут удалены. Куки и данные сайтов останутся."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Очистить"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        [YumiHistoryStore clear];
        [self reload];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)reload {
    self.entries = [YumiHistoryStore entriesMatching:self.query];
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState {
    if (self.entries.count) {
        self.tableView.backgroundView = nil;
        return;
    }
    UILabel *label = [[UILabel alloc] init];
    label.text = self.query.length ? @"Ничего не найдено" : @"История пуста";
    label.textColor = [UIColor grayColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:15];
    self.tableView.backgroundView = label;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.query = searchText;
    [self reload];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"YumiHistoryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
    }
    if (indexPath.row >= (NSInteger)self.entries.count) return cell;

    YumiHistoryEntry *entry = self.entries[(NSUInteger)indexPath.row];
    cell.textLabel.text = [entry displayTitle];
    cell.textLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightMedium];

    NSString *time = entry.date ? [self.timeFormatter stringFromDate:entry.date] : @"";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", time, entry.urlString ?: @""];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.entries.count) return;

    YumiHistoryEntry *entry = self.entries[(NSUInteger)indexPath.row];
    NSURL *url = [NSURL URLWithString:entry.urlString ?: @""];
    if (!url) return;

    [self.delegate historyController:self openURL:url];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    if (indexPath.row >= (NSInteger)self.entries.count) return;

    [YumiHistoryStore removeEntry:self.entries[(NSUInteger)indexPath.row]];
    [self reload];
}

@end
