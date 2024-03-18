import 'package:analytics/core/analytyc_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_template/api/dio_configurator.dart';
import 'package:flutter_template/common/utils/analytics/firebase/firebase_analytic_strategy.dart';
import 'package:flutter_template/common/utils/analytics/mock/mock_firebase_analytics.dart';
import 'package:flutter_template/common/utils/logger/log_writer.dart';
import 'package:flutter_template/common/utils/logger/strategies/debug_log_strategy.dart';
import 'package:flutter_template/config/app_config.dart';
import 'package:flutter_template/config/environment/environment.dart';
import 'package:flutter_template/config/url.dart';
import 'package:flutter_template/features/app/di/app_scope.dart';
import 'package:flutter_template/features/debug/data/converters/url_converter.dart';
import 'package:flutter_template/persistence/storage/config_storage/config_storage_impl.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surf_logger/surf_logger.dart' as surf_logger;

/// {@template app_scope_register.class}
/// Creates and initializes AppScope
/// {@endtemplate}
final class AppScopeRegister {
  /// {@macro app_scope_register.class}
  const AppScopeRegister();

  /// Create scope
  Future<IAppScope> createScope(Environment env) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final appConfig = await _createAppConfig(env, sharedPreferences);

    final dioConfigurator = AppDioConfigurator();
    final interceptors = <Interceptor>[];
    final dio = dioConfigurator.create(
      interceptors: interceptors,
      url: appConfig.url.value,
      proxyUrl: appConfig.proxyUrl,
    );

    final analyticsService = AnalyticService.withStrategies({
      // TODO(init): can be removed MockFirebaseAnalytics, added for demo analytics track
      FirebaseAnalyticStrategy(MockFirebaseAnalytics()),
    });

    final surfLogger = surf_logger.Logger.withStrategies({
      if (!kReleaseMode) DebugLogStrategy(Logger(printer: PrettyPrinter(methodCount: 0))),
      // TODO(init-project): Initialize CrashlyticsLogStrategy.
      // CrashlyticsLogStrategy(),
    });
    final logger = LogWriter(surfLogger);

    return AppScope(
      env: env,
      appConfig: appConfig,
      sharedPreferences: sharedPreferences,
      dio: dio,
      analyticsService: analyticsService,
      logger: logger,
    );
  }

  Future<AppConfig> _createAppConfig(Environment env, SharedPreferences prefs) async {
    if (env.isProd && kReleaseMode) {
      return AppConfig(url: env.buildType.defaultUrl);
    }

    final savedUrl = await _url(prefs);
    final savedProxyUrl = await _proxyUrl(env, prefs);

    return AppConfig(
      url: savedUrl ?? env.buildType.defaultUrl,
      proxyUrl: savedProxyUrl,
    );
  }

  Future<Url?> _url(SharedPreferences prefs) async {
    const urlTypeConverter = UrlConverter();
    final configStorage = ConfigStorageImpl(prefs);

    final rawUrl = configStorage.getUrlType();
    final savedUrl = urlTypeConverter.converter.convertNullable(rawUrl);

    return savedUrl;
  }

  Future<String?> _proxyUrl(Environment env, SharedPreferences prefs) async {
    final configStorage = ConfigStorageImpl(prefs);
    return configStorage.getProxyUrl();
  }
}
