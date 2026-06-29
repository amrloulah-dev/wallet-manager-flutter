import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'arb/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @contactUs.
  ///
  /// In ar, this message translates to:
  /// **'تواصل معنا'**
  String get contactUs;

  /// No description provided for @whatsapp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get whatsapp;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @whatsappMessageRenew.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، أريد تجديد ترخيص تطبيق Wallet Manager'**
  String get whatsappMessageRenew;

  /// No description provided for @emailSubjectRenew.
  ///
  /// In ar, this message translates to:
  /// **'تجديد ترخيص Wallet Manager'**
  String get emailSubjectRenew;

  /// No description provided for @emailBodyRenew.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً،\nأريد تجديد ترخيص تطبيق Wallet Manager.'**
  String get emailBodyRenew;

  /// No description provided for @errorOpenWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن فتح واتساب'**
  String get errorOpenWhatsapp;

  /// No description provided for @errorOpenEmail.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن فتح تطبيق البريد الإلكتروني'**
  String get errorOpenEmail;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @accountInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات الحساب'**
  String get accountInfo;

  /// No description provided for @user.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم'**
  String get user;

  /// No description provided for @noEmail.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد بريد إلكتروني'**
  String get noEmail;

  /// No description provided for @owner.
  ///
  /// In ar, this message translates to:
  /// **'مالك'**
  String get owner;

  /// No description provided for @employee.
  ///
  /// In ar, this message translates to:
  /// **'موظف'**
  String get employee;

  /// No description provided for @storeName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المتجر'**
  String get storeName;

  /// No description provided for @creationDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإنشاء'**
  String get creationDate;

  /// No description provided for @licenseInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات الترخيص'**
  String get licenseInfo;

  /// No description provided for @expired.
  ///
  /// In ar, this message translates to:
  /// **'منتهي'**
  String get expired;

  /// No description provided for @active.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get active;

  /// No description provided for @licenseKey.
  ///
  /// In ar, this message translates to:
  /// **'مفتاح الترخيص'**
  String get licenseKey;

  /// No description provided for @expiryDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء'**
  String get expiryDate;

  /// No description provided for @daysRemaining.
  ///
  /// In ar, this message translates to:
  /// **'الأيام المتبقية'**
  String get daysRemaining;

  /// No description provided for @day.
  ///
  /// In ar, this message translates to:
  /// **'يوم'**
  String get day;

  /// No description provided for @contactToRenew.
  ///
  /// In ar, this message translates to:
  /// **'تواصل معنا لتجديد الترخيص'**
  String get contactToRenew;

  /// No description provided for @appSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات التطبيق'**
  String get appSettings;

  /// No description provided for @theme.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get theme;

  /// No description provided for @license.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراكات'**
  String get license;

  /// No description provided for @subscriptionPlans.
  ///
  /// In ar, this message translates to:
  /// **'باقات الاشتراك'**
  String get subscriptionPlans;

  /// No description provided for @notAvailable.
  ///
  /// In ar, this message translates to:
  /// **'غير متوفر'**
  String get notAvailable;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @logoutConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تريد تسجيل الخروج؟'**
  String get logoutConfirmation;

  /// No description provided for @exit.
  ///
  /// In ar, this message translates to:
  /// **'خروج'**
  String get exit;

  /// No description provided for @logoutFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل الخروج'**
  String get logoutFailed;

  /// No description provided for @chooseTheme.
  ///
  /// In ar, this message translates to:
  /// **'اختر المظهر'**
  String get chooseTheme;

  /// No description provided for @light.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In ar, this message translates to:
  /// **'غامق'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In ar, this message translates to:
  /// **'حسب النظام'**
  String get system;

  /// No description provided for @appDescription.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق لإدارة محافظك المالية بكل سهولة وأمان.'**
  String get appDescription;

  /// No description provided for @error.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get error;

  /// No description provided for @pageNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الصفحة المطلوبة غير موجودة.'**
  String get pageNotFound;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'الرجوع'**
  String get back;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @chooseLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اختر اللغة'**
  String get chooseLanguage;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @walletManager.
  ///
  /// In ar, this message translates to:
  /// **'Wallet Manager'**
  String get walletManager;

  /// No description provided for @manageWallets.
  ///
  /// In ar, this message translates to:
  /// **'إدارة المحافظ'**
  String get manageWallets;

  /// No description provided for @loginWithGoogle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول عبر جوجل'**
  String get loginWithGoogle;

  /// No description provided for @noAccountLinked.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب مرتبط بهذا البريد. يرجى إكمال التسجيل.'**
  String get noAccountLinked;

  /// No description provided for @licenseKeyError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ: مفتاح الترخيص غير متوفر. يرجى الرجوع والتحقق منه.'**
  String get licenseKeyError;

  /// No description provided for @activationFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التفعيل'**
  String get activationFailed;

  /// No description provided for @loginSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الدخول بنجاح!'**
  String get loginSuccess;

  /// No description provided for @createAccount.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب جديد'**
  String get createAccount;

  /// No description provided for @step1StoreInfo.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 1: معلومات المحل'**
  String get step1StoreInfo;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @or.
  ///
  /// In ar, this message translates to:
  /// **'أو'**
  String get or;

  /// No description provided for @haveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟ تسجيل الدخول'**
  String get haveAccount;

  /// No description provided for @noAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟ إنشاء حساب جديد'**
  String get noAccount;

  /// No description provided for @loginAsEmployee.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول كموظف'**
  String get loginAsEmployee;

  /// No description provided for @step2LicenseKey.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 2: مفتاح الترخيص'**
  String get step2LicenseKey;

  /// No description provided for @getLicenseKey.
  ///
  /// In ar, this message translates to:
  /// **'للحصول على مفتاح الترخيص'**
  String get getLicenseKey;

  /// No description provided for @contactUsAt.
  ///
  /// In ar, this message translates to:
  /// **'تواصل معنا على:'**
  String get contactUsAt;

  /// No description provided for @enterLicenseKey.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مفتاح الترخيص المكون من 21 حرف'**
  String get enterLicenseKey;

  /// No description provided for @verifiedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم التحقق بنجاح!'**
  String get verifiedSuccess;

  /// No description provided for @verifyKey.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من المفتاح'**
  String get verifyKey;

  /// No description provided for @step3Google.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة الأخيرة'**
  String get step3Google;

  /// No description provided for @linkGoogle.
  ///
  /// In ar, this message translates to:
  /// **'ربط حساب جوجل وإنشاء الحساب'**
  String get linkGoogle;

  /// No description provided for @createAccountGoogle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب جديد عبر جوجل'**
  String get createAccountGoogle;

  /// No description provided for @enterValidLicense.
  ///
  /// In ar, this message translates to:
  /// **'يجب إدخال مفتاح ترخيص صحيح'**
  String get enterValidLicense;

  /// No description provided for @invalidLicense.
  ///
  /// In ar, this message translates to:
  /// **'مفتاح الترخيص غير صحيح'**
  String get invalidLicense;

  /// No description provided for @licenseUsed.
  ///
  /// In ar, this message translates to:
  /// **'مفتاح الترخيص مستخدم بالفعل'**
  String get licenseUsed;

  /// No description provided for @verifySuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم التحقق من المفتاح بنجاح'**
  String get verifySuccess;

  /// No description provided for @errorVerifying.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء التحقق من المفتاح'**
  String get errorVerifying;

  /// No description provided for @whatsappMessageLicense.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، أريد الحصول على مفتاح ترخيص لتطبيق Wallet Manager'**
  String get whatsappMessageLicense;

  /// No description provided for @emailSubjectLicense.
  ///
  /// In ar, this message translates to:
  /// **'طلب مفتاح ترخيص'**
  String get emailSubjectLicense;

  /// No description provided for @emailBodyLicense.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً،\nأريد الحصول على مفتاح ترخيص لتطبيق Wallet Manager'**
  String get emailBodyLicense;

  /// No description provided for @storeNameHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم المحل الخاص بك'**
  String get storeNameHint;

  /// No description provided for @storePassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة سر المحل'**
  String get storePassword;

  /// No description provided for @storePasswordHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة سر مكونة من 6 أرقام'**
  String get storePasswordHint;

  /// No description provided for @confirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة السر'**
  String get confirmPassword;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In ar, this message translates to:
  /// **'أعد إدخال كلمة السر'**
  String get confirmPasswordHint;

  /// No description provided for @employeeLogin.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دخول الموظف'**
  String get employeeLogin;

  /// No description provided for @step1StorePassword.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 1: أدخل كلمة سر المتجر'**
  String get step1StorePassword;

  /// No description provided for @step2Pin.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 2: أدخل الرقم السري الخاص بك'**
  String get step2Pin;

  /// No description provided for @step3GoogleStore.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 3: سجل بحساب جوجل الخاص بالمتجر'**
  String get step3GoogleStore;

  /// No description provided for @storePasswordInvalid.
  ///
  /// In ar, this message translates to:
  /// **'كلمة سر المحل غير صحيحة'**
  String get storePasswordInvalid;

  /// No description provided for @pinInvalid.
  ///
  /// In ar, this message translates to:
  /// **'الرقم السري غير صحيح'**
  String get pinInvalid;

  /// No description provided for @welcome.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً'**
  String get welcome;

  /// No description provided for @wrongGoogleAccount.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تسجيل الدخول بحساب جوجل الخاص بالمتجر.'**
  String get wrongGoogleAccount;

  /// No description provided for @unexpectedError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع'**
  String get unexpectedError;

  /// No description provided for @loggingIn.
  ///
  /// In ar, this message translates to:
  /// **'جاري تسجيل الدخول...'**
  String get loggingIn;

  /// No description provided for @employeeLoginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دخول الموظفين'**
  String get employeeLoginSubtitle;

  /// No description provided for @enterStorePassword.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة مرور المتجر'**
  String get enterStorePassword;

  /// No description provided for @requiredField.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get requiredField;

  /// No description provided for @selectEmployee.
  ///
  /// In ar, this message translates to:
  /// **'اختر الموظف'**
  String get selectEmployee;

  /// No description provided for @selectEmployeeHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للاختيار'**
  String get selectEmployeeHint;

  /// No description provided for @pleaseSelectEmployee.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار الموظف'**
  String get pleaseSelectEmployee;

  /// No description provided for @pinLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم التعريف الشخصي (PIN)'**
  String get pinLabel;

  /// No description provided for @pinMustBe4Digits.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن يكون 4 أرقام'**
  String get pinMustBe4Digits;

  /// No description provided for @loginAction.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginAction;

  /// No description provided for @createStoreSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'قم بإنشاء متجرك الجديد وابدأ فترتك التجريبية'**
  String get createStoreSubtitle;

  /// No description provided for @ownerData.
  ///
  /// In ar, this message translates to:
  /// **'بيانات المالك'**
  String get ownerData;

  /// No description provided for @ownerNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم المالك'**
  String get ownerNameLabel;

  /// No description provided for @accountPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة مرور الحساب'**
  String get accountPassword;

  /// No description provided for @registerWithGoogle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل باستخدام Google'**
  String get registerWithGoogle;

  /// No description provided for @createAccountAction.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get createAccountAction;

  /// No description provided for @authError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في المصادقة'**
  String get authError;

  /// No description provided for @pleaseSelectTransactionType.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار نوع المعاملة'**
  String get pleaseSelectTransactionType;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @payDebt.
  ///
  /// In ar, this message translates to:
  /// **'تسديد الدين'**
  String get payDebt;

  /// No description provided for @areYouOwner.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت مالك المتجر؟ تسجيل الدخول من هنا'**
  String get areYouOwner;

  /// No description provided for @verify.
  ///
  /// In ar, this message translates to:
  /// **'تحقق'**
  String get verify;

  /// No description provided for @licenseExpired.
  ///
  /// In ar, this message translates to:
  /// **'الترخيص منتهي'**
  String get licenseExpired;

  /// No description provided for @licenseExpiredMessage.
  ///
  /// In ar, this message translates to:
  /// **'يجب تجديد الترخيص للمتابعة.'**
  String get licenseExpiredMessage;

  /// No description provided for @renewLicense.
  ///
  /// In ar, this message translates to:
  /// **'تجديد الترخيص'**
  String get renewLicense;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @goodMorning.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير 🌅'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In ar, this message translates to:
  /// **'مساء الخير ☀️'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In ar, this message translates to:
  /// **'مساء الخير 🌙'**
  String get goodEvening;

  /// No description provided for @home.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get home;

  /// No description provided for @newTransaction.
  ///
  /// In ar, this message translates to:
  /// **'معاملة جديدة'**
  String get newTransaction;

  /// No description provided for @wallets.
  ///
  /// In ar, this message translates to:
  /// **'المحافظ'**
  String get wallets;

  /// No description provided for @transactions.
  ///
  /// In ar, this message translates to:
  /// **'المعاملات'**
  String get transactions;

  /// No description provided for @debts.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get debts;

  /// No description provided for @statistics.
  ///
  /// In ar, this message translates to:
  /// **'الإحصائيات'**
  String get statistics;

  /// No description provided for @manageEmployees.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الموظفين'**
  String get manageEmployees;

  /// No description provided for @mySubscription.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكي'**
  String get mySubscription;

  /// No description provided for @errorLoadingStats.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تحميل الإحصائيات'**
  String get errorLoadingStats;

  /// No description provided for @totalWallets.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المحافظ'**
  String get totalWallets;

  /// No description provided for @totalTransactions.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المعاملات'**
  String get totalTransactions;

  /// No description provided for @totalCommission.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي العمولات'**
  String get totalCommission;

  /// No description provided for @openDebts.
  ///
  /// In ar, this message translates to:
  /// **'ديون مفتوحة'**
  String get openDebts;

  /// No description provided for @lastUpdated.
  ///
  /// In ar, this message translates to:
  /// **'آخر تحديث:'**
  String get lastUpdated;

  /// No description provided for @newWallet.
  ///
  /// In ar, this message translates to:
  /// **'محفظة جديدة'**
  String get newWallet;

  /// No description provided for @newDebt.
  ///
  /// In ar, this message translates to:
  /// **'دين جديد'**
  String get newDebt;

  /// No description provided for @viewWallets.
  ///
  /// In ar, this message translates to:
  /// **'عرض المحافظ'**
  String get viewWallets;

  /// No description provided for @viewDebts.
  ///
  /// In ar, this message translates to:
  /// **'عرض الديون'**
  String get viewDebts;

  /// No description provided for @quickActions.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات سريعة'**
  String get quickActions;

  /// No description provided for @alerts.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات'**
  String get alerts;

  /// No description provided for @dailyLimitAlert.
  ///
  /// In ar, this message translates to:
  /// **'على وشك الوصول للحد اليومي للإرسال.'**
  String get dailyLimitAlert;

  /// No description provided for @viewDetails.
  ///
  /// In ar, this message translates to:
  /// **'عرض التفاصيل'**
  String get viewDetails;

  /// No description provided for @openDebtsAlert.
  ///
  /// In ar, this message translates to:
  /// **'لديك {count} ديون مفتوحة.'**
  String openDebtsAlert(int count);

  /// No description provided for @recentTransactions.
  ///
  /// In ar, this message translates to:
  /// **'آخر المعاملات'**
  String get recentTransactions;

  /// No description provided for @viewAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get viewAll;

  /// No description provided for @noTransactionsToday.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد معاملات اليوم.'**
  String get noTransactionsToday;

  /// No description provided for @employeeDashboard.
  ///
  /// In ar, this message translates to:
  /// **'لوحة تحكم الموظف'**
  String get employeeDashboard;

  /// No description provided for @availableActions.
  ///
  /// In ar, this message translates to:
  /// **'الإجراءات المتاحة'**
  String get availableActions;

  /// No description provided for @yourRecentTransactions.
  ///
  /// In ar, this message translates to:
  /// **'آخر معاملاتك'**
  String get yourRecentTransactions;

  /// No description provided for @errorLoadingTransactions.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في تحميل المعاملات'**
  String get errorLoadingTransactions;

  /// No description provided for @noTransactionsByYou.
  ///
  /// In ar, this message translates to:
  /// **'لم تقم بأي معاملات اليوم.'**
  String get noTransactionsByYou;

  /// No description provided for @walletAlertMessage.
  ///
  /// In ar, this message translates to:
  /// **'محفظة {phone} على وشك الوصول للحد اليومي للإرسال.'**
  String walletAlertMessage(String phone);

  /// No description provided for @deleteWallet.
  ///
  /// In ar, this message translates to:
  /// **'حذف المحفظة'**
  String get deleteWallet;

  /// No description provided for @deleteWalletConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تريد حذف محفظة {phone}؟'**
  String deleteWalletConfirmation(String phone);

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @walletDeletedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف المحفظة بنجاح'**
  String get walletDeletedSuccessfully;

  /// No description provided for @walletDeletionFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل حذف المحفظة'**
  String get walletDeletionFailed;

  /// No description provided for @somethingWentWrong.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ ما'**
  String get somethingWentWrong;

  /// No description provided for @noWalletsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محافظ بعد'**
  String get noWalletsYet;

  /// No description provided for @startAddingWallets.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بإضافة محفظة جديدة لإدارة معاملاتك المالية.'**
  String get startAddingWallets;

  /// No description provided for @addWallet.
  ///
  /// In ar, this message translates to:
  /// **'إضافة محفظة'**
  String get addWallet;

  /// No description provided for @addBalance.
  ///
  /// In ar, this message translates to:
  /// **'إضافة رصيد'**
  String get addBalance;

  /// No description provided for @activeWallets.
  ///
  /// In ar, this message translates to:
  /// **'المحافظ النشطة'**
  String get activeWallets;

  /// No description provided for @searchByPhoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'ابحث برقم الموبايل...'**
  String get searchByPhoneNumber;

  /// No description provided for @editWallet.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المحفظة'**
  String get editWallet;

  /// No description provided for @addNewWallet.
  ///
  /// In ar, this message translates to:
  /// **'إضافة محفظة جديدة'**
  String get addNewWallet;

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الموبايل'**
  String get phoneNumber;

  /// No description provided for @phonePlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'01xxxxxxxxx'**
  String get phonePlaceholder;

  /// No description provided for @amountPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'0.00'**
  String get amountPlaceholder;

  /// No description provided for @initialBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد المبدئي'**
  String get initialBalance;

  /// No description provided for @walletType.
  ///
  /// In ar, this message translates to:
  /// **'نوع المحفظة'**
  String get walletType;

  /// No description provided for @selectWalletType.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع المحفظة'**
  String get selectWalletType;

  /// No description provided for @walletTypeRequired.
  ///
  /// In ar, this message translates to:
  /// **'نوع المحفظة مطلوب'**
  String get walletTypeRequired;

  /// No description provided for @walletStatus.
  ///
  /// In ar, this message translates to:
  /// **'حالة المحفظة'**
  String get walletStatus;

  /// No description provided for @newStatus.
  ///
  /// In ar, this message translates to:
  /// **'جديدة'**
  String get newStatus;

  /// No description provided for @oldStatus.
  ///
  /// In ar, this message translates to:
  /// **'قديمة'**
  String get oldStatus;

  /// No description provided for @registeredStore.
  ///
  /// In ar, this message translates to:
  /// **'محل مسجل'**
  String get registeredStore;

  /// No description provided for @walletLimits.
  ///
  /// In ar, this message translates to:
  /// **'حدود المحفظة'**
  String get walletLimits;

  /// No description provided for @dailyLimit.
  ///
  /// In ar, this message translates to:
  /// **'حد المعاملة الواحدة (إرسال/استقبال)'**
  String get dailyLimit;

  /// No description provided for @monthlyLimit.
  ///
  /// In ar, this message translates to:
  /// **'الحد الشهري (إرسال/استقبال)'**
  String get monthlyLimit;

  /// No description provided for @notesOptional.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات (اختياري)'**
  String get notesOptional;

  /// No description provided for @notesPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'أي تفاصيل إضافية عن المحفظة'**
  String get notesPlaceholder;

  /// No description provided for @saveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التعديلات'**
  String get saveChanges;

  /// No description provided for @addWalletAction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة المحفظة'**
  String get addWalletAction;

  /// No description provided for @pleaseSelectWalletType.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار نوع المحفظة'**
  String get pleaseSelectWalletType;

  /// No description provided for @pleaseSelectWalletStatus.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار حالة المحفظة'**
  String get pleaseSelectWalletStatus;

  /// No description provided for @authErrorRelogin.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في المصادقة، يرجى تسجيل الدخول مرة أخرى'**
  String get authErrorRelogin;

  /// No description provided for @walletUpdatedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم تعديل المحفظة بنجاح'**
  String get walletUpdatedSuccessfully;

  /// No description provided for @walletAddedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم إضافة المحفظة بنجاح'**
  String get walletAddedSuccessfully;

  /// No description provided for @vodafoneCash.
  ///
  /// In ar, this message translates to:
  /// **'فودافون كاش'**
  String get vodafoneCash;

  /// No description provided for @orangeCash.
  ///
  /// In ar, this message translates to:
  /// **'أورانج كاش'**
  String get orangeCash;

  /// No description provided for @etisalatCash.
  ///
  /// In ar, this message translates to:
  /// **'اتصالات كاش'**
  String get etisalatCash;

  /// No description provided for @wePay.
  ///
  /// In ar, this message translates to:
  /// **'WE Pay'**
  String get wePay;

  /// No description provided for @other.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get other;

  /// No description provided for @noWalletSelected.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تحديد محفظة.'**
  String get noWalletSelected;

  /// No description provided for @walletDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المحفظة'**
  String get walletDetails;

  /// No description provided for @loadingWalletData.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل بيانات المحفظة...'**
  String get loadingWalletData;

  /// No description provided for @errorLoadingData.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحميل البيانات.'**
  String get errorLoadingData;

  /// No description provided for @walletNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على المحفظة المطلوبة.'**
  String get walletNotFound;

  /// No description provided for @sendLimits.
  ///
  /// In ar, this message translates to:
  /// **'حدود الإرسال'**
  String get sendLimits;

  /// No description provided for @receiveLimits.
  ///
  /// In ar, this message translates to:
  /// **'حدود الاستقبال'**
  String get receiveLimits;

  /// No description provided for @currentBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الحالي'**
  String get currentBalance;

  /// No description provided for @addedDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإضافة'**
  String get addedDate;

  /// No description provided for @notes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get notes;

  /// No description provided for @dailyLimitSimple.
  ///
  /// In ar, this message translates to:
  /// **'الحد اليومي'**
  String get dailyLimitSimple;

  /// No description provided for @monthlyLimitSimple.
  ///
  /// In ar, this message translates to:
  /// **'الحد الشهري'**
  String get monthlyLimitSimple;

  /// No description provided for @sendLimitReachedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم الوصول للحد الأقصى للإرسال. لا يمكن إرسال مبالغ جديدة اليوم/هذا الشهر.'**
  String get sendLimitReachedMessage;

  /// No description provided for @receiveLimitReachedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم الوصول للحد الأقصى للاستقبال. لا يمكن استقبال مبالغ جديدة اليوم/هذا الشهر.'**
  String get receiveLimitReachedMessage;

  /// No description provided for @confirmDeletion.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحذف'**
  String get confirmDeletion;

  /// No description provided for @deleteWalletConfirmationDetailed.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تريد حذف محفظة \"{phone}\"؟\n\nسيتم إخفاء المحفظة من القائمة ولكن لن يتم حذف معاملاتها السابقة.'**
  String deleteWalletConfirmationDetailed(String phone);

  /// No description provided for @pleaseSelectWalletFirst.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار محفظة أولاً'**
  String get pleaseSelectWalletFirst;

  /// No description provided for @userNotAuthenticated.
  ///
  /// In ar, this message translates to:
  /// **'المستخدم غير مسجل الدخول.'**
  String get userNotAuthenticated;

  /// No description provided for @balanceAddedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم إضافة الرصيد بنجاح'**
  String get balanceAddedSuccessfully;

  /// No description provided for @failedToAddBalance.
  ///
  /// In ar, this message translates to:
  /// **'فشل في إضافة الرصيد'**
  String get failedToAddBalance;

  /// No description provided for @addBalanceToWallet.
  ///
  /// In ar, this message translates to:
  /// **'إضافة رصيد لمحفظة'**
  String get addBalanceToWallet;

  /// No description provided for @noWalletsAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محافظ متاحة.'**
  String get noWalletsAvailable;

  /// No description provided for @selectWallet.
  ///
  /// In ar, this message translates to:
  /// **'اختر المحفظة'**
  String get selectWallet;

  /// No description provided for @selectWalletToAddBalance.
  ///
  /// In ar, this message translates to:
  /// **'اختر المحفظة التي تريد إضافة رصيد لها'**
  String get selectWalletToAddBalance;

  /// No description provided for @pleaseSelectWallet.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار محفظة'**
  String get pleaseSelectWallet;

  /// No description provided for @selectedWalletDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المحفظة المحددة'**
  String get selectedWalletDetails;

  /// No description provided for @currentBalanceLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الحالي:'**
  String get currentBalanceLabel;

  /// No description provided for @amountToAdd.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المراد إضافته'**
  String get amountToAdd;

  /// No description provided for @addBalanceAction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة الرصيد'**
  String get addBalanceAction;

  /// No description provided for @transactionFees.
  ///
  /// In ar, this message translates to:
  /// **'رسوم المعاملة'**
  String get transactionFees;

  /// No description provided for @totalDeduction.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الخصم'**
  String get totalDeduction;

  /// No description provided for @calculatingFees.
  ///
  /// In ar, this message translates to:
  /// **'جاري حساب الرسوم...'**
  String get calculatingFees;

  /// No description provided for @accessDenied.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الوصول'**
  String get accessDenied;

  /// No description provided for @frozen.
  ///
  /// In ar, this message translates to:
  /// **'مُجمد'**
  String get frozen;

  /// No description provided for @sendDaily.
  ///
  /// In ar, this message translates to:
  /// **'إرسال يومي'**
  String get sendDaily;

  /// No description provided for @receiveDaily.
  ///
  /// In ar, this message translates to:
  /// **'استقبال يومي'**
  String get receiveDaily;

  /// No description provided for @debt.
  ///
  /// In ar, this message translates to:
  /// **'دين'**
  String get debt;

  /// No description provided for @amountDue.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المستحق:'**
  String get amountDue;

  /// No description provided for @deleteDebt.
  ///
  /// In ar, this message translates to:
  /// **'حذف الدين'**
  String get deleteDebt;

  /// No description provided for @deleteDebtConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف هذا الدين؟ لا يمكن التراجع عن هذا الإجراء.'**
  String get deleteDebtConfirmation;

  /// No description provided for @dailySummary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص اليوم'**
  String get dailySummary;

  /// No description provided for @sendAmount.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ الإرسال'**
  String get sendAmount;

  /// No description provided for @receiveAmount.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ الاستقبال'**
  String get receiveAmount;

  /// No description provided for @transactionType.
  ///
  /// In ar, this message translates to:
  /// **'نوع المعاملة'**
  String get transactionType;

  /// No description provided for @amount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get amount;

  /// No description provided for @commission.
  ///
  /// In ar, this message translates to:
  /// **'العمولة'**
  String get commission;

  /// No description provided for @loadingDetails.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل التفاصيل...'**
  String get loadingDetails;

  /// No description provided for @transactionNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العور على المعاملة'**
  String get transactionNotFound;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @totalAmount.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المبلغ'**
  String get totalAmount;

  /// No description provided for @totalCommissionLabel.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي العمولة'**
  String get totalCommissionLabel;

  /// No description provided for @lastTransaction.
  ///
  /// In ar, this message translates to:
  /// **'آخر معاملة'**
  String get lastTransaction;

  /// No description provided for @debtSummary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الديون'**
  String get debtSummary;

  /// No description provided for @totalDebts.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الديون'**
  String get totalDebts;

  /// No description provided for @paidDebts.
  ///
  /// In ar, this message translates to:
  /// **'ديون مسددة'**
  String get paidDebts;

  /// No description provided for @totalPaidAmount.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المبلغ المسدد'**
  String get totalPaidAmount;

  /// No description provided for @generalStats.
  ///
  /// In ar, this message translates to:
  /// **'الإحصائيات العامة'**
  String get generalStats;

  /// No description provided for @startDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ البداية'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ النهاية'**
  String get endDate;

  /// No description provided for @applyFilter.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق الفلتر'**
  String get applyFilter;

  /// No description provided for @clearFilter.
  ///
  /// In ar, this message translates to:
  /// **'مسح الفلتر'**
  String get clearFilter;

  /// No description provided for @filterDateError.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ النهاية لا يمكن أن يكون قبل تاريخ البداية'**
  String get filterDateError;

  /// No description provided for @noDataInRange.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات في هذا النطاق الزمني.'**
  String get noDataInRange;

  /// No description provided for @noStatsToShow.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إحصائيات لعرضها.'**
  String get noStatsToShow;

  /// No description provided for @balance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get balance;

  /// No description provided for @totalWalletBalance.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الرصيد في المحافظ'**
  String get totalWalletBalance;

  /// No description provided for @sendTransactions.
  ///
  /// In ar, this message translates to:
  /// **'معاملات الإرسال'**
  String get sendTransactions;

  /// No description provided for @receiveTransactions.
  ///
  /// In ar, this message translates to:
  /// **'معاملات الاستقبال'**
  String get receiveTransactions;

  /// No description provided for @amounts.
  ///
  /// In ar, this message translates to:
  /// **'المبالغ'**
  String get amounts;

  /// No description provided for @totalAmountCombined.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ الإجمالي'**
  String get totalAmountCombined;

  /// No description provided for @averageCommission.
  ///
  /// In ar, this message translates to:
  /// **'متوسط العمولة للمعاملة'**
  String get averageCommission;

  /// No description provided for @openDebtsLabel.
  ///
  /// In ar, this message translates to:
  /// **'الديون المفتوحة'**
  String get openDebtsLabel;

  /// No description provided for @paidDebtsLabel.
  ///
  /// In ar, this message translates to:
  /// **'الديون المسددة'**
  String get paidDebtsLabel;

  /// No description provided for @transactionDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المعاملة'**
  String get transactionDetails;

  /// No description provided for @total.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get total;

  /// No description provided for @customerDetails.
  ///
  /// In ar, this message translates to:
  /// **'بيانات العميل'**
  String get customerDetails;

  /// No description provided for @name.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get name;

  /// No description provided for @usedWallet.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة المستخدمة'**
  String get usedWallet;

  /// No description provided for @walletNotFoundDetails.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن العثور على تفاصيل المحفظة.'**
  String get walletNotFoundDetails;

  /// No description provided for @walletNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم المحفظة'**
  String get walletNumber;

  /// No description provided for @timeAndDate.
  ///
  /// In ar, this message translates to:
  /// **'الوقت والتاريخ'**
  String get timeAndDate;

  /// No description provided for @date.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get date;

  /// No description provided for @time.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get time;

  /// No description provided for @since.
  ///
  /// In ar, this message translates to:
  /// **'منذ'**
  String get since;

  /// No description provided for @transactionIsDebt.
  ///
  /// In ar, this message translates to:
  /// **'هذه المعاملة دين'**
  String get transactionIsDebt;

  /// No description provided for @debtWarningMessage.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم دفع المبلغ من قبل العميل وقت إنشاء المعاملة.'**
  String get debtWarningMessage;

  /// No description provided for @recordedNotes.
  ///
  /// In ar, this message translates to:
  /// **'الملاحظات المسجلة'**
  String get recordedNotes;

  /// No description provided for @transactionIdLabel.
  ///
  /// In ar, this message translates to:
  /// **'معرف المعاملة'**
  String get transactionIdLabel;

  /// No description provided for @createdBy.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاؤها بواسطة'**
  String get createdBy;

  /// No description provided for @unknown.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get unknown;

  /// No description provided for @ownerRoleSuffix.
  ///
  /// In ar, this message translates to:
  /// **' (المالك)'**
  String get ownerRoleSuffix;

  /// No description provided for @employeeRoleSuffix.
  ///
  /// In ar, this message translates to:
  /// **' (موظف)'**
  String get employeeRoleSuffix;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordMessage.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPasswordMessage;

  /// No description provided for @comingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get comingSoon;

  /// No description provided for @orLabel.
  ///
  /// In ar, this message translates to:
  /// **'أو'**
  String get orLabel;

  /// No description provided for @continueWithGoogle.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة باستخدام Google'**
  String get continueWithGoogle;

  /// No description provided for @enterStoreEmailMessage.
  ///
  /// In ar, this message translates to:
  /// **'أدخل البريد الإلكتروني للمتجر لتسجيل الدخول كموظف'**
  String get enterStoreEmailMessage;

  /// No description provided for @storeEmail.
  ///
  /// In ar, this message translates to:
  /// **'بريد المتجر الإلكتروني'**
  String get storeEmail;

  /// No description provided for @findStore.
  ///
  /// In ar, this message translates to:
  /// **'البحث عن المتجر'**
  String get findStore;

  /// No description provided for @noAccountYet.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟'**
  String get noAccountYet;

  /// No description provided for @createStoreNew.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء متجر جديد'**
  String get createStoreNew;

  /// No description provided for @todayTransactions.
  ///
  /// In ar, this message translates to:
  /// **'معاملات اليوم'**
  String get todayTransactions;

  /// No description provided for @all.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get all;

  /// No description provided for @errorLoadingTransactionsGeneric.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحميل المعاملات.'**
  String get errorLoadingTransactionsGeneric;

  /// No description provided for @noTransactionsTodayEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد معاملات اليوم'**
  String get noTransactionsTodayEmpty;

  /// No description provided for @noTransactionsWithFilter.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد معاملات بهذا الفلتر'**
  String get noTransactionsWithFilter;

  /// No description provided for @startAddingTransaction.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بإضافة معاملة جديدة'**
  String get startAddingTransaction;

  /// No description provided for @transactionCreatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء المعاملة بنجاح'**
  String get transactionCreatedSuccess;

  /// No description provided for @transactionCreationFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إنشاء المعاملة'**
  String get transactionCreationFailed;

  /// No description provided for @ok.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get ok;

  /// No description provided for @noWalletsAvailableAddFirst.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محافظ متاحة. يرجى إضافة محفظة أولاً.'**
  String get noWalletsAvailableAddFirst;

  /// No description provided for @selectWalletForTransaction.
  ///
  /// In ar, this message translates to:
  /// **'اختر المحفظة لإجراء المعاملة'**
  String get selectWalletForTransaction;

  /// No description provided for @customerPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم موبايل العميل'**
  String get customerPhone;

  /// No description provided for @customerNameOptional.
  ///
  /// In ar, this message translates to:
  /// **'اسم العميل (اختياري)'**
  String get customerNameOptional;

  /// No description provided for @enterClientName.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم العميل'**
  String get enterClientName;

  /// No description provided for @amountAndCommission.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ والعمولة'**
  String get amountAndCommission;

  /// No description provided for @amountLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get amountLabel;

  /// No description provided for @commissionLabel.
  ///
  /// In ar, this message translates to:
  /// **'العمولة'**
  String get commissionLabel;

  /// No description provided for @invalidValue.
  ///
  /// In ar, this message translates to:
  /// **'قيمة غير صالحة'**
  String get invalidValue;

  /// No description provided for @totalLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get totalLabel;

  /// No description provided for @reviewWalletLimits.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة حدود المحفظة'**
  String get reviewWalletLimits;

  /// No description provided for @dailyLimitAfterTransaction.
  ///
  /// In ar, this message translates to:
  /// **'الحد اليومي (بعد المعاملة)'**
  String get dailyLimitAfterTransaction;

  /// No description provided for @monthlyLimitAfterTransaction.
  ///
  /// In ar, this message translates to:
  /// **'الحد الشهري (بعد المعاملة)'**
  String get monthlyLimitAfterTransaction;

  /// No description provided for @walletLimitWarning.
  ///
  /// In ar, this message translates to:
  /// **'تحذير: هذه المعاملة ستتجاوز الحد المسموح به للمحفظة.'**
  String get walletLimitWarning;

  /// No description provided for @additionalTransactionDetails.
  ///
  /// In ar, this message translates to:
  /// **'أي تفاصيل إضافية عن المعاملة'**
  String get additionalTransactionDetails;

  /// No description provided for @createTransactionButton.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء المعاملة'**
  String get createTransactionButton;

  /// No description provided for @transactionCreateFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إنشاء المعاملة'**
  String get transactionCreateFailed;

  /// No description provided for @errorTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get errorTitle;

  /// No description provided for @okButton.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get okButton;

  /// No description provided for @debtsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get debtsTitle;

  /// No description provided for @addDebt.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دين'**
  String get addDebt;

  /// No description provided for @settleDebt.
  ///
  /// In ar, this message translates to:
  /// **'تسديد الدين'**
  String get settleDebt;

  /// No description provided for @settleDebtConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تريد تسجيل هذا الدين كـ \"مسدد\"؟'**
  String get settleDebtConfirmation;

  /// No description provided for @confirmSettlement.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد التسديد'**
  String get confirmSettlement;

  /// No description provided for @userNotRegistered.
  ///
  /// In ar, this message translates to:
  /// **'خطأ: المستخدم غير مسجل'**
  String get userNotRegistered;

  /// No description provided for @debtSettlementFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسديد الدين'**
  String get debtSettlementFailed;

  /// No description provided for @debtSettledSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تسديد الدين بنجاح'**
  String get debtSettledSuccess;

  /// No description provided for @errorLoadingDebts.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحميل الديون.'**
  String get errorLoadingDebts;

  /// No description provided for @noDebtsRecorded.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ديون مسجلة'**
  String get noDebtsRecorded;

  /// No description provided for @debtsWillAppearHere.
  ///
  /// In ar, this message translates to:
  /// **'سيتم عرض الديون المفتوحة والمسددة هنا.'**
  String get debtsWillAppearHere;

  /// No description provided for @addNewDebt.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دين جديد'**
  String get addNewDebt;

  /// No description provided for @allWithCount.
  ///
  /// In ar, this message translates to:
  /// **'الكل ({count})'**
  String allWithCount(int count);

  /// No description provided for @openWithCount.
  ///
  /// In ar, this message translates to:
  /// **'مفتوح ({count})'**
  String openWithCount(int count);

  /// No description provided for @paidWithCount.
  ///
  /// In ar, this message translates to:
  /// **'مسدد ({count})'**
  String paidWithCount(int count);

  /// No description provided for @financialTransfers.
  ///
  /// In ar, this message translates to:
  /// **'تحويلات مالية'**
  String get financialTransfers;

  /// No description provided for @storeSales.
  ///
  /// In ar, this message translates to:
  /// **'مبيعات محل'**
  String get storeSales;

  /// No description provided for @addDebtTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دين جديد'**
  String get addDebtTitle;

  /// No description provided for @customerName.
  ///
  /// In ar, this message translates to:
  /// **'اسم العميل'**
  String get customerName;

  /// No description provided for @enterFullCustomerName.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم العميل بالكامل'**
  String get enterFullCustomerName;

  /// No description provided for @debtType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الدين'**
  String get debtType;

  /// No description provided for @walletTransaction.
  ///
  /// In ar, this message translates to:
  /// **'معاملة محفظة'**
  String get walletTransaction;

  /// No description provided for @walletTransactionSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'دين ناتج عن معاملة إرسال لم يتم دفعها'**
  String get walletTransactionSubtitle;

  /// No description provided for @storeSale.
  ///
  /// In ar, this message translates to:
  /// **'بيع من المحل'**
  String get storeSale;

  /// No description provided for @storeSaleSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'دين ناتج عن عملية بيع آجلة من المحل'**
  String get storeSaleSubtitle;

  /// No description provided for @amountDueTitle.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المستحق'**
  String get amountDueTitle;

  /// No description provided for @debtWillBeAdded.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إضافة هذا الدين إلى قائمة الديون المفتوحة.'**
  String get debtWillBeAdded;

  /// No description provided for @additionalDebtDetails.
  ///
  /// In ar, this message translates to:
  /// **'أي تفاصيل إضافية عن الدين'**
  String get additionalDebtDetails;

  /// No description provided for @addDebtAction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة الدين'**
  String get addDebtAction;

  /// No description provided for @debtAddedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إضافة الدين بنجاح'**
  String get debtAddedSuccess;

  /// No description provided for @employeePermissions.
  ///
  /// In ar, this message translates to:
  /// **'صلاحيات الموظف'**
  String get employeePermissions;

  /// No description provided for @defineEmployeeActions.
  ///
  /// In ar, this message translates to:
  /// **'حدد ما يمكن للموظف القيام به'**
  String get defineEmployeeActions;

  /// No description provided for @financialTransactionsSection.
  ///
  /// In ar, this message translates to:
  /// **'المعاملات المالية'**
  String get financialTransactionsSection;

  /// No description provided for @createNewTransaction.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء معاملة جديدة'**
  String get createNewTransaction;

  /// No description provided for @viewAllTransactions.
  ///
  /// In ar, this message translates to:
  /// **'عرض جميع المعاملات'**
  String get viewAllTransactions;

  /// No description provided for @debtsSection.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get debtsSection;

  /// No description provided for @viewDebtsList.
  ///
  /// In ar, this message translates to:
  /// **'عرض قائمة الديون'**
  String get viewDebtsList;

  /// No description provided for @addNewDebtPermission.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دين جديد'**
  String get addNewDebtPermission;

  /// No description provided for @collectDebt.
  ///
  /// In ar, this message translates to:
  /// **'تحصيل دين (دفع جزئي/كلي)'**
  String get collectDebt;

  /// No description provided for @deleteDebtPermission.
  ///
  /// In ar, this message translates to:
  /// **'حذف دين'**
  String get deleteDebtPermission;

  /// No description provided for @walletsSection.
  ///
  /// In ar, this message translates to:
  /// **'المحافظ'**
  String get walletsSection;

  /// No description provided for @viewWalletsList.
  ///
  /// In ar, this message translates to:
  /// **'عرض قائمة المحافظ'**
  String get viewWalletsList;

  /// No description provided for @addNewWalletPermission.
  ///
  /// In ar, this message translates to:
  /// **'إضافة محفظة جديدة'**
  String get addNewWalletPermission;

  /// No description provided for @addBalanceToWalletPermission.
  ///
  /// In ar, this message translates to:
  /// **'شحن رصيد للمحفظة'**
  String get addBalanceToWalletPermission;

  /// No description provided for @editWalletData.
  ///
  /// In ar, this message translates to:
  /// **'تعديل بيانات المحفظة'**
  String get editWalletData;

  /// No description provided for @viewWalletBalance.
  ///
  /// In ar, this message translates to:
  /// **'عرض رصيد المحافظ'**
  String get viewWalletBalance;

  /// No description provided for @dashboardSection.
  ///
  /// In ar, this message translates to:
  /// **'لوحة التحكم'**
  String get dashboardSection;

  /// No description provided for @viewStatsCharts.
  ///
  /// In ar, this message translates to:
  /// **'عرض الإحصائيات (المخططات)'**
  String get viewStatsCharts;

  /// No description provided for @editDebt.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الدين'**
  String get editDebt;

  /// No description provided for @paymentMode.
  ///
  /// In ar, this message translates to:
  /// **'دفعة'**
  String get paymentMode;

  /// No description provided for @additionMode.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get additionMode;

  /// No description provided for @currentAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ الحالي'**
  String get currentAmount;

  /// No description provided for @pleaseEnterAmount.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخل المبلغ'**
  String get pleaseEnterAmount;

  /// No description provided for @invalidAmount.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ غير صحيح'**
  String get invalidAmount;

  /// No description provided for @amountMustBePositive.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ يجب أن يكون أكبر من صفر'**
  String get amountMustBePositive;

  /// No description provided for @paymentExceedsDebt.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المدفوع أكبر من الدين'**
  String get paymentExceedsDebt;

  /// No description provided for @newAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ الجديد:'**
  String get newAmount;

  /// No description provided for @saveEdit.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التعديل'**
  String get saveEdit;

  /// No description provided for @debtUpdatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الدين بنجاح'**
  String get debtUpdatedSuccess;

  /// No description provided for @debtUpdateFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحديث الدين'**
  String get debtUpdateFailed;

  /// No description provided for @retryAction.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retryAction;

  /// No description provided for @noPermissionWallets.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية لعرض المحافظ'**
  String get noPermissionWallets;

  /// No description provided for @noPermissionTransactions.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية لعرض المعاملات'**
  String get noPermissionTransactions;

  /// No description provided for @noPermissionDebts.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية لعرض الديون'**
  String get noPermissionDebts;

  /// No description provided for @noPermissionStats.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية لعرض الإحصائيات'**
  String get noPermissionStats;

  /// No description provided for @deactivateEmployeeAccount.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل حساب الموظف'**
  String get deactivateEmployeeAccount;

  /// No description provided for @deactivateEmployeeConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تريد تعطيل حساب {name}؟\n\nلن يتمكن من تسجيل الدخول بعد الآن.'**
  String deactivateEmployeeConfirmation(String name);

  /// No description provided for @deactivate.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل'**
  String get deactivate;

  /// No description provided for @employeeDeactivated.
  ///
  /// In ar, this message translates to:
  /// **'تم تعطيل حساب الموظف'**
  String get employeeDeactivated;

  /// No description provided for @deactivationFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تعطيل الحساب'**
  String get deactivationFailed;

  /// No description provided for @loadingEmployees.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل الموظفين...'**
  String get loadingEmployees;

  /// No description provided for @errorLoadingEmployees.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحميل الموظفين'**
  String get errorLoadingEmployees;

  /// No description provided for @noEmployees.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موظفين'**
  String get noEmployees;

  /// No description provided for @startAddingEmployees.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بإضافة موظف جديد لإدارة صلاحياته.'**
  String get startAddingEmployees;

  /// No description provided for @addEmployee.
  ///
  /// In ar, this message translates to:
  /// **'إضافة موظف'**
  String get addEmployee;

  /// No description provided for @permissionsUpdatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الصلاحيات بنجاح'**
  String get permissionsUpdatedSuccess;

  /// No description provided for @employeeDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الموظف'**
  String get employeeDetails;

  /// No description provided for @editPermissions.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الصلاحيات'**
  String get editPermissions;

  /// No description provided for @inactive.
  ///
  /// In ar, this message translates to:
  /// **'معطل'**
  String get inactive;

  /// No description provided for @employeeAddedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تمت إضافة الموظف بنجاح'**
  String get employeeAddedSuccess;

  /// No description provided for @addNewEmployee.
  ///
  /// In ar, this message translates to:
  /// **'إضافة موظف جديد'**
  String get addNewEmployee;

  /// No description provided for @currentEmployeesCount.
  ///
  /// In ar, this message translates to:
  /// **'الموظفين الحاليين: {current} / {max}'**
  String currentEmployeesCount(int current, int max);

  /// No description provided for @limitReached.
  ///
  /// In ar, this message translates to:
  /// **'تم الوصول للحد الأقصى'**
  String get limitReached;

  /// No description provided for @employeeLoginInfo.
  ///
  /// In ar, this message translates to:
  /// **'سيستخدم الموظف رقم الهاتف والرقم السري لتسجيل الدخول.'**
  String get employeeLoginInfo;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get fullName;

  /// No description provided for @enterEmployeeName.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم الموظف'**
  String get enterEmployeeName;

  /// No description provided for @employeePinTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرقم السري للموظف (PIN)'**
  String get employeePinTitle;

  /// No description provided for @pin.
  ///
  /// In ar, this message translates to:
  /// **'الرقم السري'**
  String get pin;

  /// No description provided for @fourDigits.
  ///
  /// In ar, this message translates to:
  /// **'4 أرقام'**
  String get fourDigits;

  /// No description provided for @confirmPin.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الرقم السري'**
  String get confirmPin;

  /// No description provided for @reenterPin.
  ///
  /// In ar, this message translates to:
  /// **'أعد إدخال الرقم السري'**
  String get reenterPin;

  /// No description provided for @pinsDoNotMatch.
  ///
  /// In ar, this message translates to:
  /// **'الرقمان غير متطابقان'**
  String get pinsDoNotMatch;

  /// No description provided for @subscriptionDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الاشتراك'**
  String get subscriptionDetails;

  /// No description provided for @currentUsage.
  ///
  /// In ar, this message translates to:
  /// **'الاستهلاك الحالي'**
  String get currentUsage;

  /// No description provided for @employeeAccounts.
  ///
  /// In ar, this message translates to:
  /// **'حسابات الموظفين'**
  String get employeeAccounts;

  /// No description provided for @upgradeSubscription.
  ///
  /// In ar, this message translates to:
  /// **'ترقية الاشتراك'**
  String get upgradeSubscription;

  /// No description provided for @currentPlan.
  ///
  /// In ar, this message translates to:
  /// **'الباقة الحالية'**
  String get currentPlan;

  /// No description provided for @suspended.
  ///
  /// In ar, this message translates to:
  /// **'معلق'**
  String get suspended;

  /// No description provided for @freePlan.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get freePlan;

  /// No description provided for @proYearlyPlan.
  ///
  /// In ar, this message translates to:
  /// **'برو (سنوي)'**
  String get proYearlyPlan;

  /// No description provided for @lifetimeVipPlan.
  ///
  /// In ar, this message translates to:
  /// **'مدى الحياة VIP'**
  String get lifetimeVipPlan;

  /// No description provided for @trialPlan.
  ///
  /// In ar, this message translates to:
  /// **'تجريبي'**
  String get trialPlan;

  /// No description provided for @upgradeAccount.
  ///
  /// In ar, this message translates to:
  /// **'ترقية الحساب'**
  String get upgradeAccount;

  /// No description provided for @unlockStoreCapabilities.
  ///
  /// In ar, this message translates to:
  /// **'فتح إمكانيات متجرك'**
  String get unlockStoreCapabilities;

  /// No description provided for @paywallSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'توقف عن إدخال البيانات يدويا. قم بأتمتة التدفق النقدي الخاص بك بأمان مع الميزات المتقدمة.'**
  String get paywallSubtitle;

  /// No description provided for @proYearlyTitle.
  ///
  /// In ar, this message translates to:
  /// **'باقة برو السنوية'**
  String get proYearlyTitle;

  /// No description provided for @proYearlyPrice.
  ///
  /// In ar, this message translates to:
  /// **'1200 جنيه / سنة'**
  String get proYearlyPrice;

  /// No description provided for @proFeature1.
  ///
  /// In ar, this message translates to:
  /// **'قراءة المعاملات تلقائياً'**
  String get proFeature1;

  /// No description provided for @proFeature2.
  ///
  /// In ar, this message translates to:
  /// **'إدارة مرنة حتى 50 محفظة'**
  String get proFeature2;

  /// No description provided for @proFeature3.
  ///
  /// In ar, this message translates to:
  /// **'بناء فريق عمل حتى 20 موظف'**
  String get proFeature3;

  /// No description provided for @proFeature4.
  ///
  /// In ar, this message translates to:
  /// **'دعم فني مخصص'**
  String get proFeature4;

  /// No description provided for @lifetimeTitle.
  ///
  /// In ar, this message translates to:
  /// **'باقة مدى الحياة VIP'**
  String get lifetimeTitle;

  /// No description provided for @lifetimePrice.
  ///
  /// In ar, this message translates to:
  /// **'2500 جنيه فقط مرة واحدة'**
  String get lifetimePrice;

  /// No description provided for @lifetimeFeature1.
  ///
  /// In ar, this message translates to:
  /// **'قراءة المعاملات تلقائياً'**
  String get lifetimeFeature1;

  /// No description provided for @lifetimeFeature2.
  ///
  /// In ar, this message translates to:
  /// **'عدد لا نهائي من المحافظ'**
  String get lifetimeFeature2;

  /// No description provided for @lifetimeFeature3.
  ///
  /// In ar, this message translates to:
  /// **'عدد لا نهائي من الموظفين'**
  String get lifetimeFeature3;

  /// No description provided for @lifetimeFeature4.
  ///
  /// In ar, this message translates to:
  /// **'أولوية الدعم الفني VIP'**
  String get lifetimeFeature4;

  /// No description provided for @mostPopular.
  ///
  /// In ar, this message translates to:
  /// **'الأكثر طلباً'**
  String get mostPopular;

  /// No description provided for @remainingSeats.
  ///
  /// In ar, this message translates to:
  /// **'{count} مقاعد متبقية'**
  String remainingSeats(int count);

  /// No description provided for @soldOut.
  ///
  /// In ar, this message translates to:
  /// **'نفدت الكمية'**
  String get soldOut;

  /// No description provided for @subscribeNow.
  ///
  /// In ar, this message translates to:
  /// **'اشترك الآن'**
  String get subscribeNow;

  /// No description provided for @termsAgreement.
  ///
  /// In ar, this message translates to:
  /// **'بمتابعة العملية أنت توافق على شروط الخدمة وسياسة الخصوصية الخاصة بنا.'**
  String get termsAgreement;

  /// No description provided for @paymentDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الدفع'**
  String get paymentDetails;

  /// No description provided for @selectedPlan.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراك المختار: {plan}'**
  String selectedPlan(String plan);

  /// No description provided for @paymentMethod.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get paymentMethod;

  /// No description provided for @transferToNumber.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تحويل المبلغ إلى الرقم: 01091264053'**
  String get transferToNumber;

  /// No description provided for @transferToAccount.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تحويل المبلغ إلى الرقم: 01091264053'**
  String get transferToAccount;

  /// No description provided for @receiptNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف الذي تم التحويل منه'**
  String get receiptNumber;

  /// No description provided for @fieldRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get fieldRequired;

  /// No description provided for @subscriptionRequestSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلب الاشتراك بنجاح. يرجى الانتظار للمراجعة.'**
  String get subscriptionRequestSent;

  /// No description provided for @errorOccurred.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ:'**
  String get errorOccurred;

  /// No description provided for @lifetimePlan.
  ///
  /// In ar, this message translates to:
  /// **'مدى الحياة'**
  String get lifetimePlan;

  /// No description provided for @accountSuspended.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف حسابك'**
  String get accountSuspended;

  /// No description provided for @accountSuspendedMessage.
  ///
  /// In ar, this message translates to:
  /// **'لقد تم تعليق حسابك من قبل الإدارة. يرجى التواصل مع فريق الدعم الفني لحل هذه المشكلة واستعادة وصولك إلى النظام.'**
  String get accountSuspendedMessage;

  /// No description provided for @contactingSupportTeam.
  ///
  /// In ar, this message translates to:
  /// **'جاري الاتصال بالدعم الفني...'**
  String get contactingSupportTeam;

  /// No description provided for @contactSupport.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع الدعم الفني'**
  String get contactSupport;

  /// No description provided for @subscriptionActivatedMessage.
  ///
  /// In ar, this message translates to:
  /// **'لقد تم تفعيل اشتراكك بنجاح. يمكنك الآن الاستمتاع بكافة الميزات الاحترافية.'**
  String get subscriptionActivatedMessage;

  /// No description provided for @continueButton.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueButton;

  /// No description provided for @continueWithFreePlan.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة بالخطة المجانية'**
  String get continueWithFreePlan;

  /// No description provided for @subscriptionUnderReview.
  ///
  /// In ar, this message translates to:
  /// **'يتم الآن مراجعة طلب الاشتراك الخاص بك.'**
  String get subscriptionUnderReview;

  /// No description provided for @subscriptionRejected.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض طلب الاشتراك الأخير. يرجى مراجعة الدعم.'**
  String get subscriptionRejected;

  /// No description provided for @subscriptionExpiredMessage.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية اشتراكك. قم بالترقية للاستمرار.'**
  String get subscriptionExpiredMessage;

  /// No description provided for @trialEndingSoon.
  ///
  /// In ar, this message translates to:
  /// **'باقي {daysLeft} يوم على انتهاء الفترة التجريبية. قم بالترقية الآن.'**
  String trialEndingSoon(int daysLeft);

  /// No description provided for @upgradeToFullVersionTitle.
  ///
  /// In ar, this message translates to:
  /// **'الترقية للنسخة الكاملة'**
  String get upgradeToFullVersionTitle;

  /// No description provided for @getActivationKey.
  ///
  /// In ar, this message translates to:
  /// **'للحصول على مفتاح التفعيل، يرجى التواصل معنا'**
  String get getActivationKey;

  /// No description provided for @contactViaWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'تواصل عبر واتساب'**
  String get contactViaWhatsapp;

  /// No description provided for @contactViaEmail.
  ///
  /// In ar, this message translates to:
  /// **'تواصل عبر البريد الإلكتروني'**
  String get contactViaEmail;

  /// No description provided for @activateSubscription.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل الاشتراك'**
  String get activateSubscription;

  /// No description provided for @activationKey.
  ///
  /// In ar, this message translates to:
  /// **'مفتاح التفعيل'**
  String get activationKey;

  /// No description provided for @enterActivationKeyHere.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مفتاح التفعيل هنا'**
  String get enterActivationKeyHere;

  /// No description provided for @pleaseEnterActivationKey.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال مفتاح التفعيل'**
  String get pleaseEnterActivationKey;

  /// No description provided for @activate.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get activate;

  /// No description provided for @subscriptionActivatedSuccessfully.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل الاشتراك بنجاح!'**
  String get subscriptionActivatedSuccessfully;

  /// No description provided for @fullVersionActivated.
  ///
  /// In ar, this message translates to:
  /// **'النسخة الكاملة مفعلة'**
  String get fullVersionActivated;

  /// No description provided for @daysRemainingCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} يوم'**
  String daysRemainingCount(int count);

  /// No description provided for @renewSubscription.
  ///
  /// In ar, this message translates to:
  /// **'تجديد الاشتراك'**
  String get renewSubscription;

  /// No description provided for @renewWhatsappMessage.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، أرغب في تجديد اشتراكي في تطبيق مدير المحفظة.'**
  String get renewWhatsappMessage;

  /// No description provided for @activationWhatsappMessage.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، أرغب في الحصول على مفتاح تفعيل لتطبيق مدير المحفظة.'**
  String get activationWhatsappMessage;

  /// No description provided for @failedOpenWhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'فشل فتح واتساب'**
  String get failedOpenWhatsApp;

  /// No description provided for @activationEmailSubject.
  ///
  /// In ar, this message translates to:
  /// **'طلب تفعيل النسخة الكاملة'**
  String get activationEmailSubject;

  /// No description provided for @activationEmailBody.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، أود الاستفسار عن كيفية الترقية للنسخة الكاملة.'**
  String get activationEmailBody;

  /// No description provided for @failedOpenEmail.
  ///
  /// In ar, this message translates to:
  /// **'فشل فتح البريد الإلكتروني'**
  String get failedOpenEmail;

  /// No description provided for @newTransactionTitle.
  ///
  /// In ar, this message translates to:
  /// **'معاملة جديدة'**
  String get newTransactionTitle;

  /// No description provided for @noWalletsAvailableMessage.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محافظ متاحة. يرجى إضافة محفظة أولاً.'**
  String get noWalletsAvailableMessage;

  /// No description provided for @selectWalletHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر المحفظة لإجراء المعاملة'**
  String get selectWalletHint;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @smsPermissionRequired.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب صلاحية رسائل SMS'**
  String get smsPermissionRequired;

  /// No description provided for @automationAndMessages.
  ///
  /// In ar, this message translates to:
  /// **'الأتمتة والرسائل'**
  String get automationAndMessages;

  /// No description provided for @enableAutoSmsReading.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل القراءة التلقائية للرسائل'**
  String get enableAutoSmsReading;

  /// No description provided for @autoDetectTransactions.
  ///
  /// In ar, this message translates to:
  /// **'اكتشاف المعاملات تلقائياً من الإشعارات'**
  String get autoDetectTransactions;

  /// No description provided for @linkSimToWallet.
  ///
  /// In ar, this message translates to:
  /// **'ربط الشريحة بالمحفظة'**
  String get linkSimToWallet;

  /// No description provided for @sim1Label.
  ///
  /// In ar, this message translates to:
  /// **'شريحة 1'**
  String get sim1Label;

  /// No description provided for @sim2Label.
  ///
  /// In ar, this message translates to:
  /// **'شريحة 2'**
  String get sim2Label;

  /// No description provided for @noSavedWallets.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محافظ محفوظة'**
  String get noSavedWallets;

  /// No description provided for @trialDaysRemainingLabel.
  ///
  /// In ar, this message translates to:
  /// **'أيام الفترة التجريبية المتبقية'**
  String get trialDaysRemainingLabel;

  /// No description provided for @logoutButton.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logoutButton;

  /// No description provided for @instaPay.
  ///
  /// In ar, this message translates to:
  /// **'انستا باي'**
  String get instaPay;

  /// No description provided for @confirmPayment.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الدفع'**
  String get confirmPayment;

  /// No description provided for @paymentConfirmedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد الدفع بنجاح'**
  String get paymentConfirmedSuccess;

  /// No description provided for @unavailable.
  ///
  /// In ar, this message translates to:
  /// **'غير متوفر'**
  String get unavailable;

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In ar, this message translates to:
  /// **'استلام'**
  String get receive;

  /// No description provided for @clientData.
  ///
  /// In ar, this message translates to:
  /// **'بيانات العميل'**
  String get clientData;

  /// No description provided for @clientPhoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get clientPhoneNumber;

  /// No description provided for @clientNameOptional.
  ///
  /// In ar, this message translates to:
  /// **'اسم العميل (اختياري)'**
  String get clientNameOptional;

  /// No description provided for @pressBackAgainToExit.
  ///
  /// In ar, this message translates to:
  /// **'اضغط مرة أخرى للخروج'**
  String get pressBackAgainToExit;

  /// No description provided for @ownerOnlyFeature.
  ///
  /// In ar, this message translates to:
  /// **'هذه الميزة للمالك فقط'**
  String get ownerOnlyFeature;

  /// No description provided for @expiryDateValue.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء: {date}'**
  String expiryDateValue(String date);

  /// No description provided for @subscriptionExpiredRenew.
  ///
  /// In ar, this message translates to:
  /// **'انتهى اشتراكك. الرجاء التجديد.'**
  String get subscriptionExpiredRenew;

  /// No description provided for @hide.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء'**
  String get hide;

  /// No description provided for @addEmployeeAction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة موظف'**
  String get addEmployeeAction;

  /// No description provided for @dateAdded.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإضافة'**
  String get dateAdded;

  /// No description provided for @manageEmployeesTitle.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الموظفين'**
  String get manageEmployeesTitle;

  /// No description provided for @activeEmployees.
  ///
  /// In ar, this message translates to:
  /// **'الموظفين النشطين'**
  String get activeEmployees;

  /// No description provided for @inactiveEmployees.
  ///
  /// In ar, this message translates to:
  /// **'الموظفين غير النشطين'**
  String get inactiveEmployees;

  /// No description provided for @noPermissionCreateTransaction.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد صلاحية لإنشاء معاملة'**
  String get noPermissionCreateTransaction;

  /// No description provided for @noPermissionCreateWallet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد صلاحية لإنشاء محفظة'**
  String get noPermissionCreateWallet;

  /// No description provided for @noPermissionCreateDebt.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد صلاحية لإنشاء دين'**
  String get noPermissionCreateDebt;

  /// No description provided for @noPermissionViewStats.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد صلاحية لعرض الإحصائيات'**
  String get noPermissionViewStats;

  /// No description provided for @noPermissionViewTransactionDetails.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد صلاحية لعرض تفاصيل المعاملة'**
  String get noPermissionViewTransactionDetails;

  /// No description provided for @trialPeriod.
  ///
  /// In ar, this message translates to:
  /// **'فترة تجريبية'**
  String get trialPeriod;

  /// No description provided for @trialDaysRemaining.
  ///
  /// In ar, this message translates to:
  /// **'أيام الفترة التجريبية المتبقية'**
  String get trialDaysRemaining;

  /// No description provided for @upgradeFullVersion.
  ///
  /// In ar, this message translates to:
  /// **'ترقية للنسخة الكاملة'**
  String get upgradeFullVersion;

  /// No description provided for @openDebt.
  ///
  /// In ar, this message translates to:
  /// **'دين مفتوح'**
  String get openDebt;

  /// No description provided for @paidDebt.
  ///
  /// In ar, this message translates to:
  /// **'دين مدفوع'**
  String get paidDebt;

  /// No description provided for @deposit.
  ///
  /// In ar, this message translates to:
  /// **'إيداع'**
  String get deposit;

  /// No description provided for @paid.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع'**
  String get paid;

  /// No description provided for @transactionExceedsLimitWarning.
  ///
  /// In ar, this message translates to:
  /// **'تحذير: هذه المعاملة ستتجاوز الحد المسموح به.'**
  String get transactionExceedsLimitWarning;

  /// No description provided for @googleLoginError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في تسجيل الدخول بحساب جوجل'**
  String get googleLoginError;

  /// No description provided for @storeInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات المتجر'**
  String get storeInfo;

  /// No description provided for @pendingSubscriptionReview.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة الاشتراك قيد الانتظار'**
  String get pendingSubscriptionReview;

  /// No description provided for @rejectedSubscriptionRequest.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض طلب الاشتراك'**
  String get rejectedSubscriptionRequest;

  /// No description provided for @auth_error_account_not_found.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.'**
  String get auth_error_account_not_found;

  /// No description provided for @auth_error_invalid_email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني غير صحيح.'**
  String get auth_error_invalid_email;

  /// No description provided for @auth_error_too_many_requests.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة جداً. يرجى المحاولة لاحقاً.'**
  String get auth_error_too_many_requests;

  /// No description provided for @auth_error_invalid_credentials.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور أو رقم الجوال غير صحيح.'**
  String get auth_error_invalid_credentials;

  /// No description provided for @auth_error_session_expired.
  ///
  /// In ar, this message translates to:
  /// **'فشلت عملية المصادقة، يرجى تسجيل الدخول مجدداً.'**
  String get auth_error_session_expired;

  /// No description provided for @auth_error_store_not_found.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على المتجر المرتبط بهذا الموظف'**
  String get auth_error_store_not_found;

  /// No description provided for @auth_error_user_not_found.
  ///
  /// In ar, this message translates to:
  /// **'المستخدم غير موجود أو ليس مالكاً.'**
  String get auth_error_user_not_found;

  /// No description provided for @auth_error_email_already_in_use.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني مستخدم بالفعل.'**
  String get auth_error_email_already_in_use;

  /// No description provided for @auth_error_login_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل الدخول.'**
  String get auth_error_login_failed;

  /// No description provided for @auth_error_employee_login_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل دخول الموظف.'**
  String get auth_error_employee_login_failed;

  /// No description provided for @auth_error_store_lookup_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء البحث عن المتجر.'**
  String get auth_error_store_lookup_failed;

  /// No description provided for @auth_error_reset_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إرسال البريد الإلكتروني.'**
  String get auth_error_reset_failed;

  /// No description provided for @auth_error_unexpected.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع.'**
  String get auth_error_unexpected;

  /// No description provided for @auth_error_store_not_active.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد متجر نشط'**
  String get auth_error_store_not_active;

  /// No description provided for @auth_error_invalid_key.
  ///
  /// In ar, this message translates to:
  /// **'المفتاح غير صحيح'**
  String get auth_error_invalid_key;

  /// No description provided for @auth_error_key_already_used.
  ///
  /// In ar, this message translates to:
  /// **'المفتاح مستخدم من قبل'**
  String get auth_error_key_already_used;

  /// No description provided for @auth_error_logout_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تسجيل الخروج'**
  String get auth_error_logout_failed;

  /// No description provided for @auth_error_update_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحديث البيانات.'**
  String get auth_error_update_failed;

  /// No description provided for @auth_error_invalid_store_password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة سر المتجر غير صحيحة.'**
  String get auth_error_invalid_store_password;

  /// No description provided for @debt_error_fetch_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء جلب بيانات الدين'**
  String get debt_error_fetch_failed;

  /// No description provided for @debt_error_fetch_more_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل في جلب المزيد من الديون.'**
  String get debt_error_fetch_more_failed;

  /// No description provided for @debt_error_create_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إنشاء الدين'**
  String get debt_error_create_failed;

  /// No description provided for @debt_error_add_amount_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل في إضافة المبلغ إلى الدين.'**
  String get debt_error_add_amount_failed;

  /// No description provided for @debt_error_update_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحديث الدين'**
  String get debt_error_update_failed;

  /// No description provided for @debt_error_settle_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تسديد الدين.'**
  String get debt_error_settle_failed;

  /// No description provided for @debt_error_delete_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء حذف الدين'**
  String get debt_error_delete_failed;

  /// No description provided for @debt_error_auth_required.
  ///
  /// In ar, this message translates to:
  /// **'يجب تسجيل الدخول أولاً.'**
  String get debt_error_auth_required;

  /// No description provided for @employee_error_fetch_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل جلب الموظفين.'**
  String get employee_error_fetch_failed;

  /// No description provided for @employee_error_no_store.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تعيين المتجر'**
  String get employee_error_no_store;

  /// No description provided for @employee_error_limit_reached.
  ///
  /// In ar, this message translates to:
  /// **'تم الوصول للحد الأقصى للموظفين'**
  String get employee_error_limit_reached;

  /// No description provided for @employee_error_create_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إضافة الموظف'**
  String get employee_error_create_failed;

  /// No description provided for @employee_error_invalid_pin.
  ///
  /// In ar, this message translates to:
  /// **'الرقم السري يجب أن يكون 4 أرقام'**
  String get employee_error_invalid_pin;

  /// No description provided for @employee_error_wrong_pin.
  ///
  /// In ar, this message translates to:
  /// **'الرقم السري غير صحيح'**
  String get employee_error_wrong_pin;

  /// No description provided for @employee_error_account_frozen.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب مجمد بسبب تجاوز الحد المسموح في باقتك'**
  String get employee_error_account_frozen;

  /// No description provided for @employee_error_pin_check_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء التحقق من الرقم السري'**
  String get employee_error_pin_check_failed;

  /// No description provided for @employee_error_update_perms_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحديث الصلاحيات.'**
  String get employee_error_update_perms_failed;

  /// No description provided for @transaction_error_fetch_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء جلب بيانات المعاملة'**
  String get transaction_error_fetch_failed;

  /// No description provided for @transaction_error_fetch_more_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل في جلب المزيد من المعاملات.'**
  String get transaction_error_fetch_more_failed;

  /// No description provided for @transaction_error_details_fetch.
  ///
  /// In ar, this message translates to:
  /// **'فشل في جلب تفاصيل المعاملة.'**
  String get transaction_error_details_fetch;

  /// No description provided for @auth_operation_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشلت العملية.'**
  String get auth_operation_failed;

  /// No description provided for @wallet_error_fetch_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في جلب المحافظ.'**
  String get wallet_error_fetch_failed;

  /// No description provided for @wallet_error_fetch_more_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في جلب المزيد من المحافظ.'**
  String get wallet_error_fetch_more_failed;

  /// No description provided for @stats_error_summary_fetch.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في جلب ملخص الإحصائيات.'**
  String get stats_error_summary_fetch;

  /// No description provided for @stats_error_today_fetch.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في جلب إحصائيات اليوم.'**
  String get stats_error_today_fetch;

  /// No description provided for @stats_error_filtered_fetch.
  ///
  /// In ar, this message translates to:
  /// **'فشل جلب الإحصائيات المفلترة.'**
  String get stats_error_filtered_fetch;

  /// No description provided for @stats_error_init_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تهيئة الإحصائيات.'**
  String get stats_error_init_failed;

  /// No description provided for @wallet_error_create_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل في إنشاء المحفظة.'**
  String get wallet_error_create_failed;

  /// No description provided for @wallet_error_update_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تحديث المحفظة.'**
  String get wallet_error_update_failed;

  /// No description provided for @wallet_error_delete_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل في حذف المحفظة.'**
  String get wallet_error_delete_failed;

  /// No description provided for @wallet_error_balance_update_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تحديث الرصيد.'**
  String get wallet_error_balance_update_failed;

  /// No description provided for @wallet_error_balance_topup_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع أثناء شحن الرصيد.'**
  String get wallet_error_balance_topup_failed;

  /// No description provided for @wallet_error_limit_reached.
  ///
  /// In ar, this message translates to:
  /// **'تم الوصول للحد الأقصى للمحافظ.'**
  String get wallet_error_limit_reached;

  /// No description provided for @wallet_error_frozen.
  ///
  /// In ar, this message translates to:
  /// **'هذه المحفظة مجمدة بسبب تجاوز الحد المسموح في باقتك الحالية.'**
  String get wallet_error_frozen;

  /// No description provided for @wallet_error_subscription_unresolved.
  ///
  /// In ar, this message translates to:
  /// **'تعذر التحقق من حالة الاشتراك. يرجى المحاولة لاحقاً.'**
  String get wallet_error_subscription_unresolved;

  /// No description provided for @overlay_error_amount_limit_instapay.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ يتخطى الحد الأقصى للمعاملة الواحدة (70,000)'**
  String get overlay_error_amount_limit_instapay;

  /// No description provided for @overlay_error_amount_limit_telecom.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ يتخطى الحد الأقصى للمعاملة الواحدة (60,000)'**
  String get overlay_error_amount_limit_telecom;

  /// No description provided for @sendLink.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرابط'**
  String get sendLink;

  /// No description provided for @passwordResetEmailSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني.'**
  String get passwordResetEmailSent;

  /// No description provided for @weakPasswordException.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور ضعيفة جداً.'**
  String get weakPasswordException;

  /// No description provided for @contactToRenewBtn.
  ///
  /// In ar, this message translates to:
  /// **'تواصل للتجديد'**
  String get contactToRenewBtn;

  /// No description provided for @enterCustomerName.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم العميل'**
  String get enterCustomerName;

  /// No description provided for @createTransaction.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء معاملة'**
  String get createTransaction;

  /// No description provided for @continueBtn.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueBtn;

  /// No description provided for @overlayConnectionError.
  ///
  /// In ar, this message translates to:
  /// **'❌ خطأ في الاتصال'**
  String get overlayConnectionError;

  /// No description provided for @overlayCompleteFromApp.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إتمام المعاملة من التطبيق الأساسي.'**
  String get overlayCompleteFromApp;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @currencySymbol.
  ///
  /// In ar, this message translates to:
  /// **'ج'**
  String get currencySymbol;

  /// No description provided for @relativeJustNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get relativeJustNow;

  /// No description provided for @relativeMinutesAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منذ دقيقة} =2{منذ دقيقتين} few{منذ {count} دقائق} other{منذ {count} دقيقة}}'**
  String relativeMinutesAgo(int count);

  /// No description provided for @relativeHoursAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منذ ساعة} =2{منذ ساعتين} few{منذ {count} ساعات} other{منذ {count} ساعة}}'**
  String relativeHoursAgo(int count);

  /// No description provided for @relativeDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أمس} =2{منذ يومين} other{منذ {count} أيام}}'**
  String relativeDaysAgo(int count);

  /// No description provided for @relativeWeeksAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منذ أسبوع} =2{منذ أسبوعين} other{منذ {count} أسابيع}}'**
  String relativeWeeksAgo(int count);

  /// No description provided for @relativeMonthsAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منذ شهر} =2{منذ شهرين} other{منذ {count} أشهر}}'**
  String relativeMonthsAgo(int count);

  /// No description provided for @relativeYearsAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منذ سنة} =2{منذ سنتين} other{منذ {count} سنوات}}'**
  String relativeYearsAgo(int count);

  /// No description provided for @wallet_error_not_found.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة غير موجودة.'**
  String get wallet_error_not_found;

  /// No description provided for @wallet_error_inactive.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إجراء معاملة: المحفظة غير مفعلة أو تم حذفها.'**
  String get wallet_error_inactive;

  /// No description provided for @wallet_error_instapay_limit.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأقصى للمعاملة الواحدة لإنستاباي هو 70,000 جنيه.'**
  String get wallet_error_instapay_limit;

  /// No description provided for @wallet_error_telecom_limit.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأقصى للمعاملة الواحدة للمحافظ الإلكترونية هو 60,000 جنيه.'**
  String get wallet_error_telecom_limit;

  /// No description provided for @wallet_error_insufficient_balance.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المراد إرساله (مع العمولة) أكبر من الرصيد المتاح.'**
  String get wallet_error_insufficient_balance;

  /// No description provided for @wallet_error_instapay_daily_limit.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز الحد اليومي لمحفظة InstaPay (120,000 جنيه).'**
  String get wallet_error_instapay_daily_limit;

  /// No description provided for @wallet_error_daily_send_limit.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز الحد اليومي للإرسال لهذه المحفظة.'**
  String get wallet_error_daily_send_limit;

  /// No description provided for @wallet_error_monthly_send_limit.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز الحد الشهري للإرسال لهذه المحفظة.'**
  String get wallet_error_monthly_send_limit;

  /// No description provided for @wallet_error_daily_receive_limit.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز الحد اليومي للاستقبال لهذه المحفظة.'**
  String get wallet_error_daily_receive_limit;

  /// No description provided for @wallet_error_monthly_receive_limit.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز الحد الشهري للاستقبال لهذه المحفظة.'**
  String get wallet_error_monthly_receive_limit;

  /// No description provided for @wallet_error_transaction_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع أثناء حفظ المعاملة.'**
  String get wallet_error_transaction_failed;

  /// No description provided for @auth_error_google_sign_in.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل الدخول باستخدام جوجل.'**
  String get auth_error_google_sign_in;

  /// No description provided for @auth_error_sign_out_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل الخروج.'**
  String get auth_error_sign_out_failed;

  /// No description provided for @migration_error_recalculate_failed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إعادة حساب الإحصائيات.'**
  String get migration_error_recalculate_failed;

  /// No description provided for @migration_error_unexpected.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع أثناء إعادة حساب الإحصائيات.'**
  String get migration_error_unexpected;

  /// No description provided for @wallet_type_vodafone_cash.
  ///
  /// In ar, this message translates to:
  /// **'فودافون كاش'**
  String get wallet_type_vodafone_cash;

  /// No description provided for @wallet_type_insta_pay.
  ///
  /// In ar, this message translates to:
  /// **'إنستاباي'**
  String get wallet_type_insta_pay;

  /// No description provided for @wallet_type_orange_cash.
  ///
  /// In ar, this message translates to:
  /// **'أورانج كاش'**
  String get wallet_type_orange_cash;

  /// No description provided for @wallet_type_etisalat_cash.
  ///
  /// In ar, this message translates to:
  /// **'اتصالات كاش'**
  String get wallet_type_etisalat_cash;

  /// No description provided for @wallet_type_we_pay.
  ///
  /// In ar, this message translates to:
  /// **'وي باي'**
  String get wallet_type_we_pay;

  /// No description provided for @wallet_type_other.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get wallet_type_other;

  /// No description provided for @wallet_status_active.
  ///
  /// In ar, this message translates to:
  /// **'نشطة'**
  String get wallet_status_active;

  /// No description provided for @wallet_status_inactive.
  ///
  /// In ar, this message translates to:
  /// **'غير نشطة'**
  String get wallet_status_inactive;

  /// No description provided for @wallet_status_suspended.
  ///
  /// In ar, this message translates to:
  /// **'معلقة'**
  String get wallet_status_suspended;

  /// No description provided for @overlay_error_load_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحميل البيانات'**
  String get overlay_error_load_failed;

  /// No description provided for @overlay_error_submit_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تنفيذ المعاملة'**
  String get overlay_error_submit_failed;

  /// No description provided for @debt_error_payment_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء معالجة الدفعة'**
  String get debt_error_payment_failed;

  /// No description provided for @debt_error_partial_add_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إضافة دين جزئي'**
  String get debt_error_partial_add_failed;

  /// No description provided for @transaction_error_create_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إنشاء المعاملة'**
  String get transaction_error_create_failed;

  /// No description provided for @transaction_error_update_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحديث المعاملة'**
  String get transaction_error_update_failed;

  /// No description provided for @transaction_error_delete_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء حذف المعاملة'**
  String get transaction_error_delete_failed;

  /// No description provided for @wallet_error_status_update_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحديث حالة المحفظة'**
  String get wallet_error_status_update_failed;

  /// No description provided for @auth_error_must_login_first.
  ///
  /// In ar, this message translates to:
  /// **'يجب تسجيل الدخول أولاً'**
  String get auth_error_must_login_first;

  /// No description provided for @auth_error_store_already_exists.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب يمتلك متجرًا بالفعل'**
  String get auth_error_store_already_exists;

  /// No description provided for @auth_error_employee_fetch_failed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء جلب بيانات الموظف'**
  String get auth_error_employee_fetch_failed;

  /// No description provided for @error_unexpected.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع'**
  String get error_unexpected;

  /// No description provided for @subscriptionExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية اشتراكك!'**
  String get subscriptionExpired;

  /// No description provided for @subscriptionExpiresToday.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي اشتراكك اليوم!'**
  String get subscriptionExpiresToday;

  /// No description provided for @trialEndingSoonDays.
  ///
  /// In ar, this message translates to:
  /// **'متبقي {days} أيام على انتهاء الفترة التجريبية. قم بالترقية الآن!'**
  String trialEndingSoonDays(int days);

  /// No description provided for @proEndingSoonDays.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكك السنوي ينتهي خلال {days} أيام. جدد الآن!'**
  String proEndingSoonDays(int days);

  /// No description provided for @upgradeRequiredToEnableSms.
  ///
  /// In ar, this message translates to:
  /// **'هذه الميزة تتطلب ترقية الحساب'**
  String get upgradeRequiredToEnableSms;

  /// No description provided for @requestUpgradeFromOwner.
  ///
  /// In ar, this message translates to:
  /// **'برجاء طلب ترقية الباقة من مالك المتجر'**
  String get requestUpgradeFromOwner;

  /// No description provided for @employeeLoginBlockedSubscriptionExpired.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تسجيل الدخول كموظف لأن اشتراك المتجر منتهي.'**
  String get employeeLoginBlockedSubscriptionExpired;

  /// No description provided for @walletsLimitExceededFree.
  ///
  /// In ar, this message translates to:
  /// **'لقد وصلت للحد الأقصى من المحافظ (محفظتين). يرجى ترقية اشتراكك لإضافة المزيد.'**
  String get walletsLimitExceededFree;

  /// No description provided for @walletIsFrozen.
  ///
  /// In ar, this message translates to:
  /// **'هذه المحفظة مجمدة. يرجى ترقية الباقة لاستخدامها.'**
  String get walletIsFrozen;

  /// No description provided for @walletIsFrozenShort.
  ///
  /// In ar, this message translates to:
  /// **'(مجمدة)'**
  String get walletIsFrozenShort;

  /// No description provided for @refreshPlatformSettings.
  ///
  /// In ar, this message translates to:
  /// **'تحديث إعدادات المنصة'**
  String get refreshPlatformSettings;

  /// No description provided for @platformSettingsRefreshed.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث إعدادات المنصة بنجاح'**
  String get platformSettingsRefreshed;

  /// No description provided for @platformSettingsRefreshFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحديث إعدادات المنصة'**
  String get platformSettingsRefreshFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
