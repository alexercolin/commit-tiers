#!/bin/bash

if [ -z "$1" ]; then
    echo "Uso: $0 <commit-id>"
    exit 1
fi

COMMIT_ID=$1
REPO_DIR=$(pwd)
CURRENT_DATE=$(date +"%Y%m%d%H%M%S")
BRANCHES=("master-tier-3" "master-tier-2" "master-tier-1")

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Erro: Não está em um repositório git"
    exit 1
fi

ORIGINAL_BRANCH=$(git symbolic-ref --short HEAD 2> /dev/null)
if [ $? -ne 0 ]; then
    echo "Erro: Não foi possível determinar a branch atual"
    exit 1
fi

echo "=== Iniciando processo de cherry-pick para o commit $COMMIT_ID ==="

echo "Atualizando a branch master..."
git checkout master || { echo "Erro: Não foi possível mudar para a branch master"; exit 1; }
git pull origin master || { echo "Erro: Não foi possível atualizar a branch master"; exit 1; }

for branch in "${BRANCHES[@]}"; do
    echo "=== Processando $branch ==="
    
    git checkout "$branch" || { echo "Erro: Não foi possível mudar para a branch $branch"; exit 1; }
    git pull origin "$branch" || { echo "Erro: Não foi possível atualizar a branch $branch"; exit 1; }
    
    NEW_BRANCH="$branch-cherry-pick-$CURRENT_DATE"
    echo "Criando nova branch: $NEW_BRANCH"
    git checkout -b "$NEW_BRANCH" || { echo "Erro: Não foi possível criar a branch $NEW_BRANCH"; exit 1; }
    
    echo "Realizando cherry-pick do commit $COMMIT_ID"
    if ! git cherry-pick "$COMMIT_ID"; then
        echo "Conflito durante o cherry-pick na branch $NEW_BRANCH"
        echo "Por favor, resolva os conflitos manualmente, continue o cherry-pick e então execute git push"
        echo "Você está atualmente na branch $NEW_BRANCH"
        exit 1
    fi
    
    echo "Enviando $NEW_BRANCH para o repositório remoto"
    git push -u origin "$NEW_BRANCH" || { echo "Erro: Não foi possível fazer push da branch $NEW_BRANCH"; exit 1; }
    
    REPO_URL=$(git config --get remote.origin.url 2>/dev/null)
    if [[ $REPO_URL == *"github.com"* ]]; then
        REPO_PATH=$(echo $REPO_URL | sed -E 's/.*github.com[\/:]([^.]+)(\.git)?/\1/')
        echo "  GitHub: https://github.com/$REPO_PATH/compare/$branch...$NEW_BRANCH"
    else
        echo "  PR URL: Não foi possível determinar automaticamente."
        echo "  Você precisará criar o PR manualmente para a branch $NEW_BRANCH"
    fi
    echo ""
done

git checkout "$ORIGINAL_BRANCH"
echo "=== Processo concluído com sucesso ==="
echo "Cherry-pick do commit $COMMIT_ID realizado para todas as branches tier" 