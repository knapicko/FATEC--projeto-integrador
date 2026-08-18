## Projeto - Conserta Já

| **Equipe** | **Tecnologias Utilizadas** | **APIs** |
|------------|---------------------------|------------|
| • Flávio Henrique (Project Owner) <br> • Gabriel Santos (Desenvolvedor Back-end) <br> • Gustavo Almeida (Desenvolvedor Full-Stack e Designer) <br> • Leandro Oliveira (Designer e Analista) <br> • Lucas Eiji (Scrum Master e Analista) <br> • Luiz Knapick (Analista e Desenvolvedor Full-Stack) | • Dart <br> • Flutter <br> • Supabase <br> • Google Cloud | • JusBrasil <br> • AwesomeAPI
### Sobre o Projeto:

A Conserta Já é uma plataforma de integração mobile voltada para a conexão entre prestadores de serviços especializados em manutenção e seus clientes. O foco central reside em profissionais de ocupações tradicionais e pouco mercantilizados, como paneleiros, afiadores e técnicos de eletrodomésticos, que frequentemente operam na informalidade e com baixa visibilidade de mercado.

### Como executar o projeto

Existem duas formas de utilizar o projeto: **baixando o APK pronto** ou **abrindo o projeto pelo VS Code**.

#### Opção 1 — Baixar o APK

Para utilizar o aplicativo sem precisar configurar o projeto:

1. Acesse a área de **Releases** deste repositório no GitHub.
2. Baixe o arquivo **`app-release.apk`**.
3. Execute o arquivo no seu dispositivo Android para instalar o aplicativo.

#### Opção 2 — Abrir o projeto no VS Code

Para executar e modificar o projeto, é necessário ter instalado:

* **Flutter**
* **Dart**
* **Visual Studio Code**
* **Google Chrome (para executar a versão Web)**

Para **gerar o APK Android**, também é necessário ter o **Android Studio**, com o Android SDK configurado.

> Se você só quiser utilizar o aplicativo, não é necessário instalar nada disso. Basta baixar o arquivo `latest-release.apk` na área de Releases.

Depois de instalar os requisitos:

1. Abra o projeto no **Visual Studio Code**.
2. Abra o terminal dentro do VS Code.
3. Execute os comandos abaixo:

```bash
flutter pub get
flutter pub upgrade
```

Depois, escolha como deseja executar o projeto.

**Para gerar um APK:**

```bash
flutter build apk --release
```

O APK será gerado na pasta de build do projeto.

**Para executar a versão Web:**

```bash
flutter run -d chrome --web-port 8080
```

O projeto será aberto no navegador Chrome utilizando a porta **8080**.

> **Observação:** verifique se o Flutter está configurado corretamente executando `flutter doctor` no terminal antes de iniciar o projeto.
