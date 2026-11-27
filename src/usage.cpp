#include "usage.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlRecord>
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

namespace {

// Gemini CLI names each project folder after a hash of its path, and newer
// versions after the folder itself; the real path, when it's written down,
// sits next to the chats.
QString geminiProject(const QString &chatPath) {
    const QDir projectDir = QFileInfo(chatPath).dir().filePath("..");
    QFile root(projectDir.filePath(".project_root"));
    if (root.open(QIODevice::ReadOnly))
        return projectName(QString::fromUtf8(root.readAll()).trimmed());
    static const QRegularExpression hash("^[0-9a-f]{40,}$");
    const QString name = QFileInfo(QDir::cleanPath(projectDir.absolutePath())).fileName();
    return hash.match(name).hasMatch() ? QString() : name;
}

// One Gemini or Qwen message. Gemini CLI writes its own "tokens" summary,
// Qwen Code the API's usageMetadata; both count cached tokens inside the
// prompt, and thinking separately from the answer.
bool geminiRecord(const QJsonObject &message, const QString &agent, const QString &session,
                  const QString &project, UsageRecord *record) {
    qint64 prompt = 0, cached = 0, output = 0, thoughts = 0, tool = 0;
    const QJsonObject tokens = message.value("tokens").toObject();
    const QJsonObject meta = message.value("usageMetadata").toObject();
    if (!tokens.isEmpty()) {
        prompt = tokens.value("input").toInteger();
        cached = tokens.value("cached").toInteger();
        output = tokens.value("output").toInteger();
        thoughts = tokens.value("thoughts").toInteger();
        tool = tokens.value("tool").toInteger();
    } else if (!meta.isEmpty()) {
        prompt = meta.value("promptTokenCount").toInteger();
        cached = meta.value("cachedContentTokenCount").toInteger();
        output = meta.value("candidatesTokenCount").toInteger();
        thoughts = meta.value("thoughtsTokenCount").toInteger();
        tool = meta.value("toolUsePromptTokenCount").toInteger();
    } else {
        return false;
    }
    record->time = parseTime(message.value("timestamp").toString());
    if (!record->time)
        return false;
    record->agent = agent;
    record->model = message.value("model").toString();
    if (record->model.isEmpty())
        record->model = agent == "Qwen Code" ? QStringLiteral("qwen") : QStringLiteral("gemini");
    const QString cwd = message.value("cwd").toString();
    record->project = cwd.isEmpty() ? project : projectName(cwd);
    record->input = std::max<qint64>(0, prompt - cached) + tool;
    record->cacheRead = cached;
    record->output = output + thoughts;
    QString id = message.value("id").toString();
    if (id.isEmpty())
        id = message.value("uuid").toString();
    if (!id.isEmpty())
        record->key = qHash(agent + ':' + message.value("sessionId").toString(session) + ':' + id, 0) | 1;
    return record->total() > 0;
}

// OpenCode stores each assistant message as JSON, in a file or a database
// row. Its input already leaves the cache out, as Claude's does.
bool openCodeRecord(const QJsonObject &data, const QString &fallbackId, qint64 fallbackTime,
                    const QString &fallbackDir, UsageRecord *record) {
    const QString role = data.value("role").toString();
    if (!role.isEmpty() && role != "assistant")
        return false;
    const QJsonObject tokens = data.value("tokens").toObject();
    if (tokens.isEmpty())
        return false;
    const QJsonObject cache = tokens.value("cache").toObject();
    record->input = tokens.value("input").toInteger();
    record->output = tokens.value("output").toInteger() + tokens.value("reasoning").toInteger();
    record->cacheRead = cache.value("read").toInteger();
    record->cacheWrite = cache.value("write").toInteger();
    if (!record->total())
        return false;

    const QJsonValue created = data.value("time").toObject().value("created");
    qint64 time = created.isString() ? parseTime(created.toString()) : created.toInteger();
    if (!time)
        time = fallbackTime;
    // Seconds, not milliseconds.
    if (time > 0 && time < 100000000000LL)
        time *= 1000;
    if (time <= 0)
        return false;
    record->time = time;
    record->agent = "OpenCode";

    const QJsonValue model = data.value("model");
    record->model = data.value("modelID").toString();
    if (record->model.isEmpty())
        record->model = model.isObject() ? model.toObject().value("id").toString() : model.toString();
    if (record->model.isEmpty())
        record->model = "opencode";
    const QJsonObject path = data.value("path").toObject();
    QString cwd = path.value("cwd").toString();
    if (cwd.isEmpty())
        cwd = path.value("root").toString();
    record->project = projectName(cwd.isEmpty() ? fallbackDir : cwd);

    const QString id = data.value("id").toString(fallbackId);
    if (!id.isEmpty())
        record->key = qHash("opencode:" + id, 0) | 1;
    return true;
}

} // namespace

