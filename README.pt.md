# DagaDyn

[English](README.md) · [Italiano](README.it.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Português** · [Nederlands](README.nl.md) · [Svenska](README.sv.md) · [Polski](README.pl.md) · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [中文](README.zh.md)

Uma extensão para o SketchUp que torna os objetos dinâmicos. Cada
propriedade de um grupo, componente ou plano de corte passa de um estado a
outro no tempo que escolher, segundo uma curva que desenha, e vê isso
acontecer na cena. Portas que se abrem, elevadores que sobem, candeeiros que
se acendem, cortes que atravessam um edifício.

⬇ **Transferir**: [última versão](https://github.com/Dagadam/dagadyn/releases/latest) (todas as versões: [Releases](https://github.com/Dagadam/dagadyn/releases))

## O que faz

- **Propriedades**: deslocamento (a partir de onde o objeto está), posição,
  rotação, tamanho (largura, profundidade, altura), escala, cor, opacidade,
  visibilidade e etiqueta. Os planos de corte deslocam-se e ligam-se e
  desligam-se.
- **Estados e curvas**: cada propriedade tem um estado inicial, um final e
  uma duração; mais estados formam uma sequência. Cada transição segue uma
  curva: linear, acelerar, travar, ultrapassar, ressalto, elástica, degraus,
  ou uma sua, desenhada no editor de curvas arrastando os pontos.
- **Linha do tempo**: Reproduzir, Pausa, Stop e uma barra para ver qualquer
  instante. Uma vez, em ciclo ou em ida e volta, à velocidade que quiser.
- **Inícios**: um objeto começa com a linha do tempo, depois de outro
  terminar (mais uma espera), ou **ao ser acionado**: um clique com a
  ferramenta *Acionar*. Pode recomeçar do início de cada vez, ou avançar e
  na vez seguinte recuar (portas, gavetas).
- **Cadeias que seguem**: os objetos encadeados atrás de um que avança e
  recua seguem a sua direção, na ida e na volta, cada um quando o anterior
  terminou (uma alavanca, depois a ponte levadiça).
- **O projeto não muda**: as animações movem os objetos sem tocar no
  modelo. *Stop* repõe tudo e o ficheiro guarda sempre o estado de repouso;
  *Manter* deixa os objetos como estão agora (Ctrl+Z anula).
- **Dentro dos objetos**: as animações guardam-se no ficheiro `.skp` e
  copiam-se com o objeto. Com vários objetos selecionados, uma alteração vale
  para todos, adaptada à posição e ao tamanho de cada um.
- **Trajetórias na vista**: o percurso dos objetos que se movem, com um
  ponto por cada estado (SketchUp 2023 e seguintes).
- **Pré-visualização ao editar**: ao mudar o valor de um estado, o objeto
  mostra-se nesse estado.
- **Sozinha ou com o [DagaWASD](https://github.com/Dagadam/dagawasd)**: não precisa de
  mais nada. Com o DagaWASD 1.3.0 ou posterior também instalado, os objetos
  movem-se ainda enquanto caminha, explora, reproduz percursos e exporta
  vídeos (fotograma a fotograma, ao tempo do vídeo). As plataformas em
  movimento levam-no consigo e a tecla Acionar põe em marcha os objetos que
  começam ao serem acionados.
- Painel em 36 idiomas. Com o DagaWASD instalado, segue o idioma e a
  aparência dele.
- **Acessibilidade**: ver [ACCESSIBILITY.md](.github/ACCESSIBILITY.md).

Requisitos: SketchUp 2023 ou posterior. Desenvolvida e testada em Windows;
no Mac ainda não foi testada.

## Como se usa

1. *Extensões › DagaDyn › Painel de animações…* (ou a barra de
   ferramentas).
2. Selecione um grupo, um componente ou um plano de corte. Em
   *Animação › Objeto* escolha uma propriedade a animar e prima *Adicionar*.
3. Escreva o estado inicial e o final (*⌖ atual* usa o valor que o objeto
   tem agora), a duração, e escolha uma curva. Um clique na pequena curva
   para desenhar a sua.
4. Prima **▶** (ou Espaço no painel). **⏹** repõe tudo.

Para os objetos que começam «ao serem acionados», escolha a ferramenta
*Acionar* (barra ou menu) e clique no objeto no modelo; Esc sai da
ferramenta.
Sob o rato, o objeto que vai começar aparece com um contorno e o seu nome. Se
nenhum objeto começar com a linha do tempo, o botão **▶** passa a **☝**, a
ferramenta *Acionar*.

## Instalação

Transfira **`dagadyn-<versão>.rbz`** da [última
versão](https://github.com/Dagadam/dagadyn/releases/latest) (em *Assets*) e
instale-o em *Extensões › Extension Manager › Instalar extensão*.

As definições ficam em `%APPDATA%\DagaDyn\settings.json`: uma atualização
não as apaga. As animações estão nos modelos, não na extensão.

## Desenvolvimento

O código, os comentários e o registo de alterações estão em italiano; como a
extensão é feita por dentro está em [SVILUPPO.md](SVILUPPO.md).

- `installa.bat` copia o código-fonte para a pasta Plugins de cada SketchUp
  que encontra.
- `tools\run_tests.bat` executa os testes (Ruby com um SketchUp simulado; o
  teste das curvas precisa também do Node.js).
- `ruby tools\test_live.rb` testa no SketchUp real, através da ponte do
  DagaWASD (precisa de um modelo vazio e nunca alterado aberto, e deixa-o
  vazio).
- `ruby tools\crea_rbz.rb` cria o pacote em `dist\`.
- O número da versão está só em `dagadyn.rb` (`VERSION`); cada versão tem a
  sua secção em `CHANGELOG.md`.
- Este README está em vários idiomas (`README.md` em inglês,
  `README.it.md`, `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`,
  `.ru`, `.ja`, `.ko`, `.zh`): uma alteração vai para todos.

As contribuições são bem-vindas: ver
[CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Contacto

Erros e ideias, de preferência como
[issue](https://github.com/Dagadam/dagadyn/issues), onde outros os podem ver
e seguir; os problemas de segurança passam pela [política de
segurança](.github/SECURITY.md). Também pode escrever para
[DagaWASD@icloud.com](mailto:DagaWASD@icloud.com).

Se o DagaDyn lhe é útil, pode apoiar o seu desenvolvimento no
[Ko-fi](https://ko-fi.com/dagadam).

## Licença

[MIT](LICENSE) © 2026 Dagadam. Pode usar, modificar e redistribuir o código
livremente, também para fins comerciais, desde que cada cópia mantenha o
aviso de copyright e o texto da licença.
