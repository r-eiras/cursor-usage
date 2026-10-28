# Cursor Usage

Veja quanto do seu plano do Cursor você já usou, direto na barra de menus do Mac.

[English](README.md) · [Novidades](https://github.com/r-eiras/cursor-usage/releases/latest) · [Relatar um problema](https://github.com/r-eiras/cursor-usage/issues/new)

**Versão 3.4.7 · Mac com Apple Silicon (M1 ou mais novo) · macOS 14 Sonoma ou mais novo · gratuito e de código aberto**

Este é um projeto independente. Não é feito nem endossado pelo Cursor (Anysphere).

## O que ele faz

- Mostra seu uso do Cursor perto do relógio, em porcentagem, em dólar ou nos dois.
- Mostra dois números: **hoje** e o **ciclo** (o mês de cobrança do seu plano).
- Muda de cor conforme você usa mais: normal, depois amarelo, laranja e vermelho.
- Avisa quando você passa de uma meta, quando o plano renova e quando um modelo gasta muito mais que o normal.
- Se atualiza sozinho.

## Instalação

1. Abra o **Terminal** (aperte ⌘ Espaço, digite "Terminal" e aperte Return).
2. Cole esta linha e aperte Return:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/r-eiras/cursor-usage/main/install.sh | bash
   ```

3. Abra o **Cursor Usage** em Aplicativos.
4. Entre com sua conta do Cursor. Os números aparecem perto do relógio.

Se a sua empresa ou as suas ferramentas bloquearem essa linha, use estas três. O resultado é o mesmo:

```sh
curl -fsSL -O https://raw.githubusercontent.com/r-eiras/cursor-usage/main/install.sh
less install.sh    # opcional: leia antes
bash install.sh
```

> **Use o comando, não baixe pelo navegador nem pelo Homebrew.** O macOS apaga cópias deste app baixadas desses jeitos. Veja [O app sumiu](#o-app-sumiu-ou-o-ícone-não-aparece).

## Como usar

**Clique nos números** perto do relógio (ou só passe o mouse, se ligar essa opção) para abrir o cartão:

- **Resumo**: quanto você gastou no período e em que ritmo.
- **Modelos**: quais modelos custam mais. Ordene por gasto, tokens ou **ritmo** (quanto o modelo costuma gastar em 15 minutos, o mesmo número dos avisos por modelo). Pare o mouse em um para ver os detalhes.
- **Meta**: sua meta de gasto e a cota de hoje.

**Clique com o botão direito** nos números para Configurações, atualizações, desconectar e Sair.

**Hoje** não é um limite do Cursor. O app pega o que sobra no ciclo e divide pelos dias até a renovação, para você saber quanto pode gastar hoje sem passar do plano.

## Configurações

| Aba | O que você ajusta |
| --- | --- |
| **Barra** | Porcentagem ou dólar, consumido ou restante, visualização, ícone, cores pelo uso, rótulos Hoje/Ciclo. Uma prévia mostra o resultado. |
| **Avisos** | Sua meta de gasto, avisos de uso, aviso de renovação, sons e avisos por modelo. |
| **App** | De quanto em quanto tempo sincronizar, idioma, iniciar ao entrar no Mac, verificar atualizações. |

As mudanças valem quando você clica em **Salvar**.

### Visualizações

| Visualização | Mostra |
| --- | --- |
| **Detalhada (hoje e ciclo)** | Os dois números. |
| **Compacta (ciclo)** | Só o ciclo. |
| **Compacta (hoje)** | Só hoje. |
| **Somente logos** | Só o ícone. Clique nele para ver os números. |

### Cores pelo uso

| Usado | Cor |
| --- | --- |
| menos de 30% | normal |
| de 30% a 60% | amarelo |
| de 60% a 90% | laranja |
| 90% ou mais | vermelho |

Escolha se o **ícone** acompanha o ciclo, o dia, ou fica sem cor. Marque **Números também** para colorir hoje e o ciclo, cada um pelo seu uso. As cores seguem sempre o que você **usou**, mesmo que o menu mostre o que sobra.

## Avisos

As notificações só funcionam com o app aberto.

**Avisos de uso** (desligados até você ligar):
- Quando você chega a uma parte do ciclo ou da cota de hoje.
- Quando o plano renova.

**Avisos por modelo** (já vêm ligados):
- **Modelo novo**: na primeira vez que você usa um modelo.
- **Gastando rápido**: quando um modelo gasta em 15 minutos muito mais do que um modelo de referência costuma gastar. Você escolhe quanto a mais, em % ou em dólar, e a referência: seu modelo mais caro ou qualquer modelo usado neste ciclo. As Configurações mostram quanto a referência costuma gastar.
- **Seus limites**: escolha modelos e dê a cada um um limite por dia ou por ciclo. Cada linha mostra quanto ele gastou hoje e no ciclo.

Clicar numa notificação abre o lugar certo: a de atualização instala, a de uso abre o cartão, a de modelo abre as Configurações ou a lista de modelos.

## Atualizações

O app procura versão nova a cada hora. Quando sai uma, aparecem:

- uma notificação,
- um ponto colorido depois dos números na barra,
- um botão **Atualizar para …** no cartão.

Clique em qualquer um. O app confere o download, se substitui e reabre em alguns segundos. Suas configurações e seu login continuam. Se algo der errado, a versão antiga continua funcionando.

## Problemas

### O app sumiu, ou o ícone não aparece

O macOS apaga, poucos segundos depois de abrir, cópias deste app que vieram do navegador ou do Homebrew. Não é um travamento. Esvazie essas cópias da Lixeira e instale com o [comando acima](#instalação).

Por quê: o app não é notarizado pela Apple. O macOS confere apps baixados por navegadores e pelo Homebrew e apaga os que não são notarizados. O comando de instalação baixa com `curl`, que o macOS não confere. Ele não desliga nenhuma proteção do seu Mac. Detalhes em [DISTRIBUTION.md](DISTRIBUTION.md).

### O login pede uma passkey e nada acontece

Clique em **Entrar pelo navegador externo**, no canto de cima da janela de login. O login do Cursor abre no seu navegador normal, onde passkeys, Google e login da empresa funcionam. Veja o [guia do login pelo navegador externo](LOGIN.pt-BR.md).

### As notificações somem rápido demais

Quanto tempo elas ficam é um ajuste do macOS. Em **Configurações → Avisos**, clique em **Ajustar notificações no macOS…** e escolha **Persistente**. Apps que levam as notificações para o notch, como o Vorssaint, também podem escondê-las; desligue neles a opção de esconder o aviso do sistema.

### Uma versão antiga não se atualiza

Versões anteriores à 3.3.0 não conseguem. Rode o [comando de instalação](#instalação) uma vez.

## Privacidade

- Tudo fica no seu Mac, em `~/Library/Application Support/CursorUsage/`.
- Sem chave de API. Você entra pela página do próprio Cursor.
- E-mails e nomes de repositório da exportação do Cursor são descartados.
- Sem analytics nem rastreamento.
- **Desconectar conta** (Configurações ou botão direito) sai da conta e arquiva os dados dela.

Nunca publique dados da sua conta, cookies ou exportações numa issue pública.

## Desinstalar

Desligue **Iniciar ao entrar no Mac**, feche o app e apague ele de Aplicativos. Seus dados ficam em `~/Library/Application Support/CursorUsage/` até você apagar.

## Para desenvolvedores

Compilar e rodar todos os testes (precisa de Python 3 e das Command Line Tools da Apple):

```sh
python3 build.py --ui-tests
python3 package_release.py
```

- [INTEGRATION.md](INTEGRATION.md): como o app lê o painel do Cursor, guarda os dados e se atualiza.
- [DISTRIBUTION.md](DISTRIBUTION.md): assinatura, o script de instalação e os arquivos da release.
- [LOGIN.pt-BR.md](LOGIN.pt-BR.md): o login pelo navegador externo.

O app lê o painel do Cursor e a exportação de uso. Se o Cursor mudar isso, o app pode precisar de atualização. Previsões são estimativas, não faturas.

## Licença

[MIT](LICENSE). O nome e o logo do Cursor pertencem ao seu dono.