QVector<UsageRecord> Usage::parseGeminiChat(const QString &path, const QString &agent) {
    QVector<UsageRecord> records;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return records;
    const QString project = geminiProject(path);
    const QString fileSession = QFileInfo(path).completeBaseName();

    if (path.endsWith(".jsonl")) {
        while (!file.atEnd()) {
            const QByteArray line = file.readLine();
            if (!line.contains("okens") && !line.contains("TokenCount"))
                continue;
            UsageRecord record;
            if (geminiRecord(QJsonDocument::fromJson(line).object(), agent, fileSession, project, &record))
                records.append(record);
        }
        return records;
    }

    const QJsonObject chat = QJsonDocument::fromJson(file.readAll()).object();
    const QString session = chat.value("sessionId").toString(fileSession);
    for (const QJsonValue &value : chat.value("messages").toArray()) {
        UsageRecord record;
        if (geminiRecord(value.toObject(), agent, session, project, &record))
            records.append(record);
    }
    return records;
}

QVector<UsageRecord> Usage::parseOpenCodeMessage(const QString &path) {
    QVector<UsageRecord> records;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return records;
    UsageRecord record;
    if (openCodeRecord(QJsonDocument::fromJson(file.readAll()).object(), QFileInfo(path).completeBaseName(), 0, {},
                       &record))
        records.append(record);
    return records;
}

QVector<UsageRecord> Usage::parseOpenCodeDatabase(const QString &path) {
    QVector<UsageRecord> records;
    // Scans run on worker threads, and a connection belongs to the thread
    // that made it, so each read gets its own.
    static QAtomicInt counter;
    const QString connection = QStringLiteral("tokentally-opencode-%1").arg(counter.fetchAndAddRelaxed(1));
    {
        QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connection);
        db.setDatabaseName(path);
        db.setConnectOptions("QSQLITE_OPEN_READONLY;QSQLITE_BUSY_TIMEOUT=2000");
        if (db.open()) {
            const QStringList tables = db.tables();
            // Where each session ran, for messages that don't say.
            QHash<QString, QString> directories;
            if (tables.contains("session")) {
                QSqlQuery query(db);
                if (query.exec("SELECT * FROM session")) {
                    const QSqlRecord columns = query.record();
                    const int id = columns.indexOf("id"), dir = columns.indexOf("directory");
                    while (id >= 0 && dir >= 0 && query.next())
                        directories.insert(query.value(id).toString(), query.value(dir).toString());
                }
            }
            // OpenCode 1.x keeps messages in "message", 2.x in "session_message";
            // either way the message itself is a JSON column.
            for (const QString &table : {QStringLiteral("message"), QStringLiteral("session_message")}) {
                if (!tables.contains(table))
                    continue;
                QSqlQuery query(db);
                query.setForwardOnly(true);
                if (!query.exec("SELECT * FROM " + table))
                    continue;
                const QSqlRecord columns = query.record();
                const int data = columns.indexOf("data"), id = columns.indexOf("id");
                const int session = columns.indexOf("session_id"), created = columns.indexOf("time_created");
                if (data < 0)
                    continue;
                while (query.next()) {
                    const QByteArray json = query.value(data).toByteArray();
                    if (!json.contains("tokens"))
                        continue;
                    UsageRecord record;
                    if (openCodeRecord(QJsonDocument::fromJson(json).object(),
                                       id >= 0 ? query.value(id).toString() : QString(),
                                       created >= 0 ? query.value(created).toLongLong() : 0,
                                       session >= 0 ? directories.value(query.value(session).toString()) : QString(),
                                       &record))
                        records.append(record);
                }
            }
            db.close();
        }
    }
    QSqlDatabase::removeDatabase(connection);
    return records;
}

QString Usage::agentName(Kind kind) {
    switch (kind) {
    case Claude: return "Claude Code";
    case Codex: return "Codex";
    case Gemini: return "Gemini CLI";
    case Qwen: return "Qwen Code";
    case OpenCode: return "OpenCode";
    }
    return {};
}

