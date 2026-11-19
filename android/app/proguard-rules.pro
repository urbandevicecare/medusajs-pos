# Optimize native Android POS bytecode and strip unused symbols
-keep class com.urbandevicecare.pos.model.** { *; }
-keep class com.urbandevicecare.pos.printer.** { *; }
-keep class com.urbandevicecare.pos.scanner.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-dontwarn com.google.zxing.**
