#import "TabsViewController.h"
#import "YumiTab.h"

@interface TabsViewController ()
@property (nonatomic, strong) NSMutableArray<YumiTab *> *tabs;
@property (nonatomic, assign) NSInteger activeIndex;
@end

@implementation TabsViewController

- (instancetype)initWithTabs:(NSArray<YumiTab *> *)tabs activeIndex:(NSInteger)activeIndex {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _tabs = [tabs mutableCopy] ?: [NSMutableArray array];
        _activeIndex = activeIndex;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Вкладки";
    self.tableView.rowHeight = 56.0;
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(doneTapped)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                      target:self
                                                      action:@selector(addTapped)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = @"Новая вкладка";
}

- (void)doneTapped { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)addTapped {
    [self.delegate tabsControllerDidRequestNewTab:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? (NSInteger)self.tabs.count : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [NSString stringWithFormat:@"Открыто: %lu", (unsigned long)self.tabs.count];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = @"Новая вкладка";
        cell.textLabel.textColor = self.view.tintColor;
        cell.imageView.image = nil;
        return cell;
    }

    static NSString *reuse = @"YumiTabCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    }

    YumiTab *tab = self.tabs[(NSUInteger)indexPath.row];
    cell.textLabel.text = tab.title.length ? tab.title : @"Без названия";
    NSString *host = tab.url.host ?: tab.pendingURLString;
    cell.detailTextLabel.text = host.length ? host : @"Начальная страница";
    cell.detailTextLabel.textColor = [UIColor grayColor];
    cell.accessoryType = (indexPath.row == self.activeIndex) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor blackColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        [self addTapped];
        return;
    }
    [self.delegate tabsController:self didSelectTabAtIndex:indexPath.row];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 && self.tabs.count > 1;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    if (indexPath.section != 0 || self.tabs.count <= 1) return;

    [self.tabs removeObjectAtIndex:(NSUInteger)indexPath.row];
    [self.delegate tabsController:self didCloseTabAtIndex:indexPath.row];

    if (self.activeIndex >= (NSInteger)self.tabs.count) {
        self.activeIndex = (NSInteger)self.tabs.count - 1;
    }
    [tableView reloadData];
}

@end
