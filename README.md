# 📸 Feder_OPO - Gerador de Fotos 3x4 e Oficiais

![Versão](https://img.shields.io/badge/VERSÃO-1.2.1-00E676?style=for-the-badge)
![Flutter](https://img.shields.io/badge/FLUTTER-3.X-02569B?style=for-the-badge&logo=flutter)
![Android](https://img.shields.io/badge/ANDROID-5.0+-3DDC84?style=for-the-badge&logo=android)
![Licença](https://img.shields.io/badge/LICENÇA-PRIVADO-F44336?style=for-the-badge)

Este é um aplicativo Flutter profissional desenvolvido para captura, edição e geração automática de grades de impressão para fotos de documentos (3x4, Passaporte, Visto EUA, etc).

---

## 🚀 Funcionalidades Principais

- **🎨 Interface Premium**: Design moderno em modo escuro com paleta de cores Indigo e tipografia Outfit.
- **📸 Captura Inteligente**: Overlay de silhueta para garantir o enquadramento perfeito (cabeça e ombros).
- **📏 Múltiplos Formatos**: Suporte para 3x4 oficial e exportação direta em folha A4.
- **📉 APK Otimizado**: Build focada em performance e tamanho reduzido (~17.8MB).
- **💾 Salvamento e Compartilhamento**: Integração direta com a galeria e opção de compartilhar folha A4 pronta para impressão.

---

## 🛠️ Detalhes Técnicos

### 1. Estrutura do Projeto
```text
foto3x4/
├── android/               # Configurações nativas do Android (Permissões, SDK)
├── build/                 # Saída dos APKs compilados
├── lib/                   # Código fonte Dart (Flutter)
│   └── main.dart          # Lógica central (UI, Câmera, Processamento de Imagem)
├── pubspec.yaml           # Gerenciamento de dependências e versão
└── version.json           # Controle de versão para atualizações OTA
```

### 2. Otimizações de Tamanho
O projeto utiliza compilação específica para arquitetura `ARM64-v8a` (`--split-per-abi`), reduzindo drasticamente o peso do aplicativo para facilitar a distribuição e o download em conexões móveis.

---

## 🏗️ Comandos de Manutenção

### Atualizar dependências:
```powershell
flutter pub get
```

### Compilar versão de lançamento (Otimizada):
```powershell
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

O arquivo final otimizado ficará em: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

---

## 📁 Como Adicionar Novos Modelos
Para adicionar um novo formato de documento, atualize a lista `officialModels` em `lib/main.dart`:
```dart
PhotoModel(name: 'Novo Formato', aspectRatio: largura / altura, description: 'Descrição'),
```

---

## 📜 Licença

Propriedade privada de **Devair Fernandes**. Desenvolvido para facilitar o fluxo de trabalho de documentação rápida e eficiente.

---
*Dev: Devair Fernandes | (69) 99221-4709*
