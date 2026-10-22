# MultiSession Wrapper (iOS · SwiftUI)

Base arquitetural para gerenciar várias contas de serviços web (WhatsApp Web, Telegram Web etc.) no mesmo app, cada uma com login, cookies, `localStorage` e cache isolados.

> **Status:** código escrito e revisado por leitura, **não compilado** (o ambiente de geração não tem toolchain Swift). Valide no Xcode antes de qualquer uso.

## Estrutura

```
MultiSessionWrapper/
├── App/MultiSessionApp.swift            Entry point, injeção de dependências, scenePhase
├── Models/
│   ├── SessionInstance.swift            Modelo persistido + UserAgentMode
│   ├── ServicePreset.swift              Serviços prontos (WhatsApp, Telegram)
│   └── SiteMatcher.swift                Comparação de hosts (navegação e permissões)
├── Persistence/InstanceStore.swift      JSON versionado, gravação atômica
├── Isolation/DataStoreProvider.swift    Camada 1: WKWebsiteDataStore por instância
├── Runtime/
│   ├── SessionController.swift          Dono de um WKWebView + delegates
│   └── SessionRuntime.swift             Cache, LRU, ciclo de vida, memória
├── ViewModels/InstanceManager.swift     ObservableObject com a lista de contas
├── Views/
│   ├── DashboardView.swift              Lista com indicadores de status
│   ├── SessionDetailView.swift          Tela da instância + toolbar
│   ├── SessionWebView.swift             UIViewRepresentable que hospeda o WebView
│   ├── AddInstanceView.swift            Criação de conta
│   └── SessionStatus+UI.swift           Cor e texto de status
└── Tests/InstanceStoreTests.swift
```

Fluxo de dependências: `View → InstanceManager / SessionRuntime → SessionController → WKWebView`. As Views nunca criam WKWebView diretamente.

## Camadas de isolamento

### Camada 1 — Data store por instância (`Isolation/DataStoreProvider.swift`)

Cada `SessionInstance` tem um `dataStoreID: UUID` gerado uma vez e nunca alterado. No iOS 17+, esse ID vira um `WKWebsiteDataStore(forIdentifier:)`, que é um armazenamento independente gerenciado pelo WebKit contendo:

- cookies e `localStorage` / `sessionStorage`
- IndexedDB, Cache API e service workers
- cache HTTP

Duas instâncias com IDs diferentes não compartilham nenhum desses itens. O `WKWebViewConfiguration` de cada WebView recebe o store correspondente em `configuration.websiteDataStore`.

Regras:
- **Nunca** use `WKWebsiteDataStore.default()`. Ele é o store global do app e vazaria sessão entre contas.
- O `dataStoreID` é imutável. Trocá-lo faria a conta "perder" o login.
- Ao remover uma conta, `DataStoreProvider.wipe` executa `removeData(ofTypes:)` e depois `remove(forIdentifier:)`. A ordem importa: o WebView precisa ser liberado antes, senão a remoção falha.

**Fallback iOS 16:** não existe store persistente nomeado. Usa-se `nonPersistent()`, que isola a instância só durante a execução do app. O login se perde ao fechar. Por isso o **deployment target recomendado é iOS 17**.

### Camada 2 — Processo de renderização

O WebKit gerencia os processos de renderização e **não** garante um processo por store. `WKProcessPool` é ignorado desde o iOS 12 e não deve ser usado como mecanismo de isolamento. A separação lógica de dados vem da camada 1; a separação de origem entre sites é responsabilidade do próprio WebKit.

### Camada 3 — Permissões e navegação (`Runtime/SessionController.swift`)

- **Câmera/microfone:** `requestMediaCapturePermissionFor` concede apenas se o host de origem é o domínio da instância ou subdomínio (`SiteMatcher.isHost`, comparação estrita). Não usa a heurística de "mesmo site", que aceitaria `evil.com.br` para `site.com.br`.
- **Links externos:** toques em links que saem do site da instância abrem no Safari. Redirecionamentos e subrecursos continuam no WebView para não quebrar fluxos de login.
- **Popups (`target="_blank"`):** carregam no mesmo WebView, mantendo o mesmo data store.

