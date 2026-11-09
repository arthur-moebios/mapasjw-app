# Mapas JW mobile

O cliente móvel mantido está em `mobile/flutter` e é implementado em Flutter.
Ele consome a API Laravel em `https://mapasjw.com.br/api`; as telas de mapa,
territórios, Cartas, cartões de rua e conta são interfaces nativas do Flutter.
O identificador `br.com.mapasjw.cartas` permanece igual para preservar a
instalação existente e seus dados locais.

## Autenticação e localização

O login Google acontece no navegador do sistema e retorna ao app pelo deep link
PKCE. O token da API fica no armazenamento seguro do aparelho.

O app só solicita localização quando a pessoa toca em **Minha localização** ou
escolhe iniciar um trajeto. O registro em segundo plano exige confirmação e as
permissões correspondentes, verifica novamente no servidor se o território pode
ser trabalhado naquele horário e pode ser encerrado pelo usuário. Pontos
temporariamente sem conexão ficam numa fila local até o envio ser confirmado.

## Instalação e publicação

No iOS, adicione uma vez a fonte SideStore:

`https://app.moebiosenergy.com.br/sidestore/source.json`

No Android, o APK nativo Flutter assinado é publicado no endereço estável:

`https://app.moebiosenergy.com.br/sidestore/apps/android/br.com.mapasjw.cartas/latest.apk`

O workflow de release compila e publica somente o IPA por padrão. A versão
Android só é recompilada e publicada quando a execução manual de **Mapas JW
native mobile release** marca **Build completo**. Até lá, o endereço Android
continua apontando para a última publicação completa.

Para publicar, execute o workflow a partir de `master`, informe uma versão
`X.Y.Z` crescente e notas de atualização. Atualizações preservam o bundle
identifier; no SideStore, atualize a fonte para localizar a nova versão. A
publicação do IPA não renova sua assinatura no SideStore.

## Saídas de campo, "Onde foi trabalhado?" e locais

O app segue o modelo unificado do sistema: só existem cartões de rua; os
polígonos apenas delimitam. Cartões arquivados e o limite da congregação não
aparecem. Em cada saída, **Onde foi trabalhado?** abre um mapa com as ruas
coloridas por cartão e a seleção por rua
(`GET /api/mobile/field-outings/{id}/work-candidates` e
`POST /api/mobile/field-outings/{id}/work-streets`, com a mesma regra do web:
todas as ruas de um cartão o concluem, parcial só registra o dia, e editar
pode reabrir). Saídas online/informativas dispensam o registro (campo
`informational`). Locais de saída trazem `lat`/`lng`, e o ponto pode ser
marcado ou ajustado no mapa (`PATCH /api/mobile/field-locations/{id}`); o
servidor mantém o link do Maps alinhado ao ponto. O `bootstrap` informa o
circuito e a cidade de cada congregação. As rotas e os campos antigos continuam
valendo para versões anteriores do app.
