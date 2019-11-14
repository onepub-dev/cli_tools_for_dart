echo Compiling
/usr/lib/dart/bin/dart2native bin/main.dart -o bin/drtimport
echo Installing

# update this line to point to the root of your flutter install.
set FLUTTER_HOME=~/apps
cp bin/drtimport ${FLUTTER_HOME}/flutter/bin/cache/dart-sdk/bin
