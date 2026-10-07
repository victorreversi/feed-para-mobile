# feed-para-mobile

Ferramenta de versionamento automático de artes no formato **feed (1080x1080 px)** para o
formato **mobile (890x890 px, proporcional)**, com peso máximo de **400 KB** por arquivo.

É um único arquivo, `gerar-mobile.bat`, feito para quem não é técnico: copiar para a pasta das
artes e dar duplo clique. Não instala nada — usa só o que já vem no Windows 10/11
(Windows PowerShell 5.1, WinForms e System.Drawing).

## O que faz

1. Abre uma janela listando todos os arquivos `.png`, `.jpg` ou `.jpeg` **da pasta onde o
   `.bat` está** que tenham `feed` no nome.
2. Todos vêm marcados. Dá para desmarcar um a um, ou usar **Marcar todos** /
   **Desmarcar todos**.
3. Ao clicar em **Gerar**, cada arquivo marcado é copiado e:
   - redimensionado proporcionalmente para que o lado maior tenha 890 px
     (1080x1080 vira 890x890);
   - salvo em JPEG, reduzindo a qualidade aos poucos (de 92 até 40) até ficar com
     **no máximo 400 KB**;
   - renomeado trocando `feed` por `mobile`.
4. A lista mostra, para cada arquivo, o nome gerado, o peso final e a qualidade usada — ou o
   erro, se houver.

O arquivo original nunca é alterado. Se a versão mobile já existir, a lista avisa antes e ela
é substituída.

```
campanha_01_feed.png   ->   campanha_01_mobile.jpg   (890x890, <= 400 KB)
```

## Como usar

1. Baixe o [`gerar-mobile.bat`](gerar-mobile.bat) (botão **Download raw file** no GitHub).
2. Copie para a pasta onde estão as artes `..._feed.png`.
3. Dê duplo clique.

Na primeira vez, o Windows pode mostrar o aviso *"O Windows protegeu o computador"*, por ser um
arquivo baixado da internet ou vindo de pendrive. Clique em **Mais informações** e depois em
**Executar assim mesmo**.

## Por que JPEG e não PNG

Uma arte de feed em PNG costuma pesar entre 1,5 e 2 MB em 1080 px. Em 890 px continua muito
acima de 400 KB, porque o PNG não perde qualidade para diminuir o peso. O JPEG permite ajustar
a qualidade até caber no limite.

O JPEG não tem transparência: se o PNG de origem tiver áreas transparentes, elas ficam brancas.

## Ajustar os limites

Os valores ficam no início do arquivo, na seção `Parametros`. Dá para editar com o Bloco de Notas:

| variável          | padrão  | o que controla                           |
|-------------------|---------|------------------------------------------|
| `$LadoMaximo`     | `890`   | tamanho do lado maior, em pixels         |
| `$PesoMaximo`     | `400KB` | peso máximo de cada arquivo gerado       |
| `$QualidadeIni`   | `92`    | qualidade JPEG da primeira tentativa     |
| `$QualidadeMin`   | `40`    | qualidade mínima aceita antes de dar erro |
| `$PassoQualidade` | `4`     | quanto a qualidade cai a cada tentativa  |

## Como funciona por dentro

O `gerar-mobile.bat` é um arquivo híbrido. A primeira linha, `<# :`, é lida de forma diferente
pelos dois programas:

- o **Prompt de Comando** executa só as primeiras linhas, que guardam o caminho do próprio
  arquivo e abrem o PowerShell sem a janela preta;
- o **PowerShell** trata esse começo como comentário e executa o resto, que é o script de
  verdade.

Por isso o arquivo é mantido com quebras de linha do Windows (CRLF), garantidas pelo
`.gitattributes`.

## Licença

[MIT](LICENSE)
