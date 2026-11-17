#include "backend.h"

#include <QHash>
#include <QLocale>
#include <QSet>
#include <QtConcurrent>
#include <algorithm>
#include <cmath>

namespace {

struct Sum {
    qint64 input = 0, output = 0, cacheWrite = 0, cacheRead = 0, requests = 0;

    void add(const UsageRecord &r) {
        input += r.input;
        output += r.output;
        cacheWrite += r.cacheWrite;
        cacheRead += r.cacheRead;
        ++requests;
    }
    qint64 total() const { return input + output + cacheWrite + cacheRead; }
    QVariantMap toMap() const {
        return {{"input", input}, {"output", output}, {"cacheWrite", cacheWrite}, {"cacheRead", cacheRead},
                {"total", total()}, {"requests", requests}};
    }
};

// The largest entries by total, with the rest folded into one line so a long
// tail of projects doesn't push everything else off the card.
QVariantList ranked(const QHash<QString, Sum> &sums, qint64 grandTotal, int limit, const QString &otherName) {
    QVector<QPair<QString, Sum>> list;
    for (auto it = sums.begin(); it != sums.end(); ++it)
        list.append({it.key(), it.value()});
    std::sort(list.begin(), list.end(), [](const auto &a, const auto &b) { return a.second.total() > b.second.total(); });

    QVariantList result;
    Sum other;
    for (int i = 0; i < list.size(); ++i) {
        if (i < limit) {
            QVariantMap item = list[i].second.toMap();
            item["name"] = list[i].first;
            item["share"] = grandTotal ? double(list[i].second.total()) / grandTotal : 0.0;
            result.append(item);
        } else {
            other.input += list[i].second.input;
            other.output += list[i].second.output;
            other.cacheWrite += list[i].second.cacheWrite;
            other.cacheRead += list[i].second.cacheRead;
            other.requests += list[i].second.requests;
        }
    }
    if (other.total()) {
        QVariantMap item = other.toMap();
        item["name"] = otherName;
        item["share"] = grandTotal ? double(other.total()) / grandTotal : 0.0;
        result.append(item);
    }
    return result;
}

QDateTime startOfDay(const QDate &date) { return date.startOfDay(); }

} // namespace

Backend::Backend(const QStringList &claudeRoots, const QStringList &codexRoots, QObject *parent)
    : QObject(parent), m_claudeRoots(claudeRoots), m_codexRoots(codexRoots) {
    connect(&m_scan, &QFutureWatcher<ScanCache>::finished, this, &Backend::finishScan);
    // Agents append to their logs as they work; a quiet poll that only
    // re-reads files whose size changed keeps the window current.
    m_poll.setInterval(15000);
    connect(&m_poll, &QTimer::timeout, this, &Backend::refresh);
    recompute();
}

Backend::~Backend() {
    m_poll.stop();
    m_scan.waitForFinished();
}

void Backend::refresh() {
    m_poll.start();
    if (m_scan.isRunning()) {
        m_rescan = true;
        return;
    }
    if (!m_loading) {
        m_loading = true;
        emit loadingChanged();
    }
    m_scan.setFuture(QtConcurrent::run(&Usage::scan, m_claudeRoots, m_codexRoots, m_cache));
}

void Backend::finishScan() {
    m_cache = m_scan.result();
    m_records = Usage::merge(m_cache);
    m_updatedAt = QDateTime::currentDateTime();
    m_loading = false;
    emit loadingChanged();
    recompute();
    if (m_rescan) {
        m_rescan = false;
        refresh();
    }
}

void Backend::loadNow() {
    m_cache = Usage::scan(m_claudeRoots, m_codexRoots, m_cache);
    m_records = Usage::merge(m_cache);
    m_updatedAt = QDateTime::currentDateTime();
    recompute();
}

void Backend::setClock(const QDateTime &now) {
    m_fixedNow = now;
    recompute();
}

QDateTime Backend::now() const { return m_fixedNow.isValid() ? m_fixedNow : QDateTime::currentDateTime(); }

QString Backend::lastUpdated() const {
    return m_updatedAt.isValid() ? QLocale().toString(m_updatedAt.time(), QLocale::ShortFormat) : QString();
}

void Backend::setPeriod(int period) {
    period = std::clamp(period, int(Today), int(AllTime));
    if (period == m_period && m_offset == 0)
        return;
    m_period = period;
    m_offset = 0;
    recompute();
}

