import express from "express";
import { v4 as uuid } from "uuid";
import { exec, spawn } from "child_process";
import path from "path";
import fs from "fs";

const app = express();
app.use(express.json());

const MODEL_PATH = "./models/pt_BR-faber-medium.onnx";

function checkPiperInstalled() {
  return new Promise((resolve) => {
    exec("which piper", (error) => {
      resolve(!error);
    });
  });
}

app.post("/tts", async (req, res) => {
  const { text } = req.body;

  if (!text) return res.status(400).json({ error: "text is required" });

  const isPiperInstalled = await checkPiperInstalled();
  if (!isPiperInstalled) {
    return res.status(500).json({
      error: "Piper TTS não está instalado",
      message: "O Piper TTS precisa estar instalado no sistema. No Docker, isso deve ser feito durante o build da imagem."
    });
  }

  if (!fs.existsSync(MODEL_PATH)) {
    return res.status(500).json({
      error: "Modelo não encontrado",
      message: `O modelo não foi encontrado em ${MODEL_PATH}. Execute 'npm install' para baixar o modelo.`
    });
  }

  const output = `/tmp/${uuid()}.wav`;
  
  // Usar spawn para maior segurança (evita injeção de comandos)
  // Usar wrapper script que garante LD_LIBRARY_PATH está configurado
  const piperCommand = fs.existsSync("/usr/local/bin/piper-wrapper.sh") 
    ? "/usr/local/bin/piper-wrapper.sh" 
    : "piper";
  
  const piperProcess = spawn(piperCommand, ["-m", MODEL_PATH, "-f", output], {
    stdio: ["pipe", "pipe", "pipe"],
    env: {
      ...process.env,
      LD_LIBRARY_PATH: "/usr/local/lib:/usr/lib:/lib:" + (process.env.LD_LIBRARY_PATH || ""),
      PATH: process.env.PATH || "/usr/local/bin:/usr/bin:/bin"
    }
  });

  let stderrOutput = "";

  piperProcess.stderr.on("data", (data) => {
    stderrOutput += data.toString();
  });

  piperProcess.on("error", (err) => {
    console.error("Erro ao executar piper:", err);
    return res.status(500).json({
      error: "Erro ao gerar áudio",
      details: err.message
    });
  });

  piperProcess.on("close", (code) => {
    if (code !== 0) {
      console.error("Piper retornou código de erro:", code);
      console.error("stderr:", stderrOutput);
      return res.status(500).json({
        error: "Erro ao gerar áudio",
        details: `Piper retornou código ${code}`,
        stderr: stderrOutput
      });
    }

    if (!fs.existsSync(output)) {
      return res.status(500).json({
        error: "Arquivo de áudio não foi gerado",
        details: "O Piper executou mas não gerou o arquivo de saída"
      });
    }

    try {
      const file = fs.readFileSync(output);
      res.setHeader("Content-Type", "audio/wav");
      res.send(file);
      fs.unlinkSync(output);
    } catch (fileErr) {
      console.error("Erro ao ler arquivo:", fileErr);
      res.status(500).json({ error: "Erro ao ler arquivo de áudio" });
    }
  });

  // Enviar o texto para o stdin do Piper
  piperProcess.stdin.write(text);
  piperProcess.stdin.end();
});

const PORT = 3005;

app.listen(PORT, () => {
  console.log(`🚀 TTS API rodando em http://localhost:${PORT}`);
});
