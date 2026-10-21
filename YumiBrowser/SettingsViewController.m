#import "SettingsViewController.h"
#import "YumiSettings.h"

typedef NS_ENUM(NSInteger, YumiSettingsSwitchTag) {
    YumiSettingsSwitchMediaHook = 100,
    YumiSettingsSwitchAutoPlayer,
    YumiSettingsSwitchAdblock
};

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Настройки";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(doneTapped)];
    self.tableView.rowHeight = 48.0;
}

- (void)doneTapped { [self dismissViewControllerAnimated:YES completion:nil]; }

- (YumiSettings *)settings { return [YumiSettings shared]; }

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 5; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2;   // версия сайта, UA
        case 1: return 2;   // перехват, авто-плеер
        case 2: return 1;   // реклама
        case 3: return 2;   // очистить данные, сброс
        default: return 3;  // о приложении
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Сайты";
        case 1: return @"Плееры";
        case 2: return @"Реклама";
        case 3: return @"Данные";
        default: return @"О приложении";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"Если сайт криво выглядит или падает — включи полную версию. Настройка «Версия сайта» задаёт режим по умолчанию, а в меню браузера её можно переключить для конкретного сайта.";
        case 1:
            return @"Перехват находит m3u8/mp4, которые использует плеер сайта, и умеет открыть их в системном плеере с нужными Referer и cookies. Авто-режим сразу запускает первый найденный HLS.";
        case 2:
            return @"Блокировка работает на уровне WebKit (правила + косметика). Если сайт сломался — выключи и перезагрузи страницу.";
        default:
            return nil;
    }
}

- (UITableViewCell *)cellWithStyle:(UITableViewCellStyle)style {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:nil];
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    return cell;
}

- (UITableViewCell *)switchCellWithTitle:(NSString *)title tag:(YumiSettingsSwitchTag)tag on:(BOOL)on {
    UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleDefault];
    cell.textLabel.text = title;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = on;
    sw.tag = tag;
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YumiSettings *s = self.settings;

    if (indexPath.section == 0) {
        UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleValue1];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Версия сайта";
            cell.detailTextLabel.text = (s.uaMode == YumiUAModeDesktop) ? @"Полная" : @"Мобильная";
        } else {
            cell.textLabel.text = @"User-Agent";
            NSString *ua = s.customUA ?: @"";
            cell.detailTextLabel.text = (s.uaMode == YumiUAModeCustom)
                ? @"Своя строка"
                : ([ua containsString:@"Macintosh"] ? @"macOS Safari" : @"iOS Safari 12");
        }
        return cell;
    }

    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            return [self switchCellWithTitle:@"Перехватывать потоки"
                                         tag:YumiSettingsSwitchMediaHook
                                          on:s.mediaHookEnabled];
        }
        return [self switchCellWithTitle:@"Автоматически играть HLS"
                                     tag:YumiSettingsSwitchAutoPlayer
                                      on:s.autoNativePlayer];
    }

    if (indexPath.section == 2) {
        return [self switchCellWithTitle:@"Блокировать рекламу"
                                     tag:YumiSettingsSwitchAdblock
                                      on:s.adblockEnabled];
    }

    if (indexPath.section == 3) {
        UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleDefault];
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Очистить кэш и cookies";
            cell.textLabel.textColor = [UIColor colorWithRed:0.85 green:0.22 blue:0.18 alpha:1];
        } else {
            cell.textLabel.text = @"Сбросить все настройки";
            cell.textLabel.textColor = [UIColor colorWithRed:0.85 green:0.22 blue:0.18 alpha:1];
        }
        return cell;
    }

    UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleSubtitle];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Yumi Browser";
        NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Версия %@ · iOS 12+", version];
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"Плееры";
        cell.detailTextLabel.text = @"HLS/mp4 — нативно, с Referer и cookies";
    } else {
        cell.textLabel.text = @"Кинопоиск";
        cell.detailTextLabel.text = @"Платный контент защищён DRM и не играет на iOS 12";
        cell.detailTextLabel.numberOfLines = 2;
    }
    return cell;
}

#pragma mark - Actions

- (void)switchChanged:(UISwitch *)sw {
    YumiSettings *s = self.settings;
    if (sw.tag == YumiSettingsSwitchMediaHook) s.mediaHookEnabled = sw.isOn;
    else if (sw.tag == YumiSettingsSwitchAutoPlayer) s.autoNativePlayer = sw.isOn;
    else if (sw.tag == YumiSettingsSwitchAdblock) s.adblockEnabled = sw.isOn;
    [self.delegate settingsDidChange:self];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 0) {
        [self chooseUAMode];
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        [self chooseUserAgent];
    } else if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            [self.delegate settingsDidRequestClearData:self];
        } else {
            [self.delegate settingsDidRequestReset:self];
        }
    }
}

- (void)chooseUAMode {
    YumiSettings *s = self.settings;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Версия сайта"
                                                              message:@"Режим по умолчанию для новых сайтов"
                                                       preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Мобильная (Safari iOS 12)"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused UIAlertAction *action) {
        s.uaMode = YumiUAModeMobile;
        [self.tableView reloadData];
        [self.delegate settingsDidChange:self];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Полная (Safari macOS)"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused UIAlertAction *action) {
        s.uaMode = YumiUAModeDesktop;
        [self.tableView reloadData];
        [self.delegate settingsDidChange:self];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 120, 1, 1);
    [self presentViewController:a animated:YES completion:nil];
}

- (void)chooseUserAgent {
    YumiSettings *s = self.settings;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"User-Agent"
                                                              message:nil
                                                       preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"iOS Safari 12 (по умолчанию)"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused UIAlertAction *action) {
        s.uaMode = YumiUAModeMobile;
        [self.tableView reloadData];
        [self.delegate settingsDidChange:self];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"macOS Safari 16"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused UIAlertAction *action) {
        s.uaMode = YumiUAModeDesktop;
        [self.tableView reloadData];
        [self.delegate settingsDidChange:self];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Своя строка…"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused UIAlertAction *action) {
        [self editCustomUA];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 120, 1, 1);
    [self presentViewController:a animated:YES completion:nil];
}

- (void)editCustomUA {
    YumiSettings *s = self.settings;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Свой User-Agent"
                                                              message:@"Пустая строка вернёт стандартный"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = s.customUA;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Сохранить" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = a.textFields.firstObject.text ?: @"";
        // не даём самому себе перезаписать customUA дефолтом
        if (text.length) {
            [[NSUserDefaults standardUserDefaults] setObject:text forKey:@"YumiCustomUA"];
            s.uaMode = YumiUAModeCustom;
        } else {
            s.uaMode = YumiUAModeMobile;
        }
        [self.tableView reloadData];
        [self.delegate settingsDidChange:self];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
