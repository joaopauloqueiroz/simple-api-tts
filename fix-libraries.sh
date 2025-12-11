#!/bin/bash
# Script para diagnosticar e corrigir problemas com bibliotecas do Piper

echo "=== Diagnóstico de Bibliotecas do Piper ==="

echo "1. Verificando dependências do binário piper:"
ldd /usr/local/bin/piper 2>&1 | grep -E "(not found|piper|phonemize)" || echo "Todas as dependências encontradas"

echo ""
echo "2. Bibliotecas em /usr/local/lib relacionadas ao Piper:"
ls -lh /usr/local/lib/*piper* /usr/local/lib/*phonemize* 2>/dev/null || echo "Nenhuma biblioteca encontrada"

echo ""
echo "3. Buscando libpiper_phonemize.so.1:"
if [ -f "/usr/local/lib/libpiper_phonemize.so.1" ] || [ -L "/usr/local/lib/libpiper_phonemize.so.1" ]; then
    echo "  ✅ Encontrado: /usr/local/lib/libpiper_phonemize.so.1"
    ls -lh /usr/local/lib/libpiper_phonemize.so.1
else
    echo "  ❌ NÃO encontrado"
    echo "  Tentando criar link simbólico..."
    cd /usr/local/lib
    for lib in libpiper_phonemize.so*; do
        if [ -f "$lib" ]; then
            ln -sf "$lib" "libpiper_phonemize.so.1" && echo "    ✅ Criado link: libpiper_phonemize.so.1 -> $lib" && break
        fi
    done
fi

echo ""
echo "4. Atualizando cache de bibliotecas:"
ldconfig

echo ""
echo "5. Verificando novamente após ldconfig:"
ldconfig -p | grep -E "(piper|phonemize)" || echo "Bibliotecas não encontradas no cache"

echo ""
echo "6. Testando se o Piper funciona:"
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib:$LD_LIBRARY_PATH
/usr/local/bin/piper --version 2>&1 || echo "Piper ainda não funciona"

