# Notificações do ConsertaJá — guia de configuração e testes

## Como funciona

| Peça | Papel |
|---|---|
| **Supabase (banco)** | Guarda `notificacoes` e `dispositivos_notificacao`. Triggers detectam os eventos e decidem quem recebe. |
| **pg_cron** | Pendências diárias do tipo *Sistema* (09:00 de Brasília) e reenvio de push que falhou (a cada 10 min). |
| **pg_net + Vault** | O trigger de `notificacoes` chama a Edge Function com um segredo compartilhado. |
| **Edge Function `enviar-notificacao`** | Lê a notificação, busca os tokens, envia pelo **FCM (API HTTP v1)**, apaga tokens inválidos e marca `push_status`. |
| **Firebase Cloud Messaging** | Só a entrega ao celular (sem Firebase Auth e sem Firestore). |
| **App (Flutter)** | Registra o token, mostra o push (aberto, em segundo plano e fechado), abre a tela certa ao tocar, tela `minhas_notificacoes.dart` e contadores via Realtime. |

Fluxo: **evento no banco → `criar_notificacao()` grava a linha → trigger → Edge Function → FCM → celular.**
A linha é gravada antes de qualquer envio: se o FCM falhar ou o celular estiver offline, a notificação continua na tela de notificações.

Só o tipo **`feedback`** é disparado pelo app (`NotificacaoFeedback`). Todos os outros nascem no servidor.

### Tipos e eventos

| Tipo | Quando | Quem recebe |
|---|---|---|
| `Solicitação` | Nova `solicitacoes` (não vinda do Radar) | Profissional (e o dono da empresa) — com foto e nome do cliente |
| `Solicitação` | `solicitacoes.fk_status` mudou (tipo "Serviço") | Cliente: sempre. Profissional: só em 3 (Pago), 5 (Aguardando Cliente) e 38 (Cliente Deslocando) |
| `Conversa` | Nova `mensagens` | Os outros participantes (nunca quem enviou). Empresa aparece com nome/foto da empresa |
| `radar_prof` | Nova `solicitacoes_geograficas` dentro do raio, com uma **função** do profissional | Profissionais/empresas da área (foto, nome do cliente e distância) |
| `radar_prof` | Proposta aceita (46) ou recusada (45) | Profissional que enviou a proposta |
| `radar_cliente` | `solicitacoes_geograficas.fk_status` mudou (39–44) | Dono do pedido (44 = proposta recebida, com valor) |
| `Sistema` | Todo dia, enquanto houver pendência | Usuário com dados faltando (detalhes abaixo) |
| `Global` | `SELECT enviar_notificacao_global(...)` (preparado) | Todos (ou só Clientes/Profissionais) |
| `feedback` | Carrinho finalizado (`lista_servicos.dart`) | O próprio cliente (notificação local) |

> O Radar compara pela **função** (`fk_funcao`), não pelo ofício: desde
> `migration_oficios_por_categoria.sql` o ofício é a categoria, e comparar por
> ela avisaria um Encanador de pedido de Eletricista.

**Pendências do Sistema (uma notificação por pendência, no máximo 1 por dia):**
- todos: telefone / e-mail / foto (uma notificação só) e nenhum endereço;
- profissional, conforme o **perfil ativo** do aparelho (independente ou empresa):
  pagamentos aceitos, método de entrega, agenda (`agenda_profissional` com
  `fk_solicitacao = 0`), anos de experiência (empresa: `anos_mercado`),
  áreas de atuação e pelo menos um serviço ativo.

Ao preencher o dado, a pendência some e a notificação para de ser criada.

---

## 1. Supabase — banco

Rode no **SQL Editor**, nesta ordem (os que ainda não rodou):

1. `docs/sql/migration_solicitacoes_geograficas_v4.sql`
2. `docs/sql/migration_oficios_por_categoria.sql`
3. `docs/sql/migration_solicitacoes_geograficas_v5_propostas.sql`
4. `docs/sql/notificacoes.sql`

Antes do passo 4, em **Database → Extensions**, habilite **pg_net** e **pg_cron** (o script também tenta).

Depois, crie os 2 segredos do Vault (troque o segredo por um texto longo e aleatório, ex.: gerado em um gerenciador de senhas):

```sql
select vault.create_secret(
  'https://woqhicdlnkoksypipyoz.supabase.co/functions/v1/enviar-notificacao',
  'notificacoes_url_funcao');
select vault.create_secret('COLE-AQUI-UM-SEGREDO-LONGO', 'notificacoes_segredo');
```

