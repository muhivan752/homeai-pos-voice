# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Speech to text
-keep class com.csdcorp.speech_to_text.** { *; }

# Flutter TTS
-keep class com.tundralabs.fluttertts.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
