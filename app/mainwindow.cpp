#include <QtWidgets>
#include "mainwindow.h"

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
{
    setupUi();
}

MainWindow::~MainWindow()
{
}

void MainWindow::setupUi()
{
    QString pluginExtension;
#if defined(Q_OS_WIN)
    pluginExtension = ".dll";
#elif defined(Q_OS_MAC)
    pluginExtension = ".dylib";
#else
    pluginExtension = ".so";
#endif

    QString pluginPath = QCoreApplication::applicationDirPath() + "/../execution_zone_wallet_ui" + pluginExtension;
    QPluginLoader loader(pluginPath);

    QWidget* walletWidget = nullptr;

    if (loader.load()) {
        QObject* plugin = loader.instance();
        if (plugin) {
            QMetaObject::invokeMethod(plugin, "createWidget",
                                    Qt::DirectConnection,
                                    Q_RETURN_ARG(QWidget*, walletWidget));
        }
    }

    if (walletWidget) {
        setCentralWidget(walletWidget);
    } else {
        qWarning() << "================================================";
        qWarning() << "Failed to load execution zone wallet UI plugin from:" << pluginPath;
        qWarning() << "Error:" << loader.errorString();
        qWarning() << "================================================";

        QWidget* fallbackWidget = new QWidget(this);
        QVBoxLayout* layout = new QVBoxLayout(fallbackWidget);

        QLabel* messageLabel = new QLabel("Execution Zone Wallet UI module not loaded", fallbackWidget);
        QFont font = messageLabel->font();
        font.setPointSize(14);
        messageLabel->setFont(font);
        messageLabel->setAlignment(Qt::AlignCenter);

        layout->addWidget(messageLabel);
        setCentralWidget(fallbackWidget);
    }

    setWindowTitle("Logos Execution Zone Wallet UI App");
    resize(800, 600);
}
