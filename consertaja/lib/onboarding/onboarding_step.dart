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
  clientPfPrompt,
  clientPfForm,
  contactPrompt,
  contactForm,
  passwordPrompt,
  passwordForm,
  clientPjPrompt,
  clientPjReviewPrompt,
  clientPjForm,
  professionalHandoff,
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
      return 0.55;
    case OnboardingStep.contactPrompt:
    case OnboardingStep.contactForm:
      return 0.70;
    case OnboardingStep.passwordPrompt:
    case OnboardingStep.passwordForm:
      return 0.86;
  }
}
