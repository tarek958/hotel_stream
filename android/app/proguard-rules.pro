# Keep Chewie and VideoPlayer
-keep class com.jhomlala.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class com.google.android.exoplayer.** { *; }
-keep class com.google.android.exoplayer2.** { *; }

# Keep all classes used by the video player
-keep class * extends androidx.media.MediaBrowserServiceCompat { *; }
-keep class * implements androidx.media.MediaBrowserServiceCompat$MediaBrowserServiceImpl { *; }

# Keep JSON models
-keep class **.models.** { *; }
-keep class **.dto.** { *; }
-keep class **.entities.** { *; }

# Network-related classes
-keepclassmembers class * {
    @retrofit2.http.* <methods>;
}
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# For network image loading
-keep class com.bumptech.glide.** { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Fix for clear text traffic (for http URLs)
-keepattributes Exceptions 