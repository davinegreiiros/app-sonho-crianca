import 'package:flutter/widgets.dart';

/// Stable widget keys used to target UI elements from integration tests.
/// Centralized here so tests and widgets stay in sync.
class TestKeys {
  TestKeys._();

  static const navHome = ValueKey('nav_home');
  static const navActive = ValueKey('nav_active');
  static const navCatalog = ValueKey('nav_catalog');
  static const navReport = ValueKey('nav_report');

  static const fabNewRental = ValueKey('fab_new_rental');
  static const homeNewRentalButton = ValueKey('home_new_rental_button');

  static const draftChildNameField = ValueKey('draft_child_name_field');
  static const draftGuardianNameField = ValueKey('draft_guardian_name_field');
  static const draftGuardianPhoneField = ValueKey('draft_guardian_phone_field');
  static const submitNewRentalButton = ValueKey('submit_new_rental_button');
  static const cancelNewRentalButton = ValueKey('cancel_new_rental_button');

  static ValueKey activeCardKey(String rentalId) => ValueKey('active_card_$rentalId');
  static ValueKey finishRentalButton(String rentalId) => ValueKey('finish_rental_$rentalId');
  static ValueKey cancelRentalButton(String rentalId) => ValueKey('cancel_rental_$rentalId');
  static ValueKey extendRentalButton(String rentalId, int minutes) => ValueKey('extend_rental_${rentalId}_$minutes');

  static const confirmEndButton = ValueKey('confirm_end_button');
  static ValueKey paymentOption(String method) => ValueKey('payment_option_$method');

  static ValueKey toyCardKey(String toyId) => ValueKey('toy_card_$toyId');
  static const addToySubmitButton = ValueKey('add_toy_submit_button');
  static ValueKey categoryOption(String category) => ValueKey('category_option_$category');

  static const rentalModeFixed = ValueKey('rental_mode_fixed');
  static const rentalModeOpenEnded = ValueKey('rental_mode_open_ended');

  static const settingsGearButton = ValueKey('settings_gear_button');
  static const businessNameField = ValueKey('business_name_field');
  static const businessCityField = ValueKey('business_city_field');
  static const businessPixKeyField = ValueKey('business_pix_key_field');
  static const saveBusinessSettingsButton = ValueKey('save_business_settings_button');
  static const pixQrImage = ValueKey('pix_qr_image');
  static const copyPixPayloadButton = ValueKey('copy_pix_payload_button');
  static const pixQrDoneButton = ValueKey('pix_qr_done_button');
  static const pixTrocarFormaButton = ValueKey('pix_trocar_forma_button');

  static const settingsScreenBackButton = ValueKey('settings_screen_back_button');
}
