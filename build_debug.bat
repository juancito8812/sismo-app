@echo off
set "JAVA_HOME=C:\Users\JRCPU\.jdks\jbr-17.0.14"
set "PATH=%JAVA_HOME%\bin;C:\Users\JRCPU\android-sdk\platform-tools;C:\Users\JRCPU\android-sdk\cmdline-tools\latest\bin;C:\Users\JRCPU\flutter\bin;%PATH%"
flutter.bat build apk --debug
