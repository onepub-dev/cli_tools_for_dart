echo Compiling
/usr/lib/dart/bin/dart2native bin/main.dart -o bin/drtimport
echo Installing
cp bin/drtimport /home/bsutton/apps/flutter/bin/cache/dart-sdk/bin
