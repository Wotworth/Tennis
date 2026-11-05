# PHO-10 (6 Nov): keep ML Kit's text recognition whole. Release shrinking renamed and merged its
# internal classes, and on the phone it then failed with "Attempt to read from field ... on a null
# object reference" (Chris's report). ML Kit finds its own parts by class at run time.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class com.google.android.odml.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
