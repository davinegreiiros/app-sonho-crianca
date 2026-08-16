# Spec: Catálogo — disponibilidade em "tickets" + tipo obrigatório do brinquedo

Status: Draft
Criado: 2026-08-15

## Problema

Hoje o card de cada brinquedo em "Brinquedos" (`lib/screens/tabs/catalog_tab.dart:172`) mostra disponibilidade como texto: `"2 livres"` / `"todos em uso"`. Funciona, mas é só número — não dá a leitura visual rápida de "quantas unidades tenho, quantas estão em uso agora" que o dono do negócio quer numa banca com o pátio cheio.

Também não existe hoje nenhum campo de **tipo/categoria** no brinquedo (`lib/models/toy.dart`) — só nome, ícone, preço, duração e quantidade. Ao cadastrar um brinquedo novo (`AddToySheet`) não se declara que *tipo* de brinquedo é (elétrico, insuflável, passeio, aquático, etc.), então o catálogo não consegue nunca ser filtrado/agrupado por tipo nem mostrar essa informação no card.

## Objetivo

O card do catálogo mostra a disponibilidade como uma fileira de "tickets" (um por unidade cadastrada, visualmente diferenciando livre de em uso) em vez do texto de contagem, e todo brinquedo — seed ou cadastrado pelo usuário — carrega um tipo/categoria visível como tag no card.

## Fora de escopo

- Filtro/busca por tipo na UI (só exibição do tipo agora; filtrar é feature futura, não pedida aqui).
- Mudar a régua de preço/duração por tipo (preço continua por brinquedo, não por categoria).
- Geração das novas ilustrações em si — ver seção "Assets novos" abaixo, é passo manual fora do meu alcance nesta sessão.

## Cenários de usuário

1. Dado um brinquedo com quantidade 3 e 1 unidade alugada agora, quando o usuário abre "Brinquedos", então o card mostra 3 tickets — 2 no estilo "livre" e 1 no estilo "em uso" — em vez do texto "2 livres".
2. Dado um brinquedo com todas as unidades em uso, quando o usuário olha o card, então todos os tickets aparecem no estilo "em uso" (sem precisar ler texto pra saber).
3. Dado um brinquedo com quantidade alta (ex: 10), quando os tickets não cabem na largura do card, então mostra um número máximo de tickets + rótulo `"+N"` — nunca estoura o layout do card.
4. Dado o usuário cadastrando um brinquedo novo em "Adicionar brinquedo", quando ele preenche o formulário, então tipo/categoria é campo obrigatório (não dá pra salvar sem escolher) — igual a nome e ícone já são hoje.
5. Dado um brinquedo já existente (dos 5 do seed), quando o catálogo é aberto, então ele também mostra um tipo — precisa de valor padrão migrado pros 5 seeds (`carrinho`, `cama`, `pula`, `piscina`, `patinete`), não pode quebrar por falta de dado.

## Critérios de aceite

- [ ] `Toy` ganha campo `category` (tipo enum fechado, não string livre — ver dúvidas em aberto pra lista final) — `required`, sem default silencioso que mascare brinquedo sem tipo.
- [ ] Os 5 brinquedos seed em `kInitialToys` (`toy.dart:39-45`) recebem categoria coerente com o nome.
- [ ] `AddToySheet` ganha seletor de tipo, obrigatório pra habilitar "Salvar brinquedo" (mesmo padrão de validação que já existe pra nome/quantidade/preço/minutos em `_valid`).
- [ ] Card do catálogo mostra uma tag de tipo (reaproveitando o token de tag já usado pra "livre/em uso" — ver `specs/001-tema-layout-parity/`), sem quebrar a altura fixa do card (`_contentHeight` em `catalog_tab.dart:25`).
- [ ] Pílula de texto de disponibilidade é substituída por fileira de tickets no estilo **canhoto de ingresso** (retângulo pequeno com picote/serrilhado nas pontas, combinando com o tom "impresso/broadsheet" do `PrintStrip` já existente): 1 ticket por unidade de `qty`, com 2 estados visuais (livre / em uso) reusando `toy.ink` como já faz hoje.
- [ ] Acima de um limite de tickets visíveis (definir número exato no `plan.md` a partir da largura real do card), sobra vira `+N`, testado com brinquedo de `qty` alta.
- [ ] `toyAvailable(toy)` (`app_state.dart:126`) continua sendo a única fonte de verdade de quantas unidades estão livres — o widget de tickets é só leitura disso, não duplica lógica.
- [ ] Teste de widget cobrindo: card com todas unidades livres, card com unidades mistas, card com todas em uso, card com `qty` acima do limite de tickets visíveis.
- [ ] Suite atual (`test/widget_test.dart`, `integration_test/app_test.dart`) continua passando sem alteração — nenhum finder de texto existente (`"2 livres"` etc., se algum teste usar) pode quebrar sem ser atualizado deliberadamente como parte desta spec.

## Assets novos (ilustrações)

Pedido: gerar mais imagens de brinquedo seguindo a mesma estrutura visual das 12 já existentes em `assets/images/toy-*.png`, alinhadas ao design system que a spec `001-tema-layout-parity` documenta.

Não tenho ferramenta de geração de imagem disponível nesta sessão pra criar arte nova nesse estilo. Caminhos possíveis:
1. Você gera as ilustrações via Claude Design (mesmo projeto `.dc.html`) numa sessão interativa e me passa os arquivos — eu cuido de nomear (`toy-<key>.png`), registrar em `kToyIconOptions` e cablar no picker do `AddToySheet`, que já é 100% orientado a dado (nenhuma mudança estrutural necessária).
2. Você já tem os arquivos prontos — só me diz onde estão e eu integro.

Isso fica como task bloqueada em `tasks.md` até um dos dois caminhos acontecer — o resto da spec (tickets + tipo) não depende disso e pode seguir sozinho.

## Dúvidas em aberto

- Lista fechada de categorias: proponho `eletrico`, `inflavel`, `passeio`, `aquatico`, `radiocontrole`, `outro` — confirma ou ajusta?
- Limite de tickets visíveis antes do `+N`: baseado em quantas unidades reais o negócio costuma ter por brinquedo hoje (a maioria é 1–2)? Se sim, um limite baixo tipo 6 já cobre folgado.
