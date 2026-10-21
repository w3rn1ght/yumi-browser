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
    self.title = @"РќР°СЃС‚СЂРѕР№РєРё";
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
        case 0: return 2;   // РІРµСЂСЃРёСЏ СЃР°Р№С‚Р°, UA
        case 1: return 2;   // РїРµСЂРµС…РІР°С‚, Р°РІС‚Рѕ-РїР»РµРµСЂ
        case 2: return 1;   // СЂРµРєР»Р°РјР°
        case 3: return 2;   // РѕС‡РёСЃС‚РёС‚СЊ РґР°РЅРЅС‹Рµ, СЃР±СЂРѕСЃ
        default: return 3;  // Рѕ РїСЂРёР»РѕР¶РµРЅРёРё
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"РЎР°Р№С‚С‹";
        case 1: return @"РџР»РµРµСЂС‹";
        case 2: return @"Р РµРєР»Р°РјР°";
        case 3: return @"Р”Р°РЅРЅС‹Рµ";
        default: return @"Рћ РїСЂРёР»РѕР¶РµРЅРёРё";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"Р•СЃР»Рё СЃР°Р№С‚ РєСЂРёРІРѕ РІС‹РіР»СЏРґРёС‚ РёР»Рё РїР°РґР°РµС‚ вЂ” РІРєР»СЋС‡Рё РїРѕР»РЅСѓСЋ РІРµСЂСЃРёСЋ. РќР°СЃС‚СЂРѕР№РєР° В«Р’РµСЂСЃРёСЏ СЃР°Р№С‚Р°В» Р·Р°РґР°С‘С‚ СЂРµР¶РёРј РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ, Р° РІ РјРµРЅСЋ Р±СЂР°СѓР·РµСЂР° РµС‘ РјРѕР¶РЅРѕ РїРµСЂРµРєР»СЋС‡РёС‚СЊ РґР»СЏ РєРѕРЅРєСЂРµС‚РЅРѕРіРѕ СЃР°Р№С‚Р°.";
        case 1:
            return @"РџРµСЂРµС…РІР°С‚ РЅР°С…РѕРґРёС‚ m3u8/mp4, РєРѕС‚РѕСЂС‹Рµ РёСЃРїРѕР»СЊР·СѓРµС‚ РїР»РµРµСЂ СЃР°Р№С‚Р°, Рё СѓРјРµРµС‚ РѕС‚РєСЂС‹С‚СЊ РёС… РІ СЃРёСЃС‚РµРјРЅРѕРј РїР»РµРµСЂРµ СЃ РЅСѓР¶РЅС‹РјРё Referer Рё cookies. РђРІС‚Рѕ-СЂРµР¶РёРј СЃСЂР°Р·Сѓ Р·Р°РїСѓСЃРєР°РµС‚ РїРµСЂРІС‹Р№ РЅР°Р№РґРµРЅРЅС‹Р№ HLS.";
        case 2:
            return @"Р‘Р»РѕРєРёСЂРѕРІРєР° СЂР°Р±РѕС‚Р°РµС‚ РЅР° СѓСЂРѕРІРЅРµ WebKit (РїСЂР°РІРёР»Р° + РєРѕСЃРјРµС‚РёРєР°). Р•СЃР»Рё СЃР°Р№С‚ СЃР»РѕРјР°Р»СЃСЏ вЂ” РІС‹РєР»СЋС‡Рё Рё РїРµСЂРµР·Р°РіСЂСѓР·Рё СЃС‚СЂР°РЅРёС†Сѓ.";
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
    YumiSettings *s = [self settings];

    if (indexPath.section == 0) {
        UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleValue1];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Р’РµСЂСЃРёСЏ СЃР°Р№С‚Р°";
            cell.detailTextLabel.text = (s.uaMode == YumiUAModeDesktop) ? @"РџРѕР»РЅР°СЏ" : @"РњРѕР±РёР»СЊРЅР°СЏ";
        } else {
            cell.textLabel.text = @"User-Agent";
            NSString *ua = s.customUA ?: @"";
            cell.detailTextLabel.text = (s.uaMode == YumiUAModeCustom)
                ? @"РЎРІРѕСЏ СЃС‚СЂРѕРєР°"
                : ([ua containsString:@"Macintosh"] ? @"macOS Safari" : @"iOS Safari 12");
        }
        return cell;
    }

    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            return [self switchCellWithTitle:@"РџРµСЂРµС…РІР°С‚С‹РІР°С‚СЊ РїРѕС‚РѕРєРё"
                                         tag:YumiSettingsSwitchMediaHook
                                          on:s.mediaHookEnabled];
        }
        return [self switchCellWithTitle:@"РђРІС‚РѕРјР°С‚РёС‡РµСЃРєРё РёРіСЂР°С‚СЊ HLS"
                                     tag:YumiSettingsSwitchAutoPlayer
                                      on:s.autoNativePlayer];
    }

    if (indexPath.section == 2) {
        return [self switchCellWithTitle:@"Р‘Р»РѕРєРёСЂРѕРІР°С‚СЊ СЂРµРєР»Р°РјСѓ"
                                     tag:YumiSettingsSwitchAdblock
                                      on:s.adblockEnabled];
    }

    if (indexPath.section == 3) {
        UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleDefault];
        if (indexPath.row == 0) {
            cell.textLabel.text = @"РћС‡РёСЃС‚РёС‚СЊ РєСЌС€ Рё cookies";
            cell.textLabel.textColor = [UIColor colorWithRed:0.85 green:0.22 blue:0.18 alpha:1];
        } else {
            cell.textLabel.text = @"РЎР±СЂРѕСЃРёС‚СЊ РІСЃРµ РЅР°СЃС‚СЂРѕР№РєРё";
            cell.textLabel.textColor = [UIColor colorWithRed:0.85 green:0.22 blue:0.18 alpha:1];
        }
        return cell;
    }

    UITableViewCell *cell = [self cellWithStyle:UITableViewCellStyleSubtitle];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Yumi Browser";
        NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Р’РµСЂСЃРёСЏ %@ В· iOS 12+", version];
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"РџР»РµРµСЂС‹";
        cell.detailTextLabel.text = @"HLS/mp4 вЂ” РЅР°С‚РёРІРЅРѕ, СЃ Referer Рё cookies";
    } else {
        cell.textLabel.text = @"РљРёРЅРѕРїРѕРёСЃРє";
        cell.detailTextLabel.text = @"РџР»Р°С‚РЅС‹Р№ РєРѕРЅС‚РµРЅС‚ Р·Р°С‰РёС‰С‘РЅ DRM Рё РЅРµ РёРіСЂР°РµС‚ РЅР° iOS 12";
        cell.detailTextLabel.numberOfLines = 2;
    }
    return cell;
}

