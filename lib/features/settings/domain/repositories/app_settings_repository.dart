import 'package:iris/features/settings/domain/entities/app_settings.dart';

abstract interface class AppSettingsRepository {
  AppSettings load();

  Future<void> save(AppSettings settings);
}
