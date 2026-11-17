#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QObject>
#include <QProcess>
#include <QTimer>

class Theme : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString accent READ accent NOTIFY changed)
    Q_PROPERTY(QString accentForeground READ accentForeground NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)
    // The window and text colors come from the theme too, and the surfaces in
    // between are mixed from them, so cards sit on any theme's background.
    Q_PROPERTY(QColor background READ background NOTIFY changed)
    Q_PROPERTY(QColor surface READ surface NOTIFY changed)
    Q_PROPERTY(QColor surfaceHover READ surfaceHover NOTIFY changed)
    Q_PROPERTY(QColor border READ border NOTIFY changed)
    Q_PROPERTY(QColor grid READ grid NOTIFY changed)
    Q_PROPERTY(QColor text READ text NOTIFY changed)
    Q_PROPERTY(QColor muted READ muted NOTIFY changed)
    Q_PROPERTY(QColor faint READ faint NOTIFY changed)

public:
    explicit Theme(const QString &currentDirectory = {}, QObject *parent = nullptr, const QString &hyprctl = {});
    ~Theme() override;

    QString accent() const { return m_accent; }
    QString accentForeground() const;
    int radius() const { return m_radius; }

    QColor background() const { return m_background; }
    QColor surface() const { return mix(.045); }
    QColor surfaceHover() const { return mix(.085); }
    QColor border() const { return mix(.11); }
    QColor grid() const { return mix(.075); }
    QColor text() const { return m_foreground; }
    QColor muted() const { return mix(.6); }
    QColor faint() const { return mix(.38); }

    static QString readAccent(const QString &path);
    static QString readColor(const QString &path, const QString &key, const QString &fallback);

signals:
    void changed();

private:
    void reload();
    void refreshRounding();

    QString m_directory;
    QColor mix(double amount) const;

    QString m_accent = "#FFD60A";
    QColor m_background = QColor("#0e0e10");
    QColor m_foreground = QColor("#ececef");
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QString m_hyprctl;
    int m_radius = 0;
    QProcess m_roundingProcess;
    QTimer m_roundingPoll, m_roundingTimeout;
};
