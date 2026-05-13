#!/bin/bash

echo "=== Configuração do Repositório Sisvisa Architecture ==="

# 1. Perguntar ao usuário onde clonar
read -p "Onde você gostaria de clonar o repositório Sisvisa (caminho absoluto, ex: /Users/kleitonrocha/Projetos/)? " CLONE_DIR

# Validar o diretório
if [ -z "$CLONE_DIR" ]; then
  echo "Diretório de clonagem não pode ser vazio. Saindo."
  exit 1
fi

mkdir -p "$CLONE_DIR"
if [ ! -d "$CLONE_DIR" ]; then
  echo "Não foi possível criar ou acessar o diretório '$CLONE_DIR'. Saindo."
  exit 1
fi

echo "O repositório será clonado em: $CLONE_DIR/sisvisa-arch-setup"

# 2. Verificar se o Git está instalado
if ! command -v git &> /dev/null; then
  echo "Erro: Git não está instalado. Por favor, instale o Git e tente novamente."
  exit 1
fi

# 3. Clonar o repositório Sisvisa
echo "Clonando kleitonkltn/sisvisa-arch-setup..."
git clone git@github.com:kleitonkltn/sisvisa-arch-setup.git "$CLONE_DIR/sisvisa-arch-setup"
if [ $? -ne 0 ]; then
  echo "Falha ao clonar sisvisa-arch-setup."
  echo "Verifique suas permissões SSH para a conta GitHub 'kleitonkltn'."
  echo "Certifique-se de que sua chave SSH para 'kleitonkltn' está adicionada ao GitHub e ao seu ssh-agent ('ssh-add ~/.ssh/personalkey_kleitonkltn' se for essa a chave)."
fi

echo "=== Clonagem do Sisvisa concluída (verifique os logs acima para possíveis erros) ==="
echo "Você pode encontrar o repositório em: $CLONE_DIR/sisvisa-arch-setup"
echo "Lembre-se de configurar a chave SSH correta para 'kleitonkltn' no seu ambiente."