import 'package:flutter/foundation.dart';
import 'package:flutter_command/flutter_command.dart';

class HistorySelectionViewModel extends ChangeNotifier {
  HistorySelectionViewModel() {
    selectDate = Command.createSyncNoResult<String?>((date) {
      if (_selectedDate == date) return;
      _selectedDate = date;
      notifyListeners();
    });
  }

  String? _selectedDate;
  String? get selectedDate => _selectedDate;
  late final Command<String?, void> selectDate;

  @override
  void dispose() {
    selectDate.dispose();
    super.dispose();
  }
}
