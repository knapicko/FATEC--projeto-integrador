#!/usr/bin/env bash
# Plano de Testes PT-CJ-01 - ConsertaJá
# Executa os testes automatizados e gera coverage/lcov.info (+ HTML se houver lcov)
cd "$(dirname "$0")"
flutter pub get

echo "===== Testes do plano (com cobertura) ====="
flutter test test/plano_testes --coverage --reporter expanded

echo "===== Regressão (sem os testes de defeitos conhecidos) ====="
flutter test test/plano_testes --exclude-tags defeito

if command -v genhtml >/dev/null 2>&1; then
  genhtml coverage/lcov.info -o coverage/html >/dev/null
  echo "Relatório HTML: coverage/html/index.html"
else
  echo "Relatório: coverage/lcov.info (instale o lcov para gerar HTML)"
fi
