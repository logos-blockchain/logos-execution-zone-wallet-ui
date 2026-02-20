#include "LEZWalletPlugin.h"
#include "LEZWalletBackend.h"
#include <QQuickWidget>
#include <QQmlContext>
#include <QQmlEngine>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QUrl>

QWidget* LEZWalletPlugin::createWidget(LogosAPI* logosAPI) {
    qDebug() << "LEZWalletPlugin::createWidget called";

    QQuickWidget* quickWidget = new QQuickWidget();
    quickWidget->setResizeMode(QQuickWidget::SizeRootObjectToView);

    qmlRegisterType<LEZWalletBackend>("LEZWalletBackend", 1, 0, "LEZWalletBackend");

    LEZWalletBackend* backend = new LEZWalletBackend(logosAPI, quickWidget);
    quickWidget->rootContext()->setContextProperty("backend", backend);

    QString qmlSource = "qrc:/qml/ExecutionZoneWalletView.qml";
    QString importPath = "qrc:/qml";

    QString envPath = QString::fromUtf8(qgetenv("DEV_QML_PATH")).trimmed();
    if (!envPath.isEmpty()) {
        QFileInfo info(envPath);
        if (info.isDir()) {
            QString main = QDir(info.absoluteFilePath()).absoluteFilePath("ExecutionZoneWalletView.qml");
            if (QFile::exists(main)) {
                importPath = info.absoluteFilePath();
                qmlSource = QUrl::fromLocalFile(main).toString();
            } else {
                qWarning() << "DEV_QML_PATH: ExecutionZoneWalletView.qml not found in" << info.absoluteFilePath();
            }
        }
    }

    quickWidget->engine()->addImportPath(importPath);
    quickWidget->setSource(QUrl(qmlSource));

    if (quickWidget->status() == QQuickWidget::Error) {
        qWarning() << "LEZWalletPlugin: Failed to load QML:" << quickWidget->errors();
    }

    return quickWidget;
}

void LEZWalletPlugin::destroyWidget(QWidget* widget) {
    delete widget;
}
