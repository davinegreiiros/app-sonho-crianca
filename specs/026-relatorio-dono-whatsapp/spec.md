# Spec: Relatório do dono + envio pelo WhatsApp

Status: Approved
Criado: 2026-10-02

## Problema

A dona do negócio quer saber, sem estar na praça, quanto entrou, por onde entrou e se o caixa de cada monitor bateu. Hoje o app já tem metade disso, espalhado e preso a janelas fixas:

- **Relatório** ([014](../014-migracao-relatorio/spec.md)): total, por forma de pagamento e por brinquedo, mas só nos períodos Hoje / 14 dias / Tudo. Não tem semana nem mês (que é como dono de negócio pensa: "como foi a semana?", "fechou quanto em setembro?"), e não mostra **por monitor**.
- **Painel administrativo** ([023](../023-posto-monitor-painel/spec.md)): faturamento por posto e monitor e diferença de caixa por turno, mas **só do dia de hoje**. Uma diferença de caixa de ontem some da tela.
- **Nada sai do aparelho.** Se a dona não está com o tablet na mão, ela não vê nada. O canal que ela usa o dia inteiro é o WhatsApp.

## Objetivo

Na aba de faturamento, o administrador escolhe Hoje, Semana ou Mês, vê o total por forma de pagamento, por brinquedo, por monitor e as diferenças de caixa do período, e com um toque manda um resumo em texto pelo WhatsApp (ou qualquer app da folha de compartilhamento do celular).

## Fora de escopo

- **Juntar dados de vários aparelhos.** `Rental` e `Turno` ainda moram só no SQLite de cada aparelho ([020](../020-persistencia-local/spec.md); a migração de `Rental` pro backend é a spec seguinte da [025](../025-catalogo-sessao-dispositivo/spec.md)). Cada aparelho gera o relatório do que aconteceu nele. Com um tablet só na praça (cenário assumido na 023), isso já é o negócio inteiro.
- **PDF.** Texto primeiro: abre em qualquer celular, não precisa de app de PDF e cabe numa mensagem. PDF fica pra spec futura se a cliente pedir.
- **Envio automático** (ex.: todo dia às 20h sem ninguém tocar). Envio é sempre ação manual do administrador.
- **Número de WhatsApp fixo/cadastrado.** O app abre a folha de compartilhamento do sistema; quem escolhe o contato é a pessoa.
- **Locações canceladas no relatório.** Cancelar ainda apaga a locação (decisão registrada na 023); não há o que contar.
- **Mudar o painel administrativo (3d).** Continua sendo a visão "agora/hoje" ao vivo; esta spec mexe só na aba de faturamento.
- **Período personalizado** (escolher datas no calendário).

## Decisões propostas (confirmar na aprovação)

- **Períodos: Hoje / Semana / Mês / Tudo.** "14 dias" sai.
  - Semana = segunda-feira 00:00 da semana atual até agora.
  - Mês = dia 1 do mês atual 00:00 até agora.
- **Por monitor = quem recebeu o pagamento** (`finishedByMonitorName`), porque é quem responde pelo dinheiro. Locação encerrada fora de um posto (modo administrador ou dado antigo) aparece como "Administrador".
- **Caixa do período**: lista os turnos fechados no período com diferença diferente de zero (monitor, brinquedo, data, valor da diferença, colorido como no fechamento de turno), mais o saldo somado das diferenças. Sem diferença no período, mostra "Caixa bateu em todos os turnos". O esperado em dinheiro usa **a mesma regra do fechamento de turno (3c)**, pra o número do relatório nunca discordar do que o monitor viu ao fechar.
- **Texto compartilhado leva só números agregados e nomes de monitor/brinquedo.** Nunca nome de criança, nome ou telefone de responsável. Isso mantém a regra da constitution ("dado de criança/responsável nunca trafega pra fora do aparelho sem revisão explícita"): o que sai é resumo financeiro, enviado por ação manual de quem está logado como administrador.
- **Formato do texto** (exemplo, mês):

  ```
  Sonho de Criança — Setembro/2026
  Total: R$ 4.830,00 (312 locações)

  Por pagamento
  Pix: R$ 2.910,00
  Dinheiro: R$ 1.420,00
  Cartão: R$ 500,00

  Por brinquedo
  Cama elástica: R$ 2.100,00 (140)
  Carrinho: R$ 1.730,00 (110)
  Pula-pula: R$ 1.000,00 (62)

  Por monitor
  Gustavo: R$ 2.600,00
  Ana: R$ 2.230,00

  Caixa: 2 turnos com diferença, saldo -R$ 15,00
  Gustavo · Cama elástica · 12/09: -R$ 20,00
  Ana · Carrinho · 20/09: +R$ 5,00
  ```

