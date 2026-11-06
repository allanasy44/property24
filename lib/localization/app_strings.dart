import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings._(this._shona);

  final bool _shona;

  static AppStrings of(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return AppStrings._(languageCode == 'sn');
  }

  String get settings => _shona ? 'Zvirongwa' : 'Settings';
  String get account => _shona ? 'Akaunti' : 'Account';
  String get app => _shona ? 'App' : 'App';
  String get language => _shona ? 'Mutauro' : 'Language';
  String get darkMode => _shona ? 'Rima' : 'Dark Mode';
  String get accountInformation =>
      _shona ? 'Mashoko eakaunti' : 'Account Information';
  String get privacyPolicy => _shona ? 'Mutemo wekuvanzika' : 'Privacy Policy';
  String get myBookings => _shona ? 'Bhuku dzangu' : 'My Bookings';
  String get chooseLanguage => _shona
      ? 'Sarudza mutauro weapp.'
      : 'Choose the language for the app interface.';
  String get profile => _shona ? 'Nhoroondo' : 'Profile';
  String get name => _shona ? 'Zita' : 'Name';
  String get about => _shona ? 'Nezvangu' : 'About';
  String get username => _shona ? 'Zita rekushandisa' : 'Username';
  String get phoneNumber => _shona ? 'Nhamba yefoni' : 'Phone number';
  String get editPhoto => _shona ? 'Chinja mufananidzo' : 'Edit photo';
  String get saveChanges => _shona ? 'Chengetedza shanduko' : 'Save changes';
}
