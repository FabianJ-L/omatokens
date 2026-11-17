#pragma once

#include <QHash>
#include <QString>
#include <QStringList>
#include <QVector>

// One model response as an agent logged it. Times are UTC milliseconds since
// the epoch; everything shown to the user converts them to local time.
struct UsageRecord {
    qint64 time = 0;
    // Identifies the response across files, because Claude Code copies a
    // resumed session's history into the new log. Zero means "always count".
    quint64 key = 0;
    QString agent;
    QString model;
    QString project;
    qint64 input = 0;
    qint64 output = 0;
    qint64 cacheWrite = 0;
    qint64 cacheRead = 0;

    qint64 total() const { return input + output + cacheWrite + cacheRead; }
};

struct ScannedFile {
    qint64 size = -1;
    qint64 modified = 0;
    QVector<UsageRecord> records;
};

// Parsed logs by canonical path, kept between scans so only files that grew
// or changed are read again.
using ScanCache = QHash<QString, ScannedFile>;

namespace Usage {

QVector<UsageRecord> parseClaudeLog(const QString &path);
QVector<UsageRecord> parseCodexLog(const QString &path);

ScanCache scan(const QStringList &claudeRoots, const QStringList &codexRoots, const ScanCache &previous);

// Every record once, oldest first.
QVector<UsageRecord> merge(const ScanCache &cache);

QStringList defaultClaudeRoots();
QStringList defaultCodexRoots();

} // namespace Usage
