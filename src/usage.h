#pragma once

#include <QHash>
#include <QString>
#include <QStringList>
#include <QVariantMap>
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

// Which agent wrote the logs under a folder, and so how to read them.
enum Kind { Claude, Codex, Gemini, Qwen, OpenCode };

struct Root {
    Kind kind;
    QString path;
};
using Roots = QVector<Root>;

QVector<UsageRecord> parseClaudeLog(const QString &path);
QVector<UsageRecord> parseCodexLog(const QString &path);
// Gemini CLI and Qwen Code (a fork of it) keep one chat per file.
QVector<UsageRecord> parseGeminiChat(const QString &path, const QString &agent);
// OpenCode keeps everything in a SQLite database; older versions wrote one
// JSON file per message.
QVector<UsageRecord> parseOpenCodeDatabase(const QString &path);
QVector<UsageRecord> parseOpenCodeMessage(const QString &path);

ScanCache scan(const Roots &roots, const ScanCache &previous);

// Every record once, oldest first.
QVector<UsageRecord> merge(const ScanCache &cache);

Roots defaultRoots();
QString agentName(Kind kind);

// Claude Desktop samples how much of the plan's limits the account has used
// (chats in the app and on claude.ai, Claude Code, all together). There are
// no token counts for chats anywhere on disk, but this is the same meter the
// app shows. Empty when Claude Desktop isn't installed.
QVariantMap readPlanUsage(const QString &path, qint64 now);
QString defaultPlanFile();

} // namespace Usage
