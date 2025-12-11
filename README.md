# Piper TTS API

API REST para síntese de voz usando Piper TTS com modelo em português brasileiro.

## Pré-requisitos

- Node.js 18+ OU Docker
- Piper TTS instalado no sistema (se não usar Docker)

## Instalação

### Opção 1: Usando Docker (Recomendado)

A forma mais simples é usar Docker, que já instala tudo automaticamente:

```bash
# Build da imagem
docker build -t piper-tts-api .

# Executar o container
docker run -p 3000:3000 piper-tts-api
```

Ou usando Docker Compose:

```bash
docker-compose up --build
```

O servidor estará disponível em `http://localhost:3000`

### Opção 2: Instalação Local

#### 1. Instalar dependências do Node.js

```bash
npm install
```

Isso irá baixar automaticamente o modelo de voz necessário.

#### 2. Instalar Piper TTS

##### macOS (via Homebrew)

```bash
brew install piper-tts
```

Ou use o script fornecido:

```bash
npm run install-piper
```

##### Linux (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install piper-tts
```

##### Outros sistemas

Consulte a [documentação oficial do Piper](https://github.com/rhasspy/piper) para instruções de instalação.

#### 3. Iniciar o servidor

```bash
npm start
```

O servidor estará disponível em `http://localhost:3000` (ou na porta definida pela variável de ambiente `PORT`)

### Endpoint de TTS

**POST** `/tts`

**Body:**
```json
{
  "text": "Olá, seja bem vindo"
}
```

**Resposta:**
- Content-Type: `audio/wav`
- Body: Arquivo de áudio WAV

**Exemplo com curl:**

```bash
curl -X POST http://localhost:3000/tts \
  -H "Content-Type: application/json" \
  -d '{"text":"Olá, seja bem vindo"}' \
  --output audio.wav
```

## Estrutura do Projeto

- `server.js` - Servidor Express com endpoint de TTS
- `download-model.js` - Script para baixar o modelo do Hugging Face
- `install-piper.sh` - Script para instalar Piper TTS no macOS
- `Dockerfile` - Configuração para build da imagem Docker
- `docker-compose.yml` - Configuração para Docker Compose
- `models/` - Pasta onde os modelos são armazenados

## Solução de Problemas

### Erro: "Piper TTS não está instalado"

Instale o Piper TTS seguindo as instruções acima.

### Erro: "Modelo não encontrado"

Execute `npm install` novamente para baixar o modelo.

### Erro: "command not found: piper"

Certifique-se de que o Piper está instalado e disponível no PATH do sistema.

