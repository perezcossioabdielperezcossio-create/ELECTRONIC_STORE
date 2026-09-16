import 'package:flutter/foundation.dart';
import '../../domain/entities/promoter.dart';
import '../../domain/usecases/get_all_promoters.dart';
import '../../../../core/usecases/usecase.dart';

class PromotersViewModel extends ChangeNotifier {
  final GetAllPromoters _getAll;
  PromotersViewModel({required GetAllPromoters getAll}) : _getAll = getAll;

  List<Promoter> _promoters = [];
  bool _isLoading = false;
  String? _error;

  List<Promoter> get promoters => List.unmodifiable(_promoters);
  bool           get isLoading => _isLoading;
  String?        get error     => _error;

  Future<void> load() async {
    _isLoading = true; notifyListeners();
    final result = await _getAll(const NoParams());
    result.fold(
      (f) { _error = f.message; },
      (list) { _promoters = list; _error = null; },
    );
    _isLoading = false; notifyListeners();
  }
}
