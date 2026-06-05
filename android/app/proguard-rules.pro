# WorkManager (workmanager plugin) — R8 full mode (AGP 9+) strips no-arg constructors
# reached only via reflection (WorkDatabase_Impl, InputMerger, etc.).
-keep class androidx.work.** { <init>(...); }
-keep class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-dontwarn androidx.work.**

# Room types generated for WorkManager's internal database.
-keep class * extends androidx.room.RoomDatabase { <init>(...); }
-keep @androidx.room.Entity class *
-dontwarn androidx.room.**

# Flutter workmanager plugin worker.
-keep class dev.fluttercommunity.workmanager.** { *; }
