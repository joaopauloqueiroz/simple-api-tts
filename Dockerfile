FROM node:20

WORKDIR /app

# Instalar dependências básicas e dados do espeak-ng
RUN apt update && apt install -y \
    wget \
    tar \
    espeak-ng \
    espeak-ng-data \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* && \
    echo "Procurando onde o espeak-ng-data foi instalado..." && \
    find /usr -name "phontab" 2>/dev/null && \
    echo "" && \
    echo "Criando diretório /usr/share/espeak-ng-data se não existir..." && \
    mkdir -p /usr/share/espeak-ng-data && \
    echo "Copiando dados do espeak-ng para /usr/share/espeak-ng-data..." && \
    if [ -d /usr/lib/x86_64-linux-gnu/espeak-ng-data ]; then \
        echo "Copiando de /usr/lib/x86_64-linux-gnu/espeak-ng-data..." && \
        cp -rv /usr/lib/x86_64-linux-gnu/espeak-ng-data/* /usr/share/espeak-ng-data/ 2>&1 | head -10; \
    elif [ -d /usr/lib/espeak-ng-data ]; then \
        echo "Copiando de /usr/lib/espeak-ng-data..." && \
        cp -rv /usr/lib/espeak-ng-data/* /usr/share/espeak-ng-data/ 2>&1 | head -10; \
    elif [ -d /usr/share/espeak-ng-data.orig ]; then \
        echo "Copiando de /usr/share/espeak-ng-data.orig..." && \
        cp -rv /usr/share/espeak-ng-data.orig/* /usr/share/espeak-ng-data/ 2>&1 | head -10; \
    else \
        echo "⚠️ Aviso: Não foi possível encontrar os dados do espeak-ng"; \
    fi && \
    echo "" && \
    echo "Verificando phontab após correção:" && \
    if [ -f /usr/share/espeak-ng-data/phontab ]; then \
        echo "✅ phontab encontrado em /usr/share/espeak-ng-data/phontab" && \
        ls -lh /usr/share/espeak-ng-data/phontab; \
    else \
        echo "❌ phontab ainda não encontrado em /usr/share/espeak-ng-data/"; \
    fi

# Baixar binário pré-compilado ou compilar o Piper
WORKDIR /tmp
RUN ARCH=$(uname -m) && \
    echo "Arquitetura detectada: ${ARCH}" && \
    if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then \
        echo "Tentando baixar binário pré-compilado para x86_64..." && \
        (wget -q --show-progress https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_amd64.tar.gz -O piper.tar.gz 2>&1 || \
         wget -q --show-progress https://github.com/rhasspy/piper/releases/download/v1.1.0/piper_amd64.tar.gz -O piper.tar.gz 2>&1 || \
         wget -q --show-progress https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz -O piper.tar.gz 2>&1 || \
         echo "Binários pré-compilados não encontrados, será necessário compilar") && \
        if [ -f piper.tar.gz ]; then \
            echo "Extraindo binário..." && \
            mkdir -p piper_extracted && \
            tar -xzf piper.tar.gz -C piper_extracted && \
            cd piper_extracted && \
            echo "Conteúdo extraído:" && \
            find . -type f | head -20 && \
            echo "" && \
            echo "Procurando binário piper..." && \
            PIPER_BIN=$(find . -name "piper" -type f -executable | head -1) && \
            if [ -n "$PIPER_BIN" ] && [ -f "$PIPER_BIN" ]; then \
                echo "Binário encontrado em: $PIPER_BIN" && \
                cp "$PIPER_BIN" /usr/local/bin/piper && \
                chmod +x /usr/local/bin/piper && \
                echo "Procurando e copiando bibliotecas compartilhadas..." && \
                find . -name "*.so*" -type f -exec cp -v {} /usr/local/lib/ \; 2>&1 && \
                find . -name "lib" -type d -exec cp -rv {}/* /usr/local/lib/ \; 2>/dev/null || true && \
                ldconfig && \
                echo "✅ Piper instalado via binário pré-compilado"; \
            fi && \
            cd /tmp && \
            rm -rf piper* piper_extracted; \
        fi; \
    fi && \
    if [ ! -f /usr/local/bin/piper ]; then \
        echo "Compilando Piper do código-fonte (isso pode levar vários minutos)..." && \
        apt update && apt install -y \
            build-essential \
            cmake \
            git \
            python3 \
            pkg-config \
            libespeak-ng-dev \
            && rm -rf /var/lib/apt/lists/* && \
        echo "Baixando ONNX Runtime..." && \
        ONNX_VERSION="1.16.3" && \
        ARCH=$(uname -m) && \
        if [ "$ARCH" = "x86_64" ]; then ONNX_ARCH="x64"; \
        elif [ "$ARCH" = "aarch64" ]; then ONNX_ARCH="arm64"; \
        else ONNX_ARCH="x64"; fi && \
        mkdir -p /tmp/onnxruntime && \
        cd /tmp/onnxruntime && \
        if wget -q "https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-${ONNX_ARCH}-${ONNX_VERSION}.tgz" -O onnxruntime.tgz; then \
            echo "Extraindo ONNX Runtime..." && \
            tar -xzf onnxruntime.tgz && \
            ONNX_DIR=$(find . -maxdepth 1 -type d -name "onnxruntime*" | head -1) && \
            echo "ONNX_DIR encontrado: ${ONNX_DIR}" && \
            ls -la ${ONNX_DIR}/include/ 2>/dev/null | head -5 && \
            mkdir -p /usr/local/include && \
            mkdir -p /usr/local/lib && \
            if [ -d "${ONNX_DIR}/include" ]; then \
                if [ -d "${ONNX_DIR}/include/onnxruntime" ]; then \
                    cp -r ${ONNX_DIR}/include/onnxruntime /usr/local/include/ && \
                    echo "✅ Headers copiados de include/onnxruntime"; \
                else \
                    cp -r ${ONNX_DIR}/include/* /usr/local/include/ && \
                    echo "✅ Headers copiados de include/"; \
                fi && \
                echo "Verificando headers instalados..." && \
                find /usr/local/include -name "onnxruntime_cxx_api.h" 2>/dev/null | head -1 && \
                ls -la /usr/local/include/ | grep -E "(onnx|core)" | head -5 || echo "Headers podem estar em subdiretório"; \
            fi && \
            if [ -d "${ONNX_DIR}/lib" ]; then \
                cp -r ${ONNX_DIR}/lib/* /usr/local/lib/ && \
                echo "✅ Bibliotecas copiadas para /usr/local/lib"; \
            fi && \
            ldconfig && \
            echo "✅ ONNX Runtime instalado" && \
            ls -la /usr/local/include/ | grep onnx || echo "Aviso: headers não encontrados em /usr/local/include"; \
        else \
            echo "⚠️ ONNX Runtime não baixado, o Piper tentará baixar automaticamente"; \
        fi && \
        cd /tmp && \
        rm -rf onnxruntime && \
        export CXXFLAGS="-I/usr/local/include" && \
        export CPPFLAGS="-I/usr/local/include" && \
        export LDFLAGS="-L/usr/local/lib" && \
        git clone --depth 1 https://github.com/rhasspy/piper.git && \
        cd piper && \
        git submodule update --init --recursive && \
        mkdir -p build && \
        cd build && \
        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_BUILD_PARALLEL_LEVEL=$(nproc) \
            -DONNXRUNTIME_DIR=/usr/local \
            -DCMAKE_PREFIX_PATH=/usr/local \
            -DCMAKE_CXX_FLAGS="-I/usr/local/include" \
            -DCMAKE_C_FLAGS="-I/usr/local/include" && \
        cmake --build . --config Release --parallel $(nproc) || \
        cmake --build . --config Release -j1 && \
        echo "Listando TODAS as bibliotecas .so geradas..." && \
        find . -name "*.so*" -type f -o -name "*.so*" -type l 2>/dev/null | grep -v CMakeFiles | head -30 && \
        echo "Buscando binário compilado..." && \
        PIPER_BINARY=$(find . -type f -executable -name "piper" ! -path "*/test_piper" 2>/dev/null | head -1) && \
        if [ -n "$PIPER_BINARY" ] && [ -f "$PIPER_BINARY" ]; then \
            echo "✅ Binário encontrado em: $PIPER_BINARY" && \
            cp "$PIPER_BINARY" /usr/local/bin/piper && \
            chmod +x /usr/local/bin/piper && \
            echo "Instalando bibliotecas compartilhadas do Piper..." && \
            mkdir -p /usr/local/lib && \
            echo "Diretório de build atual: $(pwd)" && \
            echo "Procurando TODAS as bibliotecas .so no diretório de build..." && \
            find . -name "*.so*" \( -type f -o -type l \) ! -path "*/CMakeFiles/*" 2>/dev/null | head -50 && \
            echo "" && \
            echo "Copiando TODAS as bibliotecas .so para /usr/local/lib..." && \
            find . -name "*.so*" -type f ! -path "*/CMakeFiles/*" ! -path "*/test/*" 2>/dev/null | while read lib; do \
                echo "  Copiando: $lib" && \
                cp -v "$lib" /usr/local/lib/ 2>&1 || echo "    Erro ao copiar: $lib"; \
            done && \
            find . -name "*.so*" -type l ! -path "*/CMakeFiles/*" ! -path "*/test/*" 2>/dev/null | while read lib; do \
                echo "  Copiando link: $lib" && \
                target=$(readlink "$lib") && \
                cp -v "$lib" /usr/local/lib/ 2>&1 || echo "    Erro ao copiar link: $lib"; \
            done && \
            echo "" && \
            echo "Procurando bibliotecas do Piper..." && \
            echo "Buscando libpiper*.so*..." && \
            find . -name "libpiper*.so*" -type f 2>/dev/null | while read lib; do \
                echo "  Encontrado: $lib" && \
                cp "$lib" /usr/local/lib/ && \
                if [ -L "$lib" ]; then \
                    link_target=$(readlink "$lib") && \
                    link_dir=$(dirname "$lib") && \
                    abs_target="$link_dir/$link_target" && \
                    if [ -f "$abs_target" ]; then \
                        cp "$abs_target" /usr/local/lib/ && \
                        echo "    Copiado link simbólico: $(basename $abs_target)"; \
                    fi; \
                fi; \
            done && \
            echo "Buscando bibliotecas do piper_phonemize..." && \
            find . -path "*phonemize*" -name "*.so*" -type f 2>/dev/null | while read lib; do \
                echo "  Encontrado: $lib" && \
                cp -v "$lib" /usr/local/lib/ && \
                if [ -L "$lib" ]; then \
                    link_target=$(readlink "$lib") && \
                    link_dir=$(dirname "$lib") && \
                    abs_target="$link_dir/$link_target" && \
                    if [ -f "$abs_target" ]; then \
                        cp -v "$abs_target" /usr/local/lib/ && \
                        echo "    Copiado link simbólico: $(basename $abs_target)"; \
                    fi; \
                fi; \
            done && \
            echo "Buscando especificamente libpiper_phonemize.so.1..." && \
            find . -name "*phonemize*.so*" -o -name "*phonemize*.so*" -type l 2>/dev/null | while read lib; do \
                echo "  Encontrado (phonemize): $lib" && \
                cp -v "$lib" /usr/local/lib/ 2>&1 && \
                if [ -L "$lib" ]; then \
                    link_target=$(readlink "$lib") && \
                    link_dir=$(dirname "$lib") && \
                    abs_target="$link_dir/$link_target" && \
                    if [ -f "$abs_target" ]; then \
                        cp -v "$abs_target" /usr/local/lib/ 2>&1 && \
                        echo "    Copiado target do link: $(basename $abs_target)"; \
                    fi; \
                fi; \
            done && \
            echo "Buscando TODAS as bibliotecas que contenham 'piper' ou 'phonemize'..." && \
            find . \( -name "*piper*.so*" -o -name "*phonemize*.so*" \) -type f 2>/dev/null | while read lib; do \
                echo "  Copiando: $lib -> /usr/local/lib/$(basename $lib)" && \
                cp -v "$lib" /usr/local/lib/ 2>&1 || echo "    Erro ao copiar: $lib"; \
            done && \
            find . \( -name "*piper*.so*" -o -name "*phonemize*.so*" \) -type l 2>/dev/null | while read lib; do \
                echo "  Processando link: $lib" && \
                link_target=$(readlink "$lib") && \
                link_dir=$(dirname "$lib") && \
                abs_target="$link_dir/$link_target" && \
                if [ -f "$abs_target" ]; then \
                    echo "    Copiando target: $abs_target -> /usr/local/lib/$(basename $abs_target)" && \
                    cp -v "$abs_target" /usr/local/lib/ 2>&1 || echo "      Erro ao copiar target"; \
                    echo "    Copiando link: $lib -> /usr/local/lib/$(basename $lib)" && \
                    cp -v "$lib" /usr/local/lib/ 2>&1 || echo "      Erro ao copiar link"; \
                fi; \
            done && \
            echo "Buscando bibliotecas do espeak_ng..." && \
            find . -path "*/espeak_ng*" -name "*.so*" -type f 2>/dev/null | while read lib; do \
                echo "  Encontrado: $lib" && \
                cp "$lib" /usr/local/lib/ && \
                if [ -L "$lib" ]; then \
                    link_target=$(readlink "$lib") && \
                    link_dir=$(dirname "$lib") && \
                    abs_target="$link_dir/$link_target" && \
                    if [ -f "$abs_target" ]; then \
                        cp "$abs_target" /usr/local/lib/ && \
                        echo "    Copiado link simbólico: $(basename $abs_target)"; \
                    fi; \
                fi; \
            done && \
            echo "Procurando outras bibliotecas relacionadas..." && \
            find . -name "*.so*" -type f -not -path "*/CMakeFiles/*" -not -path "*/test*" -not -path "*/example*" | while read lib; do \
                if echo "$lib" | grep -qE "(piper|phonemize|espeak)"; then \
                    cp "$lib" /usr/local/lib/ 2>/dev/null && echo "  Copiado: $(basename $lib)" || true; \
                fi; \
            done && \
            echo "Criando links simbólicos se necessário..." && \
            cd /usr/local/lib && \
            echo "Bibliotecas libpiper_phonemize encontradas:" && \
            ls -lh libpiper_phonemize* 2>/dev/null || echo "  Nenhuma encontrada" && \
            for lib in libpiper_phonemize.so*; do \
                if [ -f "$lib" ] && [ ! -L "$lib" ]; then \
                    echo "  Processando: $lib" && \
                    if echo "$lib" | grep -q "\.so\.1$"; then \
                        echo "    Já é .so.1, ok"; \
                    else \
                        libname=$(basename "$lib" | sed 's/\.so\..*/.so.1/') && \
                        if [ "$lib" != "$libname" ] && [ ! -f "$libname" ] && [ ! -L "$libname" ]; then \
                            ln -sf "$lib" "$libname" && echo "    Criado link: $libname -> $lib" || true; \
                        fi; \
                    fi; \
                fi; \
            done && \
            echo "Verificando se libpiper_phonemize.so.1 existe..." && \
            if [ -f "libpiper_phonemize.so.1" ] || [ -L "libpiper_phonemize.so.1" ]; then \
                echo "  ✅ libpiper_phonemize.so.1 encontrado"; \
            else \
                echo "  ⚠️ libpiper_phonemize.so.1 NÃO encontrado, tentando criar..." && \
                for lib in libpiper_phonemize.so*; do \
                    if [ -f "$lib" ]; then \
                        ln -sf "$lib" "libpiper_phonemize.so.1" && echo "    Criado link libpiper_phonemize.so.1 -> $lib" && break; \
                    fi; \
                done; \
            fi && \
            echo "Bibliotecas instaladas em /usr/local/lib:" && \
            ls -lh /usr/local/lib/libpiper* /usr/local/lib/libespeak* 2>/dev/null | head -10 || echo "  (nenhuma biblioteca encontrada)" && \
            echo "Instalando arquivos de dados do espeak-ng..." && \
            find . -path "*/espeak_ng*" -type d -name "espeak-ng-data" | while read datadir; do \
                if [ -d "$datadir" ]; then \
                    mkdir -p /usr/share/espeak-ng-data && \
                    cp -r "$datadir"/* /usr/share/espeak-ng-data/ 2>/dev/null && \
                    echo "  Dados do espeak-ng copiados de: $datadir" || true; \
                fi; \
            done && \
            find . -name "espeak-ng-data" -type d | while read datadir; do \
                if [ -d "$datadir" ] && [ ! -d "/usr/share/espeak-ng-data" ] || [ -z "$(ls -A /usr/share/espeak-ng-data 2>/dev/null)" ]; then \
                    mkdir -p /usr/share/espeak-ng-data && \
                    cp -r "$datadir"/* /usr/share/espeak-ng-data/ 2>/dev/null && \
                    echo "  Dados do espeak-ng copiados de: $datadir" || true; \
                fi; \
            done && \
            echo "/usr/local/lib" > /etc/ld.so.conf.d/piper.conf && \
            ldconfig && \
            echo "" && \
            echo "=== VERIFICAÇÃO FINAL DE BIBLIOTECAS ===" && \
            echo "Bibliotecas em /usr/local/lib:" && \
            ls -lh /usr/local/lib/*.so* 2>/dev/null | grep -E "(piper|phonemize|onnx)" | head -20 || echo "  Nenhuma biblioteca encontrada" && \
            echo "" && \
            echo "Cache do ldconfig:" && \
            ldconfig -p | grep -E "(piper|phonemize|onnx)" | head -10 || echo "  Nenhuma biblioteca no cache" && \
            echo "" && \
            echo "Dependências do binário piper:" && \
            ldd /usr/local/bin/piper 2>&1 | head -20 && \
            echo "✅ Piper e bibliotecas instalados com sucesso"; \
        elif [ -f src/piper ]; then \
            cp src/piper /usr/local/bin/piper && \
            chmod +x /usr/local/bin/piper && \
            echo "Instalando bibliotecas compartilhadas..." && \
            find . -name "libpiper*.so*" -type f -exec cp {} /usr/local/lib/ \; 2>/dev/null || true && \
            ldconfig && \
            echo "✅ Piper instalado de src/piper"; \
        else \
            echo "❌ Erro: binário não foi encontrado após compilação" && \
            echo "Arquivos executáveis encontrados:" && \
            find . -type f -executable 2>/dev/null | head -10 && \
            exit 1; \
        fi && \
        cd /tmp && \
        rm -rf piper; \
    fi

