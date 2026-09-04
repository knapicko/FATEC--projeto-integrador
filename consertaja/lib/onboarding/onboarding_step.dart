enum OnboardingStep {
  splash,
  welcome,
  askDocument,
  documentInput,
  documentResult,
  loginOrOther,
  loginForm,
  continueOrLogin,
  perfect,
  chooseAccountPrompt,
  chooseAccount,
  // --- Fluxo Cliente PF ---
  clientPfPrompt,
  clientPfForm,
  contactPrompt,
  contactForm,
  passwordPrompt,
  passwordForm,
  // --- Fluxo Cliente PJ ---
  clientPjPrompt,
  clientPjReviewPrompt,
  clientPjForm,
  // --- Handoff Profissional ---
  professionalHandoff,
  // --- Fluxo Profissional PF (dados pessoais) ---
  profDataForm,
  // --- Fluxo Profissional PJ (revisão empresa) ---
  profPjReviewPrompt,
  profPjReviewPrompt2,
  profPjForm,
  // --- Fluxo Profissional (contato, senha, áreas, docs) ---
  profContactPrompt,
  profContactForm,
  profPasswordPrompt,
  profPasswordForm,
  profAreaPrompt1,
  profAreaPrompt2,
  profAreaPrompt3,
  profAreaForm,
  profDocsPrompt1,
  profDocsPrompt2,
  profDocsForm,
}

enum TipoContaOnboarding { nenhum, cliente, profissional }

bool stepMostraProgresso(OnboardingStep step) {
  return step != OnboardingStep.splash &&
      step != OnboardingStep.welcome &&
      step != OnboardingStep.askDocument;
}

bool stepPermiteToqueAvancar(OnboardingStep step) {
  switch (step) {
    case OnboardingStep.splash:
    case OnboardingStep.welcome:
    case OnboardingStep.askDocument:
    case OnboardingStep.documentResult:
    case OnboardingStep.perfect:
    case OnboardingStep.chooseAccountPrompt:
    case OnboardingStep.clientPfPrompt:
    case OnboardingStep.contactPrompt:
    case OnboardingStep.passwordPrompt:
    case OnboardingStep.clientPjPrompt:
    case OnboardingStep.clientPjReviewPrompt:
    case OnboardingStep.professionalHandoff:
    case OnboardingStep.profPjReviewPrompt:
    case OnboardingStep.profPjReviewPrompt2:
    case OnboardingStep.profContactPrompt:
    case OnboardingStep.profPasswordPrompt:
    case OnboardingStep.profAreaPrompt1:
    case OnboardingStep.profAreaPrompt2:
    case OnboardingStep.profAreaPrompt3:
    case OnboardingStep.profDocsPrompt1:
    case OnboardingStep.profDocsPrompt2:
      return true;
    default:
      return false;
  }
}

double progressoDoPasso(OnboardingStep step) {
  switch (step) {
    case OnboardingStep.splash:
    case OnboardingStep.welcome:
    case OnboardingStep.askDocument:
      return 0;
    case OnboardingStep.documentInput:
      return 0.18;
    case OnboardingStep.documentResult:
      return 0.28;
    case OnboardingStep.loginOrOther:
    case OnboardingStep.continueOrLogin:
      return 0.34;
    case OnboardingStep.loginForm:
      return 0.40;
    case OnboardingStep.perfect:
    case OnboardingStep.chooseAccountPrompt:
    case OnboardingStep.chooseAccount:
      return 0.46;
    case OnboardingStep.clientPfPrompt:
    case OnboardingStep.clientPfForm:
    case OnboardingStep.clientPjPrompt:
    case OnboardingStep.clientPjReviewPrompt:
    case OnboardingStep.clientPjForm:
    case OnboardingStep.professionalHandoff:
    case OnboardingStep.profDataForm:
    case OnboardingStep.profPjReviewPrompt:
    case OnboardingStep.profPjReviewPrompt2:
    case OnboardingStep.profPjForm:
      return 0.55;
    case OnboardingStep.contactPrompt:
    case OnboardingStep.contactForm:
    case OnboardingStep.profContactPrompt:
    case OnboardingStep.profContactForm:
      return 0.65;
    case OnboardingStep.passwordPrompt:
    case OnboardingStep.passwordForm:
    case OnboardingStep.profPasswordPrompt:
    case OnboardingStep.profPasswordForm:
      return 0.74;
    case OnboardingStep.profAreaPrompt1:
    case OnboardingStep.profAreaPrompt2:
    case OnboardingStep.profAreaPrompt3:
    case OnboardingStep.profAreaForm:
      return 0.83;
    case OnboardingStep.profDocsPrompt1:
    case OnboardingStep.profDocsPrompt2:
    case OnboardingStep.profDocsForm:
      return 0.95;
  }
}

