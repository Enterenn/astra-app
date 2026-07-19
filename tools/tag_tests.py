"""One-shot: apply @Tags to test libraries. Run from repo root."""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "test")

CRITICAL = [
    "widget_test.dart",
    "presentation/screens/app_scaffold_test.dart",
    "presentation/coordinators/app_cubit_coordinator_test.dart",
    "presentation/screens/screen_smoke_test.dart",
    "presentation/cubits/today_cubit_test.dart",
    "presentation/cubits/my_data_cubit_purge_test.dart",
    "presentation/cubits/my_data_cubit_import_test.dart",
    "presentation/cubits/my_data_cubit_export_test.dart",
    "data/datasources/step_normalizer_test.dart",
    "core/database/migrations_test.dart",
    "core/services/app_lifecycle_coordinator_test.dart",
    "data/repositories/step_repository_purge_test.dart",
    "data/repositories/step_repository_import_test.dart",
    "data/repositories/step_repository_export_test.dart",
    "data/repositories/step_repository_today_test.dart",
    "core/health/stale_data_evaluator_test.dart",
    "presentation/widgets/confirm_dialog_test.dart",
    "main_notification_boot_test.dart",
    "main_workmanager_boot_test.dart",
    "core/validation/step_goal_validator_test.dart",
    "data/repositories/user_settings_repository_test.dart",
    "core/di/app_dependencies_test.dart",
]

SLOW = [
    "presentation/cubits/history_cubit_test.dart",
    "presentation/cubits/profile_cubit_test.dart",
    "presentation/cubits/onboarding_cubit_test.dart",
    "core/services/live_step_monitor_test.dart",
    "core/services/live_step_monitor_day_rollover_test.dart",
    "core/services/background_collector_test.dart",
    "core/services/background_collector_factory_test.dart",
    "core/services/workmanager_callback_test.dart",
    "presentation/onboarding/onboarding_flow_test.dart",
    "app_persist_policy_test.dart",
    "presentation/screens/my_data_screen_test.dart",
    "presentation/screens/settings_screen_test.dart",
    "app_lifecycle_transition_test.dart",
    "core/services/data_lifecycle_service_test.dart",
    "data/repositories/step_repository_chart_aggregates_test.dart",
    "data/repositories/step_repository_chart_monthly_aggregates_test.dart",
    "data/repositories/step_repository_downsample_test.dart",
    "data/repositories/step_repository_upsert_test.dart",
    "data/csv/timeseries_csv_codec_test.dart",
    "data/repositories/user_health_metrics_repository_test.dart",
    "data/datasources/step_increment_calculator_test.dart",
    "core/services/notification_service_test.dart",
    "core/services/health_foreground_service_test.dart",
    "core/services/health_foreground_notification_test.dart",
    "core/services/fgs_step_collection_test.dart",
    "core/services/idle_flush_persist_test.dart",
    "core/services/ingestion_collection_lock_test.dart",
    "core/metrics/derived_activity_metrics_test.dart",
    "core/preferences/goal_notification_migration_test.dart",
    "core/time/local_day_boundary_test.dart",
    "core/time/local_day_calculator_test.dart",
    "core/time/local_day_formatter_test.dart",
    "core/time/calendar_week_test.dart",
    "core/ids/sample_id_generator_test.dart",
    "core/database/astra_database_session_test.dart",
    "data/datasources/data_ingestion_source_test.dart",
    "data/datasources/monitor_drain_source_test.dart",
    "data/datasources/phone_pedometer_source_test.dart",
    "android/android_manifest_test.dart",
    "release_manifest_test.dart",
    "app_health_fgs_lifecycle_test.dart",
    "dev/lifecycle_compaction_test.dart",
]


def tag_file(rel: str, tag: str) -> None:
    path = os.path.join(ROOT, rel.replace("/", os.sep))
    if not os.path.isfile(path):
        print("missing", rel)
        return
    text = open(path, encoding="utf-8").read()
    marker = f"@Tags(['{tag}'])"
    if marker in text:
        return
    if text.lstrip().startswith("@Tags"):
        print("skip tagged", rel)
        return
    open(path, "w", encoding="utf-8").write(f"@Tags(['{tag}'])\nlibrary;\n\n" + text)


if __name__ == "__main__":
    for f in CRITICAL:
        tag_file(f, "critical")
    for f in SLOW:
        tag_file(f, "slow")