#pragma mark - Actions

- (void)switchChanged:(UISwitch *)sw {
    YumiSettings *s = [self settings];
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
    YumiSettings *s = [self settings];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Р’РµСЂСЃРёСЏ СЃР°Р№С‚Р°"
                                                              message:@"Р РµР¶РёРј РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ РґР»СЏ РЅРѕРІС‹С… СЃР°Р№С‚РѕРІ"
                                                       preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"РњРѕР±РёР»СЊРЅР°СЏ (Safari iOS 12)"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused UIAlertAction *action) {
        s.uaMode = YumiUAModeMobile;
        [self.tableView reloadData];
        [self.delegate settingsDidChange:self];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"РџРѕР»РЅР°СЏ (Safari macOS)"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused UIAlertAction *action) {
        s.uaMode = YumiUAModeDesktop;
        [self.tableView reloadData];
        [self.delegate settingsDidChange:self];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"РћС‚РјРµРЅР°" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 120, 1, 1);
    [self presentViewController:a animated:YES completion:nil];
}

- (void)chooseUserAgent {
    YumiSettings *s = [self settings];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"User-Agent"
                                                              message:nil
                                                       preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"iOS Safari 12 (РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ)"
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
    [a addAction:[UIAlertAction actionWithTitle:@"РЎРІРѕСЏ СЃС‚СЂРѕРєР°вЂ¦"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused UIAlertAction *action) {
        [self editCustomUA];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"РћС‚РјРµРЅР°" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 120, 1, 1);
    [self presentViewController:a animated:YES completion:nil];
}

- (void)editCustomUA {
    YumiSettings *s = [self settings];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"РЎРІРѕР№ User-Agent"
                                                              message:@"РџСѓСЃС‚Р°СЏ СЃС‚СЂРѕРєР° РІРµСЂРЅС‘С‚ СЃС‚Р°РЅРґР°СЂС‚РЅС‹Р№"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = s.customUA;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"РЎРѕС…СЂР°РЅРёС‚СЊ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = a.textFields.firstObject.text ?: @"";
        // РЅРµ РґР°С‘Рј СЃР°РјРѕРјСѓ СЃРµР±Рµ РїРµСЂРµР·Р°РїРёСЃР°С‚СЊ customUA РґРµС„РѕР»С‚РѕРј
        if (text.length) {
            [[NSUserDefaults standardUserDefaults] setObject:text forKey:@"YumiCustomUA"];
            s.uaMode = YumiUAModeCustom;
        } else {
            s.uaMode = YumiUAModeMobile;
        }
        [self.tableView reloadData];
        [self.delegate settingsDidChange:self];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"РћС‚РјРµРЅР°" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end