void Backend::setOffset(int offset) {
    // The future has no usage yet, and "all time" has nothing to page through.
    offset = m_period == AllTime ? 0 : std::min(0, offset);
    if (offset == m_offset)
        return;
    m_offset = offset;
    recompute();
}

void Backend::shift(int steps) { setOffset(m_offset + steps); }

void Backend::setAgentFilter(const QString &agent) {
    if (agent == m_agentFilter)
        return;
    m_agentFilter = agent;
    recompute();
}

bool Backend::matches(const UsageRecord &record) const {
    return m_agentFilter.isEmpty() || record.agent == m_agentFilter;
}

QString Backend::compact(double value) const {
    const QLocale locale;
    const double magnitude = std::abs(value);
    auto scaled = [&](double divisor, const char *unit) {
        const double v = value / divisor;
        return locale.toString(v, 'f', std::abs(v) >= 100 ? 0 : std::abs(v) >= 10 ? 1 : 2) + unit;
    };
    if (magnitude >= 1e9)
        return scaled(1e9, "B");
    if (magnitude >= 1e6)
        return scaled(1e6, "M");
    if (magnitude >= 1e4)
        return scaled(1e3, "k");
    return locale.toString(qint64(std::llround(value)));
}

QString Backend::full(double value) const { return QLocale().toString(qint64(std::llround(value))); }

Backend::Range Backend::periodRange(int period, int offset, const QDateTime &now, qint64 firstRecord) {
    const QLocale locale;
    const QDate today = now.date();
    Range range;

    switch (period) {
    case Today: {
        const QDate day = today.addDays(offset);
        range.start = startOfDay(day);
        range.end = startOfDay(day.addDays(1));
        range.title = offset == 0 ? tr("Today") : offset == -1 ? tr("Yesterday")
                                                               : locale.toString(day, QLocale::LongFormat);
        for (int hour = 0; hour < 24; ++hour) {
            const QDateTime start(day, QTime(hour, 0));
            range.buckets.append({start, hour == 23 ? range.end : QDateTime(day, QTime(hour + 1, 0)),
                                  QString::number(hour),
                                  tr("%1, %2–%3").arg(locale.toString(day, QLocale::ShortFormat),
                                                      locale.toString(QTime(hour, 0), QLocale::ShortFormat),
                                                      locale.toString(QTime(hour, 59), QLocale::ShortFormat))});
        }
        break;
    }
    case Week: {
        const QDate monday = today.addDays(1 - today.dayOfWeek() + 7 * offset);
        range.start = startOfDay(monday);
        range.end = startOfDay(monday.addDays(7));
        const QString span = locale.toString(monday, "d MMM") + " – " + locale.toString(monday.addDays(6), "d MMM");
        range.title = offset == 0 ? tr("This week · %1").arg(span)
                                  : tr("Week %1 · %2").arg(monday.weekNumber()).arg(span);
        for (int i = 0; i < 7; ++i) {
            const QDate day = monday.addDays(i);
            range.buckets.append({startOfDay(day), startOfDay(day.addDays(1)), locale.toString(day, "ddd"),
                                  locale.toString(day, QLocale::LongFormat)});
        }
        break;
    }
    case Month: {
        const QDate first = QDate(today.year(), today.month(), 1).addMonths(offset);
        range.start = startOfDay(first);
        range.end = startOfDay(first.addMonths(1));
        range.title = locale.toString(first, "MMMM yyyy");
        for (int i = 0; i < first.daysInMonth(); ++i) {
            const QDate day = first.addDays(i);
            range.buckets.append({startOfDay(day), startOfDay(day.addDays(1)), QString::number(day.day()),
                                  locale.toString(day, QLocale::LongFormat)});
        }
        break;
    }
    default: {
        const QDate firstDay = firstRecord ? QDateTime::fromMSecsSinceEpoch(firstRecord).date() : today;
        range.start = startOfDay(firstDay);
        range.end = startOfDay(today.addDays(1));
        range.title = tr("All time · since %1").arg(locale.toString(firstDay, QLocale::ShortFormat));
        const qint64 days = firstDay.daysTo(today) + 1;
        // Days while they still fit as bars, then weeks, then months.
        if (days <= 62) {
            for (QDate day = firstDay; day <= today; day = day.addDays(1))
                range.buckets.append({startOfDay(day), startOfDay(day.addDays(1)), locale.toString(day, "d.M."),
                                      locale.toString(day, QLocale::LongFormat)});
        } else if (days <= 730) {
            for (QDate monday = firstDay.addDays(1 - firstDay.dayOfWeek()); monday <= today; monday = monday.addDays(7))
                range.buckets.append({startOfDay(monday), startOfDay(monday.addDays(7)), locale.toString(monday, "d.M."),
                                      tr("Week %1, %2").arg(monday.weekNumber()).arg(monday.year())});
        } else {
            for (QDate month(firstDay.year(), firstDay.month(), 1); month <= today; month = month.addMonths(1))
                range.buckets.append({startOfDay(month), startOfDay(month.addMonths(1)), locale.toString(month, "MMM yy"),
                                      locale.toString(month, "MMMM yyyy")});
        }
        break;
    }
    }
    return range;
}