ScanCache Usage::scan(const Roots &roots, const ScanCache &previous) {
    ScanCache next;
    // A SQLite database in WAL mode grows its -wal file first, so both count
    // toward whether it changed.
    auto add = [&](const QFileInfo &info, Kind kind) {
        // Roots can overlap through symlinks (~/.config/claude), so files are
        // keyed by where they really are.
        const QString path = info.canonicalFilePath();
        if (path.isEmpty() || next.contains(path))
            return;
        ScannedFile file;
        file.size = info.size();
        file.modified = info.lastModified().toMSecsSinceEpoch();
        const bool database = path.endsWith(".db");
        if (database) {
            const QFileInfo wal(path + "-wal");
            if (wal.exists()) {
                file.size += wal.size();
                file.modified = std::max(file.modified, wal.lastModified().toMSecsSinceEpoch());
            }
        }
        const auto old = previous.constFind(path);
        if (old != previous.cend() && old->size == file.size && old->modified == file.modified) {
            file.records = old->records;
        } else {
            switch (kind) {
            case Claude: file.records = parseClaudeLog(path); break;
            case Codex: file.records = parseCodexLog(path); break;
            case Gemini:
            case Qwen: file.records = parseGeminiChat(path, agentName(kind)); break;
            case OpenCode: file.records = database ? parseOpenCodeDatabase(path) : parseOpenCodeMessage(path); break;
            }
        }
        next.insert(path, file);
    };

    for (const Root &root : roots) {
        if (root.kind == OpenCode) {
            const QFileInfoList dbs = QDir(root.path).entryInfoList({"opencode*.db"}, QDir::Files);
            for (const QFileInfo &info : dbs)
                add(info, OpenCode);
            QDirIterator it(root.path + "/storage/message", {"*.json"}, QDir::Files, QDirIterator::Subdirectories);
            while (it.hasNext())
                add(QFileInfo(it.next()), OpenCode);
            continue;
        }
        const bool chats = root.kind == Gemini || root.kind == Qwen;
        const QStringList patterns = chats ? QStringList{"*.json", "*.jsonl"} : QStringList{"*.jsonl"};
        QDirIterator it(root.path, patterns, QDir::Files, QDirIterator::Subdirectories | QDirIterator::FollowSymlinks);
        while (it.hasNext()) {
            const QFileInfo info(it.next());
            // Gemini's project folders also hold settings and prompt history;
            // only the chats carry usage.
            if (chats && info.dir().dirName() != "chats")
                continue;
            add(info, root.kind);
        }
    }
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

Usage::Roots Usage::defaultRoots() {
    Roots roots;
    const QString home = QDir::homePath();
    auto add = [&](Kind kind, const QString &path) {
        for (const Root &r : roots)
            if (r.kind == kind && r.path == path)
                return;
        roots.append({kind, path});
    };

    for (const QString &dir : qEnvironmentVariable("CLAUDE_CONFIG_DIR").split(',', Qt::SkipEmptyParts))
        add(Claude, dir.trimmed() + "/projects");
    add(Claude, home + "/.claude/projects");
    add(Claude, home + "/.config/claude/projects");

    const QString codex = qEnvironmentVariable("CODEX_HOME", home + "/.codex");
    add(Codex, codex + "/sessions");
    add(Codex, codex + "/archived_sessions");

    add(Gemini, qEnvironmentVariable("GEMINI_CLI_HOME", home) + "/.gemini/tmp");

    add(Qwen, home + "/.qwen/tmp");
    add(Qwen, home + "/.qwen/projects");

    const QString data = qEnvironmentVariable("XDG_DATA_HOME", home + "/.local/share");
    add(OpenCode, qEnvironmentVariable("OPENCODE_DATA_DIR", data + "/opencode"));
    return roots;
}

QString Usage::defaultPlanFile() {
    return qEnvironmentVariable("XDG_CONFIG_HOME", QDir::homePath() + "/.config") + "/Claude/plan-usage-history.json";
}

QVariantMap Usage::readPlanUsage(const QString &path, qint64 now) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    const QJsonArray samples = QJsonDocument::fromJson(file.readAll()).object().value("samples").toArray();

    // The newest sample says which account is signed in; older samples of
    // another account would mix two plans.
    qint64 latest = 0;
    QString org;
    for (const QJsonValue &v : samples) {
        const QJsonObject s = v.toObject();
        const qint64 t = s.value("t").toInteger();
        if (t > latest) {
            latest = t;
            org = s.value("org").toString();
        }
    }
    if (!latest)
        return {};

    constexpr qint64 hour = 3600 * 1000LL;
    QVariantList history;
    int fiveHour = -1, sevenDay = -1;
    for (const QJsonValue &v : samples) {
        const QJsonObject s = v.toObject();
        const qint64 t = s.value("t").toInteger();
        if (s.value("org").toString() != org || t < now - 7 * 24 * hour)
            continue;
        const QJsonObject u = s.value("u").toObject();
        history.append(QVariantMap{{"time", t}, {"fiveHour", u.value("fh").toInt(-1)}, {"sevenDay", u.value("sd").toInt(-1)}});
        if (t == latest) {
            fiveHour = u.value("fh").toInt(-1);
            sevenDay = u.value("sd").toInt(-1);
        }
    }
    // The app only samples while it's open; a reading older than its window
    // says nothing about now.
    if (now - latest > 5 * hour)
        fiveHour = -1;
    if (now - latest > 7 * 24 * hour)
        sevenDay = -1;
    std::sort(history.begin(), history.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap()["time"].toLongLong() < b.toMap()["time"].toLongLong();
    });
    return {{"fiveHour", fiveHour}, {"sevenDay", sevenDay}, {"sampledAt", latest}, {"history", history}};
}
