#include <QDir>
#include <QFile>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtTest>

#include "backend.h"
#include "theme.h"
#include "translator.h"
#include "usage.h"

namespace {

QByteArray claudeLine(const char *id, const char *time, int input, int output, int cacheRead = 0,
                      const char *model = "claude-opus-5-5") {
    return QString(R"({"type":"assistant","cwd":"/work/shop","requestId":"req_%1","timestamp":"%2",)"
                   R"("message":{"id":"%1","model":"%3","usage":{"input_tokens":%4,"output_tokens":%5,)"
                   R"("cache_creation_input_tokens":0,"cache_read_input_tokens":%6}}})")
               .arg(id, time, model).arg(input).arg(output).arg(cacheRead).toUtf8() + "\n";
}

QByteArray codexCount(const char *time, int total, int input, int cached, int output) {
    return QString(R"({"timestamp":"%1","type":"event_msg","payload":{"type":"token_count","info":{)"
                   R"("total_token_usage":{"total_tokens":%2},"last_token_usage":{"input_tokens":%3,)"
                   R"("cached_input_tokens":%4,"cache_write_input_tokens":0,"output_tokens":%5}}}})")
               .arg(time).arg(total).arg(input).arg(cached).arg(output).toUtf8() + "\n";
}

} // namespace

