# ── ProGuard / R8 Rules — Kasir Dapur ────────────────────────────────────────

# Flutter — jangan obfuscate embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter plugins
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# SQLite / sqflite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Kotlin coroutines
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

# Gson / JSON (digunakan oleh beberapa plugin)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp (networking — sync, subscription)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Retrofit
-keepattributes Signature, Exceptions
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }

# Bluetooth thermal printer
-keep class com.xhunold.** { *; }
-dontwarn com.xhunold.**

# Mobile scanner / ZXing barcode
-keep class com.google.zxing.** { *; }
-dontwarn com.google.zxing.**

# image_picker / camera
-keep class io.flutter.plugins.imagepicker.** { *; }

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# PDF / printing
-keep class com.pdf.printing.** { *; }

# Jaga class MainActivity
-keep class com.kasirdapur.app.MainActivity { *; }

# Jaga semua annotation
-keepattributes *Annotation*
-keepattributes SourceFile, LineNumberTable

# Jaga stack trace agar bisa di-debug
-renamesourcefileattribute SourceFile
