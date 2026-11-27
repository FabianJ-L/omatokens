QT += core gui qml quick quickcontrols2 concurrent sql

CONFIG += c++17 release
TARGET = omatokens
TEMPLATE = app

HEADERS += \
    src/backend.h \
    src/usage.h \
    src/theme.h \
    src/translator.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/usage.cpp \
    src/theme.cpp \
    src/translator.cpp

RESOURCES += src/resources.qrc