## 2. Firebase — projeto e app Android

1. Acesse <https://console.firebase.google.com> → **Adicionar projeto** → nome `ConsertaJa` (o Google Analytics é opcional).
2. No projeto: **Adicionar app → Android**.
   - **Nome do pacote:** `com.example.consertaja` — tem que ser **igual** ao `applicationId` em `android/app/build.gradle.kts`.
     Se um dia trocar o `applicationId` (por exemplo, para `br.com.consertaja`), troque também o `namespace` e cadastre um app novo no Firebase.
   - Apelido: ConsertaJá. O SHA-1 não é necessário para FCM.
3. Baixe o **`google-services.json`** e coloque em **`consertaja/android/app/google-services.json`**.
   - O Gradle já está pronto: `android/settings.gradle.kts` declara o plugin `com.google.gms.google-services` e `android/app/build.gradle.kts` só o aplica quando esse arquivo existe (sem ele, o app compila normalmente, só sem push).
   - Esse arquivo não contém segredo de servidor, mas, se preferir, deixe-o fora do Git e compartilhe com a equipe por fora.
4. **Cloud Messaging** já vem habilitado. Confira em **Configurações do projeto → Cloud Messaging** que a **API Firebase Cloud Messaging (V1)** está **Ativada** (se aparecer como desativada, clique nos ⋮ e ative no Google Cloud).
5. Firebase Core no app: nada a fazer — `NotificacaoService.inicializar()` (em `lib/main.dart`) chama `Firebase.initializeApp()` usando o `google-services.json`.

### Permissões e Android em segundo plano / fechado
- `AndroidManifest.xml` já tem `POST_NOTIFICATIONS` (Android 13+ pede ao usuário na primeira entrada) e `VIBRATE`, além do ícone (`@drawable/ic_notificacao`), cor (`#0FB3FF`) e canal padrão do FCM.
- Desugaring habilitado (exigido pelo `flutter_local_notifications`).
- Em segundo plano/fechado, a Edge Function manda a mensagem **só com `data` e prioridade HIGH**; o app a recebe em `notificacaoEmSegundoPlano` e desenha a notificação (foto redonda, estilo de conversa, cor do status). Isso funciona com o app fechado, **exceto se o usuário usar "Forçar parada"** nas configurações (limitação do Android).
- Alguns celulares (Xiaomi, Samsung com economia agressiva) bloqueiam apps em segundo plano: em testes, deixe o ConsertaJá como "Sem restrições" em Bateria.
- Se preferir que o próprio Android desenhe a notificação (menos estilizada, mas sem depender do app), defina o secret `NOTIFICACOES_MODO_ANDROID=notificacao`.
- Ícones: `tool/gerar_icones_notificacao.dart` gera `ic_notificacao.png` (a própria logo, fundo #0FB3FF opaco) e `notif_logo.png` a partir de `assets/images/icone/icone_consertaja.png`. Na barra de status o Android usa só a transparência do ícone pequeno, então ali ele aparece como um quadrado preenchido. Rode de novo se a logo mudar:
  `dart run tool/gerar_icones_notificacao.dart`

## 3. Credenciais do FCM para a Edge Function

1. Firebase Console → **Configurações do projeto → Contas de serviço → Gerar nova chave privada** (baixa um JSON).
2. **Nunca** coloque esse JSON no app ou no Git (o `.gitignore` já bloqueia `*firebase-adminsdk*.json`). Guarde-o só no Supabase:

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat caminho/da/chave-firebase-adminsdk.json)"
```

```bash
supabase secrets set NOTIFICACOES_SEGREDO=COLE-AQUI-O-MESMO-SEGREDO-DO-VAULT
```

(Pelo painel: **Edge Functions → Secrets → Add new secret**, colando o JSON inteiro como valor.)

3. Publique a função (ela é chamada pelo banco, não pelo app, por isso `--no-verify-jwt`; a proteção é o segredo):

```bash
supabase functions deploy enviar-notificacao --no-verify-jwt
```

A função usa a **API HTTP v1** com OAuth2 da conta de serviço (JWT assinado em `supabase/functions/_shared/fcm.ts`) — nenhuma chave legada.

## 4. Flutter

Dependências (já estão no `pubspec.yaml`):

```yaml
firebase_core: ^5.1.0
firebase_messaging: ^17.0.1
flutter_local_notifications: ^23.0.2
supabase_flutter: ^2.12.4   # já existia
http: ^1.2.1                # já existia (foto do remetente)
image: ^4.5.4               # já existia (foto redonda / ícones)
```

Arquivos novos:

| Arquivo | O que faz |
|---|---|
| `lib/services/notificacoes/notificacao_service.dart` | Serviço central: Firebase, permissão, token, recebimento, toque, Realtime e contadores |
| `lib/services/notificacoes/notificacao_exibicao.dart` | Desenho das notificações (canais, foto, estilo, cor) — também no segundo plano |
| `lib/services/notificacoes/notificacao_destinos.dart` | `tela_destino` → tela (e o destino padrão de cada tipo) |
| `lib/services/notificacoes/notificacao_tipos.dart` | Tipos, canais, cores e ícones; visual por status |
| `lib/services/notificacoes/notificacao_feedback.dart` | Único disparo manual (`feedback`) |
| `lib/services/notificacoes/notificacao_repositorio.dart` | Leitura/abertura/contadores no Supabase |
| `lib/services/notificacoes/notificacao_app.dart` | Modelo |
| `lib/minhas_notificacoes.dart` | Tela de notificações |
| `lib/widgets/contador_notificacoes.dart` | Sininho com contador, contador de mensagens |

Para **criar um tipo novo**: acrescente-o no `CHECK` de `notificacoes.tipo` e no enum `TipoNotificacao`, crie o trigger que chama `public.criar_notificacao(...)` e, se precisar, uma chave nova em `NotificacaoDestinos`.
Para **um feedback novo**: uma função em `NotificacaoFeedback` e a chamada no ponto da tela.

## 5. Como testar cada tipo

Use **dois celulares/emuladores** (ou um celular + o Supabase): um cliente e um profissional. Emulador precisa ter **Google Play**.

Conferência geral no SQL Editor:

```sql
select id_notificacao, fk_usuario, tipo, titulo, push_status, push_erro, data_criacao
from notificacoes order by id_notificacao desc limit 20;

