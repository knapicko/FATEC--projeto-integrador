# Testes automatizados — Plano de Testes PT-CJ-01 (ConsertaJá)

Testes **unitários** e de **integração** (com backend simulado) escritos com o
`flutter_test`, sem nenhuma dependência nova no `pubspec.yaml`.

## Onde colocar

Copie para dentro do projeto Flutter (`consertaja/`):

```
consertaja/
├── dart_test.yaml                 ← declara a tag "defeito"
├── executar_testes.bat            ← Windows
├── executar_testes.sh             ← Linux / macOS / Git Bash
└── test/
    └── plano_testes/
        ├── ct01_cadastro_validacoes_test.dart
        ├── ct02_perfil_configuracoes_test.dart
        ├── ct03_busca_filtros_test.dart
        ├── ct04_solicitacao_cotacao_test.dart
        ├── ct05_status_entrega_rastreamento_test.dart
        ├── ct06_pagamento_test.dart
        ├── ct07_chat_presenca_anexos_test.dart
        ├── ct08_avaliacao_historico_notificacoes_test.dart
        └── integracao/
            └── ct09_integracao_servicos_test.dart
```

## Como executar

```bash
flutter pub get

# Todos os testes do plano + relatório de cobertura (coverage/lcov.info)
flutter test test/plano_testes --coverage --reporter expanded

# Só a regressão (sem os 3 testes que documentam defeitos conhecidos)
flutter test test/plano_testes --exclude-tags defeito

# Toda a suíte do projeto (inclui os testes que a equipe já tinha)
flutter test --coverage
```

Ou rode `executar_testes.bat` (Windows) / `./executar_testes.sh`.

### Relatório de cobertura em HTML (opcional)

- Linux/macOS: `genhtml coverage/lcov.info -o coverage/html` (pacote `lcov`)
  e abra `coverage/html/index.html`.
- Windows: extensão **Coverage Gutters** no VS Code, ou
  `dart pub global activate test_cov_console` e depois `test_cov_console`.

## Mapa casos de teste → requisitos

| Arquivo | Casos | Requisitos |
|---|---|---|
| ct01 | CT01–CT08 | RF001, RF004, RN010 |
| ct02 | CT09–CT12 | RF003, RNF007 |
| ct03 | CT13–CT19 | RF005, RF006 |
| ct04 | CT20–CT26 | RF008, RF009 |
| ct05 | CT27–CT33 | RF014, RF016, RF017 |
| ct06 | CT34–CT36 | RF018, RN001 |
| ct07 | CT37–CT42 | RF010, RF011 |
| ct08 | CT43–CT48 | RF021, RF022, RF024, RN006 |
| integracao/ct09 | CT49–CT54 | RF001, RF002, RF004, RF009, RF014 |

## Testes que falham de propósito (tag `defeito`)

| Caso | Defeito | Onde corrigir |
|---|---|---|
| CT38 | DEF-01 — "há 1 semanas" (concordância) | `lib/services/formatacao_data.dart` |
| CT40 | DEF-02 — texto "Online" até 59 s, indicador só até 45 s | `lib/services/formatacao_data.dart` |
| CT54 | DEF-03 — e-mail com domínio de 5+ letras recusado | `lib/services/consulta_cadastro_service.dart` |

Depois de corrigir o código do app, esses testes passam a ficar verdes
sem nenhuma alteração nos testes.
