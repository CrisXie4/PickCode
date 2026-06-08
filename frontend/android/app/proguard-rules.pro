# Flutter
-keep class io.flutter.** { *; }

# ML Kit text recognition —— 插件引用了中/日/韩/梵文等语言识别类，
# 但这些是独立的 ML Kit 模型，未作为依赖打包，R8 压缩时会报 Missing class。
# 这里抑制相关警告并保留 ML Kit 类，避免 minifyReleaseWithR8 失败。
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# Google Play Core —— Flutter 的延迟组件/动态分发(deferred components)代码引用了
# Play Core split-install 类，但本项目未使用该功能也未引入 play-core 依赖，
# R8 压缩时会报 Missing class。这里抑制相关警告。
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
