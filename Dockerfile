FROM node:20

WORKDIR /app

# Instalar dependências básicas e dados do espeak-ng
RUN apt update && apt install -y \
    wget \
    tar \
    espeak-ng \
    espeak-ng-data \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Baixar binário pré-compilado ou compilar o Piper
WORKDIR /tmp
RUN ARCH=$(uname -m) && \
    echo "Arquitetura detectada: ${ARCH}" && \
    if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then \
        echo "Tentando baixar binário pré-compilado para x86_64..." && \
        (wget -q --show-progress https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_amd64.tar.gz -O piper.tar.gz 2>&1 || \
         wget -q --show-progress https://github.com/rhasspy/piper/releases/download/v1.1.0/piper_amd64.tar.gz -O piper.tar.gz 2>&1 || \
         echo "Binários pré-compilados não encontrados, será necessário compilar") && \
        if [ -f piper.tar.gz ]; then \
            echo "Extraindo binário..." && \
            tar -xzf piper.tar.gz && \
            find . -name "piper" -type f -executable | head -1 | xargs -I {} cp {} /usr/local/bin/piper && \
            chmod +x /usr/local/bin/piper && \
            rm -rf piper* && \
            echo "✅ Piper instalado via binário pré-compilado"; \
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
        echo "Buscando binário compilado..." && \
        PIPER_BINARY=$(find . -type f -executable -name "piper" ! -path "*/test_piper" 2>/dev/null | head -1) && \
        if [ -n "$PIPER_BINARY" ] && [ -f "$PIPER_BINARY" ]; then \
            echo "✅ Binário encontrado em: $PIPER_BINARY" && \
            cp "$PIPER_BINARY" /usr/local/bin/piper && \
            chmod +x /usr/local/bin/piper && \
            echo "Instalando bibliotecas compartilhadas do Piper..." && \
            mkdir -p /usr/local/lib && \
            echo "Procurando bibliotecas do Piper..." && \
            find . -name "libpiper*.so*" -type f -exec sh -c 'echo "  Encontrado: $1" && cp "$1" /usr/local/lib/' _ {} \; 2>/dev/null || true && \
            find . -path "*/piper_phonemize*" -name "*.so*" -type f -exec sh -c 'echo "  Encontrado: $1" && cp "$1" /usr/local/lib/' _ {} \; 2>/dev/null || true && \
            find . -path "*/espeak_ng*" -name "*.so*" -type f -exec sh -c 'echo "  Encontrado: $1" && cp "$1" /usr/local/lib/' _ {} \; 2>/dev/null || true && \
            echo "Procurando outras bibliotecas relacionadas..." && \
            find . -name "*.so*" -type f -not -path "*/CMakeFiles/*" -not -path "*/test*" -not -path "*/example*" | while read lib; do \
                if echo "$lib" | grep -qE "(piper|phonemize|espeak)"; then \
                    cp "$lib" /usr/local/lib/ 2>/dev/null && echo "  Copiado: $(basename $lib)" || true; \
                fi; \
            done && \
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
            ldconfig -v 2>&1 | grep -E "(piper|phonemize|espeak)" | head -5 || true && \
            echo "Verificando se as bibliotecas podem ser encontradas..." && \
            ldconfig -p | grep -E "(piper|phonemize|espeak)" | head -5 || echo "  Aviso: bibliotecas não encontradas no cache" && \
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

# Verificar se o modelo foi baixado
RUN test -f ./models/pt_BR-faber-medium.onnx || (echo "Erro: Modelo não foi baixado" && exit 1)

# Verificar se o Piper foi instalado corretamente
RUN if [ -f /usr/local/bin/piper ]; then \
        export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH && \
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
