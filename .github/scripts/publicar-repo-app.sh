#!/usr/bin/env bash
# Espelha o app nativo (mobile/ e .github/) no repositório público
# arthur-moebios/mapasjw-app, onde rodam os builds do GitHub Actions.
#
# O repositório principal fica privado porque o histórico dele tem segredos;
# o público recebe só uma foto do commit atual, sem histórico do principal.
# Uso: .github/scripts/publicar-repo-app.sh [ref]   (padrão: HEAD)
set -euo pipefail

ref="${1:-HEAD}"
principal="$(git rev-parse --show-toplevel)"
destino="${MAPASJW_APP_CLONE:-/root/.local/share/mapasjw-app-repo}"
remoto="https://github.com/arthur-moebios/mapasjw-app.git"
sha="$(git -C "$principal" rev-parse --short "$ref")"

if [ ! -d "$destino/.git" ]; then
  git clone -q "$remoto" "$destino" 2>/dev/null || { mkdir -p "$destino"; git -C "$destino" init -q -b master; git -C "$destino" remote add origin "$remoto"; }
fi

cd "$destino"
git fetch -q origin 2>/dev/null || true
# Repo público vazio ainda não tem origin/master: cria master local para o 1º push.
if git rev-parse -q --verify refs/remotes/origin/master >/dev/null; then
  git checkout -q -B master origin/master
else
  git checkout -q -B master
fi

# Troca tudo pelo conteúdo do ref: o que sumiu de lá some daqui também.
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
git -C "$principal" archive "$ref" mobile .github | tar -x
find . -name __pycache__ -type d -prune -exec rm -rf {} +

# Os workflows de build do app ficam em mobile/ci/ no repo principal, fora de
# .github/workflows/, para não rodarem no privado. No espelho público eles
# voltam para .github/workflows/, que é onde o GitHub Actions os executa.
if [ -d mobile/ci ]; then
  mkdir -p .github/workflows
  cp mobile/ci/*.yml .github/workflows/
  rm -rf mobile/ci
fi

cat > README.md <<'MD'
# Mapas JW — app nativo

Espelho do app Flutter (`mobile/flutter`) e dos workflows de build. O
desenvolvimento acontece no repositório principal (privado); este recebe uma
cópia a cada publicação para rodar os builds Android/iOS no GitHub Actions e
publicar no SideStore. Não contém segredos: assinatura e deploy ficam nos
GitHub Secrets deste repositório.
MD

git add -A
if git diff --cached --quiet; then
  echo "Nada mudou desde a última publicação."
  exit 0
fi

git -c user.name="$(git -C "$principal" config user.name)" -c user.email="$(git -C "$principal" config user.email)" \
  commit -q -m "Sincroniza com o repositório principal (${sha})"
git push -q origin master
echo "Publicado: $(git rev-parse --short HEAD) ← principal ${sha}"
