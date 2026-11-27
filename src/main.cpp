// omatokens — how many tokens AI coding agents spent, and when.

#include <QGuiApplication>
#include <QIcon>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTextStream>
#include <QUrl>
#include <cstring>

#include "backend.h"
#include "theme.h"
#include "translator.h"

namespace {

// `omatokens summary [--json]` prints today, this week, this month, and all
// time without opening a window, so scripts and agents can read the numbers.
int printSummary(Backend &backend, bool json) {
    backend.loadNow();
    const QVariantMap overview = backend.overviewNow();
    QTextStream out(stdout);
    if (json) {
        QVariantMap all = overview;
        QVariantMap plan = backend.planUsage();
        plan.remove("history");
        if (!plan.isEmpty())
            all["claudePlan"] = plan;
        out << QJsonDocument(QJsonObject::fromVariantMap(all)).toJson(QJsonDocument::Indented);
        return 0;
    }
    const QList<QPair<QString, QString>> rows{{"today", "Today"}, {"week", "This week"},
                                              {"month", "This month"}, {"all", "All time"}};
    for (const auto &[key, name] : rows) {
        const QVariantMap s = overview.value(key).toMap();
        out << QString("%1  %2 tokens  (in %3, out %4, cache write %5, cache read %6, %7 requests)\n")
                   .arg(name, -10)
                   .arg(backend.compact(s["total"].toDouble()), 8)
                   .arg(backend.compact(s["input"].toDouble()), backend.compact(s["output"].toDouble()),
                        backend.compact(s["cacheWrite"].toDouble()), backend.compact(s["cacheRead"].toDouble()))
                   .arg(s["requests"].toLongLong());
    }
    const QVariantMap plan = backend.planUsage();
    auto percent = [](const QVariant &v) { return v.toInt() < 0 ? QStringLiteral("–") : QString::number(v.toInt()) + "%"; };
    if (!plan.isEmpty())
        out << QString("Claude plan  5-hour limit %1, weekly limit %2 (from Claude Desktop)\n")
                   .arg(percent(plan["fiveHour"]), percent(plan["sevenDay"]));
    return 0;
}

} // namespace

int main(int argc, char *argv[]) {
    const bool summary = argc > 1 && std::strcmp(argv[1], "summary") == 0;
    if (argc > 1 && !summary && std::strcmp(argv[1], "open") != 0) {
        fprintf(stderr, "usage: omatokens [open | summary [--json]]\n");
        return 1;
    }
    if (summary)
        qputenv("QT_QPA_PLATFORM", "offscreen");

    QGuiApplication app(argc, argv);
    app.setApplicationName("omatokens");
    app.setApplicationVersion("0.1.0");

    // Matches the window to omatokens.desktop, so the compositor (Wayland
    // app_id) and the launcher pick up the installed icon.
    app.setDesktopFileName("omatokens");
    app.setWindowIcon(QIcon::fromTheme("omatokens"));

    // Installed before anything is translated, and every qsTr() binding is
    // re-evaluated when the Omarchy language changes.
    Translator translator;
    app.installTranslator(&translator);

    Backend backend;
    if (summary)
        return printSummary(backend, argc > 2 && std::strcmp(argv[2], "--json") == 0);

    QQuickStyle::setStyle("Material");
    // A see-through window background, so Hyprland's blur shows behind the
    // app the way it does behind the terminal.
    QQuickWindow::setDefaultAlphaBuffer(true);
    Theme theme;

    QQmlApplicationEngine engine;
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    // Period titles and dates are formatted in C++, so they follow too.
    QObject::connect(&translator, &Translator::changed, &backend, &Backend::recompute);
    engine.rootContext()->setContextProperty("translator", &translator);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    backend.refresh();
    return app.exec();
}