## Cenários de usuário

1. Dado locações encerradas nesta semana e na anterior, quando o administrador escolhe "Semana", então o total considera só as locações encerradas desde segunda-feira 00:00.
2. Dado locações encerradas em agosto e setembro, quando escolhe "Mês" em setembro, então só setembro entra no total, nos agrupamentos e no histórico.
3. Dado locações encerradas por Gustavo, por Ana e uma pelo administrador, quando o relatório abre, então "Por monitor" mostra uma linha para cada um, incluindo "Administrador", e a soma das linhas é igual ao total do período.
4. Dado um turno fechado ontem com R$ 20 a menos em dinheiro, quando o administrador escolhe "Semana", então a seção de caixa mostra esse turno com -R$ 20,00, o mesmo valor que o monitor viu no fechamento.
5. Dado todos os turnos do período com caixa batendo, quando o relatório abre, então a seção de caixa diz "Caixa bateu em todos os turnos".
6. Dado o relatório de "Mês" na tela, quando o administrador toca em "Enviar resumo", então abre a folha de compartilhamento do celular com o texto do período escolhido pronto, e ele pode escolher o WhatsApp.
7. Dado nenhuma locação no período, quando toca em "Enviar resumo", então o texto diz que não houve locações no período (não manda mensagem vazia nem quebrada).
8. Dado locações com nome de criança e telefone do responsável, quando o resumo é gerado, então nenhum desses dados aparece no texto.
9. Dado a pessoa abre a folha de compartilhamento e desiste, quando volta pro app, então continua na mesma tela, no mesmo período, sem erro.

## Critérios de aceite

- [ ] Seletor de período com Hoje / Semana / Mês / Tudo; Semana começa segunda 00:00, Mês começa dia 1 00:00 (hora local do aparelho).
- [ ] Total, por pagamento, por brinquedo e histórico continuam funcionando em todos os períodos (paridade com a 014 para Hoje e Tudo).
- [ ] Seção "Por monitor" agrupando por quem recebeu o pagamento; sem monitor = "Administrador"; soma das linhas = total.
- [ ] Seção de caixa com turnos fechados no período que tiveram diferença, saldo somado, e mensagem própria quando tudo bateu.
- [ ] Regra de "esperado em dinheiro" do turno idêntica à do fechamento de turno (3c), coberta por teste que compara os dois.
- [ ] Botão "Enviar resumo" abre a folha de compartilhamento do sistema com o texto do período atual.
- [ ] Texto gerado nunca contém `childName`, `guardianName` nem `guardianPhone` (teste dedicado).
- [ ] Texto para período vazio é legível e diz que não houve locações.
- [ ] Nenhuma permissão nova no Android/iOS.
- [ ] `flutter analyze` limpo; testes novos em `test/` cobrindo períodos, agrupamento por monitor, caixa, texto e ausência de dado pessoal. Testes existentes do relatório continuam passando (ajustados só onde "14 dias" virou "Semana").

## Requisitos não-funcionais

- Funciona sem internet (tudo local); compartilhar depende só do app de destino.
- Valores no formato brasileiro (`R$ 1.234,56`), mesmo formatador já usado no app.
- Texto curto o bastante pra ler no celular sem rolar demais: brinquedos e monitores ordenados por valor, do maior pro menor.

## Dúvidas em aberto

Nenhuma bloqueante — resolvidas na aprovação (2026-10-02):

1. ~~Semana de calendário ou últimos 7 dias?~~ **Resolvido**: calendário, segunda 00:00 a domingo.
2. ~~"Tudo" continua existindo?~~ **Resolvido**: mantém.
3. ~~Seção de caixa lista turnos que bateram?~~ **Resolvido**: não, só os com diferença, mais uma linha com a contagem ("18 turnos, 2 com diferença").
4. **Pacote de compartilhamento**: dependência nova pra abrir a folha de compartilhamento nativa (provavelmente `share_plus`). Decisão técnica do `plan.md`, registrada aqui porque mexe em `pubspec.yaml`.