void Backend::recompute() {
    const QDateTime current = now();
    const qint64 first = m_records.isEmpty() ? 0 : m_records.first().time;

    QSet<QString> agentSet;
    for (const UsageRecord &r : m_records)
        agentSet.insert(r.agent);
    m_agents = QStringList(agentSet.begin(), agentSet.end());
    std::sort(m_agents.begin(), m_agents.end());

    auto sumBetween = [&](const QDateTime &start, const QDateTime &end) {
        Sum sum;
        const qint64 from = start.toMSecsSinceEpoch(), to = end.toMSecsSinceEpoch();
        for (const UsageRecord &r : m_records)
            if (r.time >= from && r.time < to && matches(r))
                sum.add(r);
        return sum;
    };

    m_overview.clear();
    const char *names[] = {"today", "week", "month", "all"};
    for (int p = Today; p <= AllTime; ++p) {
        const Range r = periodRange(p, 0, current, first);
        m_overview[names[p]] = sumBetween(r.start, r.end).toMap();
    }

    const Range range = periodRange(m_period, m_offset, current, first);
    m_periodTitle = range.title;

    QVector<Sum> bucketSums(range.buckets.size());
    QVector<qint64> bucketStarts;
    for (const Bucket &b : range.buckets)
        bucketStarts.append(b.start.toMSecsSinceEpoch());
    QHash<QString, Sum> byModel, byProject, byAgent;
    QVector<qint64> heat(7 * 24, 0);
    Sum total;
    const qint64 from = range.start.toMSecsSinceEpoch(), to = range.end.toMSecsSinceEpoch();
    for (const UsageRecord &r : m_records) {
        if (r.time < from || r.time >= to || !matches(r))
            continue;
        total.add(r);
        const auto it = std::upper_bound(bucketStarts.cbegin(), bucketStarts.cend(), r.time);
        if (it != bucketStarts.cbegin())
            bucketSums[int(it - bucketStarts.cbegin()) - 1].add(r);
        byModel[r.model].add(r);
        byProject[r.project.isEmpty() ? tr("Unknown") : r.project].add(r);
        byAgent[r.agent].add(r);
        const QDateTime local = QDateTime::fromMSecsSinceEpoch(r.time);
        heat[(local.date().dayOfWeek() - 1) * 24 + local.time().hour()] += r.total();
    }

    m_summary = total.toMap();
    if (m_period != AllTime) {
        const Range previous = periodRange(m_period, m_offset - 1, current, first);
        m_summary["previousTotal"] = sumBetween(previous.start, previous.end).total();
    } else {
        m_summary["previousTotal"] = qint64(-1);
    }

    m_buckets.clear();
    for (int i = 0; i < range.buckets.size(); ++i) {
        QVariantMap item = bucketSums[i].toMap();
        item["label"] = range.buckets[i].label;
        item["detail"] = range.buckets[i].detail;
        item["current"] = range.buckets[i].start <= current && current < range.buckets[i].end;
        m_buckets.append(item);
    }

    m_models = ranked(byModel, total.total(), 6, tr("Other"));
    m_projects = ranked(byProject, total.total(), 6, tr("Other"));
    m_agentShares = ranked(byAgent, total.total(), 6, tr("Other"));
    m_heatmap.clear();
    for (qint64 v : heat)
        m_heatmap.append(v);

    emit changed();
}
