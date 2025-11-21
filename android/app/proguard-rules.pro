########################################
## 🧩 FLUTTER CORE
########################################
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

########################################
## 🔥 FIREBASE
########################################
-keep class com.google.firebase.** { *; }

########################################
## 📍 GOOGLE PLAY SERVICES
########################################
-keep class com.google.android.gms.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

########################################
## 🧱 GOOGLE PLAY CORE (Play Store / Split Install)
########################################
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# SplitInstall and SplitCompat
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.listener.** { *; }
-keep class com.google.android.play.core.common.** { *; }

########################################
## 🧱 FLUTTER DEFERRED COMPONENTS
########################################
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }

########################################
## ⚙️ PREVENT WARNINGS
########################################
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.splitcompat.**

########################################
## ✅ KEEP ANNOTATIONS
########################################
-keepattributes *Annotation*
