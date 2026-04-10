import 'package:flutter/foundation.dart';
import 'dart:async';
import '../data/models/system_configs_model.dart';
import '../data/repositories/system_config_repository.dart';

class SystemConfigProvider extends ChangeNotifier {
  final SystemConfigRepository _repository;
  SystemConfigsModel _configs = SystemConfigsModel();
  StreamSubscription? _subscription;

  SystemConfigsModel get configs => _configs;

  SystemConfigProvider({required SystemConfigRepository repository}) 
      : _repository = repository {
    _init();
  }

  void _init() {
    _subscription = _repository.watchConfigs().listen((newConfigs) {
      _configs = newConfigs;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
