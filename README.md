# BenLoki

App iOS (Swift/SwiftUI) para usar várias contas de serviços web, como WhatsApp Web e Telegram Web, no mesmo aparelho. Cada conta tem login, cookies, `localStorage` e cache isolados.

## Destaques

- **Isolamento por conta:** um `WKWebsiteDataStore` dedicado para cada conta (iOS 17+).
- **Painel de contas** com status (Ativa, Carregando, Inativa, Erro).
- **User-Agent** mobile ou desktop por conta.
- **Câmera e microfone** liberados só para o site de cada conta.
- **Economia de memória e bateria:** no máximo 2 WebViews vivos; tudo é descarregado em segundo plano.
- **Bloqueio por Face ID** ao abrir o app, com conteúdo oculto no alternador de apps.

## Código e documentação

O projeto está em [`MultiSessionWrapper/`](MultiSessionWrapper/). O [README do projeto](MultiSessionWrapper/README.md) traz a arquitetura, as camadas de isolamento, as limitações e a configuração no Xcode.