WORKDIR /app

# Copiar arquivos de dependências e o script de download do modelo
COPY package*.json ./
COPY download-model.js ./

# Instalar dependências do Node.js (isso também executa o postinstall que baixa o modelo)
RUN npm install

# Copiar o resto dos arquivos
COPY . .

# Criar wrapper script para o Piper garantir LD_LIBRARY_PATH
RUN echo '#!/bin/bash' > /usr/local/bin/piper-wrapper.sh && \
    echo 'export LD_LIBRARY_PATH=/usr/local/lib:/usr/lib:/lib:${LD_LIBRARY_PATH}' >> /usr/local/bin/piper-wrapper.sh && \
    echo 'exec /usr/local/bin/piper "$@"' >> /usr/local/bin/piper-wrapper.sh && \
    chmod +x /usr/local/bin/piper-wrapper.sh

# Diagnóstico e correção de bibliotecas
RUN echo "=== Diagnóstico de Bibliotecas do Piper ===" && \
    echo "1. Verificando dependências do binário piper:" && \
    ldd /usr/local/bin/piper 2>&1 | grep -E "(not found|piper|phonemize|onnx)" || echo "Todas as dependências encontradas" && \
    echo "" && \
    echo "2. Bibliotecas em /usr/local/lib relacionadas ao Piper:" && \
    ls -lh /usr/local/lib/*piper* /usr/local/lib/*phonemize* /usr/local/lib/*onnx* 2>/dev/null || echo "Nenhuma biblioteca encontrada" && \
    echo "" && \
    echo "3. Criando links simbólicos se necessário..." && \
    cd /usr/local/lib && \
    for lib in *.so.*.*; do \
        if [ -f "$lib" ]; then \
            base=$(echo "$lib" | sed 's/\.so\..*/\.so/') && \
            major=$(echo "$lib" | sed 's/.*\.so\.\([0-9]*\).*/\1/') && \
            if [ -n "$major" ] && [ "$major" != "$lib" ]; then \
                link_name="${base}.${major}" && \
                if [ ! -f "$link_name" ] && [ ! -L "$link_name" ]; then \
                    ln -sf "$lib" "$link_name" && echo "  Criado link: $link_name -> $lib"; \
                fi; \
            fi; \
        fi; \
    done && \
    echo "" && \
    echo "4. Atualizando cache de bibliotecas:" && \
    ldconfig && \
    echo "" && \
    echo "5. Verificando bibliotecas após correção:" && \
    ls -lh /usr/local/lib/*piper* /usr/local/lib/*phonemize* /usr/local/lib/*onnx* 2>/dev/null | head -20 || echo "Nenhuma biblioteca encontrada" && \
    echo "" && \
    echo "6. Verificando dependências novamente:" && \
    ldd /usr/local/bin/piper 2>&1 | head -20