select fk_usuario, plataforma, perfil_ativo, data_atualizacao from dispositivos_notificacao;
```

- `push_status = enviado` → chegou ao FCM. `sem_dispositivo` → o usuário não tem token (entre no app com permissão concedida). `falhou` → veja `push_erro`. `pendente` → faltam os segredos do Vault (passo 1).
- Logs da função: **Edge Functions → enviar-notificacao → Logs**.

| Tipo | Teste |
|---|---|
| **Solicitação (nova)** | Cliente finaliza o carrinho → o profissional recebe "Nova solicitação de …" com a foto do cliente. |
| **Solicitação (status)** | Profissional aceita / cliente paga / profissional inicia deslocamento… Cliente recebe a cada mudança; profissional recebe em Pago, Aguardando Cliente e Cliente Deslocando. Ou: `update solicitacoes set fk_status = 3 where id_solicitacao = X;` |
| **Conversa** | Mande mensagem de um celular para o outro. Com o chat aberto no destinatário, o push não aparece; ao ler, o contador da aba Mensagens zera. |
| **radar_prof** | Cliente cria pedido no Radar a até 5 km do endereço de um profissional com a mesma função → profissional recebe com a distância. Profissional manda proposta; cliente aceita/recusa → profissional recebe "Proposta aceita/recusada". |
| **radar_cliente** | Profissional envia proposta → cliente recebe "Você recebeu uma proposta!" com o valor. Aceitar/recusar/cancelar também gera aviso. |
| **Sistema** | Use uma conta sem telefone ou sem endereço e rode `select public.gerar_notificacoes_sistema();` (rodar de novo no mesmo dia não duplica). |
| **Global** | `select public.enviar_notificacao_global('Novidade!', 'Texto do aviso', null);` |
| **feedback** | Finalize o carrinho → aparece "Solicitação enviada! ✅" na hora. |
| **App fechado** | Feche o app (deslizando nos recentes, sem "Forçar parada"), dispare um evento acima, toque na notificação → o app abre direto na tela certa. |

Teste só de entrega (sem evento): `select public.criar_notificacao(<id_usuario>, 'Sistema', 'Teste', 'Olá do ConsertaJá');`

## 6. Segurança

- `service_role` e a conta de serviço do Firebase ficam só em Secrets do Supabase.
- RLS: cada usuário só lê/abre/exclui as próprias notificações e vê os próprios aparelhos; o app só pode alterar `aberta`/`data_abertura`. Criar notificação e cadastrar token só por funções `SECURITY DEFINER`.
- A Edge Function rejeita chamadas sem o `x-notificacoes-segredo` correto.
