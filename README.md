# 📸 Feder_OPO - Gerador de Fotos 3x4 e Oficiais

Este é um aplicativo Flutter profissional desenvolvido para captura, edição e geração automática de grades de impressão para fotos de documentos (3x4, Passaporte, Visto EUA, etc).

## 🚀 Funcionalidades Principais

- **Captura Inteligente**: Overlay de silhueta para garantir o enquadramento perfeito (cabeça e ombros).
- **Múltiplos Formatos**: Seleção dinâmica de modelos (3x4, Passaporte BR, Passaporte EUA, Crachás).
- **Remoção de Fundo (IA)**: Usa o **Google ML Kit (Selfie Segmentation)** para identificar o usuário e trocar o fundo por branco puro (#FFFFFF) de forma offline.
- **Edição em Tempo Real**: Ajustes de Brilho e Contraste com preview instantâneo via GPU (`ColorFilter`).
- **Folha de Impressão (10x15cm)**: Gera automaticamente uma grade de fotos pronta para imprimir em papel fotográfico padrão.
- **Salvamento Direto**: Integração com a galeria de fotos do Android (`Gal`).

---

## 🛠️ Detalhes Técnicos

### 1. Estrutura do Projeto
```text
foto3x4/
├── android/               # Configurações nativas do Android (Permissões, SDK)
│   └── app/
│       ├── build.gradle.kts # Configuração de compilação (minSdk 21)
│       └── src/main/
│           └── AndroidManifest.xml # Permissões de Câmera/Galeria
├── lib/                   # Código fonte Dart (Flutter)
│   └── main.dart          # Arquivo único com TODA a lógica do app (UI/Câmera/IA)
├── pubspec.yaml           # Dependências (camera, mlkit, image, gal)
├── build/                 # Saída dos APKs compilados
└── README.md              # Guia de documentação (este arquivo)
```

- **`lib/main.dart`**: Contém toda a lógica do app (Câmera, Telas de Edição, Processamento de Imagem).
- **`android/app/build.gradle.kts`**: Configurado com `minSdk 21` (Necessário para o ML Kit).
- **`AndroidManifest.xml`**: Permissões de Câmera (`CAMERA`) e Galeria (`WRITE_EXTERNAL_STORAGE` para APIs antigas).

### 2. Processamento de Imagem (Fix "Foto Preta")
Alguns dispositivos Android retornam imagens com profundidade de cor ou canais diferentes do padrão. Para evitar o erro de "foto preta" ao salvar, implementamos:
- **Normalização de Cores**: Toda imagem capturada é convertida para RGB 8-bit frame-a-frame antes de qualquer edição.
- **Pintura de Pixels**: O método `setPixelRgb` é usado para garantir que todos os dados de cor sejam preservados durante a cópia e crop.

### 3. Remoção de Fundo (IA)
A remoção de fundo utiliza a tecnologia de segmentação de selfie do ML Kit. Ela gera uma "máscara de confiança". Pixels com confiança < 0.5 são pintados de branco.

---

## 📁 Como Adicionar Novos Modelos
Para adicionar um novo formato de documento, basta adicionar um novo item na lista `officialModels` em `lib/main.dart`:
```dart
PhotoModel(name: 'Novo Formato', aspectRatio: largura / altura, description: 'Descrição do uso'),
```

---

## 🏗️ Comandos de Compilação

Para gerar o APK de teste (Debug):
```powershell
flutter build apk --debug
```

Para gerar a versão final para uso (Release):
```powershell
flutter build apk --release
```

O arquivo final ficará em: `build/app/outputs/flutter-apk/app-release.apk`

# 📸 Feder_OPO - Gerador de Fotos 3x4 e Oficiais

Este é um aplicativo Flutter profissional desenvolvido para captura, edição e geração automática de grades de impressão para fotos de documentos (3x4, Passaporte, Visto EUA, etc).

## 🚀 Funcionalidades Principais

- **Captura Inteligente**: Overlay de silhueta para garantir o enquadramento perfeito (cabeça e ombros).
- **Múltiplos Formatos**: Seleção dinâmica de modelos (3x4, Passaporte BR, Passaporte EUA, Crachás).
- **Remoção de Fundo (IA)**: Usa o **Google ML Kit (Selfie Segmentation)** para identificar o usuário e trocar o fundo por branco puro (#FFFFFF) de forma offline.
- **Edição em Tempo Real**: Ajustes de Brilho e Contraste com preview instantâneo via GPU (`ColorFilter`).
- **Folha de Impressão (10x15cm)**: Gera automaticamente uma grade de fotos pronta para imprimir em papel fotográfico padrão.
- **Salvamento Direto**: Integração com a galeria de fotos do Android (`Gal`).

---

## 🛠️ Detalhes Técnicos

### 1. Estrutura do Projeto
```text
foto3x4/
├── android/               # Configurações nativas do Android (Permissões, SDK)
│   └── app/
│       ├── build.gradle.kts # Configuração de compilação (minSdk 21)
│       └── src/main/
│           └── AndroidManifest.xml # Permissões de Câmera/Galeria
├── lib/                   # Código fonte Dart (Flutter)
│   └── main.dart          # Arquivo único com TODA a lógica do app (UI/Câmera/IA)
├── pubspec.yaml           # Dependências (camera, mlkit, image, gal)
├── build/                 # Saída dos APKs compilados
└── README.md              # Guia de documentação (este arquivo)
```

- **`lib/main.dart`**: Contém toda a lógica do app (Câmera, Telas de Edição, Processamento de Imagem).
- **`android/app/build.gradle.kts`**: Configurado com `minSdk 21` (Necessário para o ML Kit).
- **`AndroidManifest.xml`**: Permissões de Câmera (`CAMERA`) e Galeria (`WRITE_EXTERNAL_STORAGE` para APIs antigas).

### 2. Processamento de Imagem (Fix "Foto Preta")
Alguns dispositivos Android retornam imagens com profundidade de cor ou canais diferentes do padrão. Para evitar o erro de "foto preta" ao salvar, implementamos:
- **Normalização de Cores**: Toda imagem capturada é convertida para RGB 8-bit frame-a-frame antes de qualquer edição.
- **Pintura de Pixels**: O método `setPixelRgb` é usado para garantir que todos os dados de cor sejam preservados durante a cópia e crop.

### 3. Remoção de Fundo (IA)
A remoção de fundo utiliza a tecnologia de segmentação de selfie do ML Kit. Ela gera uma "máscara de confiança". Pixels com confiança < 0.5 são pintados de branco.

---

## 📁 Como Adicionar Novos Modelos
Para adicionar um novo formato de documento, basta adicionar um novo item na lista `officialModels` em `lib/main.dart`:
```dart
PhotoModel(name: 'Novo Formato', aspectRatio: largura / altura, description: 'Descrição do uso'),
```

---

## 🏗️ Comandos de Compilação

Para gerar o APK de teste (Debug):
```powershell
flutter build apk --debug
```

Para gerar a versão final para uso (Release):
```powershell
flutter build apk --release
```

O arquivo final ficará em: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📝 Notas de Versão (V1.0)
- ✅ Fix: Bug de foto preta em dispositivos Sansung/Xiaomi.
- ✅ Fix: Botão de salvar agora respeita a `SafeArea` do Android.
- ✅ Performance: Preview de edição usando filtros de matriz (GPU).
- ✅ IA: Selfie Segmentation da Google integrada (processamento offline).

---

## 📜 Licença

Este projeto está licenciado sob a **Licença MIT**. Consulte o arquivo `LICENSE.txt` para obter mais detalhes.

---
*Documentação gerada para facilitar manutenções futuras e expansão de recursos.*