# Verificar se o modelo foi baixado
RUN test -f ./models/pt_BR-faber-medium.onnx || (echo "Erro: Modelo não foi baixado" && exit 1)

# Verificar se o Piper foi instalado corretamente e suas dependências
RUN if [ -f /usr/local/bin/piper ]; then \
        echo "Verificando dependências do Piper..." && \
        export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH && \
        ldd /usr/local/bin/piper 2>&1 | grep -E "(not found|piper|phonemize)" || echo "Todas as dependências encontradas" && \
        echo "Bibliotecas do Piper em /usr/local/lib:" && \
        ls -lh /usr/local/lib/libpiper* 2>/dev/null || echo "  Nenhuma biblioteca libpiper encontrada" && \
        /usr/local/bin/piper --version || echo "Aviso: piper --version falhou, mas o binário existe"; \
    else \
        echo "❌ Erro: Piper não foi instalado corretamente"; \
        exit 1; \
    fi

# Configurar variáveis de ambiente para encontrar bibliotecas
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
ENV PATH=/usr/local/bin:$PATH

# Verificar se todas as bibliotecas necessárias estão presentes
RUN echo "Verificando bibliotecas instaladas..." && \
    ls -lh /usr/local/lib/libpiper* /usr/local/lib/libespeak* 2>/dev/null | head -10 && \
    ldconfig -p | grep -E "(piper|phonemize|espeak)" | head -5 || echo "Aviso: algumas bibliotecas podem não estar no cache" && \
    echo "Verificando se o Piper pode encontrar suas dependências..." && \
    ldd /usr/local/bin/piper 2>&1 | grep -E "(not found|piper|phonemize|espeak)" | head -5 || echo "Todas as dependências encontradas"

EXPOSE 3005

CMD ["npm", "start"]