### Camada 4 — Metadados em disco (`Persistence/InstanceStore.swift`)

Só metadados (nome, URL, modo de User-Agent, IDs) vão para `instances.json` no Application Support, com proteção `completeFileProtectionUntilFirstUserAuthentication`. Credenciais e cookies **nunca** saem dos data stores do WebKit, e o app não copia cookies entre instâncias.

## Ciclo de vida, memória e bateria

| Evento | Comportamento |
|---|---|
| Tela da conta aparece | `didActivate`: cria o WKWebView se necessário e marca como ativo |
| Tela fecha | `didDeactivate`: o WebView fica "aquecido" até o limite de vivos |
| Mais de `maxLiveSessions` (padrão 2) | LRU: despeja o menos usado recentemente. O ativo nunca é despejado |
| App vai para background | `BackgroundPolicy.unloadAll` (padrão): descarrega todos os WebViews |
| Volta ao foreground | `didActivate` recria o WebView; a sessão volta do data store |
| Aviso de memória do sistema | Descarrega tudo, exceto o ativo |
| Processo de renderização morto | `webViewWebContentProcessDidTerminate` recarrega a página |

O descarregamento não apaga nada: o data store permanece, então reativar a conta equivale a reabrir o site no navegador.

Por que `unloadAll` por padrão: em background o iOS suspende o app em segundos, WebSockets são fechados e chamadas de voz não sobrevivem. Manter WebViews vivos só gastaria RAM e bateria.

**Atenção à atualização de tela:** `SessionWebView.updateUIView` só reanexa WebViews existentes (`liveWebView(for:)`) e nunca cria novos. Criar durante uma atualização disparada pelo descarregamento em background recarregaria a página imediatamente e anularia a economia.

## Notificações: o que é possível e o que não é

- O WKWebView **não expõe a API Notification** do navegador, e não há Web Push dentro de um app nativo.
- Com o app fechado não há sockets nem JS rodando, então mensagens só chegam ao abrir o app.
- Caminhos viáveis, em ordem de custo:
  1. Badge e contagem de não lidas via `WKScriptMessageHandler` observando `document.title` e enviando para o app. Gera notificação local (`UNUserNotificationCenter`) apenas enquanto o app está em execução.
  2. Push nativo real exige cliente próprio e acesso às APIs oficiais do serviço. Para WhatsApp e Telegram, na prática, não é viável com a abordagem de wrapper.

## Pontos de atenção de produto

- **Termos de uso:** WhatsApp e Telegram restringem automação e clientes não oficiais. Avalie o risco de bloqueio de contas.
- **App Store:** apps de "clone" de contas costumam ser rejeitados pelas diretrizes sobre spam/duplicação (4.3). Revise a proposta de valor antes de submeter.
- **Fingerprinting:** data stores isolados não escondem IP, modelo do aparelho ou fingerprint de navegador. Serviços que correlacionam dispositivos podem associar as contas.

## Configuração no Xcode

1. Xcode 15+ → *New Project* → iOS → *App* (SwiftUI, Swift). Nome: `MultiSessionWrapper`.
2. Substitua o `App` e o `ContentView` padrão. Adicione as pastas desta árvore ao target.
3. Em **Deployment Info**, defina iOS 17.0 (recomendado; iOS 16 compila com o fallback).
4. Em `Info.plist`, adicione:

```xml
<key>NSCameraUsageDescription</key>
<string>Usada pelos serviços de chamada de vídeo nas suas contas.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Usada para mensagens de voz e chamadas nas suas contas.</string>
```

5. Não é necessária nenhuma capability especial.
6. Rode os testes (`⌘U`) e confirme que os cinco casos passam.

## Próximos passos sugeridos

- Bloqueio por Face ID (`LocalAuthentication`) ao abrir o app e tela de privacidade no app switcher (overlay em `.inactive`).
- Editor de nome e ícone da conta.
- Limite de contas e verificação de capacidade de RAM por aparelho.
- Atualizar `desktopSafariUserAgent` periodicamente ou torná-lo configurável remotamente.
- Versão de schema em `FileInstanceStore` com migrações reais quando o modelo mudar.
