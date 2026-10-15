# MedUltra (Flutter)

Reimplementacao em Flutter do app MedUltra (referencia de ultrassonografia: fetal, pediatrica e adulto).
O app e **dirigido por dados**: todo o conteudo vem de JSON extraidos do APK original (pacote `medultra-extraido`).

## Estrutura
- `assets/app/menu.json` – grupos e itens do menu (61 medidas/orgaos), icones e publico.
- `assets/app/paginas.json` – tipo de cada pagina (`calc`, `ped`, `tabela`, `texto`, `lista`) e configuracao das calculadoras.
- `assets/app/tabelas.json` – cabecalhos e colunas de cada tabela de dados.
- `assets/data/*.json` – 38 tabelas de referencia (fetal e pediatrica). Linhas pediatricas trazem `_lo`/`_hi` (faixa de idade em meses).
- `assets/content/<Orgao>.json` – abas e blocos de texto/imagem de cada orgao; `assets/strings/{pt-BR,en,es}.json` – textos.
- `lib/core/calc.dart` – busca em tabela, formula do CC (Hadlock) e conversao de idade.
- `lib/widgets/` – renderizador de blocos, tabelas, calculadoras. `lib/screens/` – Home, Orgao, SubPagina.
- `tools/build_assets.py` – regenera `assets/` a partir do pacote de extracao.

## Compilar (sem Flutter local)
Suba o conteudo para um repositorio GitHub; o workflow `.github/workflows/build-apk.yml` gera `android/`,
roda `flutter analyze` e `flutter build apk --release`, e publica o APK como artefato.
Com Flutter local: `flutter create --platforms=android .` e depois `flutter run`.

## Observacoes
- Package id gerado: `br.com.medultra.medultra` (`--org br.com.medultra --project-name medultra` no workflow).
  O app original usa `com.x3reistec.medultrassom`; para atualizar/substituir a instalacao dele, use esse id (e a mesma assinatura).
- Busca por valor (calculadoras fetais): o valor digitado e arredondado para a linha mais proxima (meio passo da tabela).
- A imagem `ultra_pn_fetal.jpg` nao existe no APK original; a pagina mostra um icone no lugar.
- Layout visual (cores/espacamentos) e Material 3 padrao, nao a copia exata do original.
