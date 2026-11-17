QT += core gui quick quickcontrols2 testlib concurrent
CONFIG += c++17 testcase
TARGET = tokentally_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/backend.h ../src/usage.h ../src/theme.h ../src/translator.h
RESOURCES += ../src/resources.qrc
SOURCES += tokentally_tests.cpp ../src/backend.cpp ../src/usage.cpp ../src/theme.cpp ../src/translator.cpp
