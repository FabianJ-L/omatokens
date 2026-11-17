#include "usage.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <algorithm>

namespace {

qint64 parseTime(const QString &text) {
    const QDateTime time = QDateTime::fromString(text, Qt::ISODateWithMs);
    return time.isValid() ? time.toMSecsSinceEpoch() : 0;
}

// Projects are named after the folder the agent ran in, which is what people
// recognise; the home folder itself reads better as "~".
QString projectName(const QString &cwd) {
    if (cwd.isEmpty())
        return {};
    const QString clean = QDir::cleanPath(cwd);
    if (clean == QDir::homePath())
        return "~";
    return QFileInfo(clean).fileName();
}

} // namespace

QVector<UsageRecord> Usage::parseClaudeLog(const QString &path) {
    QVector<UsageRecord> records;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return records;

    while (!file.atEnd()) {
        const QByteArray line = file.readLine();
        // Most lines are tool output and prompts; skip them before parsing.
        if (!line.contains("\"usage\""))
            continue;
        const QJsonObject entry = QJsonDocument::fromJson(line).object();
        if (entry.value("type").toString() != "assistant")
            continue;
        const QJsonObject message = entry.value("message").toObject();
        const QJsonObject usage = message.value("usage").toObject();
        const QString model = message.value("model").toString();
        // Synthetic messages are written by Claude Code itself, not a model.
        if (usage.isEmpty() || model.isEmpty() || model == "<synthetic>")
            continue;

        UsageRecord record;
        record.time = parseTime(entry.value("timestamp").toString());
        if (!record.time)
            continue;
        record.agent = "Claude Code";
        record.model = model;
        record.project = projectName(entry.value("cwd").toString());
        record.input = usage.value("input_tokens").toInteger();
        record.output = usage.value("output_tokens").toInteger();
        record.cacheWrite = usage.value("cache_creation_input_tokens").toInteger();
        record.cacheRead = usage.value("cache_read_input_tokens").toInteger();
        if (!record.total())
            continue;

        // A response with several content blocks is logged once per block,
        // each with the same id and usage, so it must only count once.
        const QString id = message.value("id").toString();
        if (!id.isEmpty())
            record.key = qHash(id + ':' + entry.value("requestId").toString(), 0) | 1;
        records.append(record);
    }
    return records;
}

QVector<UsageRecord> Usage::parseCodexLog(const QString &path) {
    QVector<UsageRecord> records;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return records;

    QString model, project;
    qint64 lastTotal = -1;
    while (!file.atEnd()) {
        const QByteArray line = file.readLine();
        if (!line.contains("token_count") && !line.contains("turn_context") && !line.contains("session_meta"))
            continue;
        const QJsonObject entry = QJsonDocument::fromJson(line).object();
        const QString type = entry.value("type").toString();
        const QJsonObject payload = entry.value("payload").toObject();

        if (type == "session_meta" || type == "turn_context") {
            if (payload.contains("model"))
                model = payload.value("model").toString();
            if (payload.contains("cwd"))
                project = projectName(payload.value("cwd").toString());
            continue;
        }
        if (payload.value("type").toString() != "token_count")
            continue;
        const QJsonObject info = payload.value("info").toObject();
        if (info.isEmpty())
            continue;

        // Codex repeats the last count when nothing new was spent (rate limit
        // updates, for example); the running total tells the two apart.
        const qint64 total = info.value("total_token_usage").toObject().value("total_tokens").toInteger();
        if (total == lastTotal)
            continue;
        lastTotal = total;

        const QJsonObject last = info.value("last_token_usage").toObject();
        UsageRecord record;
        record.time = parseTime(entry.value("timestamp").toString());
        if (!record.time)
            continue;
        record.agent = "Codex";
        record.model = model.isEmpty() ? QStringLiteral("codex") : model;
        record.project = project;
        // OpenAI counts cached tokens inside input_tokens, while Claude counts
        // them separately; split them so both agents mean the same thing.
        const qint64 cached = last.value("cached_input_tokens").toInteger();
        record.input = std::max<qint64>(0, last.value("input_tokens").toInteger() - cached);
        record.cacheRead = cached;
        record.cacheWrite = last.value("cache_write_input_tokens").toInteger();
        record.output = last.value("output_tokens").toInteger();
        if (record.total())
            records.append(record);
    }
    return records;
}

ScanCache Usage::scan(const QStringList &claudeRoots, const QStringList &codexRoots, const ScanCache &previous) {
    ScanCache next;
    auto walk = [&](const QStringList &roots, bool codex) {
        for (const QString &root : roots) {
            QDirIterator it(root, {"*.jsonl"}, QDir::Files, QDirIterator::Subdirectories | QDirIterator::FollowSymlinks);
            while (it.hasNext()) {
                const QFileInfo info(it.next());
                // Roots can overlap through symlinks (~/.config/claude), so
                // files are keyed by where they really are.
                const QString path = info.canonicalFilePath();
                if (path.isEmpty() || next.contains(path))
                    continue;
                ScannedFile file;
                file.size = info.size();
                file.modified = info.lastModified().toMSecsSinceEpoch();
                const auto old = previous.constFind(path);
                if (old != previous.cend() && old->size == file.size && old->modified == file.modified)
                    file.records = old->records;
                else
                    file.records = codex ? parseCodexLog(path) : parseClaudeLog(path);
                next.insert(path, file);
            }
        }
    };
    walk(claudeRoots, false);
    walk(codexRoots, true);
    return next;
}

QVector<UsageRecord> Usage::merge(const ScanCache &cache) {
    QVector<UsageRecord> all;
    QSet<quint64> seen;
    for (const ScannedFile &file : cache) {
        for (const UsageRecord &record : file.records) {
            if (record.key) {
                if (seen.contains(record.key))
                    continue;
                seen.insert(record.key);
            }
            all.append(record);
        }
    }
    std::stable_sort(all.begin(), all.end(), [](const UsageRecord &a, const UsageRecord &b) { return a.time < b.time; });
    return all;
}

QStringList Usage::defaultClaudeRoots() {
    QStringList roots;
    const QString configured = qEnvironmentVariable("CLAUDE_CONFIG_DIR");
    for (const QString &dir : configured.split(',', Qt::SkipEmptyParts))
        roots << dir.trimmed() + "/projects";
    roots << QDir::homePath() + "/.claude/projects" << QDir::homePath() + "/.config/claude/projects";
    roots.removeDuplicates();
    return roots;
}

QStringList Usage::defaultCodexRoots() {
    const QString home = qEnvironmentVariable("CODEX_HOME", QDir::homePath() + "/.codex");
    return {home + "/sessions", home + "/archived_sessions"};
}
