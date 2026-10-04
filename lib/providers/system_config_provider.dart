import 'dart:async';
import '../core/errors/app_error_handler.dart';
import '../data/models/system_configs_model.dart';
import '../data/repositories/system_config_repository.dart';
import 'base_provider.dart';

class SystemConfigProvider extends BaseProvider {
  final SystemConfigRepository _repository;
  SystemConfigsModel _configs = SystemConfigsModel();
  StreamSubscription? _subscription;

  SystemConfigsModel get configs => _configs;

  SystemConfigProvider({required SystemConfigRepository repository})
      : _repository = repository {
    Future.microtask(() => _init());
  }

  void _init() {
    _subscription = _repository.watchConfigs().listen((newConfigs) {
      _configs = newConfigs;
      safeNotify();
    }, onError: (error) {
      AppErrorHandler.handle(error, operation: 'SystemConfigProvider._init');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
