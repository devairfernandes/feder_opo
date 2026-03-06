# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep specific plugins
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class io.flutter.plugins.packageinfo.** { *; }
-keep class com.it_nomads.flutter_ota_update.** { *; }
