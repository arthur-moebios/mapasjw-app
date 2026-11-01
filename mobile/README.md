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
