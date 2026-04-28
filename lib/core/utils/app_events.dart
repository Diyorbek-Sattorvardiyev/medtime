import 'package:flutter/foundation.dart';

class AppEvents {
  const AppEvents._();

  static final medicineChanged = ValueNotifier<int>(0);

  static void notifyMedicineChanged() {
    medicineChanged.value++;
  }
}
