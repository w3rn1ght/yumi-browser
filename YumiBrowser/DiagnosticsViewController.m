#import "DiagnosticsViewController.h"
#import "YumiDiagnostics.h"

@interface DiagnosticsViewController ()
@property (nonatomic, strong) NSDateFormatter *formatter;
@end

@implementation DiagnosticsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Диагностика";
    self.tableView.rowHeight = 66.0;

    self.formatter = [[NSDateFormatter alloc] init];
    self.formatter.dateFormat = @"HH:mm:ss";

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(doneTapped)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Копировать"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(copyTapped)];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reload)
                                                 name:YumiDiagnosticsDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)doneTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)copyTapped {
    [UIPasteboard generalPasteboard].string = [[YumiDiagnostics shared] plainText];
    [self.tableView reloadData];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Скопировано"
                                            message:@"Весь журнал в буфере обмена"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)reload {
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState {
    if ([YumiDiagnostics shared].entries.count) {
        self.tableView.backgroundView = nil;
        return;
    }
    UILabel *label = [[UILabel alloc] init];
    label.text = @"Ошибок не поймано.\nОткрой проблемную страницу и вернись сюда.";
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor grayColor];
    label.font = [UIFont systemFontOfSize:15];
    self.tableView.backgroundView = label;
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[YumiDiagnostics shared].entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"YumiDiagnosticsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
    }

    NSArray<NSDictionary *> *entries = [YumiDiagnostics shared].entries;
    if (indexPath.row >= (NSInteger)entries.count) return cell;
    NSDictionary *entry = entries[(NSUInteger)indexPath.row];

    NSString *time = [self.formatter stringFromDate:entry[@"time"]];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ · %@", time, entry[@"kind"]];
    cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];

    NSString *message = [entry[@"message"] description];
    if (!message.length) message = [entry[@"source"] description];
    cell.detailTextLabel.text = message;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    cell.detailTextLabel.numberOfLines = 2;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray<NSDictionary *> *entries = [YumiDiagnostics shared].entries;
    if (indexPath.row >= (NSInteger)entries.count) return;

    NSDictionary *entry = entries[(NSUInteger)indexPath.row];
    [UIPasteboard generalPasteboard].string = [[YumiDiagnostics shared] plainText];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:[entry[@"kind"] description]
                                            message:[NSString stringWithFormat:@"%@\n\n%@\n\n(журнал скопирован)",
                                                     [entry[@"message"] description],
                                                     [entry[@"page"] description]]
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Очистить журнал"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        [[YumiDiagnostics shared] clear];
        [self reload];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
