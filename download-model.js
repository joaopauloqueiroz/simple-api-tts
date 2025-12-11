import fs from "fs";
import axios from "axios";

const modelUrl =
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx";
const configUrl =
  "https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx.json";

const folder = "./models";
const modelPath = `${folder}/pt_BR-faber-medium.onnx`;
const configPath = `${folder}/pt_BR-faber-medium.onnx.json`;

if (!fs.existsSync(folder)) fs.mkdirSync(folder, { recursive: true });

async function downloadFile(url, outputPath, description) {
  return new Promise((resolve, reject) => {
    if (fs.existsSync(outputPath)) {
      console.log(`✅ ${description} já existe, skip download.`);
      resolve();
      return;
    }

    console.log(`📥 Baixando ${description}...`);
    axios({
      url,
      method: "GET",
      responseType: "stream",
      maxRedirects: 5,
      validateStatus: (status) => status >= 200 && status < 400
    })
      .then(res => {
        const writer = fs.createWriteStream(outputPath);
        res.data.pipe(writer);
        res.data.on("end", () => {
          console.log(`✅ ${description} baixado!`);
          resolve();
        });
        writer.on("error", (err) => {
          console.error(`❌ Erro ao salvar ${description}:`, err);
          reject(err);
        });
      })
      .catch(err => {
        console.error(`❌ Erro ao baixar ${description}:`, err.message);
        reject(err);
      });
  });
}

async function downloadModel() {
  try {
    await Promise.all([
      downloadFile(modelUrl, modelPath, "modelo Piper PT-BR"),
      downloadFile(configUrl, configPath, "configuração do modelo")
    ]);
    console.log("✅ Todos os arquivos foram baixados com sucesso!");
    process.exit(0);
  } catch (err) {
    console.error("❌ Erro ao baixar arquivos:", err.message);
    process.exit(1);
  }
}

downloadModel();

