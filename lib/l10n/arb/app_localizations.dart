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
  /// **'الترخيص'**
  String get license;

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
  /// **'تم إنشاء الحساب ولكن فشل تفعيل مفتاح الترخيص. يرجى التواصل مع الدعم الفني.'**
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
  /// **'حدث خطأ غير متوقع.'**
  String get unexpectedError;

  /// No description provided for @contactToRenewBtn.
  ///
  /// In ar, this message translates to:
  /// **'تواصل للتجديد'**
  String get contactToRenewBtn;

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

  /// No description provided for @walletLimits.
  ///
  /// In ar, this message translates to:
  /// **'حدود المحفظة'**
  String get walletLimits;

  /// No description provided for @dailyLimit.
  ///
  /// In ar, this message translates to:
  /// **'الحد اليومي (إرسال/استقبال)'**
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

  /// No description provided for @instapay.
  ///
  /// In ar, this message translates to:
  /// **'إنستاباي'**
  String get instapay;

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

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

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

  ///
  /// In ar, this message translates to:
  /// **'المستخدم غير مسجل الدخول.'**
  String get userNotAuthenticated;

  ///
  /// In ar, this message translates to:
  /// **'تم إضافة الرصيد بنجاح'**
  String get balanceAddedSuccessfully;

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
