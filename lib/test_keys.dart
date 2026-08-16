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

  static const confirmEndButton = ValueKey('confirm_end_button');
  static ValueKey paymentOption(String method) => ValueKey('payment_option_$method');
}
