# Login pelo navegador externo

[English](LOGIN.md) · [Voltar ao README](README.pt-BR.md)

O Cursor Usage lê o seu consumo no painel do Cursor, que ele abre numa janela de login própria. A maioria das contas entra por ali. Quando essa janela não consegue terminar — geralmente porque a conta usa passkey — **Entrar pelo navegador externo** faz o login no Safari, no Chrome ou no navegador que for o seu padrão.

## Quando usar

Use se a janela de login travar, por exemplo quando:

- sua conta do Google, GitHub ou Apple pede uma **passkey** e nenhum pedido de passkey aparece;
- o Google se recusa a entrar dentro do app;
- o login da sua empresa (SSO) precisa de algo que a janela não oferece.

Se você entra com e-mail e código, a janela funciona e você não precisa disto.

## Como entrar

1. Abra o **Cursor Usage**. Se ele ainda não estiver conectado, a janela de login abre.
2. No canto superior direito dessa janela, clique em **Entrar pelo navegador externo**.
3. A página de login do Cursor abre no seu navegador. Entre como você sempre faz: com passkey, Google, GitHub ou SSO.
4. Quando o navegador disser que terminou, volte ao app. Ele pega a sessão sozinho em alguns segundos, fecha a janela e mostra seu consumo perto do relógio.

Você tem cinco minutos para terminar no navegador. Enquanto o app espera, o botão vira **Cancelar login no navegador externo**; clique nele para parar.

## Por que a janela não mostra a passkey

O macOS só deixa o navegador embutido de um app usar passkeys em sites vinculados a esse app. O login do Cursor acontece nos sites do Cursor e dos provedores de identidade dele, aos quais um app de terceiros nunca pode ser vinculado. Por isso, dentro da janela, o pedido de passkey desses sites nunca aparece.

O seu navegador padrão não tem essa limitação. O login pelo navegador externo roda o login do próprio Cursor ali — o mesmo fluxo que o editor do Cursor usa — e depois entrega o resultado ao app.

## O que acontece com a sua sessão

- O app recebe uma sessão do Cursor e a entrega à janela de login, então a leitura da cota e do histórico funciona exatamente como depois de um login normal.
- A sessão fica salva em `browser-session.json`, em `~/Library/Application Support/CursorUsage/`, legível só pelo seu usuário do macOS.
- Uma sessão dura cerca de dois meses. O app a renova mais ou menos um dia antes de expirar, então você não precisa entrar de novo.
- **Desconectar conta** apaga essa sessão junto com o resto dos dados de login.
- O app nunca vê sua senha, passkey ou código de MFA. Eles ficam entre você, o seu navegador e o Cursor.

## Se algo der errado

| O que aparece | O que significa | O que fazer |
| --- | --- | --- |
| "O tempo para concluir o login no navegador acabou" | Passaram cinco minutos sem o login terminar. | Clique no botão de novo e termine no navegador. |
| "Não foi possível falar com o Cursor" | O app não conseguiu falar com os servidores do Cursor. | Confira a conexão ou a VPN e tente de novo. |
| "O Cursor não aceitou o login feito no navegador" | O painel do Cursor recusou a sessão que o navegador gerou. | Entre pela janela com e-mail e código. |
| "O Cursor respondeu de um jeito que o app não reconhece" | O Cursor mudou a forma como o login responde. | Entre pela janela com e-mail e código e [reporte o problema](https://github.com/r-eiras/cursor-usage/issues/new). |

Contas corporativas também podem ser bloqueadas por uma política da organização que só permite login de dispositivos ou apps aprovados. Nesse caso quem decide é a sua empresa, não o app.

## Limitações

A janela de login continua sendo a primeira opção, porque depende só das páginas públicas do Cursor. O login pelo navegador externo usa endpoints que os apps do próprio Cursor chamam, mas que o Cursor não documenta, então uma mudança do lado do Cursor pode quebrá-lo até o app ser atualizado. Quando isso acontecer, entrar pela janela com e-mail e código continua funcionando.

Os detalhes técnicos do fluxo estão em [INTEGRATION.md](INTEGRATION.md).
