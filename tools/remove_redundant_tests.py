"""Remove redundant tests — each entry reviewed 2026-07-19."""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "test")

# Rationale summary in spec-test-suite-cleanup.md Phase D
DELETE = [
    # Widget atomics — covered by screen_smoke + app_scaffold
    "presentation/widgets/goal_ring_test.dart",
    "presentation/widgets/activity_stats_row_test.dart",
    "presentation/widgets/week_progress_row_test.dart",
    "presentation/widgets/step_bar_chart_test.dart",
    "presentation/widgets/chart/astra_bar_chart_painter_test.dart",
    "presentation/widgets/chart/astra_bar_chart_core_test.dart",
    "presentation/widgets/trends_monthly_bar_chart_test.dart",
    "presentation/widgets/trends_average_stats_row_test.dart",
    "presentation/widgets/trends_peak_day_card_test.dart",
    "presentation/widgets/trend_chip_test.dart",
    "presentation/widgets/astra_horizontal_ruler_test.dart",
    "presentation/widgets/animated_step_count_test.dart",
    "presentation/widgets/goal_celebration_test.dart",
    "presentation/widgets/profile_editor_sheets_test.dart",
    "presentation/widgets/theme_selector_test.dart",
    "presentation/widgets/accent_preset_selector_test.dart",
    "presentation/widgets/period_toggle_test.dart",
    "presentation/widgets/status_banner_test.dart",
    "presentation/widgets/collection_health_indicator_test.dart",
    "presentation/widgets/background_status_card_test.dart",
    "presentation/widgets/footprint_kpi_row_test.dart",
    "presentation/widgets/display_name_editor_row_test.dart",
    "presentation/widgets/week_trophy_badge_test.dart",
    "presentation/widgets/sheet_drag_handle_test.dart",
    "presentation/widgets/section_card_test.dart",
    "presentation/widgets/secondary_screen_header_test.dart",
    "presentation/widgets/bar_chart_layout_test.dart",
    "presentation/widgets/astra_pressable_test.dart",
    "presentation/widgets/astra_inset_shadow_test.dart",
    "presentation/widgets/astra_bar_loading_skeleton_test.dart",
    "presentation/widgets/ruler_tick_scroll_physics_test.dart",
    "presentation/widgets/chart_axis_ticks_test.dart",
    "presentation/widgets/astra_button_test.dart",
    "presentation/widgets/astra_segmented_control_test.dart",
    "presentation/widgets/goal_editor_sheet_test.dart",
    "presentation/widgets/unit_option_picker_sheet_test.dart",
    # Screens — redundant with scaffold/smoke/cubits; settings+my_data kept (slow)
    "presentation/screens/today_screen_selector_test.dart",  # selector perf; cubit+smoke cover UX
    "presentation/screens/profile_screen_test.dart",  # settings_screen covers profile prefs
    "presentation/screens/about_screen_test.dart",
    "presentation/screens/menu_hub_screen_test.dart",
    "presentation/screens/today_screen_trophy_test.dart",
    # Cubits — duplicate or covered by specialized my_data_* tests
    "presentation/cubits/today_cubit_contract_test.dart",
    "presentation/cubits/theme_cubit_test.dart",
    "presentation/cubits/units_cubit_test.dart",
    "presentation/cubits/my_data_cubit_test.dart",
    "presentation/cubits/my_data_cubit_goal_test.dart",
    # Formatters / utils / helpers — trivial or UI-covered
    "presentation/formatters/display_unit_formatter_test.dart",
    "presentation/formatters/footprint_formatters_test.dart",
    "presentation/formatters/activity_metrics_formatter_test.dart",
    "presentation/utils/display_name_initials_test.dart",
    "presentation/helpers/collection_health_evaluator_test.dart",
    "presentation/l10n/language_l10n_test.dart",
    # Design tokens — compile-time
    "core/constants/astra_colors_test.dart",
    "core/constants/astra_accent_presets_test.dart",
    "core/constants/astra_typography_tokens_test.dart",
    "core/constants/display_unit_preferences_test.dart",
    "core/icons/phosphor_icons_subset_test.dart",
    "core/debug/live_pipeline_log_test.dart",
    # l10n spot checks — ARB compile is enough
    "l10n/migrated_strings_fr_test.dart",
    "l10n/locale_preference_binding_test.dart",
    "l10n/app_localizations_scaffold_test.dart",
    # Granular repo/model — covered by integration cubits/screens
    "data/models/timeseries_sample_model_test.dart",
    "data/repositories/step_repository_footprint_test.dart",
    "data/repositories/step_repository_last_ingestion_test.dart",
    "data/repositories/step_repository_dev_batch_test.dart",
    "data/repositories/step_repository_active_buckets_test.dart",
    "data/repositories/ingestion_baseline_repository_test.dart",
    "core/database/isolate_database_factory_test.dart",
]

if __name__ == "__main__":
    n = 0
    for rel in DELETE:
        path = os.path.join(ROOT, rel.replace("/", os.sep))
        if os.path.isfile(path):
            os.remove(path)
            n += 1
            print("removed", rel)
        else:
            print("missing", rel)
    print("removed_files", n)
