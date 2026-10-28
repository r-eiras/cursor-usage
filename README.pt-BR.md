# Cursor Usage

Seu consumo e saldo do Cursor na barra de menus do macOS.

[English](README.md) · [Novidades da versão](https://github.com/r-eiras/cursor-usage/releases/latest) · [Reportar problema](https://github.com/r-eiras/cursor-usage/issues/new)

## Instalação

Cole esta linha no Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/r-eiras/cursor-usage/main/install.sh | bash
```

Alguns shells, ferramentas de segurança corporativas e agentes de código com IA recusam um script redirecionado para o shell. Se for o seu caso, baixe primeiro e execute o arquivo — o resultado é o mesmo:

```sh
curl -fsSL -O https://raw.githubusercontent.com/r-eiras/cursor-usage/main/install.sh
less install.sh    # opcional: leia antes de executar
bash install.sh
```

Depois, abra **Cursor Usage** em Aplicativos e entre na sua conta pela página oficial do Cursor. O indicador aparece na barra de menus, perto do relógio. Não há ícone permanente no Dock.

Se a página de login dessa janela não funcionar — por exemplo, sua conta Google pede uma passkey — clique em **Entrar pelo navegador externo**, no canto superior direito da janela. O login do Cursor abre no seu navegador padrão, onde passkeys funcionam, e o app recebe a sessão quando você terminar. Veja [Login pelo navegador externo](#login-pelo-navegador-externo).

Esse comando é a forma de instalar o app, e o mesmo comando atualiza depois. [Por que só este comando](#por-que-só-este-comando) traz o motivo, se você quiser.

**Versão atual: 3.4.3 · build 19 · Apple Silicon · macOS 14 Sonoma ou superior · gratuito e de código aberto**

| Você precisa de | Requisito |
| --- | --- |
| Mac | Apple Silicon: M1 ou mais recente. Este download não atende Macs Intel. |
| macOS | Versão 14 (Sonoma) ou superior. |
| Conta | Uma conta do Cursor com uso disponível no painel oficial. |
| Conexão | Internet para entrar na conta e atualizar o consumo. |

Não precisa instalar Python, Node.js, Xcode, chave de API ou ferramentas de desenvolvimento. Para instalar uma versão específica, informe o número: `bash install.sh 3.4.3`. Quem desenvolve pode compilar a partir do código; veja [Build, testes e distribuição](#build-testes-e-distribuição).

### O app desaparece, ou nenhum ícone aparece

Você vê um ou mais destes sinais:

- Você abre o Cursor Usage e nada aparece perto do relógio.
- O app desaparece de Aplicativos poucos segundos depois de você abrir.
- A Lixeira tem uma cópia com horário no nome, como `Cursor Usage 16-29-25-877.app`.
- Não existe relatório de falha em lugar nenhum.

**É o macOS removendo o app, não o app falhando.** Isso acontece com uma cópia baixada pelo navegador ou instalada pelo Homebrew. Para ter uma instalação que funciona:

1. Apague essas cópias da Lixeira, para não confundir uma delas com uma instalação boa mais tarde.
2. Rode o comando de instalação acima.
3. Abra o app. O indicador aparece perto do relógio.

Se preferir manter uma cópia que o macOS já marcou, pode autorizá-la em **Ajustes do Sistema → Privacidade e Segurança**, na mensagem sobre o app bloqueado. Consulte [a orientação da Apple](https://support.apple.com/pt-br/102445).

### Por que só este comando

Esta versão tem **assinatura ad hoc e não é notarizada**, e isso tem uma consequência concreta.

O macOS coloca um atributo chamado `com.apple.quarantine` nos arquivos gravados por navegadores e por gerenciadores de pacotes como o Homebrew Cask. É esse atributo que faz o Gatekeeper avaliar o app na primeira execução. Quando o Mac está configurado para permitir apps da App Store e de desenvolvedores identificados — o padrão, e o que Macs gerenciados normalmente exigem — a avaliação reprova uma assinatura ad hoc. O app é encerrado poucos segundos depois de abrir e **o bundle é movido para a Lixeira**, o que parece o app se apagando sozinho. Não é gerado relatório de falha, porque é encerramento por política, não travamento.

Ferramentas que gravam arquivos diretamente, como o `curl`, não colocam esse atributo, então uma cópia obtida pelo script de instalação nunca é avaliada. O script não desliga o Gatekeeper, não altera nenhuma configuração do sistema e nunca remove o atributo; em vez disso, recusa instalar uma cópia marcada.

É por isso que este projeto não oferece link de download por navegador nem cask do Homebrew: os dois produzem uma cópia que o macOS remove na primeira abertura. O release continua publicando o ZIP do app, porque o script o baixa, mas baixar esse ZIP pelo navegador reproduz o problema.

Notarizar o app com um Apple Developer ID é a única mudança que faria todos os caminhos funcionarem. Veja as [notas de distribuição](DISTRIBUTION.md).

### Login pelo navegador externo

A janela de login não consegue mostrar a passkey dos sites do Cursor: o macOS só deixa o navegador embutido de um app usar passkeys em sites vinculados a esse app. **Entrar pelo navegador externo**, no canto superior direito dessa janela, faz o login do próprio Cursor no seu navegador padrão, onde passkey, Google e SSO da empresa funcionam, e o app recebe a sessão quando você termina.

A janela continua sendo a primeira opção, porque depende só das páginas públicas do Cursor; o login pelo navegador externo usa endpoints que os apps do próprio Cursor chamam, mas que o Cursor não documenta. O **[guia do login pelo navegador externo](LOGIN.pt-BR.md)** explica quando usar, o passo a passo, o que acontece com a sessão e o que significa cada erro.

### Como atualizar

O app procura uma versão nova a cada hora. Quando sai uma, ele manda uma notificação, põe um ponto na cor de destaque depois do valor na barra de menus e mostra **Atualizar para …** no rodapé do cartão e no topo do menu do botão direito; tudo isso fica até você atualizar. O ponto e o botão não dependem de notificação, então aparecem mesmo quando o Foco ou um utilitário de notificações esconde o aviso. Clique na notificação ou em qualquer um deles: o app baixa a versão, confere contra os checksums e a assinatura do release, se substitui e reabre em alguns segundos. Suas preferências e a sessão da conta continuam como estavam. **Configurações → App → Verificar atualizações** faz o mesmo na hora.

A primeira notificação pede permissão ao macOS uma vez, mesmo que você nunca tenha ligado os avisos de consumo. Se recusar, o item do menu continua oferecendo a atualização.

Se uma atualização não puder terminar, a versão atual continua funcionando e nada é alterado. Você sempre pode reinstalar com o comando de instalação:

```sh
curl -fsSL https://raw.githubusercontent.com/r-eiras/cursor-usage/main/install.sh | bash
```

Versões anteriores à 3.3.0 não se atualizam sozinhas; rode esse comando uma vez para chegar lá.

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
- Avisos por modelo: primeiro uso de um modelo, modelo gastando bem acima do seu modelo mais caro e metas para os modelos que você escolher.
- Opção de desconectar, iniciar com o Mac e interface em português brasileiro ou inglês.

**A cota de hoje é calculada pelo app; não é uma cota diária oficial do Cursor.** O orçamento disponível é dividido entre os dias restantes do ciclo. Um limite pessoal muda essa referência de planejamento: não altera seu plano e não bloqueia cobranças.

Algumas requisições do CSV não informam tokens. Elas continuam contando como requisições e mantêm o custo informado; o total de tokens fica parcial. Uma linha do histórico não equivale necessariamente a uma mensagem sua.

## Como usar

Clique no indicador, ou passe o mouse quando essa opção estiver habilitada. O cartão tem três abas:

- **Resumo:** gastos e atividade do período escolhido, além de informações de ritmo.
- **Modelos:** ranking por gastos ou tokens informados. Pare o mouse sobre um modelo para ver todos os números dele ao lado do cartão: gasto e fatia, requisições, custo médio por requisição e cada tipo de token.
- **Meta:** limite pessoal, planejamento diário e avisos.

O período selecionado muda o relatório histórico. A cota do ciclo na barra continua sendo a referência da assinatura. O botão direito abre o menu com Sobre, Configurações, desconectar, atualizações e sair.

### Configurações

| Aba | Opções |
| --- | --- |
| **Barra** | Formato dos valores, consumo/saldo, densidade, hover/clique, ícone, rótulos Hoje/Ciclo e prévia. |
| **Avisos** | Limite pessoal, porcentagem de aviso no ciclo e no diário calculado, sons, renovação e avisos por modelo com modelos monitorados. |
| **App** | Sincronização, idioma, início com o Mac, Sobre e situação das atualizações. |

**Salvar** aplica as mudanças; **Cancelar** descarta. Iniciar com o Mac é aplicado imediatamente. Mantenha o app num local estável antes de habilitar essa opção. Abrir o cartão da barra esconde temporariamente as configurações sem salvar o rascunho.

Os avisos de consumo começam desligados. Os avisos por modelo começam ligados, porque não precisam de configuração; o primeiro pede permissão de notificação ao macOS uma vez. O app deve estar aberto, e o modo Foco pode afetar a entrega. A mesma leitura não gera avisos repetidos para o mesmo limite. Sem limite pessoal, o aviso do ciclo usa a cota do Cursor.

Clicar num aviso abre o lugar certo: o de atualização instala a versão, o de meta ou renovação abre o orçamento no cartão, o de modelo abre a lista de modelos, e **Monitorar este modelo** abre as Configurações com o modelo na lista.

Quanto tempo o aviso fica na tela é um ajuste do macOS que o app não consegue mudar. Banners **Temporários** somem em alguns segundos e vão para a Central de Notificações; os **Persistentes** ficam até você fechar. **Configurações → Avisos** mostra qual estilo o macOS usa para o app e tem **Ajustar notificações no macOS…**, que abre essa página. Utilitários que levam as notificações para outro lugar, como o Vorssaint com as notificações no notch apagando as nativas, tiram os avisos da Central cerca de um segundo depois de aparecerem; desligue essa opção se os avisos deste app sumirem.

### Avisos por modelo

A cota do Cursor é uma só para todos os modelos, então estes avisos mostram para onde o dinheiro vai, e não um limite do Cursor.

- **Primeiro uso de um modelo.** Quando aparece um modelo que esta conta nunca usou, chega uma notificação com quanto ele já gastou e a ação **Monitorar este modelo**, que abre as Configurações com ele já na lista. A primeira sincronização só aprende os modelos que você usa, para não chegar uma enxurrada de avisos ao instalar o app.
- **Gasto acima do seu modelo mais caro.** O app aprende quanto cada modelo costuma gastar em 15 minutos, pela mediana dos últimos 14 dias, e usa o mais caro como referência. Se algum modelo gastar mais que essa referência mais um limite que você escolhe — 50% por padrão — nos últimos 15 minutos, chega um aviso naquele dia, com os dois modelos e, quando for o caso, quanto cada requisição custa a mais. Ele precisa de algumas sessões de histórico antes de conseguir comparar, e ignora picos abaixo de US$ 1.
- **Modelos monitorados.** Escolha modelos entre os que você usa e dê a cada um um limite por dia, por ciclo ou os dois. Cada linha mostra quanto o modelo gastou hoje e no ciclo, cada valor ao lado do seu limite. Campo vazio significa sem limite; cada campo preenchido avisa uma vez quando o valor é ultrapassado.

Os dados por modelo vêm do histórico que o app importa, então esses avisos chegam dentro do intervalo de sincronização, e não na hora.

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

Métricas e preferências ficam em `~/Library/Application Support/CursorUsage/`. E-mails e repositórios do CSV são descartados; um digest identifica a conta nas métricas importadas. CSVs com várias contas são recusados. Os arquivos temporários são removidos após a importação. Observações de cota ficam por até 40 dias; arquivos de contas desconectadas permanecem no arquivo local até serem removidos. Os nomes dos modelos que esta conta já usou ficam em `models-seen.json`, para reconhecer um primeiro uso; ao desconectar, o arquivo é arquivado com as outras métricas da conta. Depois de um login pelo navegador, a sessão fica em `browser-session.json` nessa pasta, legível só pelo seu usuário, e é renovada cerca de um dia antes de expirar. Desconectar a conta apaga esse arquivo.

O app não pede chave de API, não executa outra ferramenta de IA para consultar a cota e não processa códigos de MFA. O código próprio não adiciona um serviço de analytics ou telemetria; o painel oficial e os provedores de login mantêm seu comportamento de rede.

Não publique cookies, exports brutos, URLs de autenticação ou arquivos pessoais de uso em issues. Detalhes técnicos estão em [INTEGRATION.md](INTEGRATION.md).

## Build, testes e distribuição

Versão atual: **3.4.3, build 19**. Para compilar, instale Python 3 e Apple Command Line Tools compatíveis.

```sh
python3 build.py
python3 build.py --ui-tests
python3 package_release.py
```

O build executa os testes principais e de conteúdo do pacote. A opção `--ui-tests` acrescenta fixtures AppKit/WebKit com dados fictícios numa sessão gráfica. Elas não fazem login numa conta real. O pacote usa uma lista explícita de arquivos permitidos e gera o ZIP do usuário, o ZIP de fontes e um manifesto SHA-256 separados.

## Limitações e colaboração

A leitura depende do resumo mensal e do formato de CSV do Cursor. Mudanças no painel podem exigir ajustes. Dados ausentes ou desatualizados não devem ser tratados como uma nova leitura de consumo zero. Projeções são estimativas.

Intel, outro Mac físico, primeiro login de uma conta limpa, entrega real de notificações sob diferentes modos Foco e início após reiniciar são validações separadas dos testes locais. Assinatura ad hoc não equivale a notarização.

O Sobre traz links do projeto, das versões e das issues. Verificar atualizações consulta a versão pública mais recente sem token do GitHub e compara os números das versões. Quando há uma versão nova, o app pode instalá-la no lugar depois de conferir o checksum do release e a assinatura do bundle, ou abrir a página da versão no GitHub. Reportar problema abre um formulário vazio e não envia diagnósticos ou dados de uso automaticamente.

Use GitHub Issues para bugs reproduzíveis e sugestões objetivas. Informe versões, passos, resultado esperado e resultado observado, sem dados pessoais. Mudanças de comportamento devem incluir testes de regressão.

Para desinstalar, desative o início com o Mac, saia do app e remova-o de Aplicativos. Isso não apaga automaticamente histórico local ou sessão WebKit; consulte [DISTRIBUTION.md](DISTRIBUTION.md) antes de redefinir os dados.

## Licença

[MIT](LICENSE). O nome e o logo do Cursor pertencem ao respectivo titular e identificam o serviço acompanhado.

O teste HTTP opcional das atualizações roda com `python3 Tests/ReleaseUpdates/run.py`. Ele usa Postman CLI 1.73+ para simular o GitHub localmente; essa dependência é somente de desenvolvimento e não entra no app.
