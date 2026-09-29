import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @aboutBrand.
  ///
  /// In en, this message translates to:
  /// **'TradeHub Demo'**
  String get aboutBrand;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'TradeHub Demo is a demonstration marketplace that shows how retailers, wholesalers, and buyers can work together on one platform. You can discover products, place orders, negotiate bulk deals, and manage delivery from one app. All data in this environment is synthetic.'**
  String get aboutDescription;

  /// No description provided for @aboutFeatureCatalogue.
  ///
  /// In en, this message translates to:
  /// **'A sample catalogue across many product categories'**
  String get aboutFeatureCatalogue;

  /// No description provided for @aboutFeatureDealerSupport.
  ///
  /// In en, this message translates to:
  /// **'Dealer and bulk order support'**
  String get aboutFeatureDealerSupport;

  /// No description provided for @aboutFeatureDirectContact.
  ///
  /// In en, this message translates to:
  /// **'Direct contact with the business support team'**
  String get aboutFeatureDirectContact;

  /// No description provided for @aboutFeatureDispatch.
  ///
  /// In en, this message translates to:
  /// **'Sales and dispatch coordination'**
  String get aboutFeatureDispatch;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Distribution made simple'**
  String get aboutTagline;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About TradeHub Demo'**
  String get aboutTitle;

  /// No description provided for @aboutWhatYouCanDo.
  ///
  /// In en, this message translates to:
  /// **'What you can do'**
  String get aboutWhatYouCanDo;

  /// No description provided for @addProductAllowNegotiation.
  ///
  /// In en, this message translates to:
  /// **'Allow Price Negotiation'**
  String get addProductAllowNegotiation;

  /// No description provided for @addProductAllowNegotiationHint.
  ///
  /// In en, this message translates to:
  /// **'Buyers can send price proposals'**
  String get addProductAllowNegotiationHint;

  /// No description provided for @addProductBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get addProductBasicInfo;

  /// No description provided for @addProductCategoryHarvesters.
  ///
  /// In en, this message translates to:
  /// **'Harvesters'**
  String get addProductCategoryHarvesters;

  /// No description provided for @addProductCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get addProductCategoryLabel;

  /// No description provided for @addProductCategoryMills.
  ///
  /// In en, this message translates to:
  /// **'Mills'**
  String get addProductCategoryMills;

  /// No description provided for @addProductCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get addProductCategoryOther;

  /// No description provided for @addProductCategoryPumps.
  ///
  /// In en, this message translates to:
  /// **'Pumps'**
  String get addProductCategoryPumps;

  /// No description provided for @addProductCategorySprayers.
  ///
  /// In en, this message translates to:
  /// **'Sprayers'**
  String get addProductCategorySprayers;

  /// No description provided for @addProductCategoryTillers.
  ///
  /// In en, this message translates to:
  /// **'Tillers'**
  String get addProductCategoryTillers;

  /// No description provided for @addProductDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Enter product description'**
  String get addProductDescriptionHint;

  /// No description provided for @addProductDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get addProductDescriptionLabel;

  /// No description provided for @addProductEnginePowerHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 7HP'**
  String get addProductEnginePowerHint;

  /// No description provided for @addProductEnginePowerLabel.
  ///
  /// In en, this message translates to:
  /// **'Engine Power'**
  String get addProductEnginePowerLabel;

  /// No description provided for @addProductFuelTypeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Petrol'**
  String get addProductFuelTypeHint;

  /// No description provided for @addProductFuelTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fuel Type'**
  String get addProductFuelTypeLabel;

  /// No description provided for @addProductMinOrderQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum Order Qty'**
  String get addProductMinOrderQtyLabel;

  /// No description provided for @addProductNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter product name'**
  String get addProductNameHint;

  /// No description provided for @addProductNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get addProductNameLabel;

  /// No description provided for @addProductPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price (\$)'**
  String get addProductPriceLabel;

  /// No description provided for @addProductPricingStock.
  ///
  /// In en, this message translates to:
  /// **'Pricing & Stock'**
  String get addProductPricingStock;

  /// No description provided for @addProductPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish Product'**
  String get addProductPublish;

  /// No description provided for @addProductPublished.
  ///
  /// In en, this message translates to:
  /// **'Product published successfully!'**
  String get addProductPublished;

  /// No description provided for @addProductSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save Draft'**
  String get addProductSaveDraft;

  /// No description provided for @addProductSpecifications.
  ///
  /// In en, this message translates to:
  /// **'Specifications'**
  String get addProductSpecifications;

  /// No description provided for @addProductStockQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock Qty'**
  String get addProductStockQtyLabel;

  /// No description provided for @addProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Product'**
  String get addProductTitle;

  /// No description provided for @addProductUploadHint.
  ///
  /// In en, this message translates to:
  /// **'Add up to 5 images (JPG, PNG)'**
  String get addProductUploadHint;

  /// No description provided for @addProductUploadImages.
  ///
  /// In en, this message translates to:
  /// **'Upload Product Images'**
  String get addProductUploadImages;

  /// No description provided for @addProductWarrantyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 1 Year'**
  String get addProductWarrantyHint;

  /// No description provided for @addProductWarrantyLabel.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get addProductWarrantyLabel;

  /// No description provided for @addProductWeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 50kg'**
  String get addProductWeightHint;

  /// No description provided for @addProductWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get addProductWeightLabel;

  /// No description provided for @addProductWholesaleSettings.
  ///
  /// In en, this message translates to:
  /// **'Wholesale Settings'**
  String get addProductWholesaleSettings;

  /// No description provided for @addressAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addressAdd;

  /// No description provided for @addressBanner.
  ///
  /// In en, this message translates to:
  /// **'Keep two delivery slots ready: Primary and Secondary.'**
  String get addressBanner;

  /// No description provided for @addressDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get addressDefaultBadge;

  /// No description provided for @addressDefaultForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Default for delivery'**
  String get addressDefaultForDelivery;

  /// No description provided for @addressEmpty.
  ///
  /// In en, this message translates to:
  /// **'No address saved yet. Add this delivery slot now.'**
  String get addressEmpty;

  /// No description provided for @addressPrimarySaved.
  ///
  /// In en, this message translates to:
  /// **'Primary address saved'**
  String get addressPrimarySaved;

  /// No description provided for @addressPrimarySetDefault.
  ///
  /// In en, this message translates to:
  /// **'Primary set as default'**
  String get addressPrimarySetDefault;

  /// No description provided for @addressPrimaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Primary Address'**
  String get addressPrimaryTitle;

  /// No description provided for @addressSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Address'**
  String get addressSaveButton;

  /// No description provided for @addressSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save address. Please try again.'**
  String get addressSaveFailed;

  /// No description provided for @addressSecondarySaved.
  ///
  /// In en, this message translates to:
  /// **'Secondary address saved'**
  String get addressSecondarySaved;

  /// No description provided for @addressSecondarySetDefault.
  ///
  /// In en, this message translates to:
  /// **'Secondary set as default'**
  String get addressSecondarySetDefault;

  /// No description provided for @addressSecondaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Secondary Address'**
  String get addressSecondaryTitle;

  /// No description provided for @addressSetAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get addressSetAsDefault;

  /// No description provided for @addressSlotPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get addressSlotPrimary;

  /// No description provided for @addressSlotSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get addressSlotSecondary;

  /// No description provided for @apiErrorAccountDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Your account is deactivated. Please contact support.'**
  String get apiErrorAccountDeactivated;

  /// No description provided for @apiErrorAddressIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Your address is incomplete. Please enter the full delivery address.'**
  String get apiErrorAddressIncomplete;

  /// No description provided for @apiErrorCartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty.'**
  String get apiErrorCartEmpty;

  /// No description provided for @apiErrorCouponMinPurchase.
  ///
  /// In en, this message translates to:
  /// **'Your order total is below the minimum amount for this coupon.'**
  String get apiErrorCouponMinPurchase;

  /// No description provided for @apiErrorCouponMinPurchaseAmount.
  ///
  /// In en, this message translates to:
  /// **'Minimum purchase amount for this coupon is ₹{amount}.'**
  String apiErrorCouponMinPurchaseAmount(String amount);

  /// No description provided for @apiErrorCouponNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'This coupon can\'t be used for this order.'**
  String get apiErrorCouponNotApplicable;

  /// No description provided for @apiErrorInsufficientStock.
  ///
  /// In en, this message translates to:
  /// **'Some items don\'t have enough stock. Please update the quantity.'**
  String get apiErrorInsufficientStock;

  /// No description provided for @apiErrorInvalidCoupon.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired coupon code.'**
  String get apiErrorInvalidCoupon;

  /// No description provided for @apiErrorInvalidQuantity.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid quantity.'**
  String get apiErrorInvalidQuantity;

  /// No description provided for @apiErrorMinWholesaleQuantity.
  ///
  /// In en, this message translates to:
  /// **'Please order at least the minimum wholesale quantity.'**
  String get apiErrorMinWholesaleQuantity;

  /// No description provided for @apiErrorNegotiationCheckoutDisabled.
  ///
  /// In en, this message translates to:
  /// **'Ordering from a deal is turned off right now.'**
  String get apiErrorNegotiationCheckoutDisabled;

  /// No description provided for @apiErrorNegotiationDisabled.
  ///
  /// In en, this message translates to:
  /// **'Negotiation is not available for this product.'**
  String get apiErrorNegotiationDisabled;

  /// No description provided for @apiErrorNegotiationExpired.
  ///
  /// In en, this message translates to:
  /// **'This deal has expired.'**
  String get apiErrorNegotiationExpired;

  /// No description provided for @apiErrorNegotiationNotFound.
  ///
  /// In en, this message translates to:
  /// **'This deal is no longer available.'**
  String get apiErrorNegotiationNotFound;

  /// No description provided for @apiErrorNoPermission.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this.'**
  String get apiErrorNoPermission;

  /// No description provided for @apiErrorOrderNotFound.
  ///
  /// In en, this message translates to:
  /// **'This order could not be found.'**
  String get apiErrorOrderNotFound;

  /// No description provided for @apiErrorProductNotFound.
  ///
  /// In en, this message translates to:
  /// **'This product is no longer available.'**
  String get apiErrorProductNotFound;

  /// No description provided for @apiErrorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Please try again later.'**
  String get apiErrorServiceUnavailable;

  /// No description provided for @apiErrorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get apiErrorSessionExpired;

  /// No description provided for @apiErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment and try again.'**
  String get apiErrorTooManyRequests;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TradeHub Demo'**
  String get appTitle;

  /// No description provided for @authBusinessNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your shop or company name'**
  String get authBusinessNameHint;

  /// No description provided for @authConfirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get authConfirmPasswordHint;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authConsentAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get authConsentAnd;

  /// No description provided for @authConsentIntro.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our:'**
  String get authConsentIntro;

  /// No description provided for @authConsentPointCollect.
  ///
  /// In en, this message translates to:
  /// **'- We collect basic details like name, phone, email, and app usage data.'**
  String get authConsentPointCollect;

  /// No description provided for @authConsentPointRights.
  ///
  /// In en, this message translates to:
  /// **'- You can request access, correction, or deletion of your data where permitted.'**
  String get authConsentPointRights;

  /// No description provided for @authConsentPointShare.
  ///
  /// In en, this message translates to:
  /// **'- We share data only with logistics, payment, service partners, or legal authorities.'**
  String get authConsentPointShare;

  /// No description provided for @authConsentPointUse.
  ///
  /// In en, this message translates to:
  /// **'- We use this data to process orders, provide support, and improve services.'**
  String get authConsentPointUse;

  /// No description provided for @authConsentPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy.'**
  String get authConsentPrivacyLink;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authErrorAcceptTerms.
  ///
  /// In en, this message translates to:
  /// **'Please accept Terms & Conditions and Privacy Policy'**
  String get authErrorAcceptTerms;

  /// No description provided for @authErrorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get authErrorInvalidPhone;

  /// No description provided for @authErrorPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authErrorPasswordMismatch;

  /// No description provided for @authErrorPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authErrorPasswordShort;

  /// No description provided for @authErrorPhoneIndian.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9.'**
  String get authErrorPhoneIndian;

  /// No description provided for @authErrorPhoneNotReal.
  ///
  /// In en, this message translates to:
  /// **'Enter a real mobile number, not a repeated or sequential number.'**
  String get authErrorPhoneNotReal;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authHaveAccount;

  /// No description provided for @authJoinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join TradeHub Demo today'**
  String get authJoinSubtitle;

  /// No description provided for @authNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get authNameHint;

  /// No description provided for @authNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help accessing your account? Contact Support'**
  String get authNeedHelp;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordHint;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'10-digit mobile number'**
  String get authPhoneHint;

  /// No description provided for @authRoleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get authRoleCustomer;

  /// No description provided for @authRoleWholesaler.
  ///
  /// In en, this message translates to:
  /// **'Wholesaler'**
  String get authRoleWholesaler;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue to TradeHub Demo'**
  String get authSignInSubtitle;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get authWelcomeBack;

  /// No description provided for @authWholesalerProofNote.
  ///
  /// In en, this message translates to:
  /// **'After creating your account, submit your business proof from Become a Wholesaler for admin review.'**
  String get authWholesalerProofNote;

  /// No description provided for @buyNowAddAddress.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get buyNowAddAddress;

  /// No description provided for @buyNowAddDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Add Delivery Address'**
  String get buyNowAddDeliveryAddress;

  /// No description provided for @buyNowAddNewAddress.
  ///
  /// In en, this message translates to:
  /// **'+ Add New'**
  String get buyNowAddNewAddress;

  /// No description provided for @buyNowChangeAddress.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get buyNowChangeAddress;

  /// No description provided for @buyNowDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get buyNowDeliveryAddress;

  /// No description provided for @buyNowLoginRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Login is required before placing an order. Please log in to continue checkout.'**
  String get buyNowLoginRequiredMessage;

  /// No description provided for @buyNowOrderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create order'**
  String get buyNowOrderFailed;

  /// No description provided for @buyNowPreviewDisabled.
  ///
  /// In en, this message translates to:
  /// **'Buy Now is disabled in customer preview mode. Your wholesaler account remains unchanged.'**
  String get buyNowPreviewDisabled;

  /// No description provided for @buyNowPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Preview'**
  String get buyNowPreviewTitle;

  /// No description provided for @buyNowPrimaryAddress.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get buyNowPrimaryAddress;

  /// No description provided for @buyNowSelectAddress.
  ///
  /// In en, this message translates to:
  /// **'Select Address'**
  String get buyNowSelectAddress;

  /// No description provided for @buyNowSubmitOrder.
  ///
  /// In en, this message translates to:
  /// **'Submit Order'**
  String get buyNowSubmitOrder;

  /// No description provided for @buyNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get buyNowTitle;

  /// No description provided for @cartBrowseProducts.
  ///
  /// In en, this message translates to:
  /// **'Browse Products'**
  String get cartBrowseProducts;

  /// No description provided for @cartCheckingStock.
  ///
  /// In en, this message translates to:
  /// **'Checking stock...'**
  String get cartCheckingStock;

  /// No description provided for @cartCheckoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Checkout failed'**
  String get cartCheckoutFailed;

  /// No description provided for @cartCouponApplied.
  ///
  /// In en, this message translates to:
  /// **'Code applied: -₹{amount}'**
  String cartCouponApplied(String amount);

  /// No description provided for @cartCouponEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter a coupon code'**
  String get cartCouponEnterCode;

  /// No description provided for @cartCouponFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to apply coupon'**
  String get cartCouponFailed;

  /// No description provided for @cartCouponHint.
  ///
  /// In en, this message translates to:
  /// **'Enter coupon code'**
  String get cartCouponHint;

  /// No description provided for @cartCouponInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid coupon code'**
  String get cartCouponInvalid;

  /// No description provided for @cartDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get cartDeliveryFee;

  /// No description provided for @cartDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get cartDiscount;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @cartFixStockIssues.
  ///
  /// In en, this message translates to:
  /// **'Fix Stock Issues'**
  String get cartFixStockIssues;

  /// No description provided for @cartGrandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get cartGrandTotal;

  /// No description provided for @cartInStockCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in stock'**
  String cartInStockCount(String count);

  /// No description provided for @cartIssueGeneric.
  ///
  /// In en, this message translates to:
  /// **'Stock issue'**
  String get cartIssueGeneric;

  /// No description provided for @cartIssueInsufficientStock.
  ///
  /// In en, this message translates to:
  /// **'Only {count, plural, =1{1 unit} other{{count} units}} of {product} available'**
  String cartIssueInsufficientStock(int count, String product);

  /// No description provided for @cartIssueMinWholesale.
  ///
  /// In en, this message translates to:
  /// **'Minimum wholesale quantity for {product} is {quantity}'**
  String cartIssueMinWholesale(String product, String quantity);

  /// No description provided for @cartIssueOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'{product} is out of stock'**
  String cartIssueOutOfStock(String product);

  /// No description provided for @cartIssueUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{product} is currently unavailable'**
  String cartIssueUnavailable(String product);

  /// No description provided for @cartItemMinWholesale.
  ///
  /// In en, this message translates to:
  /// **'Minimum wholesale quantity is {quantity}'**
  String cartItemMinWholesale(String quantity);

  /// No description provided for @cartItemOnlyAvailable.
  ///
  /// In en, this message translates to:
  /// **'Only {available} available (you selected {selected})'**
  String cartItemOnlyAvailable(String available, String selected);

  /// No description provided for @cartItemOnlyStockAvailable.
  ///
  /// In en, this message translates to:
  /// **'Only {available} available'**
  String cartItemOnlyStockAvailable(String available);

  /// No description provided for @cartItemOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock — please remove this item'**
  String get cartItemOutOfStock;

  /// No description provided for @cartItemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This product is currently unavailable'**
  String get cartItemUnavailable;

  /// No description provided for @cartLoginRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'You can add products to cart, but login is required to place an order.'**
  String get cartLoginRequiredMessage;

  /// No description provided for @cartLoginRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get cartLoginRequiredTitle;

  /// No description provided for @cartMinusRupees.
  ///
  /// In en, this message translates to:
  /// **'-₹{amount}'**
  String cartMinusRupees(String amount);

  /// No description provided for @cartNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get cartNotNow;

  /// No description provided for @cartOnlyUnitsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Only {count, plural, =1{1 unit} other{{count} units}} available'**
  String cartOnlyUnitsAvailable(int count);

  /// No description provided for @cartPreviewCheckoutDisabled.
  ///
  /// In en, this message translates to:
  /// **'Checkout is disabled in customer preview mode.'**
  String get cartPreviewCheckoutDisabled;

  /// No description provided for @cartPreviewDisabled.
  ///
  /// In en, this message translates to:
  /// **'Shopping is disabled in preview mode'**
  String get cartPreviewDisabled;

  /// No description provided for @cartPreviewPrivate.
  ///
  /// In en, this message translates to:
  /// **'Your wholesaler cart is private and remains unchanged.'**
  String get cartPreviewPrivate;

  /// No description provided for @cartPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Cart Preview'**
  String get cartPreviewTitle;

  /// No description provided for @cartPriceSummary.
  ///
  /// In en, this message translates to:
  /// **'Price Summary'**
  String get cartPriceSummary;

  /// No description provided for @cartProceedToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get cartProceedToCheckout;

  /// No description provided for @cartProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get cartProcessing;

  /// No description provided for @cartSetQuantity.
  ///
  /// In en, this message translates to:
  /// **'Set to {quantity}'**
  String cartSetQuantity(String quantity);

  /// No description provided for @cartStockIssuesBanner.
  ///
  /// In en, this message translates to:
  /// **'Some items have stock issues. Please adjust quantities.'**
  String get cartStockIssuesBanner;

  /// No description provided for @cartStockIssuesMessage.
  ///
  /// In en, this message translates to:
  /// **'Some items in your cart have stock issues. Please update quantities before checkout.'**
  String get cartStockIssuesMessage;

  /// No description provided for @cartStockIssuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Issues'**
  String get cartStockIssuesTitle;

  /// No description provided for @cartTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping Cart'**
  String get cartTitle;

  /// No description provided for @categoryBackToCategories.
  ///
  /// In en, this message translates to:
  /// **'Back to categories'**
  String get categoryBackToCategories;

  /// No description provided for @categoryBackToTypes.
  ///
  /// In en, this message translates to:
  /// **'Back to types'**
  String get categoryBackToTypes;

  /// No description provided for @categoryBrandNotFound.
  ///
  /// In en, this message translates to:
  /// **'Brand not found. Select a brand from the left.'**
  String get categoryBrandNotFound;

  /// No description provided for @categoryCategoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category} other{{count} categories}}'**
  String categoryCategoriesCount(int count);

  /// No description provided for @categoryGeneralProducts.
  ///
  /// In en, this message translates to:
  /// **'General Products'**
  String get categoryGeneralProducts;

  /// No description provided for @categoryLoadProductsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load products'**
  String get categoryLoadProductsError;

  /// No description provided for @categoryNoBrands.
  ///
  /// In en, this message translates to:
  /// **'No brands found'**
  String get categoryNoBrands;

  /// No description provided for @categoryNoCategoriesForBrand.
  ///
  /// In en, this message translates to:
  /// **'No categories available for this brand'**
  String get categoryNoCategoriesForBrand;

  /// No description provided for @categoryNoProductsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No products in this category'**
  String get categoryNoProductsInCategory;

  /// No description provided for @categoryNoProductsInSubcategory.
  ///
  /// In en, this message translates to:
  /// **'No products in this subcategory'**
  String get categoryNoProductsInSubcategory;

  /// No description provided for @categoryOtherProducts.
  ///
  /// In en, this message translates to:
  /// **'Other Products'**
  String get categoryOtherProducts;

  /// No description provided for @categorySelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get categorySelectCategory;

  /// No description provided for @categorySelectType.
  ///
  /// In en, this message translates to:
  /// **'Select a type'**
  String get categorySelectType;

  /// No description provided for @categorySubcategoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subcategory} other{{count} subcategories}}'**
  String categorySubcategoriesCount(int count);

  /// No description provided for @categoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoryTitle;

  /// No description provided for @categoryTypesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 type} other{{count} types}}'**
  String categoryTypesCount(int count);

  /// No description provided for @categoryViewProduct.
  ///
  /// In en, this message translates to:
  /// **'View Product'**
  String get categoryViewProduct;

  /// No description provided for @checkoutAddressLine1.
  ///
  /// In en, this message translates to:
  /// **'Address Line 1'**
  String get checkoutAddressLine1;

  /// No description provided for @checkoutApprovalNote.
  ///
  /// In en, this message translates to:
  /// **'We’ll notify you after the TradeHub Demo team reviews your order.'**
  String get checkoutApprovalNote;

  /// No description provided for @checkoutAwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Approval'**
  String get checkoutAwaitingApproval;

  /// No description provided for @checkoutChooseAnotherWay.
  ///
  /// In en, this message translates to:
  /// **'Choose another way to send or save your receipt.'**
  String get checkoutChooseAnotherWay;

  /// No description provided for @checkoutConfirmAndPay.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Pay'**
  String get checkoutConfirmAndPay;

  /// No description provided for @checkoutContinueShopping.
  ///
  /// In en, this message translates to:
  /// **'Continue Shopping'**
  String get checkoutContinueShopping;

  /// No description provided for @checkoutCopyOrderDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy Order Details'**
  String get checkoutCopyOrderDetails;

  /// No description provided for @checkoutFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get checkoutFullName;

  /// No description provided for @checkoutOrderDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'Order details copied.'**
  String get checkoutOrderDetailsCopied;

  /// No description provided for @checkoutOrderSaved.
  ///
  /// In en, this message translates to:
  /// **'Order saved successfully'**
  String get checkoutOrderSaved;

  /// No description provided for @checkoutOrderSavedChooseAnotherWay.
  ///
  /// In en, this message translates to:
  /// **'Order {orderNumber} is saved. Choose another way to send or save your receipt.'**
  String checkoutOrderSavedChooseAnotherWay(String orderNumber);

  /// No description provided for @checkoutOrderSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Order Submitted'**
  String get checkoutOrderSubmitted;

  /// No description provided for @checkoutPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get checkoutPhone;

  /// No description provided for @checkoutPhoneValue.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String checkoutPhoneValue(String phone);

  /// No description provided for @checkoutReceiptPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'We saved your order, but could not prepare the PDF receipt.'**
  String get checkoutReceiptPrepareFailed;

  /// No description provided for @checkoutReceiptShareFailed.
  ///
  /// In en, this message translates to:
  /// **'We saved your order, but could not open the receipt sharing options.'**
  String get checkoutReceiptShareFailed;

  /// No description provided for @checkoutReceiptUnavailableNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to prepare the PDF receipt right now.'**
  String get checkoutReceiptUnavailableNow;

  /// No description provided for @checkoutShareOptionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open receipt sharing options.'**
  String get checkoutShareOptionsFailed;

  /// No description provided for @checkoutShareReceipt.
  ///
  /// In en, this message translates to:
  /// **'Share Receipt'**
  String get checkoutShareReceipt;

  /// No description provided for @checkoutShareSheetOpened.
  ///
  /// In en, this message translates to:
  /// **'Choose an app to send your receipt.'**
  String get checkoutShareSheetOpened;

  /// No description provided for @checkoutShippingAddress.
  ///
  /// In en, this message translates to:
  /// **'Shipping Address'**
  String get checkoutShippingAddress;

  /// No description provided for @checkoutViewOrder.
  ///
  /// In en, this message translates to:
  /// **'View Order'**
  String get checkoutViewOrder;

  /// No description provided for @checkoutWebSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your order was saved. You can try sharing the receipt again.'**
  String get checkoutWebSavedMessage;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get commonCall;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get commonDate;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// No description provided for @commonInStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get commonInStock;

  /// No description provided for @commonItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String commonItemsCount(int count);

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonLogin.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get commonLogin;

  /// No description provided for @commonLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please log in to continue'**
  String get commonLoginRequired;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get commonLogout;

  /// No description provided for @commonMrp.
  ///
  /// In en, this message translates to:
  /// **'MRP'**
  String get commonMrp;

  /// No description provided for @commonNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Please check your internet and try again.'**
  String get commonNetworkError;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonNoDataFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show yet'**
  String get commonNoDataFound;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get commonOutOfStock;

  /// No description provided for @commonPerUnit.
  ///
  /// In en, this message translates to:
  /// **'/unit'**
  String get commonPerUnit;

  /// No description provided for @commonPercentOff.
  ///
  /// In en, this message translates to:
  /// **'{percent}% OFF'**
  String commonPercentOff(String percent);

  /// No description provided for @commonPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get commonPrice;

  /// No description provided for @commonPricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'₹{price}/unit'**
  String commonPricePerUnit(String price);

  /// No description provided for @commonProductsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 product} other{{count} products}}'**
  String commonProductsCount(int count);

  /// No description provided for @commonQtyValue.
  ///
  /// In en, this message translates to:
  /// **'Qty: {quantity}'**
  String commonQtyValue(String quantity);

  /// No description provided for @commonQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get commonQuantity;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRupees.
  ///
  /// In en, this message translates to:
  /// **'₹{amount}'**
  String commonRupees(String amount);

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get commonSaveChanges;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get commonSeeAll;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonSomethingWentWrong;

  /// No description provided for @commonStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// No description provided for @commonStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get commonStock;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get commonSubtotal;

  /// No description provided for @commonTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get commonTotal;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// No description provided for @commonUnitsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit} other{{count} units}}'**
  String commonUnitsCount(int count);

  /// No description provided for @commonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get commonViewAll;

  /// No description provided for @commonViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get commonViewDetails;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @conversionAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Address is required'**
  String get conversionAddressRequired;

  /// No description provided for @conversionAlreadyAppliedBody.
  ///
  /// In en, this message translates to:
  /// **'Your wholesaler application is currently under review by our team. We will notify you shortly once it has been processed.'**
  String get conversionAlreadyAppliedBody;

  /// No description provided for @conversionAlreadyAppliedTitle.
  ///
  /// In en, this message translates to:
  /// **'Already Applied'**
  String get conversionAlreadyAppliedTitle;

  /// No description provided for @conversionBusinessAddress.
  ///
  /// In en, this message translates to:
  /// **'Business Address'**
  String get conversionBusinessAddress;

  /// No description provided for @conversionBusinessAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter full office address'**
  String get conversionBusinessAddressHint;

  /// No description provided for @conversionBusinessNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your company name'**
  String get conversionBusinessNameHint;

  /// No description provided for @conversionBusinessNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Business name is required'**
  String get conversionBusinessNameRequired;

  /// No description provided for @conversionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get conversionChange;

  /// No description provided for @conversionContactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact Person'**
  String get conversionContactPerson;

  /// No description provided for @conversionContactPersonHint.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get conversionContactPersonHint;

  /// No description provided for @conversionContactPersonRequired.
  ///
  /// In en, this message translates to:
  /// **'Contact person name is required'**
  String get conversionContactPersonRequired;

  /// No description provided for @conversionGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get conversionGoBack;

  /// No description provided for @conversionGstHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 15-digit GSTIN'**
  String get conversionGstHint;

  /// No description provided for @conversionGstInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid GST number format'**
  String get conversionGstInvalid;

  /// No description provided for @conversionGstNumber.
  ///
  /// In en, this message translates to:
  /// **'GST Number'**
  String get conversionGstNumber;

  /// No description provided for @conversionHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get access to exclusive bulk pricing, negotiation tools, and priority support.'**
  String get conversionHeaderSubtitle;

  /// No description provided for @conversionHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Wholesaler Account Application'**
  String get conversionHeaderTitle;

  /// No description provided for @conversionImageFormats.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG, or similar image files'**
  String get conversionImageFormats;

  /// No description provided for @conversionImagesSelected.
  ///
  /// In en, this message translates to:
  /// **'{count}/3 images selected'**
  String conversionImagesSelected(int count);

  /// No description provided for @conversionLoginFirst.
  ///
  /// In en, this message translates to:
  /// **'Please login first, then submit your application.'**
  String get conversionLoginFirst;

  /// No description provided for @conversionLoginRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Please login to your account first, then submit your wholesaler application.'**
  String get conversionLoginRequiredBody;

  /// No description provided for @conversionLoginRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get conversionLoginRequiredTitle;

  /// No description provided for @conversionMaxProofImages.
  ///
  /// In en, this message translates to:
  /// **'You can upload up to 3 proof images only.'**
  String get conversionMaxProofImages;

  /// No description provided for @conversionPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 10-digit mobile number'**
  String get conversionPhoneHint;

  /// No description provided for @conversionPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get conversionPhoneInvalid;

  /// No description provided for @conversionPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get conversionPhoneRequired;

  /// No description provided for @conversionPick.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get conversionPick;

  /// No description provided for @conversionPickLocationError.
  ///
  /// In en, this message translates to:
  /// **'Please pick your shop location on the map.'**
  String get conversionPickLocationError;

  /// No description provided for @conversionPickShopLocation.
  ///
  /// In en, this message translates to:
  /// **'Pick shop location on map'**
  String get conversionPickShopLocation;

  /// No description provided for @conversionProofAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get conversionProofAdd;

  /// No description provided for @conversionProofDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload shop photo, GST certificate, trade license, or any valid business proof.'**
  String get conversionProofDescription;

  /// No description provided for @conversionProofFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get conversionProofFull;

  /// No description provided for @conversionProofImagesTrimmed.
  ///
  /// In en, this message translates to:
  /// **'Only the first 3 proof images were added.'**
  String get conversionProofImagesTrimmed;

  /// No description provided for @conversionProofLimit.
  ///
  /// In en, this message translates to:
  /// **'(Up to 3)'**
  String get conversionProofLimit;

  /// No description provided for @conversionProofTitle.
  ///
  /// In en, this message translates to:
  /// **'Valid Image Proof'**
  String get conversionProofTitle;

  /// No description provided for @conversionRejectedNote.
  ///
  /// In en, this message translates to:
  /// **'Your previous application was not approved. You can review your details and submit again.'**
  String get conversionRejectedNote;

  /// No description provided for @conversionSectionBusiness.
  ///
  /// In en, this message translates to:
  /// **'BUSINESS INFORMATION'**
  String get conversionSectionBusiness;

  /// No description provided for @conversionSectionContact.
  ///
  /// In en, this message translates to:
  /// **'CONTACT INFORMATION'**
  String get conversionSectionContact;

  /// No description provided for @conversionShopLocation.
  ///
  /// In en, this message translates to:
  /// **'Shop Location'**
  String get conversionShopLocation;

  /// No description provided for @conversionShopLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Mark your shop on the map. You can use current location and then adjust the pin before saving it.'**
  String get conversionShopLocationDescription;

  /// No description provided for @conversionShopLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Use current location or manually place a pin'**
  String get conversionShopLocationHint;

  /// No description provided for @conversionShopLocationSelected.
  ///
  /// In en, this message translates to:
  /// **'Shop location selected'**
  String get conversionShopLocationSelected;

  /// No description provided for @conversionStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Application Status'**
  String get conversionStatusTitle;

  /// No description provided for @conversionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get conversionSubmit;

  /// No description provided for @conversionSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit application. Please try again.'**
  String get conversionSubmitFailed;

  /// No description provided for @conversionSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application submitted successfully! Our team will verify your details.'**
  String get conversionSubmitted;

  /// No description provided for @conversionTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply for wholesaler account'**
  String get conversionTitle;

  /// No description provided for @conversionUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get conversionUnexpectedError;

  /// No description provided for @conversionUploadProof.
  ///
  /// In en, this message translates to:
  /// **'Upload proof images'**
  String get conversionUploadProof;

  /// No description provided for @dealAcceptedByPlatform.
  ///
  /// In en, this message translates to:
  /// **'Accepted by TradeHub Demo'**
  String get dealAcceptedByPlatform;

  /// No description provided for @dealAcceptedByPlatformName.
  ///
  /// In en, this message translates to:
  /// **'Accepted by TradeHub Demo: {name}'**
  String dealAcceptedByPlatformName(String name);

  /// No description provided for @dealBulletTotal.
  ///
  /// In en, this message translates to:
  /// **'• Total: ₹{amount}'**
  String dealBulletTotal(String amount);

  /// No description provided for @dealChatAndHistory.
  ///
  /// In en, this message translates to:
  /// **'Chat & History'**
  String get dealChatAndHistory;

  /// No description provided for @dealConfirmAndProceed.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Proceed'**
  String get dealConfirmAndProceed;

  /// No description provided for @dealCreateOrderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create order'**
  String get dealCreateOrderFailed;

  /// No description provided for @dealCurrentPricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'Current Price/unit'**
  String get dealCurrentPricePerUnit;

  /// No description provided for @dealDeclinedByPlatform.
  ///
  /// In en, this message translates to:
  /// **'Declined by TradeHub Demo'**
  String get dealDeclinedByPlatform;

  /// No description provided for @dealEnterMessage.
  ///
  /// In en, this message translates to:
  /// **'Please enter a message'**
  String get dealEnterMessage;

  /// No description provided for @dealErrorWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String dealErrorWithDetails(String error);

  /// No description provided for @dealFieldAddressLine1.
  ///
  /// In en, this message translates to:
  /// **'Address Line 1'**
  String get dealFieldAddressLine1;

  /// No description provided for @dealFieldCouponCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon / Affiliate Code (Optional)'**
  String get dealFieldCouponCode;

  /// No description provided for @dealFieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get dealFieldFullName;

  /// No description provided for @dealFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get dealFieldPhone;

  /// No description provided for @dealPlatform.
  ///
  /// In en, this message translates to:
  /// **'TradeHub Demo'**
  String get dealPlatform;

  /// No description provided for @dealPlatformActor.
  ///
  /// In en, this message translates to:
  /// **'TradeHub Demo: {name}'**
  String dealPlatformActor(String name);

  /// No description provided for @dealLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get dealLoadFailed;

  /// No description provided for @dealLrLine.
  ///
  /// In en, this message translates to:
  /// **'LR: {tracking}'**
  String dealLrLine(String tracking);

  /// No description provided for @dealLrLineWithCourier.
  ///
  /// In en, this message translates to:
  /// **'LR: {tracking} · {courier}'**
  String dealLrLineWithCourier(String tracking, String courier);

  /// No description provided for @dealMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get dealMessageHint;

  /// No description provided for @dealMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent!'**
  String get dealMessageSent;

  /// No description provided for @dealMessageTooLong.
  ///
  /// In en, this message translates to:
  /// **'Message too long (max {max} characters)'**
  String dealMessageTooLong(String max);

  /// No description provided for @dealOrderStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get dealOrderStatusCancelled;

  /// No description provided for @dealOrderStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get dealOrderStatusDelivered;

  /// No description provided for @dealOrderStatusDispatched.
  ///
  /// In en, this message translates to:
  /// **'Dispatched'**
  String get dealOrderStatusDispatched;

  /// No description provided for @dealOrderStatusLine.
  ///
  /// In en, this message translates to:
  /// **'Order {orderNumber} · {status}'**
  String dealOrderStatusLine(String orderNumber, String status);

  /// No description provided for @dealOrderStatusPacking.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get dealOrderStatusPacking;

  /// No description provided for @dealOrderStatusPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment Pending'**
  String get dealOrderStatusPaymentPending;

  /// No description provided for @dealOrderStatusPaymentVerificationPending.
  ///
  /// In en, this message translates to:
  /// **'Payment Verification Pending'**
  String get dealOrderStatusPaymentVerificationPending;

  /// No description provided for @dealOrderStatusPaymentVerified.
  ///
  /// In en, this message translates to:
  /// **'Payment Verified'**
  String get dealOrderStatusPaymentVerified;

  /// No description provided for @dealOrderTrackingNote.
  ///
  /// In en, this message translates to:
  /// **'Live status from your order. Open full order for payment & dispatch details.'**
  String get dealOrderTrackingNote;

  /// No description provided for @dealProductFallback.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get dealProductFallback;

  /// No description provided for @dealQtyUnits.
  ///
  /// In en, this message translates to:
  /// **'Qty: {count, plural, =1{1 unit} other{{count} units}}'**
  String dealQtyUnits(int count);

  /// No description provided for @dealReplyInChat.
  ///
  /// In en, this message translates to:
  /// **'Reply in Chat'**
  String get dealReplyInChat;

  /// No description provided for @dealRetailPrice.
  ///
  /// In en, this message translates to:
  /// **'Retail: ₹{price}'**
  String dealRetailPrice(String price);

  /// No description provided for @dealSendMessageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message'**
  String get dealSendMessageFailed;

  /// No description provided for @dealShippingAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Shipping Address'**
  String get dealShippingAddressTitle;

  /// No description provided for @dealStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get dealStatusAccepted;

  /// No description provided for @dealStatusNewPriceFromPlatform.
  ///
  /// In en, this message translates to:
  /// **'New Price from TradeHub Demo'**
  String get dealStatusNewPriceFromPlatform;

  /// No description provided for @dealStatusNewPriceReceived.
  ///
  /// In en, this message translates to:
  /// **'New Price Received'**
  String get dealStatusNewPriceReceived;

  /// No description provided for @dealStatusRequirementDeclined.
  ///
  /// In en, this message translates to:
  /// **'Requirement Declined'**
  String get dealStatusRequirementDeclined;

  /// No description provided for @dealStatusRequirementExpired.
  ///
  /// In en, this message translates to:
  /// **'Requirement Expired'**
  String get dealStatusRequirementExpired;

  /// No description provided for @dealStatusRequirementSent.
  ///
  /// In en, this message translates to:
  /// **'Requirement Sent'**
  String get dealStatusRequirementSent;

  /// No description provided for @dealStatusYourCounterOffer.
  ///
  /// In en, this message translates to:
  /// **'Your Counter Offer'**
  String get dealStatusYourCounterOffer;

  /// No description provided for @dealTotalForUnits.
  ///
  /// In en, this message translates to:
  /// **'Total ({count, plural, =1{1 unit} other{{count} units}})'**
  String dealTotalForUnits(int count);

  /// No description provided for @dealTyping.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing...'**
  String dealTyping(String name);

  /// No description provided for @dealViewOrder.
  ///
  /// In en, this message translates to:
  /// **'View Order'**
  String get dealViewOrder;

  /// No description provided for @dealViewOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'View Order {orderNumber}'**
  String dealViewOrderNumber(String orderNumber);

  /// No description provided for @dealYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get dealYou;

  /// No description provided for @dealYouAccepted.
  ///
  /// In en, this message translates to:
  /// **'You Accepted'**
  String get dealYouAccepted;

  /// No description provided for @dealYouCancelled.
  ///
  /// In en, this message translates to:
  /// **'You Cancelled'**
  String get dealYouCancelled;

  /// No description provided for @editProfileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get editProfileUpdateFailed;

  /// No description provided for @editProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get editProfileUpdated;

  /// No description provided for @featuredEmpty.
  ///
  /// In en, this message translates to:
  /// **'No products available'**
  String get featuredEmpty;

  /// No description provided for @featuredHotDealsCustomer.
  ///
  /// In en, this message translates to:
  /// **'Hot Deals'**
  String get featuredHotDealsCustomer;

  /// No description provided for @featuredHotDealsDealer.
  ///
  /// In en, this message translates to:
  /// **'Dealer Schemes'**
  String get featuredHotDealsDealer;

  /// No description provided for @featuredLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading products'**
  String get featuredLoadError;

  /// No description provided for @featuredPopularCustomer.
  ///
  /// In en, this message translates to:
  /// **'Popular Products'**
  String get featuredPopularCustomer;

  /// No description provided for @featuredPopularDealer.
  ///
  /// In en, this message translates to:
  /// **'Fast-Moving Products'**
  String get featuredPopularDealer;

  /// No description provided for @fieldAddressLine1.
  ///
  /// In en, this message translates to:
  /// **'Address Line 1'**
  String get fieldAddressLine1;

  /// No description provided for @fieldBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Business Name'**
  String get fieldBusinessName;

  /// No description provided for @fieldCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get fieldCity;

  /// No description provided for @fieldEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get fieldEnterName;

  /// No description provided for @fieldEnterPincode.
  ///
  /// In en, this message translates to:
  /// **'Enter a pincode'**
  String get fieldEnterPincode;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fieldFullName;

  /// No description provided for @fieldOptionalTag.
  ///
  /// In en, this message translates to:
  /// **'(Optional)'**
  String get fieldOptionalTag;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fieldPhone;

  /// No description provided for @fieldPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get fieldPhoneNumber;

  /// No description provided for @fieldPincodeEditable.
  ///
  /// In en, this message translates to:
  /// **'Pincode (editable)'**
  String get fieldPincodeEditable;

  /// No description provided for @fieldSelectCity.
  ///
  /// In en, this message translates to:
  /// **'Select a city'**
  String get fieldSelectCity;

  /// No description provided for @fieldSelectState.
  ///
  /// In en, this message translates to:
  /// **'Select a state'**
  String get fieldSelectState;

  /// No description provided for @fieldState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get fieldState;

  /// No description provided for @guestPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re seeing what customers see'**
  String get guestPreviewSubtitle;

  /// No description provided for @guestPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Viewing as Customer'**
  String get guestPreviewTitle;

  /// No description provided for @guideContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get guideContactSupport;

  /// No description provided for @guideHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn how to request and review bulk-price offers.'**
  String get guideHeroSubtitle;

  /// No description provided for @guideHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk Pricing Guide'**
  String get guideHeroTitle;

  /// No description provided for @guideHowItWorksBody.
  ///
  /// In en, this message translates to:
  /// **'Use negotiations for bulk requirements when you want to discuss quantity, price, and delivery expectations with the seller.'**
  String get guideHowItWorksBody;

  /// No description provided for @guideHowItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How price negotiation works'**
  String get guideHowItWorksTitle;

  /// No description provided for @guideStep1Body.
  ///
  /// In en, this message translates to:
  /// **'Open an eligible product and submit your quantity, target price, and delivery requirements.'**
  String get guideStep1Body;

  /// No description provided for @guideStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Request a bulk price'**
  String get guideStep1Title;

  /// No description provided for @guideStep2Body.
  ///
  /// In en, this message translates to:
  /// **'The seller may accept your request or send a counter-offer. Check the app for updates before confirming an order.'**
  String get guideStep2Body;

  /// No description provided for @guideStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Review the seller response'**
  String get guideStep2Title;

  /// No description provided for @guideStep3Body.
  ///
  /// In en, this message translates to:
  /// **'After your order is created, share its receipt with the TradeHub Demo team so they can coordinate the next step.'**
  String get guideStep3Body;

  /// No description provided for @guideStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Send your order receipt'**
  String get guideStep3Title;

  /// No description provided for @guideStep4Body.
  ///
  /// In en, this message translates to:
  /// **'Complete payment at the shop or using QR or bank details provided by the TradeHub Demo team. Your order status is updated after admin verification.'**
  String get guideStep4Body;

  /// No description provided for @guideStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Pay through the TradeHub Demo team'**
  String get guideStep4Title;

  /// No description provided for @guideTip.
  ///
  /// In en, this message translates to:
  /// **'Include the quantity and your preferred delivery timeline in your request so the seller can provide a useful response.'**
  String get guideTip;

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'Negotiation Guide'**
  String get guideTitle;

  /// No description provided for @guideViewNegotiations.
  ///
  /// In en, this message translates to:
  /// **'View Negotiations'**
  String get guideViewNegotiations;

  /// No description provided for @helpAppTagline.
  ///
  /// In en, this message translates to:
  /// **'Distribution made simple'**
  String get helpAppTagline;

  /// No description provided for @helpBrandName.
  ///
  /// In en, this message translates to:
  /// **'TradeHub Demo'**
  String get helpBrandName;

  /// No description provided for @helpCallUs.
  ///
  /// In en, this message translates to:
  /// **'Call Us'**
  String get helpCallUs;

  /// No description provided for @helpContactInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get in touch with our support team'**
  String get helpContactInfoSubtitle;

  /// No description provided for @helpContactInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get helpContactInfoTitle;

  /// No description provided for @helpEmailUs.
  ///
  /// In en, this message translates to:
  /// **'Email Us'**
  String get helpEmailUs;

  /// No description provided for @helpFaqBulkOrderAnswer.
  ///
  /// In en, this message translates to:
  /// **'Navigate to the product page and tap \"Initiate Negotiation\" to start the bulk ordering process. You can request custom pricing for large quantities.'**
  String get helpFaqBulkOrderAnswer;

  /// No description provided for @helpFaqBulkOrderQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do I place a bulk order?'**
  String get helpFaqBulkOrderQuestion;

  /// No description provided for @helpFaqDeliveryAnswer.
  ///
  /// In en, this message translates to:
  /// **'Delivery availability and timing depend on the product, order, and location. Contact support to confirm delivery arrangements for your order.'**
  String get helpFaqDeliveryAnswer;

  /// No description provided for @helpFaqDeliveryQuestion.
  ///
  /// In en, this message translates to:
  /// **'How long does delivery take?'**
  String get helpFaqDeliveryQuestion;

  /// No description provided for @helpFaqNegotiationAnswer.
  ///
  /// In en, this message translates to:
  /// **'Wholesalers can negotiate prices for bulk orders. Submit a negotiation request with your preferred price, and our team will review and respond with a counter-offer or acceptance.'**
  String get helpFaqNegotiationAnswer;

  /// No description provided for @helpFaqNegotiationQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do negotiations work?'**
  String get helpFaqNegotiationQuestion;

  /// No description provided for @helpFaqPaymentAnswer.
  ///
  /// In en, this message translates to:
  /// **'Retail orders are reviewed in the app after submission. Once accepted, complete payment at the shop or use the QR code, UPI, or bank details shared by our team. Your order status updates after payment is confirmed.'**
  String get helpFaqPaymentAnswer;

  /// No description provided for @helpFaqPaymentQuestion.
  ///
  /// In en, this message translates to:
  /// **'What payment methods are accepted?'**
  String get helpFaqPaymentQuestion;

  /// No description provided for @helpFaqReturnAnswer.
  ///
  /// In en, this message translates to:
  /// **'Return availability depends on the product and order. Contact support so our team can review your request.'**
  String get helpFaqReturnAnswer;

  /// No description provided for @helpFaqReturnQuestion.
  ///
  /// In en, this message translates to:
  /// **'What is the return policy?'**
  String get helpFaqReturnQuestion;

  /// No description provided for @helpFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get helpFaqTitle;

  /// No description provided for @helpFaqTrackAnswer.
  ///
  /// In en, this message translates to:
  /// **'Go to the Orders section in your profile and tap on any order to view its available status updates.'**
  String get helpFaqTrackAnswer;

  /// No description provided for @helpFaqTrackQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do I track my order?'**
  String get helpFaqTrackQuestion;

  /// No description provided for @helpFaqWholesalerAnswer.
  ///
  /// In en, this message translates to:
  /// **'Register with a wholesaler account and provide your business details. Once verified by our team, you\'ll get access to wholesale pricing and negotiations.'**
  String get helpFaqWholesalerAnswer;

  /// No description provided for @helpFaqWholesalerQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do I become a wholesaler?'**
  String get helpFaqWholesalerQuestion;

  /// No description provided for @helpHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re here to help with anything you need.\nReach out and we\'ll respond as soon as we can.'**
  String get helpHeroSubtitle;

  /// No description provided for @helpHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'How can we help you?'**
  String get helpHeroTitle;

  /// No description provided for @helpSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupportTitle;

  /// No description provided for @helpVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String helpVersion(String version);

  /// No description provided for @helpVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get helpVersionLabel;

  /// No description provided for @helpWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get helpWorkingHours;

  /// No description provided for @helpWorkingHoursValue.
  ///
  /// In en, this message translates to:
  /// **'Mon - Sat, 9:00 AM - 6:00 PM'**
  String get helpWorkingHoursValue;

  /// No description provided for @homeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get homeAdd;

  /// No description provided for @homeAddShippingDetails.
  ///
  /// In en, this message translates to:
  /// **'Add Shipping Details'**
  String get homeAddShippingDetails;

  /// No description provided for @homeAddedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added to cart'**
  String get homeAddedToCart;

  /// No description provided for @homeAffiliateCodeApplied.
  ///
  /// In en, this message translates to:
  /// **'Affiliate code applied'**
  String get homeAffiliateCodeApplied;

  /// No description provided for @homeAllOrders.
  ///
  /// In en, this message translates to:
  /// **'All Orders'**
  String get homeAllOrders;

  /// No description provided for @homeApplyCoupon.
  ///
  /// In en, this message translates to:
  /// **'APPLY COUPON'**
  String get homeApplyCoupon;

  /// No description provided for @homeBadgeHot.
  ///
  /// In en, this message translates to:
  /// **'HOT'**
  String get homeBadgeHot;

  /// No description provided for @homeBadgeNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get homeBadgeNew;

  /// No description provided for @homeBadgeSale.
  ///
  /// In en, this message translates to:
  /// **'SALE'**
  String get homeBadgeSale;

  /// No description provided for @homeBannerExploreProducts.
  ///
  /// In en, this message translates to:
  /// **'Explore Products'**
  String get homeBannerExploreProducts;

  /// No description provided for @homeBannerNewArrival.
  ///
  /// In en, this message translates to:
  /// **'NEW ARRIVAL'**
  String get homeBannerNewArrival;

  /// No description provided for @homeBannerShopNow.
  ///
  /// In en, this message translates to:
  /// **'Shop Now'**
  String get homeBannerShopNow;

  /// No description provided for @homeBrandFirstWord.
  ///
  /// In en, this message translates to:
  /// **'TradeHub'**
  String get homeBrandFirstWord;

  /// No description provided for @homeBrandName.
  ///
  /// In en, this message translates to:
  /// **'TradeHub Demo'**
  String get homeBrandName;

  /// No description provided for @homeBrandSecondWord.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get homeBrandSecondWord;

  /// No description provided for @homeBrandTagline.
  ///
  /// In en, this message translates to:
  /// **'Grow Together  •  Trade Better'**
  String get homeBrandTagline;

  /// No description provided for @homeBrandValue.
  ///
  /// In en, this message translates to:
  /// **'Brand: {brand}'**
  String homeBrandValue(String brand);

  /// No description provided for @homeBrowseCategories.
  ///
  /// In en, this message translates to:
  /// **'Browse Categories'**
  String get homeBrowseCategories;

  /// No description provided for @homeBrowseProducts.
  ///
  /// In en, this message translates to:
  /// **'Browse Products'**
  String get homeBrowseProducts;

  /// No description provided for @homeCartEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover products and add them here'**
  String get homeCartEmptySubtitle;

  /// No description provided for @homeCartEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get homeCartEmptyTitle;

  /// No description provided for @homeCatalogProducts.
  ///
  /// In en, this message translates to:
  /// **'Catalog Products'**
  String get homeCatalogProducts;

  /// No description provided for @homeCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get homeCategoriesTitle;

  /// No description provided for @homeCategoryValue.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String homeCategoryValue(String category);

  /// No description provided for @homeChangeCode.
  ///
  /// In en, this message translates to:
  /// **'Change code'**
  String get homeChangeCode;

  /// No description provided for @homeCheckoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Checkout failed'**
  String get homeCheckoutFailed;

  /// No description provided for @homeCheckoutLoginMessage.
  ///
  /// In en, this message translates to:
  /// **'You can add products to cart and view them, but login is required to buy.'**
  String get homeCheckoutLoginMessage;

  /// No description provided for @homeClearAll.
  ///
  /// In en, this message translates to:
  /// **'CLEAR ALL'**
  String get homeClearAll;

  /// No description provided for @homeConfirmAndProceed.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Proceed'**
  String get homeConfirmAndProceed;

  /// No description provided for @homeContinueDealChat.
  ///
  /// In en, this message translates to:
  /// **'Continue Deal Chat'**
  String get homeContinueDealChat;

  /// No description provided for @homeCountdownSoon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get homeCountdownSoon;

  /// No description provided for @homeCounterLabel.
  ///
  /// In en, this message translates to:
  /// **'Counter:'**
  String get homeCounterLabel;

  /// No description provided for @homeCouponAppliedAtCheckout.
  ///
  /// In en, this message translates to:
  /// **'Applied successfully during checkout'**
  String get homeCouponAppliedAtCheckout;

  /// No description provided for @homeCouponAppliedButton.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get homeCouponAppliedButton;

  /// No description provided for @homeCouponAppliedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Coupon applied successfully'**
  String get homeCouponAppliedSuccess;

  /// No description provided for @homeCouponCopied.
  ///
  /// In en, this message translates to:
  /// **'{code} copied! Use it in cart or find it in \"My Coupons\" in Profile.'**
  String homeCouponCopied(String code);

  /// No description provided for @homeCouponFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Enter coupon or affiliate code'**
  String get homeCouponFieldHint;

  /// No description provided for @homeCouponFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Coupon / Affiliate Code'**
  String get homeCouponFieldLabel;

  /// No description provided for @homeCouponWithCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon ({code})'**
  String homeCouponWithCode(String code);

  /// No description provided for @homeCreateOrderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create order'**
  String get homeCreateOrderFailed;

  /// No description provided for @homeCreatingOrder.
  ///
  /// In en, this message translates to:
  /// **'Creating Order...'**
  String get homeCreatingOrder;

  /// No description provided for @homeCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current:'**
  String get homeCurrentLabel;

  /// No description provided for @homeDealDeskTitle.
  ///
  /// In en, this message translates to:
  /// **'Deal Desk'**
  String get homeDealDeskTitle;

  /// No description provided for @homeDealEmptyActive.
  ///
  /// In en, this message translates to:
  /// **'No active negotiations'**
  String get homeDealEmptyActive;

  /// No description provided for @homeDealEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed negotiations'**
  String get homeDealEmptyCompleted;

  /// No description provided for @homeDealEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Start negotiating on product pages'**
  String get homeDealEmptyHint;

  /// No description provided for @homeDealNewPriceReceived.
  ///
  /// In en, this message translates to:
  /// **'New Price Received'**
  String get homeDealNewPriceReceived;

  /// No description provided for @homeDealQtyTotal.
  ///
  /// In en, this message translates to:
  /// **'Qty {quantity} · ₹{amount}'**
  String homeDealQtyTotal(String quantity, String amount);

  /// No description provided for @homeDealRequirementSent.
  ///
  /// In en, this message translates to:
  /// **'Requirement Sent'**
  String get homeDealRequirementSent;

  /// No description provided for @homeDealStatusCountered.
  ///
  /// In en, this message translates to:
  /// **'COUNTER-OFFER'**
  String get homeDealStatusCountered;

  /// No description provided for @homeDealStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get homeDealStatusExpired;

  /// No description provided for @homeDealStatusPending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get homeDealStatusPending;

  /// No description provided for @homeDealStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'REJECTED'**
  String get homeDealStatusRejected;

  /// No description provided for @homeDealTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get homeDealTabActive;

  /// No description provided for @homeDealTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get homeDealTabCompleted;

  /// No description provided for @homeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get homeDelivery;

  /// No description provided for @homeDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String homeDurationHours(String hours);

  /// No description provided for @homeDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String homeDurationHoursMinutes(String hours, String minutes);

  /// No description provided for @homeDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String homeDurationMinutes(String minutes);

  /// No description provided for @homeEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get homeEditProfile;

  /// No description provided for @homeErrorWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String homeErrorWithDetails(String error);

  /// No description provided for @homeExclusiveOffers.
  ///
  /// In en, this message translates to:
  /// **'Exclusive Offers'**
  String get homeExclusiveOffers;

  /// No description provided for @homeExitCustomerPreview.
  ///
  /// In en, this message translates to:
  /// **'Exit Customer Preview'**
  String get homeExitCustomerPreview;

  /// No description provided for @homeExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get homeExpired;

  /// No description provided for @homeExploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get homeExploreTitle;

  /// No description provided for @homeFeaturedProducts.
  ///
  /// In en, this message translates to:
  /// **'Featured Products'**
  String get homeFeaturedProducts;

  /// No description provided for @homeFieldAddressLine1.
  ///
  /// In en, this message translates to:
  /// **'Address Line 1'**
  String get homeFieldAddressLine1;

  /// No description provided for @homeFieldCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get homeFieldCity;

  /// No description provided for @homeFieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get homeFieldFullName;

  /// No description provided for @homeFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get homeFieldPhone;

  /// No description provided for @homeFieldPincode.
  ///
  /// In en, this message translates to:
  /// **'Pincode'**
  String get homeFieldPincode;

  /// No description provided for @homeFieldState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get homeFieldState;

  /// No description provided for @homeGuestPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'Please login or sign up to continue enjoying all features.'**
  String get homeGuestPromptMessage;

  /// No description provided for @homeGuestPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get homeGuestPromptTitle;

  /// No description provided for @homeGuestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get homeGuestUser;

  /// No description provided for @homeHotDealsCustomer.
  ///
  /// In en, this message translates to:
  /// **'Hot Deals'**
  String get homeHotDealsCustomer;

  /// No description provided for @homeHotDealsDealer.
  ///
  /// In en, this message translates to:
  /// **'Dealer Schemes'**
  String get homeHotDealsDealer;

  /// No description provided for @homeHotDealsSubtitleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Limited-time savings'**
  String get homeHotDealsSubtitleCustomer;

  /// No description provided for @homeHotDealsSubtitleDealer.
  ///
  /// In en, this message translates to:
  /// **'Bulk offers for your business'**
  String get homeHotDealsSubtitleDealer;

  /// No description provided for @homeInvalidCoupon.
  ///
  /// In en, this message translates to:
  /// **'Invalid coupon code'**
  String get homeInvalidCoupon;

  /// No description provided for @homeLoginOrSignUp.
  ///
  /// In en, this message translates to:
  /// **'Login / Sign Up'**
  String get homeLoginOrSignUp;

  /// No description provided for @homeMinWholesaleQtyValue.
  ///
  /// In en, this message translates to:
  /// **'Min. wholesale quantity: {quantity}'**
  String homeMinWholesaleQtyValue(String quantity);

  /// No description provided for @homeMyCart.
  ///
  /// In en, this message translates to:
  /// **'My Cart'**
  String get homeMyCart;

  /// No description provided for @homeMyOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get homeMyOrders;

  /// No description provided for @homeNavCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get homeNavCart;

  /// No description provided for @homeNavCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get homeNavCategories;

  /// No description provided for @homeNavDealDesk.
  ///
  /// In en, this message translates to:
  /// **'Deal Desk'**
  String get homeNavDealDesk;

  /// No description provided for @homeNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeNavHome;

  /// No description provided for @homeNavProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get homeNavProfile;

  /// No description provided for @homeNavSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeNavSearch;

  /// No description provided for @homeNegotiationFallback.
  ///
  /// In en, this message translates to:
  /// **'NEGOTIATION'**
  String get homeNegotiationFallback;

  /// No description provided for @homeNewPriceEffectiveIn.
  ///
  /// In en, this message translates to:
  /// **'New price effective in {time}'**
  String homeNewPriceEffectiveIn(String time);

  /// No description provided for @homeNoBrandsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No brands available'**
  String get homeNoBrandsAvailable;

  /// No description provided for @homeNoBrandsFound.
  ///
  /// In en, this message translates to:
  /// **'No brands found'**
  String get homeNoBrandsFound;

  /// No description provided for @homeNoCategoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get homeNoCategoriesFound;

  /// No description provided for @homeNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get homeNoDate;

  /// No description provided for @homeNoOpenDeals.
  ///
  /// In en, this message translates to:
  /// **'No open deals — browse the catalogue to send your first requirement'**
  String get homeNoOpenDeals;

  /// No description provided for @homeNoProductsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No products available'**
  String get homeNoProductsAvailable;

  /// No description provided for @homeNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get homeNotNow;

  /// No description provided for @homeNotificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get homeNotificationsEmptySubtitle;

  /// No description provided for @homeNotificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get homeNotificationsEmptyTitle;

  /// No description provided for @homeNotificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get homeNotificationsMarkAllRead;

  /// No description provided for @homeNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get homeNotificationsTitle;

  /// No description provided for @homeNotificationsViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All Notifications'**
  String get homeNotificationsViewAll;

  /// No description provided for @homeOfferApplyDuringCheckout.
  ///
  /// In en, this message translates to:
  /// **'Apply during checkout'**
  String get homeOfferApplyDuringCheckout;

  /// No description provided for @homeOfferCode.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}'**
  String homeOfferCode(String code);

  /// No description provided for @homeOfferOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get homeOfferOff;

  /// No description provided for @homeOfferRuleFallback.
  ///
  /// In en, this message translates to:
  /// **'Apply during checkout to unlock offer'**
  String get homeOfferRuleFallback;

  /// No description provided for @homeOfferRuleFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat Rs {value} off on eligible orders'**
  String homeOfferRuleFlat(String value);

  /// No description provided for @homeOfferRulePercent.
  ///
  /// In en, this message translates to:
  /// **'Up to {value}% off on selected products'**
  String homeOfferRulePercent(String value);

  /// No description provided for @homeOrderFallback.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get homeOrderFallback;

  /// No description provided for @homeOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String homeOrderNumber(String number);

  /// No description provided for @homeOrderNumberTotal.
  ///
  /// In en, this message translates to:
  /// **'Order {number} · ₹{amount}'**
  String homeOrderNumberTotal(String number, String amount);

  /// No description provided for @homeOrderStageTotal.
  ///
  /// In en, this message translates to:
  /// **'{stage} · ₹{amount}'**
  String homeOrderStageTotal(String stage, String amount);

  /// No description provided for @homePartnershipsTitle.
  ///
  /// In en, this message translates to:
  /// **'AUTHORIZED REPRESENTATIVE & PARTNERSHIPS'**
  String get homePartnershipsTitle;

  /// No description provided for @homePayableTotal.
  ///
  /// In en, this message translates to:
  /// **'Payable Total'**
  String get homePayableTotal;

  /// No description provided for @homePopularProductsCustomer.
  ///
  /// In en, this message translates to:
  /// **'Popular Products'**
  String get homePopularProductsCustomer;

  /// No description provided for @homePopularProductsDealer.
  ///
  /// In en, this message translates to:
  /// **'Fast-Moving Products'**
  String get homePopularProductsDealer;

  /// No description provided for @homePopularSubtitleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Loved by buyers'**
  String get homePopularSubtitleCustomer;

  /// No description provided for @homePopularSubtitleDealer.
  ///
  /// In en, this message translates to:
  /// **'Popular dealer picks'**
  String get homePopularSubtitleDealer;

  /// No description provided for @homePreviewAddToCartDisabled.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart disabled in preview mode'**
  String get homePreviewAddToCartDisabled;

  /// No description provided for @homePreviewCartMessage.
  ///
  /// In en, this message translates to:
  /// **'Shopping is disabled in preview mode. Your wholesaler cart remains unchanged.'**
  String get homePreviewCartMessage;

  /// No description provided for @homePreviewCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer cart preview'**
  String get homePreviewCartTitle;

  /// No description provided for @homePreviewCheckoutDisabled.
  ///
  /// In en, this message translates to:
  /// **'Checkout disabled in preview mode'**
  String get homePreviewCheckoutDisabled;

  /// No description provided for @homePreviewFeatureDisabled.
  ///
  /// In en, this message translates to:
  /// **'This feature is disabled while viewing the customer experience. Exit preview mode to return to your wholesaler account.'**
  String get homePreviewFeatureDisabled;

  /// No description provided for @homePreviewGuestCustomer.
  ///
  /// In en, this message translates to:
  /// **'Guest Customer'**
  String get homePreviewGuestCustomer;

  /// No description provided for @homePreviewNotificationsHidden.
  ///
  /// In en, this message translates to:
  /// **'Notifications hidden in preview mode'**
  String get homePreviewNotificationsHidden;

  /// No description provided for @homePreviewOffersReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Offers are read-only in preview mode'**
  String get homePreviewOffersReadOnly;

  /// No description provided for @homePreviewProfileMessage.
  ///
  /// In en, this message translates to:
  /// **'This read-only profile shows the guest customer experience without exposing or changing your wholesaler account.'**
  String get homePreviewProfileMessage;

  /// No description provided for @homePreviewWishlistDisabled.
  ///
  /// In en, this message translates to:
  /// **'Wishlist disabled in preview mode'**
  String get homePreviewWishlistDisabled;

  /// No description provided for @homePriceApplyingSoon.
  ///
  /// In en, this message translates to:
  /// **'Applying soon'**
  String get homePriceApplyingSoon;

  /// No description provided for @homeProceedToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get homeProceedToCheckout;

  /// No description provided for @homeProceedToOrder.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Order'**
  String get homeProceedToOrder;

  /// No description provided for @homeProfileAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get homeProfileAbout;

  /// No description provided for @homeProfileAccountPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Account & Privacy'**
  String get homeProfileAccountPrivacy;

  /// No description provided for @homeProfileAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get homeProfileAddresses;

  /// No description provided for @homeProfileApplyWholesaler.
  ///
  /// In en, this message translates to:
  /// **'Apply for wholesaler account'**
  String get homeProfileApplyWholesaler;

  /// No description provided for @homeProfileApplyWholesalerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock bulk pricing & deals'**
  String get homeProfileApplyWholesalerSubtitle;

  /// No description provided for @homeProfileHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get homeProfileHelpSupport;

  /// No description provided for @homeProfileLegalPolicies.
  ///
  /// In en, this message translates to:
  /// **'Legal & Policies'**
  String get homeProfileLegalPolicies;

  /// No description provided for @homeProfileMyCoupons.
  ///
  /// In en, this message translates to:
  /// **'My Coupon & Offer Code'**
  String get homeProfileMyCoupons;

  /// No description provided for @homeProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get homeProfileTitle;

  /// No description provided for @homeProfileViewCustomerApp.
  ///
  /// In en, this message translates to:
  /// **'View Customer App'**
  String get homeProfileViewCustomerApp;

  /// No description provided for @homeProfileViewCustomerAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See what customers see'**
  String get homeProfileViewCustomerAppSubtitle;

  /// No description provided for @homeQtyUnits.
  ///
  /// In en, this message translates to:
  /// **'Qty: {quantity} units'**
  String homeQtyUnits(String quantity);

  /// No description provided for @homeRecentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get homeRecentSearches;

  /// No description provided for @homeRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get homeRejected;

  /// No description provided for @homeRepeatButton.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get homeRepeatButton;

  /// No description provided for @homeRepeatFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not repeat requirement'**
  String get homeRepeatFailed;

  /// No description provided for @homeRepeatItemQty.
  ///
  /// In en, this message translates to:
  /// **'{name} × {quantity}'**
  String homeRepeatItemQty(String name, String quantity);

  /// No description provided for @homeRepeatProductUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Product unavailable for repeat'**
  String get homeRepeatProductUnavailable;

  /// No description provided for @homeRepeatRequirement.
  ///
  /// In en, this message translates to:
  /// **'Repeat Requirement'**
  String get homeRepeatRequirement;

  /// No description provided for @homeRequirementFallback.
  ///
  /// In en, this message translates to:
  /// **'Requirement'**
  String get homeRequirementFallback;

  /// No description provided for @homeRespondToCounter.
  ///
  /// In en, this message translates to:
  /// **'Respond to Counter'**
  String get homeRespondToCounter;

  /// No description provided for @homeReviewsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Voices of Trust'**
  String get homeReviewsEyebrow;

  /// No description provided for @homeReviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'What Our Customers Say'**
  String get homeReviewsTitle;

  /// No description provided for @homeSampleReview1Name.
  ///
  /// In en, this message translates to:
  /// **'Rajesh Kumar'**
  String get homeSampleReview1Name;

  /// No description provided for @homeSampleReview1Role.
  ///
  /// In en, this message translates to:
  /// **'Retail Buyer, Sample City'**
  String get homeSampleReview1Role;

  /// No description provided for @homeSampleReview1Text.
  ///
  /// In en, this message translates to:
  /// **'TradeHub Demo has completely changed how I source my stock. The bulk pricing and quality are unbeatable.'**
  String get homeSampleReview1Text;

  /// No description provided for @homeSampleReview2Name.
  ///
  /// In en, this message translates to:
  /// **'Priya Sharma'**
  String get homeSampleReview2Name;

  /// No description provided for @homeSampleReview2Role.
  ///
  /// In en, this message translates to:
  /// **'Retailer, Demo State'**
  String get homeSampleReview2Role;

  /// No description provided for @homeSampleReview2Text.
  ///
  /// In en, this message translates to:
  /// **'As a retailer, I need reliable delivery and authentic brands. The service on TradeHub Demo is a lifesaver for my business.'**
  String get homeSampleReview2Text;

  /// No description provided for @homeSampleReview3Name.
  ///
  /// In en, this message translates to:
  /// **'Amit Patel'**
  String get homeSampleReview3Name;

  /// No description provided for @homeSampleReview3Role.
  ///
  /// In en, this message translates to:
  /// **'Wholesale Distributor, Gujarat'**
  String get homeSampleReview3Role;

  /// No description provided for @homeSampleReview3Text.
  ///
  /// In en, this message translates to:
  /// **'I\'ve been using TradeHub Demo for a year now. It has greatly simplified how I manage large orders and track inventory.'**
  String get homeSampleReview3Text;

  /// No description provided for @homeSampleReview4Name.
  ///
  /// In en, this message translates to:
  /// **'Anjali Singh'**
  String get homeSampleReview4Name;

  /// No description provided for @homeSampleReview4Role.
  ///
  /// In en, this message translates to:
  /// **'Store Owner, Sample City'**
  String get homeSampleReview4Role;

  /// No description provided for @homeSampleReview4Text.
  ///
  /// In en, this message translates to:
  /// **'The variety of products on TradeHub Demo is impressive. Truly a one-stop shop for wholesale buying.'**
  String get homeSampleReview4Text;

  /// No description provided for @homeSaveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save Address'**
  String get homeSaveAddress;

  /// No description provided for @homeScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get homeScheduled;

  /// No description provided for @homeSearchFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search filter'**
  String get homeSearchFilterTooltip;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search products, brands, categories...'**
  String get homeSearchHint;

  /// No description provided for @homeSearchLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load products. Please try again.'**
  String get homeSearchLoadFailed;

  /// No description provided for @homeSearchLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load more products.'**
  String get homeSearchLoadMoreFailed;

  /// No description provided for @homeSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get homeSearchNoResults;

  /// No description provided for @homeSearchScopeBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get homeSearchScopeBrand;

  /// No description provided for @homeSearchScopeCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get homeSearchScopeCategory;

  /// No description provided for @homeSearchScopeProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get homeSearchScopeProduct;

  /// No description provided for @homeSearchTryChangingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try changing your filters'**
  String get homeSearchTryChangingFilters;

  /// No description provided for @homeShippingAddress.
  ///
  /// In en, this message translates to:
  /// **'Shipping Address'**
  String get homeShippingAddress;

  /// No description provided for @homeSignInToSync.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync data'**
  String get homeSignInToSync;

  /// No description provided for @homeSoldIn24Hrs.
  ///
  /// In en, this message translates to:
  /// **'{count} sold in 24hrs'**
  String homeSoldIn24Hrs(String count);

  /// No description provided for @homeStageCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get homeStageCancelled;

  /// No description provided for @homeStageDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get homeStageDelivered;

  /// No description provided for @homeStageDispatched.
  ///
  /// In en, this message translates to:
  /// **'Dispatched'**
  String get homeStageDispatched;

  /// No description provided for @homeStagePacking.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get homeStagePacking;

  /// No description provided for @homeStagePaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment Pending'**
  String get homeStagePaymentPending;

  /// No description provided for @homeStagePaymentVerified.
  ///
  /// In en, this message translates to:
  /// **'Payment Verified'**
  String get homeStagePaymentVerified;

  /// No description provided for @homeStageVerificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification Pending'**
  String get homeStageVerificationPending;

  /// No description provided for @homeStockIssueFallback.
  ///
  /// In en, this message translates to:
  /// **'Stock issue'**
  String get homeStockIssueFallback;

  /// No description provided for @homeStockIssuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot proceed — stock issues:'**
  String get homeStockIssuesTitle;

  /// No description provided for @homeTapApplyCoupon.
  ///
  /// In en, this message translates to:
  /// **'Tap Apply to use this coupon'**
  String get homeTapApplyCoupon;

  /// No description provided for @homeTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String homeTimeDaysAgo(String days);

  /// No description provided for @homeTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String homeTimeHoursAgo(String hours);

  /// No description provided for @homeTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get homeTimeJustNow;

  /// No description provided for @homeTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'LEFT'**
  String get homeTimeLeft;

  /// No description provided for @homeTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String homeTimeMinutesAgo(String minutes);

  /// No description provided for @homeTopBrands.
  ///
  /// In en, this message translates to:
  /// **'Top Brands'**
  String get homeTopBrands;

  /// No description provided for @homeTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get homeTotalLabel;

  /// No description provided for @homeTrackActiveOrders.
  ///
  /// In en, this message translates to:
  /// **'Track Active Orders'**
  String get homeTrackActiveOrders;

  /// No description provided for @homeTrustBulkSale.
  ///
  /// In en, this message translates to:
  /// **'Bulk Sale Active'**
  String get homeTrustBulkSale;

  /// No description provided for @homeTrustCertifiedProducts.
  ///
  /// In en, this message translates to:
  /// **'Certified Products'**
  String get homeTrustCertifiedProducts;

  /// No description provided for @homeTrustExpertSupport.
  ///
  /// In en, this message translates to:
  /// **'24/7 Expert Support'**
  String get homeTrustExpertSupport;

  /// No description provided for @homeTrustPanIndiaDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pan-India Delivery'**
  String get homeTrustPanIndiaDelivery;

  /// No description provided for @homeTryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get homeTryDifferentSearch;

  /// No description provided for @homeUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get homeUnderReview;

  /// No description provided for @homeUnknownProduct.
  ///
  /// In en, this message translates to:
  /// **'Unknown Product'**
  String get homeUnknownProduct;

  /// No description provided for @homeViewDeals.
  ///
  /// In en, this message translates to:
  /// **'View Deals'**
  String get homeViewDeals;

  /// No description provided for @homeWhyBuyDeliverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pan-India shipping'**
  String get homeWhyBuyDeliverySubtitle;

  /// No description provided for @homeWhyBuyDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Fast Delivery'**
  String get homeWhyBuyDeliveryTitle;

  /// No description provided for @homeWhyBuyPricingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Best wholesale rates'**
  String get homeWhyBuyPricingSubtitle;

  /// No description provided for @homeWhyBuyPricingTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk Pricing'**
  String get homeWhyBuyPricingTitle;

  /// No description provided for @homeWhyBuyQualitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Certified products'**
  String get homeWhyBuyQualitySubtitle;

  /// No description provided for @homeWhyBuyQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Quality'**
  String get homeWhyBuyQualityTitle;

  /// No description provided for @homeWhyBuySupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always here to help'**
  String get homeWhyBuySupportSubtitle;

  /// No description provided for @homeWhyBuySupportTitle.
  ///
  /// In en, this message translates to:
  /// **'24/7 Support'**
  String get homeWhyBuySupportTitle;

  /// No description provided for @homeWhyBuyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why Buy From Us?'**
  String get homeWhyBuyTitle;

  /// No description provided for @homeWishlistCustomer.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get homeWishlistCustomer;

  /// No description provided for @homeWishlistDealer.
  ///
  /// In en, this message translates to:
  /// **'Regular Items'**
  String get homeWishlistDealer;

  /// No description provided for @homeYourPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Price:'**
  String get homeYourPriceLabel;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed to English'**
  String get languageChanged;

  /// No description provided for @languageChooseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime from your profile.'**
  String get languageChooseSubtitle;

  /// No description provided for @languageChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageChooseTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिंदी'**
  String get languageHindi;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @legalCancellationPolicy.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Policy'**
  String get legalCancellationPolicy;

  /// No description provided for @legalCodDeliveryPolicy.
  ///
  /// In en, this message translates to:
  /// **'COD Delivery Policy'**
  String get legalCodDeliveryPolicy;

  /// No description provided for @legalComprehensivePolicies.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive Legal Policies'**
  String get legalComprehensivePolicies;

  /// No description provided for @legalDealerAgreement.
  ///
  /// In en, this message translates to:
  /// **'Dealer Agreement'**
  String get legalDealerAgreement;

  /// No description provided for @legalDealerPricingPolicy.
  ///
  /// In en, this message translates to:
  /// **'Dealer Pricing Policy'**
  String get legalDealerPricingPolicy;

  /// No description provided for @legalEnglishOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'This policy is available in English.'**
  String get legalEnglishOnlyNote;

  /// No description provided for @legalHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal & Policies'**
  String get legalHubTitle;

  /// No description provided for @legalLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load policy content.'**
  String get legalLoadFailed;

  /// No description provided for @legalNotFound.
  ///
  /// In en, this message translates to:
  /// **'Policy not found.'**
  String get legalNotFound;

  /// No description provided for @legalPolicyBadge.
  ///
  /// In en, this message translates to:
  /// **'Policy'**
  String get legalPolicyBadge;

  /// No description provided for @legalPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyPolicy;

  /// No description provided for @legalRefundReturnPolicy.
  ///
  /// In en, this message translates to:
  /// **'Refund & Return Policy'**
  String get legalRefundReturnPolicy;

  /// No description provided for @legalShippingPolicy.
  ///
  /// In en, this message translates to:
  /// **'Shipping Policy'**
  String get legalShippingPolicy;

  /// No description provided for @legalTermsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get legalTermsConditions;

  /// No description provided for @legalWarrantyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Warranty Policy'**
  String get legalWarrantyPolicy;

  /// No description provided for @localNotificationBrand.
  ///
  /// In en, this message translates to:
  /// **'TradeHub Demo'**
  String get localNotificationBrand;

  /// No description provided for @localNotificationCountdownChannel.
  ///
  /// In en, this message translates to:
  /// **'Price Countdown Notifications'**
  String get localNotificationCountdownChannel;

  /// No description provided for @localNotificationCountdownChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Live countdown notifications for scheduled price updates'**
  String get localNotificationCountdownChannelDescription;

  /// No description provided for @localNotificationGeneralChannel.
  ///
  /// In en, this message translates to:
  /// **'General Notifications'**
  String get localNotificationGeneralChannel;

  /// No description provided for @localNotificationGeneralChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'General notifications for TradeHub Demo'**
  String get localNotificationGeneralChannelDescription;

  /// No description provided for @localNotificationPriceUpdateActive.
  ///
  /// In en, this message translates to:
  /// **'A scheduled price update is active.'**
  String get localNotificationPriceUpdateActive;

  /// No description provided for @localNotificationPriceUpdateScheduled.
  ///
  /// In en, this message translates to:
  /// **'Price update scheduled'**
  String get localNotificationPriceUpdateScheduled;

  /// No description provided for @localNotificationPricesApplied.
  ///
  /// In en, this message translates to:
  /// **'New prices are now applied.'**
  String get localNotificationPricesApplied;

  /// No description provided for @localNotificationShopNow.
  ///
  /// In en, this message translates to:
  /// **'Shop Now'**
  String get localNotificationShopNow;

  /// No description provided for @negotiationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Negotiation Completed'**
  String get negotiationCompleted;

  /// No description provided for @negotiationTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Negotiation'**
  String get negotiationTitleFallback;

  /// No description provided for @negotiationsCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current:'**
  String get negotiationsCurrentLabel;

  /// No description provided for @negotiationsEmptyActive.
  ///
  /// In en, this message translates to:
  /// **'No active negotiations'**
  String get negotiationsEmptyActive;

  /// No description provided for @negotiationsEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed negotiations'**
  String get negotiationsEmptyCompleted;

  /// No description provided for @negotiationsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Start negotiating on product pages'**
  String get negotiationsEmptyHint;

  /// No description provided for @negotiationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load negotiations'**
  String get negotiationsLoadFailed;

  /// No description provided for @negotiationsNewPriceFromPlatformLabel.
  ///
  /// In en, this message translates to:
  /// **'New Price from TradeHub Demo:'**
  String get negotiationsNewPriceFromPlatformLabel;

  /// No description provided for @negotiationsNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get negotiationsNoDate;

  /// No description provided for @negotiationsNumberFallback.
  ///
  /// In en, this message translates to:
  /// **'NEGOTIATION'**
  String get negotiationsNumberFallback;

  /// No description provided for @negotiationsTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get negotiationsTabActive;

  /// No description provided for @negotiationsTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get negotiationsTabCompleted;

  /// No description provided for @negotiationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Negotiations'**
  String get negotiationsTitle;

  /// No description provided for @negotiationsTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get negotiationsTotalLabel;

  /// No description provided for @negotiationsUnknownProduct.
  ///
  /// In en, this message translates to:
  /// **'Unknown Product'**
  String get negotiationsUnknownProduct;

  /// No description provided for @negotiationsYourExpectedPrice.
  ///
  /// In en, this message translates to:
  /// **'Your Expected Price:'**
  String get negotiationsYourExpectedPrice;

  /// No description provided for @notificationsDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String notificationsDaysAgo(String count);

  /// No description provided for @notificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see your notifications here'**
  String get notificationsEmptySubtitle;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String notificationsHoursAgo(String count);

  /// No description provided for @notificationsJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get notificationsJustNow;

  /// No description provided for @notificationsMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String notificationsMinutesAgo(String count);

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @onboardingEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get onboardingEnableNotifications;

  /// No description provided for @onboardingNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get onboardingNotNow;

  /// No description provided for @onboardingNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Receive alerts when your order or payment status changes and when price updates are scheduled.'**
  String get onboardingNotificationsBody;

  /// No description provided for @onboardingNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get onboardingNotificationsTitle;

  /// No description provided for @onboardingOtherPermissionsNote.
  ///
  /// In en, this message translates to:
  /// **'Location and photo access are requested only when you choose a current shop location or upload an image.'**
  String get onboardingOtherPermissionsNote;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose whether you would like order, payment, and price-update notifications. You can change this later in device settings.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay updated'**
  String get onboardingTitle;

  /// No description provided for @orderIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get orderIdLabel;

  /// No description provided for @orderNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Order {orderNumber}'**
  String orderNumberLabel(String orderNumber);

  /// No description provided for @orderSuccessDeliveryNote.
  ///
  /// In en, this message translates to:
  /// **'Contact TradeHub Demo to confirm arrangements'**
  String get orderSuccessDeliveryNote;

  /// No description provided for @orderSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your order has been placed successfully.\nWe\'ll notify you once it\'s shipped.'**
  String get orderSuccessMessage;

  /// No description provided for @orderSuccessPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment Verification Pending'**
  String get orderSuccessPaymentPending;

  /// No description provided for @orderSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Confirmed!'**
  String get orderSuccessTitle;

  /// No description provided for @ordersCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{orderType} · {date}'**
  String ordersCardSubtitle(String orderType, String date);

  /// No description provided for @ordersCardSubtitleNegotiated.
  ///
  /// In en, this message translates to:
  /// **'{orderType} · Negotiated price · {date}'**
  String ordersCardSubtitleNegotiated(String orderType, String date);

  /// No description provided for @ordersCourierValue.
  ///
  /// In en, this message translates to:
  /// **'Courier: {courier}'**
  String ordersCourierValue(String courier);

  /// No description provided for @ordersDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get ordersDelivery;

  /// No description provided for @ordersDeliveryDetails.
  ///
  /// In en, this message translates to:
  /// **'Delivery Details'**
  String get ordersDeliveryDetails;

  /// No description provided for @ordersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get ordersEmpty;

  /// No description provided for @ordersFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get ordersFree;

  /// No description provided for @ordersItemQtyPrice.
  ///
  /// In en, this message translates to:
  /// **'Qty: {quantity} × ₹{price}'**
  String ordersItemQtyPrice(String quantity, String price);

  /// No description provided for @ordersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load orders'**
  String get ordersLoadFailed;

  /// No description provided for @ordersMrpValue.
  ///
  /// In en, this message translates to:
  /// **'MRP ₹{price}'**
  String ordersMrpValue(String price);

  /// No description provided for @ordersNegotiatedChip.
  ///
  /// In en, this message translates to:
  /// **'Negotiated'**
  String get ordersNegotiatedChip;

  /// No description provided for @ordersProductFallback.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get ordersProductFallback;

  /// No description provided for @ordersRejectedNoReason.
  ///
  /// In en, this message translates to:
  /// **'This order was not approved. Contact support if you need more information.'**
  String get ordersRejectedNoReason;

  /// No description provided for @ordersRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Rejected'**
  String get ordersRejectedTitle;

  /// No description provided for @ordersSendReceipt.
  ///
  /// In en, this message translates to:
  /// **'Send Receipt'**
  String get ordersSendReceipt;

  /// No description provided for @ordersStartShopping.
  ///
  /// In en, this message translates to:
  /// **'Start Shopping'**
  String get ordersStartShopping;

  /// No description provided for @ordersStatusHistory.
  ///
  /// In en, this message translates to:
  /// **'Status History'**
  String get ordersStatusHistory;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get ordersTitle;

  /// No description provided for @ordersTrackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track Order'**
  String get ordersTrackOrder;

  /// No description provided for @ordersTrackingValue.
  ///
  /// In en, this message translates to:
  /// **'Tracking: {trackingNumber}'**
  String ordersTrackingValue(String trackingNumber);

  /// No description provided for @ordersTypeRetail.
  ///
  /// In en, this message translates to:
  /// **'Retail order'**
  String get ordersTypeRetail;

  /// No description provided for @ordersTypeWholesale.
  ///
  /// In en, this message translates to:
  /// **'Wholesale order'**
  String get ordersTypeWholesale;

  /// No description provided for @ordersViewStatus.
  ///
  /// In en, this message translates to:
  /// **'View Status'**
  String get ordersViewStatus;

  /// No description provided for @priceNoticeChangeIn.
  ///
  /// In en, this message translates to:
  /// **'₹{currentPrice} → ₹{newPrice} in {time}'**
  String priceNoticeChangeIn(String currentPrice, String newPrice, String time);

  /// No description provided for @priceNoticeChangesSoon.
  ///
  /// In en, this message translates to:
  /// **'Price changes soon'**
  String get priceNoticeChangesSoon;

  /// No description provided for @priceNoticeDurationDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String priceNoticeDurationDaysHours(String days, String hours);

  /// No description provided for @priceNoticeDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String priceNoticeDurationHoursMinutes(String hours, String minutes);

  /// No description provided for @priceNoticeDurationMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String priceNoticeDurationMinutesSeconds(String minutes, String seconds);

  /// No description provided for @priceNoticeTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'Time left: {time}'**
  String priceNoticeTimeLeft(String time);

  /// No description provided for @priceNoticeUpcomingChange.
  ///
  /// In en, this message translates to:
  /// **'Upcoming price change'**
  String get priceNoticeUpcomingChange;

  /// No description provided for @privacyAfterDeletionBody.
  ///
  /// In en, this message translates to:
  /// **'Your account access is revoked. Profile details, saved addresses, uploaded account media, carts, notification tokens, notification history, and negotiations are deleted or anonymized. Orders and payment records are kept in restricted records for the applicable legal retention period. Backup handling follows our applicable operational and legal retention requirements.'**
  String get privacyAfterDeletionBody;

  /// No description provided for @privacyAfterDeletionTitle.
  ///
  /// In en, this message translates to:
  /// **'What happens when deletion is completed'**
  String get privacyAfterDeletionTitle;

  /// No description provided for @privacyCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to cancel deletion request.'**
  String get privacyCancelFailed;

  /// No description provided for @privacyCancelPending.
  ///
  /// In en, this message translates to:
  /// **'Cancel pending request'**
  String get privacyCancelPending;

  /// No description provided for @privacyCompleteBy.
  ///
  /// In en, this message translates to:
  /// **'Complete by: {date}'**
  String privacyCompleteBy(String date);

  /// No description provided for @privacyCompletedOn.
  ///
  /// In en, this message translates to:
  /// **'Completed on: {date}'**
  String privacyCompletedOn(String date);

  /// No description provided for @privacyControlsBody.
  ///
  /// In en, this message translates to:
  /// **'Manage your account-deletion request here. You can also submit a request after uninstalling the app at {url}.'**
  String privacyControlsBody(String url);

  /// No description provided for @privacyControlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your privacy controls'**
  String get privacyControlsTitle;

  /// No description provided for @privacyDialogBody.
  ///
  /// In en, this message translates to:
  /// **'We will process your request within 30 days. Direct account data, uploaded business documents, saved addresses, carts, device tokens, and notifications will be removed or anonymized. Financial records may be retained where required for tax, payment, fraud-prevention, dispute, or warranty obligations. Backup handling follows our applicable operational and legal retention requirements.'**
  String get privacyDialogBody;

  /// No description provided for @privacyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion?'**
  String get privacyDialogTitle;

  /// No description provided for @privacyKeepAccount.
  ///
  /// In en, this message translates to:
  /// **'Keep account'**
  String get privacyKeepAccount;

  /// No description provided for @privacyRequestBody.
  ///
  /// In en, this message translates to:
  /// **'After Member verification, we complete deletion within 30 days. Restricted financial records may be retained only for legal, tax, payment, fraud-prevention, dispute, or warranty obligations.'**
  String get privacyRequestBody;

  /// No description provided for @privacyRequestButton.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get privacyRequestButton;

  /// No description provided for @privacyRequestDeletion.
  ///
  /// In en, this message translates to:
  /// **'Request deletion'**
  String get privacyRequestDeletion;

  /// No description provided for @privacyRequestHeading.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get privacyRequestHeading;

  /// No description provided for @privacyStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get privacyStatusCompleted;

  /// No description provided for @privacyStatusReceived.
  ///
  /// In en, this message translates to:
  /// **'Request received'**
  String get privacyStatusReceived;

  /// No description provided for @privacyStatusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get privacyStatusUnderReview;

  /// No description provided for @privacySubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to submit deletion request.'**
  String get privacySubmitFailed;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Account & Privacy'**
  String get privacyTitle;

  /// No description provided for @productAddShort.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get productAddShort;

  /// No description provided for @productAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get productAddToCart;

  /// No description provided for @productAddToCartDisabledPreview.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart disabled in preview mode'**
  String get productAddToCartDisabledPreview;

  /// No description provided for @productAddedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added to cart'**
  String get productAddedToCart;

  /// No description provided for @productBadgeHot.
  ///
  /// In en, this message translates to:
  /// **'HOT'**
  String get productBadgeHot;

  /// No description provided for @productBadgeNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get productBadgeNew;

  /// No description provided for @productBadgeSale.
  ///
  /// In en, this message translates to:
  /// **'SALE'**
  String get productBadgeSale;

  /// No description provided for @productBrandFallback.
  ///
  /// In en, this message translates to:
  /// **'TradeHub Demo'**
  String get productBrandFallback;

  /// No description provided for @productBrandValue.
  ///
  /// In en, this message translates to:
  /// **'Brand: {brand}'**
  String productBrandValue(String brand);

  /// No description provided for @productBulkNegotiation.
  ///
  /// In en, this message translates to:
  /// **'Bulk Negotiation'**
  String get productBulkNegotiation;

  /// No description provided for @productBulkNegotiationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get wholesale pricing for custom bulk orders'**
  String get productBulkNegotiationSubtitle;

  /// No description provided for @productBulkOrder.
  ///
  /// In en, this message translates to:
  /// **'Bulk Order'**
  String get productBulkOrder;

  /// No description provided for @productBulkQuantityNegotiation.
  ///
  /// In en, this message translates to:
  /// **'Bulk Quantity Negotiation'**
  String get productBulkQuantityNegotiation;

  /// No description provided for @productBulkQuantityNegotiationBody.
  ///
  /// In en, this message translates to:
  /// **'Want to deal in more quantity? Send us your requirement and we\'ll get back to you with the best price.'**
  String get productBulkQuantityNegotiationBody;

  /// No description provided for @productBulkUpiNote.
  ///
  /// In en, this message translates to:
  /// **'Bulk orders require manual UPI verification before processing.'**
  String get productBulkUpiNote;

  /// No description provided for @productBuyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy Now'**
  String get productBuyNow;

  /// No description provided for @productBuyNowDisabledPreview.
  ///
  /// In en, this message translates to:
  /// **'Buy Now disabled in preview mode'**
  String get productBuyNowDisabledPreview;

  /// No description provided for @productChooseVariantHint.
  ///
  /// In en, this message translates to:
  /// **'Choose size or pack option'**
  String get productChooseVariantHint;

  /// No description provided for @productConfirmBeforeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Confirm details before submitting'**
  String get productConfirmBeforeSubmit;

  /// No description provided for @productContinueToPricing.
  ///
  /// In en, this message translates to:
  /// **'Continue to Pricing'**
  String get productContinueToPricing;

  /// No description provided for @productCustomQuantity.
  ///
  /// In en, this message translates to:
  /// **'Custom quantity'**
  String get productCustomQuantity;

  /// No description provided for @productDeliveryWithin5Days.
  ///
  /// In en, this message translates to:
  /// **'Delivery within 5 days of Purchase'**
  String get productDeliveryWithin5Days;

  /// No description provided for @productDemoVideo.
  ///
  /// In en, this message translates to:
  /// **'Product Demo'**
  String get productDemoVideo;

  /// No description provided for @productDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get productDescription;

  /// No description provided for @productEnterQuantity.
  ///
  /// In en, this message translates to:
  /// **'Please enter quantity'**
  String get productEnterQuantity;

  /// No description provided for @productExpectedQuantity.
  ///
  /// In en, this message translates to:
  /// **'Expected Quantity'**
  String get productExpectedQuantity;

  /// No description provided for @productExpectedQuantityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 100 units'**
  String get productExpectedQuantityHint;

  /// No description provided for @productGallery.
  ///
  /// In en, this message translates to:
  /// **'Product Gallery'**
  String get productGallery;

  /// No description provided for @productGuestModeDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'This feature is disabled while viewing the customer experience. Exit preview mode to return to your wholesaler account.'**
  String get productGuestModeDisabledMessage;

  /// No description provided for @productHowManyUnits.
  ///
  /// In en, this message translates to:
  /// **'How many units?'**
  String get productHowManyUnits;

  /// No description provided for @productHowManyUnitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select quantity for your bulk quote'**
  String get productHowManyUnitsSubtitle;

  /// No description provided for @productInclTaxes.
  ///
  /// In en, this message translates to:
  /// **'Incl. taxes'**
  String get productInclTaxes;

  /// No description provided for @productLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load product details'**
  String get productLoadFailed;

  /// No description provided for @productLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading product...'**
  String get productLoading;

  /// No description provided for @productMinWholesaleQuantity.
  ///
  /// In en, this message translates to:
  /// **'Minimum wholesale quantity: {quantity}'**
  String productMinWholesaleQuantity(String quantity);

  /// No description provided for @productMrpLabel.
  ///
  /// In en, this message translates to:
  /// **'MRP: '**
  String get productMrpLabel;

  /// No description provided for @productNegotiationSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit negotiation'**
  String get productNegotiationSubmitFailed;

  /// No description provided for @productNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description available for this product.'**
  String get productNoDescription;

  /// No description provided for @productNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get productNotFound;

  /// No description provided for @productOnlyPlatformCanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Only TradeHub Demo can confirm the deal'**
  String get productOnlyPlatformCanConfirm;

  /// No description provided for @productPlaceholderControlPanel.
  ///
  /// In en, this message translates to:
  /// **'Control Panel'**
  String get productPlaceholderControlPanel;

  /// No description provided for @productPlaceholderDrone.
  ///
  /// In en, this message translates to:
  /// **'Agri Drone'**
  String get productPlaceholderDrone;

  /// No description provided for @productPlaceholderFarmTool.
  ///
  /// In en, this message translates to:
  /// **'Farm Tool'**
  String get productPlaceholderFarmTool;

  /// No description provided for @productPlaceholderFencing.
  ///
  /// In en, this message translates to:
  /// **'Fencing'**
  String get productPlaceholderFencing;

  /// No description provided for @productPlaceholderFertilizer.
  ///
  /// In en, this message translates to:
  /// **'Fertilizer'**
  String get productPlaceholderFertilizer;

  /// No description provided for @productPlaceholderGiFitting.
  ///
  /// In en, this message translates to:
  /// **'GI Fitting'**
  String get productPlaceholderGiFitting;

  /// No description provided for @productPlaceholderHarvester.
  ///
  /// In en, this message translates to:
  /// **'Harvester'**
  String get productPlaceholderHarvester;

  /// No description provided for @productPlaceholderIrrigation.
  ///
  /// In en, this message translates to:
  /// **'Irrigation'**
  String get productPlaceholderIrrigation;

  /// No description provided for @productPlaceholderPesticide.
  ///
  /// In en, this message translates to:
  /// **'Pesticide'**
  String get productPlaceholderPesticide;

  /// No description provided for @productPlaceholderPipe.
  ///
  /// In en, this message translates to:
  /// **'Pipe'**
  String get productPlaceholderPipe;

  /// No description provided for @productPlaceholderProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productPlaceholderProduct;

  /// No description provided for @productPlaceholderPumpSet.
  ///
  /// In en, this message translates to:
  /// **'Pump Set'**
  String get productPlaceholderPumpSet;

  /// No description provided for @productPlaceholderRiceMill.
  ///
  /// In en, this message translates to:
  /// **'Rice Mill'**
  String get productPlaceholderRiceMill;

  /// No description provided for @productPlaceholderSeeds.
  ///
  /// In en, this message translates to:
  /// **'Seeds'**
  String get productPlaceholderSeeds;

  /// No description provided for @productPlaceholderStarterOil.
  ///
  /// In en, this message translates to:
  /// **'Starter & Oil'**
  String get productPlaceholderStarterOil;

  /// No description provided for @productPlaceholderTestingKit.
  ///
  /// In en, this message translates to:
  /// **'Testing Kit'**
  String get productPlaceholderTestingKit;

  /// No description provided for @productPlaceholderTractor.
  ///
  /// In en, this message translates to:
  /// **'Tractor'**
  String get productPlaceholderTractor;

  /// No description provided for @productPlaceholderWireCable.
  ///
  /// In en, this message translates to:
  /// **'Wire & Cable'**
  String get productPlaceholderWireCable;

  /// No description provided for @productPriceWithUnit.
  ///
  /// In en, this message translates to:
  /// **'₹{price}/{unit}'**
  String productPriceWithUnit(String price, String unit);

  /// No description provided for @productQtyRetailSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit} other{{count} units}} · Retail: ₹{price}/unit'**
  String productQtyRetailSummary(int count, String price);

  /// No description provided for @productQuickSelect.
  ///
  /// In en, this message translates to:
  /// **'QUICK SELECT'**
  String get productQuickSelect;

  /// No description provided for @productQuotationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Quotation {number} submitted for {count, plural, =1{1 unit} other{{count} units}}!'**
  String productQuotationSubmitted(int count, String number);

  /// No description provided for @productReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get productReadMore;

  /// No description provided for @productRelatedProducts.
  ///
  /// In en, this message translates to:
  /// **'Related Products'**
  String get productRelatedProducts;

  /// No description provided for @productRequirementDetails.
  ///
  /// In en, this message translates to:
  /// **'Requirement Details'**
  String get productRequirementDetails;

  /// No description provided for @productRequirementDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your requirement or target price...'**
  String get productRequirementDetailsHint;

  /// No description provided for @productRetailPrice.
  ///
  /// In en, this message translates to:
  /// **'Retail Price'**
  String get productRetailPrice;

  /// No description provided for @productReviewProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productReviewProduct;

  /// No description provided for @productReviewRequirement.
  ///
  /// In en, this message translates to:
  /// **'Review Requirement'**
  String get productReviewRequirement;

  /// No description provided for @productSaveAmount.
  ///
  /// In en, this message translates to:
  /// **'Save ₹{amount} total ({percent}% off × {quantity} units)'**
  String productSaveAmount(String amount, String percent, String quantity);

  /// No description provided for @productSelectQuantity.
  ///
  /// In en, this message translates to:
  /// **'Select Quantity:'**
  String get productSelectQuantity;

  /// No description provided for @productSelectVariant.
  ///
  /// In en, this message translates to:
  /// **'Select Variant'**
  String get productSelectVariant;

  /// No description provided for @productSendRequirement.
  ///
  /// In en, this message translates to:
  /// **'Send Requirement'**
  String get productSendRequirement;

  /// No description provided for @productSendToDealDesk.
  ///
  /// In en, this message translates to:
  /// **'Send to Deal Desk'**
  String get productSendToDealDesk;

  /// No description provided for @productShareText.
  ///
  /// In en, this message translates to:
  /// **'Check out {name} on TradeHub Demo!\n\n{url}'**
  String productShareText(String name, String url);

  /// No description provided for @productShareTextWithPrice.
  ///
  /// In en, this message translates to:
  /// **'Check out {name} - ₹{price} on TradeHub Demo!\n\n{url}'**
  String productShareTextWithPrice(String name, String price, String url);

  /// No description provided for @productShippingReturns.
  ///
  /// In en, this message translates to:
  /// **'Shipping & Returns'**
  String get productShippingReturns;

  /// No description provided for @productShippingTermsDefault.
  ///
  /// In en, this message translates to:
  /// **'Delivery, payment, and return arrangements depend on the product, order, and location. Contact TradeHub Demo to confirm the applicable terms before payment or dispatch.'**
  String get productShippingTermsDefault;

  /// No description provided for @productShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get productShowLess;

  /// No description provided for @productSkuValue.
  ///
  /// In en, this message translates to:
  /// **'SKU: {sku}'**
  String productSkuValue(String sku);

  /// No description provided for @productSoldLast24h.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit} other{{count} units}} sold in the last 24 hours'**
  String productSoldLast24h(int count);

  /// No description provided for @productSomethingWentWrongDetail.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String productSomethingWentWrongDetail(String error);

  /// No description provided for @productSpecialPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Special Price: '**
  String get productSpecialPriceLabel;

  /// No description provided for @productSpecifications.
  ///
  /// In en, this message translates to:
  /// **'Specifications'**
  String get productSpecifications;

  /// No description provided for @productSubmitQuote.
  ///
  /// In en, this message translates to:
  /// **'Submit Quote'**
  String get productSubmitQuote;

  /// No description provided for @productSuggestedSellingPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggested Selling Price: '**
  String get productSuggestedSellingPriceLabel;

  /// No description provided for @productTapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get productTapToSelect;

  /// No description provided for @productTargetPricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'TARGET PRICE PER UNIT'**
  String get productTargetPricePerUnit;

  /// No description provided for @productTrustEasyReturns.
  ///
  /// In en, this message translates to:
  /// **'Easy Returns'**
  String get productTrustEasyReturns;

  /// No description provided for @productTrustFastDelivery.
  ///
  /// In en, this message translates to:
  /// **'Fast Delivery'**
  String get productTrustFastDelivery;

  /// No description provided for @productTrustReviews.
  ///
  /// In en, this message translates to:
  /// **'Trusted Reviews'**
  String get productTrustReviews;

  /// No description provided for @productTrustSecurePayments.
  ///
  /// In en, this message translates to:
  /// **'Secure Payments'**
  String get productTrustSecurePayments;

  /// No description provided for @productTrustSupport.
  ///
  /// In en, this message translates to:
  /// **'Guaranteed Support'**
  String get productTrustSupport;

  /// No description provided for @productTrustVerifiedProducts.
  ///
  /// In en, this message translates to:
  /// **'Verified Products'**
  String get productTrustVerifiedProducts;

  /// No description provided for @productUnitMeter.
  ///
  /// In en, this message translates to:
  /// **'Meter'**
  String get productUnitMeter;

  /// No description provided for @productUnitPacket.
  ///
  /// In en, this message translates to:
  /// **'Packet'**
  String get productUnitPacket;

  /// No description provided for @productUnitPiece.
  ///
  /// In en, this message translates to:
  /// **'Piece'**
  String get productUnitPiece;

  /// No description provided for @productVariantFallback.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get productVariantFallback;

  /// No description provided for @productVerifiedSeller.
  ///
  /// In en, this message translates to:
  /// **'Verified Seller'**
  String get productVerifiedSeller;

  /// No description provided for @productViewAllSpecifications.
  ///
  /// In en, this message translates to:
  /// **'View all specifications'**
  String get productViewAllSpecifications;

  /// No description provided for @productWholesaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Wholesale: '**
  String get productWholesaleLabel;

  /// No description provided for @productWishlistDisabledPreview.
  ///
  /// In en, this message translates to:
  /// **'Wishlist disabled in preview mode'**
  String get productWishlistDisabledPreview;

  /// No description provided for @productYouSaveVsRetail.
  ///
  /// In en, this message translates to:
  /// **'You save ₹{amount} vs retail'**
  String productYouSaveVsRetail(String amount);

  /// No description provided for @productYourDealerPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Dealer Price: '**
  String get productYourDealerPriceLabel;

  /// No description provided for @productYourExpectedPrice.
  ///
  /// In en, this message translates to:
  /// **'Your Expected Price'**
  String get productYourExpectedPrice;

  /// No description provided for @profileAccountFallback.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountFallback;

  /// No description provided for @profileAddProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get profileAddProduct;

  /// No description provided for @profileAddProductSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a product listing'**
  String get profileAddProductSubtitle;

  /// No description provided for @profileAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get profileAddresses;

  /// No description provided for @profileAddressesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage delivery addresses'**
  String get profileAddressesSubtitle;

  /// No description provided for @profileBecomeWholesaler.
  ///
  /// In en, this message translates to:
  /// **'Become a Wholesaler'**
  String get profileBecomeWholesaler;

  /// No description provided for @profileCompleteWholesalerVerification.
  ///
  /// In en, this message translates to:
  /// **'Complete Wholesaler Verification'**
  String get profileCompleteWholesalerVerification;

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditProfile;

  /// No description provided for @profileEditProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your account information'**
  String get profileEditProfileSubtitle;

  /// No description provided for @profileHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get profileHelpSupport;

  /// No description provided for @profileHelpSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'FAQs and contact information'**
  String get profileHelpSupportSubtitle;

  /// No description provided for @profileNegotiations.
  ///
  /// In en, this message translates to:
  /// **'Negotiations'**
  String get profileNegotiations;

  /// No description provided for @profileNegotiationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View your price negotiations'**
  String get profileNegotiationsSubtitle;

  /// No description provided for @profilePreviousOrders.
  ///
  /// In en, this message translates to:
  /// **'Previous Orders'**
  String get profilePreviousOrders;

  /// No description provided for @profilePreviousOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View order history and status'**
  String get profilePreviousOrdersSubtitle;

  /// No description provided for @profilePrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How we collect and use data'**
  String get profilePrivacySubtitle;

  /// No description provided for @profileSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get profileSectionAccount;

  /// No description provided for @profileSectionActivity.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY'**
  String get profileSectionActivity;

  /// No description provided for @profileSectionSupportLegal.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT & LEGAL'**
  String get profileSectionSupportLegal;

  /// No description provided for @profileSectionWholesale.
  ///
  /// In en, this message translates to:
  /// **'WHOLESALE'**
  String get profileSectionWholesale;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @profileSignOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log out of your account'**
  String get profileSignOutSubtitle;

  /// No description provided for @profileStatusApplicationPending.
  ///
  /// In en, this message translates to:
  /// **'Wholesaler application pending'**
  String get profileStatusApplicationPending;

  /// No description provided for @profileStatusApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Wholesaler application needs attention'**
  String get profileStatusApplicationRejected;

  /// No description provided for @profileStatusCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer account'**
  String get profileStatusCustomer;

  /// No description provided for @profileStatusVerificationRequired.
  ///
  /// In en, this message translates to:
  /// **'Wholesaler verification required'**
  String get profileStatusVerificationRequired;

  /// No description provided for @profileStatusVerifiedWholesaler.
  ///
  /// In en, this message translates to:
  /// **'Verified wholesaler'**
  String get profileStatusVerifiedWholesaler;

  /// No description provided for @profileSubmitBusinessDetails.
  ///
  /// In en, this message translates to:
  /// **'Submit business details for verification'**
  String get profileSubmitBusinessDetails;

  /// No description provided for @profileSubmitBusinessProof.
  ///
  /// In en, this message translates to:
  /// **'Submit business proof for admin review'**
  String get profileSubmitBusinessProof;

  /// No description provided for @profileTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get profileTermsSubtitle;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get profileTitle;

  /// No description provided for @profileViewApplicationStatus.
  ///
  /// In en, this message translates to:
  /// **'View your application status'**
  String get profileViewApplicationStatus;

  /// No description provided for @profileViewCustomerApp.
  ///
  /// In en, this message translates to:
  /// **'View Customer App'**
  String get profileViewCustomerApp;

  /// No description provided for @profileViewCustomerAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See what customers see'**
  String get profileViewCustomerAppSubtitle;

  /// No description provided for @profileWholesalerApplication.
  ///
  /// In en, this message translates to:
  /// **'Wholesaler Application'**
  String get profileWholesalerApplication;

  /// No description provided for @shopLocationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use This Shop Location'**
  String get shopLocationConfirm;

  /// No description provided for @shopLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get your current location. Please try again.'**
  String get shopLocationFailed;

  /// No description provided for @shopLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere on the map to place your shop, or use your current location and adjust it.'**
  String get shopLocationHint;

  /// No description provided for @shopLocationLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating'**
  String get shopLocationLocating;

  /// No description provided for @shopLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get shopLocationPermissionDenied;

  /// No description provided for @shopLocationSelectedCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Selected Coordinates'**
  String get shopLocationSelectedCoordinates;

  /// No description provided for @shopLocationServicesOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off'**
  String get shopLocationServicesOff;

  /// No description provided for @shopLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick Shop Location'**
  String get shopLocationTitle;

  /// No description provided for @shopLocationUseCurrent.
  ///
  /// In en, this message translates to:
  /// **'Use Current'**
  String get shopLocationUseCurrent;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Distribution made simple'**
  String get splashTagline;

  /// No description provided for @statusAcceptedAwaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Accepted · Awaiting Payment'**
  String get statusAcceptedAwaitingPayment;

  /// No description provided for @statusAwaitingAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Submitted · Awaiting Approval'**
  String get statusAwaitingAcceptance;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusDealAcceptedOrderPending.
  ///
  /// In en, this message translates to:
  /// **'Accepted · Order Pending'**
  String get statusDealAcceptedOrderPending;

  /// No description provided for @statusDealOrderCreated.
  ///
  /// In en, this message translates to:
  /// **'Order Created'**
  String get statusDealOrderCreated;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusPaymentUploaded.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Shop Confirmation'**
  String get statusPaymentUploaded;

  /// No description provided for @statusPaymentVerified.
  ///
  /// In en, this message translates to:
  /// **'Payment Confirmed'**
  String get statusPaymentVerified;

  /// No description provided for @statusPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Payment Confirmation'**
  String get statusPendingPayment;

  /// No description provided for @statusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get statusProcessing;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Order Rejected'**
  String get statusRejected;

  /// No description provided for @statusShipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get statusShipped;

  /// No description provided for @trackingContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support if you need more information.'**
  String get trackingContactSupport;

  /// No description provided for @trackingCourier.
  ///
  /// In en, this message translates to:
  /// **'Courier'**
  String get trackingCourier;

  /// No description provided for @trackingCourierInfo.
  ///
  /// In en, this message translates to:
  /// **'Courier Information'**
  String get trackingCourierInfo;

  /// No description provided for @trackingDeliveredDate.
  ///
  /// In en, this message translates to:
  /// **'Delivered Date'**
  String get trackingDeliveredDate;

  /// No description provided for @trackingInvalidOrder.
  ///
  /// In en, this message translates to:
  /// **'This notification does not contain a valid order.'**
  String get trackingInvalidOrder;

  /// No description provided for @trackingItemQtyTotal.
  ///
  /// In en, this message translates to:
  /// **'Qty: {quantity} • ₹{amount}'**
  String trackingItemQtyTotal(String quantity, String amount);

  /// No description provided for @trackingLatestBadge.
  ///
  /// In en, this message translates to:
  /// **'LATEST'**
  String get trackingLatestBadge;

  /// No description provided for @trackingLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load order details. Please try again.'**
  String get trackingLoadFailed;

  /// No description provided for @trackingMoreItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 more item} other{+{count} more items}}'**
  String trackingMoreItems(int count);

  /// No description provided for @trackingNotApproved.
  ///
  /// In en, this message translates to:
  /// **'Order not approved'**
  String get trackingNotApproved;

  /// No description provided for @trackingNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Tracking Number'**
  String get trackingNumberLabel;

  /// No description provided for @trackingOrderGone.
  ///
  /// In en, this message translates to:
  /// **'This order is no longer available.'**
  String get trackingOrderGone;

  /// No description provided for @trackingOrderJourney.
  ///
  /// In en, this message translates to:
  /// **'Order Journey'**
  String get trackingOrderJourney;

  /// No description provided for @trackingOrderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get trackingOrderNotFound;

  /// No description provided for @trackingShippedDate.
  ///
  /// In en, this message translates to:
  /// **'Shipped Date'**
  String get trackingShippedDate;

  /// No description provided for @trackingSignInToView.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to view this order.'**
  String get trackingSignInToView;

  /// No description provided for @trackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Shipment Details'**
  String get trackingTitle;

  /// No description provided for @trackingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Order details are unavailable.'**
  String get trackingUnavailable;

  /// No description provided for @trackingViewPreviousOrders.
  ///
  /// In en, this message translates to:
  /// **'View Previous Orders'**
  String get trackingViewPreviousOrders;

  /// No description provided for @updateCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get updateCurrentVersion;

  /// No description provided for @updateLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get updateLatestVersion;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @updateOpeningStore.
  ///
  /// In en, this message translates to:
  /// **'Opening Store...'**
  String get updateOpeningStore;

  /// No description provided for @updateStoreOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the app store. Check your connection and try again.'**
  String get updateStoreOpenFailed;

  /// No description provided for @wishlistClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get wishlistClearAll;

  /// No description provided for @wishlistClearMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove all items from your wishlist?'**
  String get wishlistClearMessage;

  /// No description provided for @wishlistClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Wishlist?'**
  String get wishlistClearTitle;

  /// No description provided for @wishlistEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save items you love by tapping the\nheart icon on product pages'**
  String get wishlistEmptySubtitle;

  /// No description provided for @wishlistEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your wishlist is empty'**
  String get wishlistEmptyTitle;

  /// No description provided for @wishlistSwipeToRemove.
  ///
  /// In en, this message translates to:
  /// **'Swipe left on an item to remove it'**
  String get wishlistSwipeToRemove;

  /// No description provided for @wishlistTitle.
  ///
  /// In en, this message translates to:
  /// **'My Wishlist'**
  String get wishlistTitle;

  /// No description provided for @productRequirementMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'MESSAGE / DELIVERY REQUIREMENT (OPTIONAL)'**
  String get productRequirementMessageLabel;

  /// No description provided for @productRequirementMessageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. preferred delivery date, packaging or site details'**
  String get productRequirementMessageHint;

  /// No description provided for @productRequirementMessageReview.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get productRequirementMessageReview;

  /// No description provided for @negotiationBuyerMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get negotiationBuyerMessage;
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
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
