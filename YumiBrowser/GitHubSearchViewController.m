#import "GitHubSearchViewController.h"

@interface GitHubSearchViewController () <UISearchBarDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<NSDictionary *> *users;
@property (nonatomic, strong) NSArray<NSDictionary *> *repositories;
@property (nonatomic, copy) NSString *query;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, strong) NSURLSessionTask *usersTask;
@property (nonatomic, strong) NSURLSessionTask *repositoriesTask;
@property (nonatomic, strong) NSTimer *debounceTimer;
@property (nonatomic, assign) NSUInteger searchGeneration;

@end

@implementation GitHubSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Поиск GitHub";
    self.users = @[];
    self.repositories = @[];
    self.tableView.rowHeight = 72.0;
    self.tableView.tableFooterView = [[UIView alloc] init];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                      target:self
                                                      action:@selector(cancelTapped)];

    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    searchBar.delegate = self;
    searchBar.placeholder = @"Имя пользователя или репозиторий";
    searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    searchBar.returnKeyType = UIReturnKeySearch;
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar = searchBar;
    self.tableView.tableHeaderView = searchBar;
    self.statusText = @"Введи имя пользователя или репозитория";
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.searchBar becomeFirstResponder];
}

- (void)dealloc {
    [self.debounceTimer invalidate];
    [self.usersTask cancel];
    [self.repositoriesTask cancel];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Search

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self.debounceTimer invalidate];
    [self runSearch];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self.debounceTimer invalidate];
    if (!searchText.length) {
        self.searchGeneration += 1;
        [self.usersTask cancel];
        [self.repositoriesTask cancel];
        self.query = nil;
        self.users = @[];
        self.repositories = @[];
        self.statusText = @"Введи имя пользователя или репозитория";
        [self.tableView reloadData];
        return;
    }
    self.debounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.65
                                                         target:self
                                                       selector:@selector(debounceFired:)
                                                       userInfo:nil
                                                        repeats:NO];
}

- (void)debounceFired:(NSTimer *)timer {
    if (self.searchBar.text.length >= 2) [self runSearch];
}

- (void)runSearch {
    NSString *text = [self.searchBar.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) return;

    [self.usersTask cancel];
    [self.repositoriesTask cancel];
    self.searchGeneration += 1;
    NSUInteger generation = self.searchGeneration;
    self.query = text;
    self.users = @[];
    self.repositories = @[];
    self.statusText = @"Поиск…";
    self.loading = YES;
    [self.tableView reloadData];

    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"];
    NSString *encoded = [text stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: text;
    NSString *usersURL = [NSString stringWithFormat:
        @"https://api.github.com/search/users?q=%@&per_page=12", encoded];
    NSString *reposURL = [NSString stringWithFormat:
        @"https://api.github.com/search/repositories?q=%@&per_page=12", encoded];

    __block NSInteger pending = 2;
    __weak typeof(self) weakSelf = self;
    void (^finished)(void) = ^{
        if (generation != self.searchGeneration) return;
        pending -= 1;
        if (pending > 0) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || generation != self.searchGeneration) return;
            self.loading = NO;
            if (self.users.count == 0 && self.repositories.count == 0) {
                self.statusText = self.statusText.length ? self.statusText : @"Ничего не найдено";
            } else {
                self.statusText = nil;
            }
            [self.tableView reloadData];
        });
    };

    self.usersTask = [self requestURL:usersURL completion:^(NSArray<NSDictionary *> *items, NSString *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { finished(); return; }
        if (generation != self.searchGeneration) return;
        if (items) self.users = items;
        if (error.length) self.statusText = error;
        finished();
    }];
    self.repositoriesTask = [self requestURL:reposURL completion:^(NSArray<NSDictionary *> *items, NSString *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { finished(); return; }
        if (generation != self.searchGeneration) return;
        if (items) self.repositories = items;
        if (error.length) self.statusText = error;
        finished();
    }];
}

- (NSURLSessionTask *)requestURL:(NSString *)urlString
                      completion:(void (^)(NSArray<NSDictionary *> *, NSString *))completion {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion(nil, @"Некорректный запрос");
        return nil;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:20.0];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"YumiBrowser" forHTTPHeaderField:@"User-Agent"];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task =
        [session dataTaskWithRequest:request
                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error.localizedDescription ?: @"Ошибка сети");
            });
            return;
        }
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response : nil;
        id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSDictionary *rootDict = [root isKindOfClass:[NSDictionary class]]
            ? (NSDictionary *)root : nil;
        if (http.statusCode != 200) {
            NSString *message = @"GitHub API недоступен";
            if ([rootDict[@"message"] isKindOfClass:[NSString class]]) {
                message = rootDict[@"message"];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, message);
            });
            return;
        }

        NSArray *items = rootDict[@"items"];
        NSMutableArray *result = [NSMutableArray array];
        if ([items isKindOfClass:[NSArray class]]) {
            for (id item in items) {
                if ([item isKindOfClass:[NSDictionary class]]) [result addObject:item];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result, nil);
        });
    }];
    [task resume];
    return task;
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.users.count == 0 && self.repositories.count == 0) return 1;
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.users.count == 0 && self.repositories.count == 0) return 1;
    return section == 0 ? self.users.count : self.repositories.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.users.count == 0 && self.repositories.count == 0) return nil;
    return section == 0 ? @"Пользователи" : @"Репозитории";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.users.count == 0 && self.repositories.count == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:nil];
        cell.textLabel.text = self.statusText;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.textLabel.textColor = [UIColor grayColor];
        cell.textLabel.numberOfLines = 0;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                   reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    cell.detailTextLabel.numberOfLines = 2;

    if (indexPath.section == 0) {
        NSDictionary *user = self.users[indexPath.row];
        cell.textLabel.text = [user[@"login"] description];
        NSString *type = [user[@"type"] description];
        cell.detailTextLabel.text = type.length ? type : @"Пользователь";
    } else {
        NSDictionary *repo = self.repositories[indexPath.row];
        cell.textLabel.text = [repo[@"full_name"] description];
        NSNumber *stars = [repo[@"stargazers_count"] isKindOfClass:[NSNumber class]]
            ? repo[@"stargazers_count"] : @0;
        NSString *description = [repo[@"description"] isKindOfClass:[NSString class]]
            ? repo[@"description"] : @"";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"★ %@%@",
                                     stars, description.length ? [@" · " stringByAppendingString:description] : @""];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.users.count == 0 && self.repositories.count == 0) return;

    NSURL *url = nil;
    if (indexPath.section == 0) {
        NSDictionary *user = self.users[indexPath.row];
        NSString *login = [user[@"login"] description];
        if (login.length) {
            url = [NSURL URLWithString:[NSString stringWithFormat:
                @"https://github.com/%@?tab=repositories", login]];
        }
    } else {
        NSDictionary *repo = self.repositories[indexPath.row];
        NSString *fullName = [repo[@"full_name"] description];
        if (fullName.length) {
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://github.com/%@", fullName]];
        }
    }
    if (!url) return;
    if ([self.delegate respondsToSelector:@selector(gitHubSearchController:openURL:)]) {
        [self.delegate gitHubSearchController:self openURL:url];
    }
}

@end
