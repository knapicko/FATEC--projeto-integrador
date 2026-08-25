# Conserta Já

<p align="center">
  <a href="https://flutter.dev/" target="_blank">
    <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter">
  </a>
  <a href="https://dart.dev/" target="_blank">
    <img src="https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  </a>
  <a href="https://developer.android.com/studio" target="_blank">
    <img src="https://img.shields.io/badge/Android%20Studio-3DDC84?style=for-the-badge&logo=android-studio&logoColor=white" alt="Android Studio">
  </a>
  <a href="https://supabase.com/" target="_blank">
    <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase">
  </a>
  <a href="https://leafletjs.com/" target="_blank">
    <img src="https://img.shields.io/badge/Leaflet-199900?style=for-the-badge&logo=leaflet&logoColor=white" alt="Leaflet">
  </a>
  <a href="https://cloud.google.com/" target="_blank">
    <img src="https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white" alt="Google Cloud">
  </a>
</p>

> A **Conserta Já** é uma plataforma de integração mobile voltada para a conexão entre prestadores de serviços especializados em manutenção e seus clientes. O foco central reside em profissionais de ocupações tradicionais e pouco mercantilizados (como paneleiros, afiadores e técnicos de eletrodomésticos), que frequentemente operam na informalidade e com baixa visibilidade de mercado.

---

## Telas do Aplicativo

<p align="center">
  <img src="docs/Imagens Projeto/home.png" alt="Tela 1" width="30%">
  &nbsp;&nbsp;&nbsp;
  <img src="docs/Imagens Projeto/perfil_profissional.png" alt="Tela 2" width="30%">
  &nbsp;&nbsp;&nbsp;
  <img src="docs/Imagens Projeto/servicos.png" alt="Tela 3" width="30%">
</p>

---

## Nossa Equipe

O projeto foi desenvolvido por uma equipe multidisciplinar:

* **Flávio Henrique** — *Product Owner*
* **Gabriel Santos** — *Desenvolvedor Back-end*
* **Gustavo Almeida** — *Desenvolvedor Full-Stack e Designer*
* **Leandro Oliveira** — *Designer e Analista*
* **Lucas Eiji** — *Scrum Master e Analista*
* **Luiz Knapick** — *Analista e Desenvolvedor Full-Stack*

---

## APIs e Ferramentas Utilizadas

* **[JusBrasil](https://www.jusbrasil.com.br/)**
* **[AwesomeAPI](https://docs.awesomeapi.com.br/)**
* **[Leaflet](https://leafletjs.com/)** — Mapeamento e geolocalização interativa

---

## Como executar o projeto

Você pode testar a **Conserta Já** de duas maneiras: utilizando o aplicativo pronto ou executando o código-fonte na sua máquina.

### Opção 1 — Baixar o APK (Instalação Rápida)

Se você deseja apenas testar o aplicativo sem precisar configurar um ambiente de desenvolvimento:

1. Acesse a área de **[Releases](../../releases)** deste repositório.
2. Baixe o arquivo `app-release.apk`.
3. Transfira para o seu dispositivo Android e execute-o para instalar.

### Opção 2 — Executar pelo VS Code ou Android Studio (Para Desenvolvedores)

Para executar e modificar o projeto, certifique-se de ter os seguintes requisitos instalados:
* **[Flutter SDK](https://flutter.dev/docs/get-started/install)** e **Dart**
* **Visual Studio Code** ou **[Android Studio](https://developer.android.com/studio)**
* **Google Chrome** (para rodar a versão Web)

> **Atenção!** Ao executar `flutter build apk` no seu terminal para buildar o apk, o cadastro e login com o Google não ficará disponível por conta do SHA-1 cadastrado no computador.

> **Dica:** Antes de começar, execute `flutter doctor` no seu terminal para verificar se o seu ambiente está configurado corretamente.

**Passo a passo:**

1. Clone o repositório e abra o projeto no **VS Code** ou **Android Studio**.
2. Abra o terminal integrado e atualize as dependências:
   ```bash
   flutter pub get
   flutter pub upgrade