class TokentallyTests : public QObject {
    Q_OBJECT

private slots:
    void claudeCountsEachResponseOnce()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath("a.jsonl");
        // The same response logged twice (two content blocks), a synthetic
        // message, and a user line that mentions "usage" in its text.
        write(path, claudeLine("msg_1", "2026-11-17T09:00:00.000Z", 10, 20, 100)
                        + claudeLine("msg_1", "2026-11-17T09:00:00.000Z", 10, 20, 100)
                        + claudeLine("msg_2", "2026-11-17T10:00:00.000Z", 1, 2, 0, "<synthetic>")
                        + R"({"type":"user","message":{"content":"what is my usage"}})" "\n");
        const auto records = Usage::merge(Usage::scan({{Usage::Claude, dir.path()}}, {}));
        QCOMPARE(records.size(), 1);
        QCOMPARE(records[0].total(), qint64(130));
        QCOMPARE(records[0].project, QString("shop"));
        QCOMPARE(records[0].agent, QString("Claude Code"));
    }

    void claudeDeduplicatesAcrossFiles()
    {
        QTemporaryDir dir;
        write(dir.filePath("a.jsonl"), claudeLine("msg_1", "2026-11-17T09:00:00.000Z", 10, 20));
        write(dir.filePath("b.jsonl"), claudeLine("msg_1", "2026-11-17T09:00:00.000Z", 10, 20)
                                           + claudeLine("msg_2", "2026-11-17T09:05:00.000Z", 1, 1));
        QCOMPARE(Usage::merge(Usage::scan({{Usage::Claude, dir.path()}}, {})).size(), 2);
    }

    void codexSplitsCachedInputAndSkipsRepeats()
    {
        QTemporaryDir dir;
        write(dir.filePath("rollout.jsonl"),
              R"({"type":"turn_context","payload":{"model":"gpt-test","cwd":"/work/api"}})" "\n"
              + codexCount("2026-11-17T09:00:00.000Z", 1100, 1000, 800, 100)
              + codexCount("2026-11-17T09:00:01.000Z", 1100, 1000, 800, 100)
              + codexCount("2026-11-17T09:01:00.000Z", 1350, 200, 150, 50));
        const auto records = Usage::merge(Usage::scan({{Usage::Codex, dir.path()}}, {}));
        QCOMPARE(records.size(), 2);
        QCOMPARE(records[0].input, qint64(200));
        QCOMPARE(records[0].cacheRead, qint64(800));
        QCOMPARE(records[0].output, qint64(100));
        QCOMPARE(records[0].model, QString("gpt-test"));
        QCOMPARE(records[1].total(), qint64(250));
    }

    void rescanReusesUnchangedFiles()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath("a.jsonl");
        write(path, claudeLine("msg_1", "2026-11-17T09:00:00.000Z", 10, 20));
        ScanCache cache = Usage::scan({{Usage::Claude, dir.path()}}, {});
        // Poison the cached copy: an unchanged file must not be read again.
        cache[QFileInfo(path).canonicalFilePath()].records[0].output = 999;
        cache = Usage::scan({{Usage::Claude, dir.path()}}, cache);
        QCOMPARE(Usage::merge(cache)[0].output, qint64(999));
    }

    void weekStartsOnMonday()
    {
        const QDateTime wednesday(QDate(2026, 11, 18), QTime(12, 0));
        const auto range = Backend::periodRange(Backend::Week, 0, wednesday, 0);
        QCOMPARE(range.start.date(), QDate(2026, 11, 16));
        QCOMPARE(range.end.date(), QDate(2026, 11, 23));
        QCOMPARE(range.buckets.size(), 7);
        QCOMPARE(Backend::periodRange(Backend::Week, -1, wednesday, 0).start.date(), QDate(2026, 11, 9));
    }

    void monthHasOneBarPerDay()
    {
        const QDateTime now(QDate(2026, 2, 10), QTime(8, 0));
        QCOMPARE(Backend::periodRange(Backend::Month, 0, now, 0).buckets.size(), 28);
        QCOMPARE(Backend::periodRange(Backend::Month, -1, now, 0).buckets.size(), 31);
        QCOMPARE(Backend::periodRange(Backend::Today, 0, now, 0).buckets.size(), 24);
    }

    void backendSumsThePeriodsAndFilters()
    {
        QTemporaryDir claude, codex;
        const QString local = QDateTime(QDate(2026, 11, 17), QTime(9, 30)).toUTC().toString(Qt::ISODateWithMs);
        const QString lastWeek = QDateTime(QDate(2026, 11, 10), QTime(9, 30)).toUTC().toString(Qt::ISODateWithMs);
        write(claude.filePath("a.jsonl"), claudeLine("m1", local.toUtf8(), 100, 50)
                                              + claudeLine("m2", lastWeek.toUtf8(), 10, 5));
        write(codex.filePath("b.jsonl"), codexCount(local.toUtf8(), 30, 20, 0, 10));

        Backend backend({{Usage::Claude, claude.path()}, {Usage::Codex, codex.path()}}, {});
        backend.setClock(QDateTime(QDate(2026, 11, 17), QTime(18, 0)));
        backend.loadNow();

        QCOMPARE(backend.overview()["today"].toMap()["total"].toLongLong(), 180);
        QCOMPARE(backend.overview()["all"].toMap()["total"].toLongLong(), 195);
        QCOMPARE(backend.agents(), QStringList({"Claude Code", "Codex"}));

        backend.setPeriod(Backend::Today);
        QCOMPARE(backend.buckets()[9].toMap()["total"].toLongLong(), 180);
        QCOMPARE(backend.heatmap()[1 * 24 + 9].toLongLong(), 180); // Tuesday, 9:00

        backend.setPeriod(Backend::Week);
        // Last Tuesday 9:30 falls inside "last week up to Tuesday 18:00".
        QCOMPARE(backend.summary()["previousTotal"].toLongLong(), 15);
        backend.shift(1); // No future weeks.
        QCOMPARE(backend.offset(), 0);
        backend.shift(-1);
        QCOMPARE(backend.summary()["total"].toLongLong(), 15);

        backend.setOffset(0);
        backend.setAgentFilter("Codex");
        QCOMPARE(backend.summary()["total"].toLongLong(), 30);
        QCOMPARE(backend.models()[0].toMap()["name"].toString(), QString("codex"));
    }

    void runningPeriodComparesTheSameStretch()
    {
        QTemporaryDir claude;
        auto at = [](QDate d, QTime t) { return QDateTime(d, t).toUTC().toString(Qt::ISODateWithMs).toUtf8(); };
        write(claude.filePath("a.jsonl"), claudeLine("m1", at({2026, 11, 10}, {9, 0}), 10, 0)
                                              + claudeLine("m2", at({2026, 11, 10}, {20, 0}), 100, 0));
        Backend backend({{Usage::Claude, claude.path()}}, {});
        backend.setClock(QDateTime(QDate(2026, 11, 17), QTime(12, 0)));
        backend.loadNow();
        backend.setPeriod(Backend::Week);
        // Last Tuesday 20:00 is later in the week than now, so it's left out.
        QCOMPARE(backend.summary()["previousTotal"].toLongLong(), 10);
        backend.shift(-1);
        QCOMPARE(backend.summary()["previousTotal"].toLongLong(), 0);
    }

    void unchangedPollStaysQuiet()
    {
        QTemporaryDir claude;
        write(claude.filePath("a.jsonl"), claudeLine("m1", "2026-11-17T09:00:00.000Z", 10, 20));
        Backend backend({{Usage::Claude, claude.path()}}, {});
        backend.setClock(QDateTime(QDate(2026, 11, 17), QTime(12, 0)));
        backend.loadNow();
        QSignalSpy changed(&backend, &Backend::changed);
        QSignalSpy updated(&backend, &Backend::updated);
        backend.loadNow();
        QCOMPARE(changed.count(), 0);
        QCOMPARE(updated.count(), 1);
    }

    void geminiSplitsCacheAndCountsThoughts()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("shop/chats");
        // Settings and prompt history live next to the chats and are ignored.
        write(dir.filePath("shop/logs.json"), R"([{"tokens":{"input":5}}])");
        write(dir.filePath("shop/chats/session-1.json"),
              R"({"sessionId":"s1","messages":[)"
              R"({"id":"u1","type":"user","timestamp":"2026-11-17T09:00:00.000Z","content":"hi"},)"
              R"({"id":"g1","type":"gemini","timestamp":"2026-11-17T09:00:05.000Z","model":"gemini-3-pro",)"
              R"("tokens":{"input":1000,"output":50,"cached":600,"thoughts":20,"tool":5,"total":1075}}]})");
        const auto records = Usage::merge(Usage::scan({{Usage::Gemini, dir.path()}}, {}));
        QCOMPARE(records.size(), 1);
        QCOMPARE(records[0].agent, QString("Gemini CLI"));
        QCOMPARE(records[0].model, QString("gemini-3-pro"));
        QCOMPARE(records[0].project, QString("shop"));
        QCOMPARE(records[0].input, qint64(405));
        QCOMPARE(records[0].cacheRead, qint64(600));
        QCOMPARE(records[0].output, qint64(70));
    }

    void qwenReadsUsageMetadata()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("p/chats");
        write(dir.filePath("p/chats/a.jsonl"),
              R"({"uuid":"q1","sessionId":"s","type":"assistant","timestamp":"2026-11-17T09:00:00.000Z",)"
              R"("cwd":"/work/api","model":"qwen3-coder","usageMetadata":{"promptTokenCount":300,)"
              R"("candidatesTokenCount":40,"cachedContentTokenCount":100,"thoughtsTokenCount":0}})" "\n");
        const auto records = Usage::merge(Usage::scan({{Usage::Qwen, dir.path()}}, {}));
        QCOMPARE(records.size(), 1);
        QCOMPARE(records[0].agent, QString("Qwen Code"));
        QCOMPARE(records[0].project, QString("api"));
        QCOMPARE(records[0].total(), qint64(340));
    }

    void openCodeReadsDatabaseAndOldFilesOnce()
    {
        QTemporaryDir dir;
        const QString message =
            R"({"id":"msg_1","role":"assistant","modelID":"claude-sonnet-5-5","path":{"cwd":"/work/shop"},)"
            R"("time":{"created":1794906000000},"tokens":{"input":10,"output":20,"reasoning":5,)"
            R"("cache":{"read":100,"write":7}}})";
        {
            QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", "opencode-test");
            db.setDatabaseName(dir.filePath("opencode.db"));
            QVERIFY(db.open());
            QSqlQuery q(db);
            QVERIFY(q.exec("CREATE TABLE message (id TEXT, session_id TEXT, time_created INTEGER, data TEXT)"));
            q.prepare("INSERT INTO message VALUES ('msg_1', 'ses_1', 0, ?)");
            q.addBindValue(message);
            QVERIFY(q.exec());
            QVERIFY(q.exec(R"(INSERT INTO message VALUES ('msg_0', 'ses_1', 0, '{"role":"user"}'))"));
            db.close();
        }
        QSqlDatabase::removeDatabase("opencode-test");
        // The same message from before OpenCode moved to SQLite.
        QDir(dir.path()).mkpath("storage/message/ses_1");
        write(dir.filePath("storage/message/ses_1/msg_1.json"), message.toUtf8());

        const auto records = Usage::merge(Usage::scan({{Usage::OpenCode, dir.path()}}, {}));
        QCOMPARE(records.size(), 1);
        QCOMPARE(records[0].agent, QString("OpenCode"));
        QCOMPARE(records[0].project, QString("shop"));
        QCOMPARE(records[0].output, qint64(25));
        QCOMPARE(records[0].total(), qint64(142));
    }

    void planUsageTakesTheNewestAccountAndAgesOut()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath("plan.json");
        write(path, R"({"version":2,"samples":[{"t":1000,"org":"a","u":{"fh":50,"sd":10}},)"
                    R"({"t":2000,"org":"b","u":{"fh":7,"sd":30}}]})");
        QVariantMap plan = Usage::readPlanUsage(path, 3000);
        QCOMPARE(plan["fiveHour"].toInt(), 7);
        QCOMPARE(plan["sevenDay"].toInt(), 30);
        QCOMPARE(plan["history"].toList().size(), 1);
        plan = Usage::readPlanUsage(path, 2000 + 6 * 3600 * 1000LL);
        QCOMPARE(plan["fiveHour"].toInt(), -1);
        QCOMPARE(plan["sevenDay"].toInt(), 30);
        QVERIFY(Usage::readPlanUsage(dir.filePath("missing.json"), 0).isEmpty());
    }

    void compactNumbers()
    {
        QLocale::setDefault(QLocale(QLocale::English));
        Backend backend({}, {});
        QCOMPARE(backend.compact(950), QString("950"));
        QCOMPARE(backend.compact(48304398), QString("48.3M"));
        QCOMPARE(backend.compact(1500000000), QString("1.50B"));
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QString("black"));
    }

    void themeReadsAccent()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        write(dir.path() + "/theme/colors.toml", "accent = \"#112233\"\n");
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#112233"));
        QCOMPARE(theme.accentForeground(), QString("white"));
    }

    void translatorFallsBackToEnglish()
    {
        QTemporaryDir dir;
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("en"));
        QVERIFY(translator.translate("Main", "Today").isNull());
    }

    void germanCatalogLoads()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "de\n");
        Translator translator(dir.path() + "/language", ":/i18n");
        QCOMPARE(translator.translate("Main", "Today"), QString("Heute"));
        QCOMPARE(translator.translate("Main", "%n requests", nullptr, 1), QString("%n Anfrage"));
        QCOMPARE(translator.translate("Main", "%n requests", nullptr, 3), QString("%n Anfragen"));
    }

private:
    static void write(const QString &path, const QByteArray &contents)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(contents);
    }
};

QTEST_MAIN(TokentallyTests)
#include "tokentally_tests.moc"
