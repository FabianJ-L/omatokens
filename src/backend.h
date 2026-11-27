#pragma once

#include <QDateTime>
#include <QFutureWatcher>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

#include "usage.h"

// Reads the agents' logs and sums them up for the period on screen. QML reads
// the results as plain lists and maps; everything recomputes together and
// announces itself with one changed() signal.
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int period READ period WRITE setPeriod NOTIFY changed)
    Q_PROPERTY(int offset READ offset WRITE setOffset NOTIFY changed)
    Q_PROPERTY(QString agentFilter READ agentFilter WRITE setAgentFilter NOTIFY changed)
    Q_PROPERTY(QStringList agents READ agents NOTIFY changed)
    Q_PROPERTY(int recordCount READ recordCount NOTIFY changed)
    Q_PROPERTY(QString periodTitle READ periodTitle NOTIFY changed)
    Q_PROPERTY(QString lastUpdated READ lastUpdated NOTIFY updated)
    Q_PROPERTY(QVariantMap summary READ summary NOTIFY changed)
    Q_PROPERTY(QVariantMap overview READ overview NOTIFY changed)
    Q_PROPERTY(QVariantList buckets READ buckets NOTIFY changed)
    Q_PROPERTY(QVariantList models READ models NOTIFY changed)
    Q_PROPERTY(QVariantList projects READ projects NOTIFY changed)
    Q_PROPERTY(QVariantList agentShares READ agentShares NOTIFY changed)
    Q_PROPERTY(QVariantList heatmap READ heatmap NOTIFY changed)
    Q_PROPERTY(QStringList roots READ roots CONSTANT)
    Q_PROPERTY(QVariantMap planUsage READ planUsage NOTIFY planUsageChanged)

public:
    enum Period { Today, Week, Month, AllTime };
    Q_ENUM(Period)

    struct Bucket {
        QDateTime start;
        QDateTime end;
        QString label;
        QString detail;
    };
    struct Range {
        QDateTime start;
        QDateTime end;
        QString title;
        QVector<Bucket> buckets;
    };

    explicit Backend(const Usage::Roots &roots = Usage::defaultRoots(),
                     const QString &planFile = Usage::defaultPlanFile(), QObject *parent = nullptr);
    ~Backend() override;

    bool loading() const { return m_loading; }
    int period() const { return m_period; }
    int offset() const { return m_offset; }
    QString agentFilter() const { return m_agentFilter; }
    QStringList agents() const { return m_agents; }
    int recordCount() const { return m_records.size(); }
    QString periodTitle() const { return m_periodTitle; }
    QString lastUpdated() const;
    QVariantMap summary() const { return m_summary; }
    QVariantMap overview() const { return m_overview; }
    QVariantList buckets() const { return m_buckets; }
    QVariantList models() const { return m_models; }
    QVariantList projects() const { return m_projects; }
    QVariantList agentShares() const { return m_agentShares; }
    QVariantList heatmap() const { return m_heatmap; }
    QStringList roots() const;
    QVariantMap planUsage() const { return m_planUsage; }

    void setPeriod(int period);
    void setOffset(int offset);
    void setAgentFilter(const QString &agent);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void shift(int steps);
    Q_INVOKABLE QString compact(double value) const;
    Q_INVOKABLE QString full(double value) const;

    // Reads every log right away, for the command line and the tests.
    void loadNow();
    // Pins "now" so tests see the same periods every run.
    void setClock(const QDateTime &now);
    // For the command line: totals of today, this week, this month, all time.
    QVariantMap overviewNow() const { return m_overview; }

    static Range periodRange(int period, int offset, const QDateTime &now, qint64 firstRecord);

public slots:
    // Recomputes and only announces a change when a number actually moved, so
    // the quiet poll doesn't make the window rebuild or re-animate.
    void recompute();

signals:
    void changed();
    // Every finished read of the logs, changed or not.
    void updated();
    void loadingChanged();
    void planUsageChanged();

private:
    void finishScan();
    bool rebuild();
    QDateTime now() const;
    bool matches(const UsageRecord &record) const;
    void readPlan();

    Usage::Roots m_roots;
    QString m_planFile;
    QVariantMap m_planUsage;
    ScanCache m_cache;
    QVector<UsageRecord> m_records;
    QFutureWatcher<ScanCache> m_scan;
    QTimer m_poll;
    bool m_loading = false;
    bool m_rescan = false;
    QDateTime m_fixedNow;
    QDateTime m_updatedAt;

    int m_period = Today;
    int m_offset = 0;
    QString m_agentFilter;
    QStringList m_agents;
    QString m_periodTitle;
    QVariantMap m_summary;
    QVariantMap m_overview;
    QVariantList m_buckets;
    QVariantList m_models;
    QVariantList m_projects;
    QVariantList m_agentShares;
    QVariantList m_heatmap;
};
