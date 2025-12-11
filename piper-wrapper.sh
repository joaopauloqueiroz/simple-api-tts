#!/bin/bash
# Wrapper para garantir que o Piper encontre suas bibliotecas
export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib:${LD_LIBRARY_PATH}
exec /usr/local/bin/piper "$@"

