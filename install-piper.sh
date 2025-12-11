#!/bin/bash

echo "🔍 Verificando se Piper TTS está instalado..."

if command -v piper &> /dev/null; then
    echo "✅ Piper TTS já está instalado!"
    piper --version
    exit 0
fi

echo "📦 Piper TTS não encontrado. Verificando Homebrew..."

if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew não está instalado."
    echo "Por favor, instale o Homebrew primeiro: https://brew.sh"
    exit 1
fi

echo "📥 Instalando Piper TTS via Homebrew..."
brew install piper-tts

if [ $? -eq 0 ]; then
    echo "✅ Piper TTS instalado com sucesso!"
    piper --version
else
    echo "❌ Erro ao instalar Piper TTS"
    echo "Tente instalar manualmente: brew install piper-tts"
    exit 1
fi

