# Reglas de Proguard para evitar que R8 elimine código crítico de firma de PDF
-dontwarn org.slf4j.**
-dontwarn java.awt.**
-dontwarn javax.xml.crypto.**
-dontwarn javax.naming.**
-dontwarn javax.imageio.**
-dontwarn com.fasterxml.jackson.**
-dontwarn org.bouncycastle.**
-keep class com.itextpdf.** { *; }
-keep class org.bouncycastle.** { *; }
