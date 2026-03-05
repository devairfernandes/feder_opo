# 📘 Guia de Publicação - Feder_OPO

Este documento contém os textos e informações necessários para publicar o aplicativo na Google Play Store.

---

## 1. Informações Básicas (Ficha da Loja)

*   **Nome do App:** Feder_OPO - Fotos 3x4
*   **Título Curto:** Fotos para Documentos 3x4
*   **Descrição Curta:** Crie fotos 3x4 e documentos oficiais em segundos com fundo branco automático.

### Descrição Completa:
O Feder_OPO é a ferramenta definitiva para quem precisa de fotos para documentos de forma rápida, profissional e gratuita. Ideal para fotos de Identidade (RG), CNH, Passaporte e Crachás.

**Principais Recursos:**
*   **Remoção de Fundo Inteligente:** Nossa tecnologia de IA identifica a pessoa e substitui o fundo original por um fundo branco padrão oficial automaticamente.
*   **Guia de Enquadramento:** Overlay de silhueta para garantir que sua cabeça e ombros fiquem na posição correta.
*   **Grade de Impressão A4:** Escolha a quantidade de fotos (padrão 2 unidades, expansível até 12) e gere uma folha A4 pronta para impressão.
*   **Qualidade Profissional:** Fotos redimensionadas para o tamanho exato de 30x40mm com alta resolução (300 DPI).
*   **Privacidade Total:** Todo o processamento de imagem é feito localmente no seu celular. Não enviamos suas fotos para servidores externos.

Desenvolvido especialmente para facilitar a vida do cidadão e de instituições que precisam de fotos rápidas com qualidade garantida.

---

## 2. Gráficos e Imagens (Assets)

Para a loja, você precisará preparar:
1.  **Ícone do App:** 512x512 pixels (PNG com transparência ou fundo preenchido).
2.  **Gráfico de Recurso (Banner):** 1024x500 pixels.
3.  **Capturas de Tela (Screenshots):** Pelo menos 4 fotos do app em funcionamento (Tela da Câmera, Tela de Edição com fundo branco e a Folha A4 gerada).

---

## 3. Informações Técnicas para o Console

*   **Identificador do Pacote (Package Name):** `br.org.federopo.foto3x4`
*   **Categoria:** Ferramentas / Fotografia.
*   **Classificação Etária:** Livre (L).
*   **Acesso a Dados:** O app solicita acesso à **Câmera** e **Galeria** (Armazenamento).

---

## 4. Política de Privacidade (Obrigatório)

O Google exige um link para uma política de privacidade. Segue um modelo simplificado:

> **Política de Privacidade - Feder_OPO**
> O aplicativo Feder_OPO não coleta, armazena ou compartilha dados pessoais dos usuários. O acesso à câmera e galeria é utilizado exclusivamente para a captura e salvamento das fotos no próprio dispositivo do usuário. O processamento de inteligência artificial para remoção de fundo é executado de forma offline. Nenhuma imagem é transmitida para fora do dispositivo.

---

## 5. Como gerar o arquivo final para a Loja (AAB)

Para publicar, o Google não aceita mais o arquivo `.apk`, você deve gerar o arquivo `.aab` (Android App Bundle).

**Comando para gerar:**
```powershell
flutter build appbundle
```

O arquivo final estará em: `build/app/outputs/bundle/release/app-release.aab`

---

*Documento gerado em 05/03/2026 para auxílio na publicação oficial.*
