# Cursor Usage

Seu consumo e saldo do Cursor na barra de menus do macOS.

[English](README.md) · [Novidades da versão](https://github.com/r-eiras/cursor-usage/releases/latest) · [Reportar problema](https://github.com/r-eiras/cursor-usage/issues/new)

## Download e instalação

**Versão atual: 3.1.6 · build 12**

### [⬇ Baixar Cursor Usage 3.1.6 para macOS](https://github.com/r-eiras/cursor-usage/releases/download/v3.1.6/CursorUsage-3.1.6-macOS-arm64.zip)

**Apple Silicon · macOS 14 Sonoma ou superior · gratuito e de código aberto**

| Você precisa de | Requisito |
| --- | --- |
| Mac | Apple Silicon: M1 ou mais recente. Este download não atende Macs Intel. |
| macOS | Versão 14 (Sonoma) ou superior. |
| Conta | Uma conta do Cursor com uso disponível no painel oficial. |
| Conexão | Internet para entrar na conta e atualizar o consumo. |

Não precisa instalar Python, Node.js, Xcode, chave de API ou ferramentas de desenvolvimento.

### Opção 1: ZIP — o jeito mais simples

1. **[Baixe o ZIP do app](https://github.com/r-eiras/cursor-usage/releases/download/v3.1.6/CursorUsage-3.1.6-macOS-arm64.zip)** e dê dois cliques nele para extrair.
2. Arraste **Cursor Usage.app** para **Aplicativos**.
3. Abra **Cursor Usage** em Aplicativos e entre na sua conta pela página oficial do Cursor.
4. Clique no indicador perto do relógio para ver seu consumo. O app fica na barra de menus, sem um ícone permanente no Dock.

Use o download acima. Os arquivos **Source code** e **`-source.zip`** são para desenvolvimento, não para instalar o app.

### Opção 2: Homebrew

Já usa o [Homebrew](https://brew.sh)? Copie estas duas linhas no Terminal:

```sh
brew tap r-eiras/cursor-usage https://github.com/r-eiras/cursor-usage
brew install --cask r-eiras/cursor-usage/cursor-usage
```

Depois, abra **Cursor Usage** em Aplicativos e entre na conta. O Homebrew baixa o mesmo app pronto; não compila o projeto nem instala os testes. Este é o tap próprio do projeto, não uma entrada no catálogo oficial do Homebrew.

### Primeira abertura no macOS

Esta versão tem **assinatura ad hoc e não é notarizada**. O macOS pode bloquear o download ou exigir uma decisão explícita do usuário. Instalar pelo Homebrew não elimina essa limitação. Consulte [a orientação da Apple](https://support.apple.com/pt-br/102445) e [as notas de distribuição](DISTRIBUTION.md).

### Como atualizar

Abra **Configurações → App → Verificar atualizações** ou use o botão direito no indicador da barra. O app consulta os releases públicos deste projeto. Se instalou pelo ZIP, baixe a nova versão, saia do app, substitua-o em Aplicativos e abra novamente. As preferências e a sessão da conta ficam preservadas.

Se instalou pelo Homebrew, use:

```sh
brew update
brew upgrade --cask r-eiras/cursor-usage/cursor-usage
```

## Por que ele existe

É fácil se concentrar no trabalho e perder a noção de quanto da cota do Cursor ainda está disponível. Abrir o dashboard o tempo todo interrompe esse fluxo. Além disso, o limite do plano pode ser maior do que você pretende gastar.

O Cursor Usage coloca os números úteis a um olhar de distância: cota consumida ou restante, uso de hoje e ritmo do ciclo. Metas pessoais e avisos opcionais ajudam a perceber seus limites antes. A proposta é um app simples, com configurações claras e dados armazenados localmente.

Este é um projeto independente, sem vínculo ou endosso da Anysphere.

## O que ele oferece

- Porcentagem, valor em US$ ou ambos, como consumo ou saldo restante.
- Visualização **Detalhada** com hoje e ciclo, **Compacta** com o ciclo e **Somente logos**.
- Ícone próprio de medidor ou logo do Cursor; abertura por clique ou hover.
- Resumo de gastos, requisições, tokens informados e ranking de modelos.
- Períodos: hoje, semana corrente, últimos três ou sete dias e mês corrente. O padrão de uma instalação nova é o mês corrente.
- Limite pessoal de gastos, avisos de ciclo/cota diária calculada, som opcional e aviso de renovação.
- Opção de desconectar, iniciar com o Mac e interface em português brasileiro ou inglês.

**A cota de hoje é calculada pelo app; não é uma cota diária oficial do Cursor.** O orçamento disponível é dividido entre os dias restantes do ciclo. Um limite pessoal muda essa referência de planejamento: não altera seu plano e não bloqueia cobranças.

Algumas requisições do CSV não informam tokens. Elas continuam contando como requisições e mantêm o custo informado; o total de tokens fica parcial. Uma linha do histórico não equivale necessariamente a uma mensagem sua.

## Como usar

Clique no indicador, ou passe o mouse quando essa opção estiver habilitada. O cartão tem três abas:

- **Resumo:** gastos e atividade do período escolhido, além de informações de ritmo.
- **Modelos:** ranking por gastos ou tokens informados.
- **Meta:** limite pessoal, planejamento diário e avisos.

O período selecionado muda o relatório histórico. A cota do ciclo na barra continua sendo a referência da assinatura. O botão direito abre o menu com Sobre, Configurações, desconectar, atualizações e sair.

### Configurações

| Aba | Opções |
| --- | --- |
| **Barra** | Formato dos valores, consumo/saldo, densidade, hover/clique, ícone, rótulos Hoje/Ciclo e prévia. |
| **Avisos** | Limite pessoal, porcentagem de aviso no ciclo e no diário calculado, sons e renovação. |
| **App** | Sincronização, idioma, início com o Mac, Sobre e situação das atualizações. |

**Salvar** aplica as mudanças; **Cancelar** descarta. Iniciar com o Mac é aplicado imediatamente. Mantenha o app num local estável antes de habilitar essa opção. Abrir o cartão da barra esconde temporariamente as configurações sem salvar o rascunho.

Os avisos começam desligados e precisam de permissão do macOS. O app deve estar aberto, e o modo Foco pode afetar a entrega. A mesma leitura não gera avisos repetidos para o mesmo limite. Sem limite pessoal, o aviso do ciclo usa a cota do Cursor.

Para trocar de conta, use **Desconectar conta** nas configurações ou no menu do botão direito; depois conecte novamente. A ação limpa a sessão de website deste app e arquiva as métricas da conta localmente, preservando as preferências visuais.

## Tecnologias

| Tecnologia | Uso |
| --- | --- |
| **Swift** | Lógica, cálculos, parsing e persistência. |
| **AppKit** | Barra de menus, cartão, configurações e ícone vetorial do medidor. |
| **WebKit** | Login no painel oficial e exportação de uso. |
| **UserNotifications** | Notificações locais. |
| **ServiceManagement** | Início opcional com o Mac por `SMAppService`. |
| **Foundation / CryptoKit** | Datas, CSV/JSON, arquivos locais e identificador derivado da conta. |
| **Python 3 / ferramentas Apple** | Build, testes, pacotes e checksums; somente no desenvolvimento. |

O app pronto não exige instalar Python, Node.js, Electron ou pacotes de terceiros.

## Dados e privacidade

O app usa a sessão própria do WebKit para abrir `https://cursor.com/dashboard/usage`. Lê o resumo de cota mensal e importa o CSV oficial. O parsing acontece em segundo plano, e o WebView é liberado entre sincronizações concluídas, preservando a sessão.

Métricas e preferências ficam em `~/Library/Application Support/CursorUsage/`. E-mails e repositórios do CSV são descartados; um digest identifica a conta nas métricas importadas. CSVs com várias contas são recusados. Os arquivos temporários são removidos após a importação. Observações de cota ficam por até 40 dias; arquivos de contas desconectadas permanecem no arquivo local até serem removidos.

O app não pede chave de API, não executa outra ferramenta de IA para consultar a cota e não processa códigos de MFA. O código próprio não adiciona um serviço de analytics ou telemetria; o painel oficial e os provedores de login mantêm seu comportamento de rede.

Não publique cookies, exports brutos, URLs de autenticação ou arquivos pessoais de uso em issues. Detalhes técnicos estão em [INTEGRATION.md](INTEGRATION.md).

## Build, testes e distribuição

Versão atual: **3.1.6, build 12**. Para compilar, instale Python 3 e Apple Command Line Tools compatíveis.

```sh
python3 build.py
python3 build.py --ui-tests
python3 package_release.py
```

O build executa os testes principais e de conteúdo do pacote. A opção `--ui-tests` acrescenta fixtures AppKit/WebKit com dados fictícios numa sessão gráfica. Elas não fazem login numa conta real. O pacote usa uma lista explícita de arquivos permitidos e gera o ZIP do usuário, o ZIP de fontes e um manifesto SHA-256 separados.

## Limitações e colaboração

A leitura depende do resumo mensal e do formato de CSV do Cursor. Mudanças no painel podem exigir ajustes. Dados ausentes ou desatualizados não devem ser tratados como uma nova leitura de consumo zero. Projeções são estimativas.

Intel, outro Mac físico, primeiro login de uma conta limpa, entrega real de notificações sob diferentes modos Foco e início após reiniciar são validações separadas dos testes locais. Assinatura ad hoc não equivale a notarização.

O Sobre traz links do projeto, das versões e das issues. Verificar atualizações consulta a versão pública mais recente sem token do GitHub e compara os números das versões. O usuário pode abrir a página da nova versão para baixar e instalar. Reportar problema abre um formulário vazio e não envia diagnósticos ou dados de uso automaticamente.

Use GitHub Issues para bugs reproduzíveis e sugestões objetivas. Informe versões, passos, resultado esperado e resultado observado, sem dados pessoais. Mudanças de comportamento devem incluir testes de regressão.

Para desinstalar, desative o início com o Mac, saia do app e remova-o de Aplicativos. Isso não apaga automaticamente histórico local ou sessão WebKit; consulte [DISTRIBUTION.md](DISTRIBUTION.md) antes de redefinir os dados.

## Licença

[MIT](LICENSE). O nome e o logo do Cursor pertencem ao respectivo titular e identificam o serviço acompanhado.

O teste HTTP opcional das atualizações roda com `python3 Tests/ReleaseUpdates/run.py`. Ele usa Postman CLI 1.73+ para simular o GitHub localmente; essa dependência é somente de desenvolvimento e não entra no app.
