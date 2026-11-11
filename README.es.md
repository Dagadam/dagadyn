# DagaDyn

[English](README.md) · [Italiano](README.it.md) · **Español** · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Svenska](README.sv.md) · [Polski](README.pl.md) · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [中文](README.zh.md)

Una extensión para SketchUp que hace dinámicos los objetos. Cada propiedad
de un grupo, un componente o un plano de sección pasa de un estado a otro en
el tiempo que eliges, siguiendo una curva que dibujas tú, y lo ves ocurrir en
la escena. Puertas que se abren, ascensores que suben, lámparas que se
encienden, secciones que recorren un edificio.

⬇ **Descargar**: [última versión](https://github.com/Dagadam/dagadyn/releases/latest) (todas las versiones: [Releases](https://github.com/Dagadam/dagadyn/releases))

## Qué hace

- **Propiedades**: desplazamiento (desde donde está el objeto), posición,
  rotación, tamaño (ancho, profundidad, alto), escala, color, opacidad,
  visibilidad y etiqueta. Los planos de sección se desplazan y se encienden
  y apagan.
- **Estados y curvas**: cada propiedad tiene un estado inicial, uno final y
  una duración; más estados forman una secuencia. Cada transición sigue una
  curva: lineal, acelerar, frenar, sobrepasar, rebote, elástica, escalones,
  o una tuya, dibujada en el editor de curvas arrastrando sus puntos.
- **Línea de tiempo**: Reproducir, Pausa, Stop y una barra para ver
  cualquier instante. Una vez, en bucle o de ida y vuelta, a la velocidad que
  quieras.
- **Inicios**: un objeto empieza con la línea de tiempo, después de que otro
  termine (más una espera), o **al accionarlo**: un clic con la herramienta
  *Accionar*. Puede empezar cada vez desde el principio, o avanzar y la vez
  siguiente retroceder (puertas, cajones).
- **El proyecto no cambia**: las animaciones mueven los objetos sin tocar el
  modelo. *Stop* lo devuelve todo a su sitio y el archivo guarda siempre el
  estado de reposo; *Conservar* deja los objetos como están ahora (Ctrl+Z lo
  deshace).
- **Dentro de los objetos**: las animaciones se guardan en el archivo `.skp`
  y se copian con el objeto. Con varios objetos seleccionados, un cambio vale
  para todos, adaptado a la posición y el tamaño de cada uno.
- **Trayectorias en la vista**: el recorrido de los objetos que se mueven,
  con un punto por cada estado (SketchUp 2023 y posteriores).
- **Vista previa al editar**: al cambiar el valor de un estado, el objeto se
  muestra en ese estado.
- **Con [DagaWASD](https://github.com/Dagadam/dagawasd)** los objetos también
  se mueven mientras caminas, exploras, reproduces recorridos y exportas
  vídeos (fotograma a fotograma, al tiempo del vídeo). Las plataformas en
  movimiento te llevan consigo y la tecla Accionar pone en marcha los objetos
  que empiezan al accionarlos.
- Panel en 36 idiomas, con los mismos ajustes, temas y aspecto que DagaWASD.
- **Accesibilidad**: ver [ACCESSIBILITY.md](.github/ACCESSIBILITY.md).

Requisitos: SketchUp 2023 o posterior. Desarrollada y probada en Windows; en
Mac aún no se ha probado.

## Cómo se usa

1. *Extensiones › DagaDyn › Panel de animaciones…* (o la barra de
   herramientas).
2. Selecciona un grupo, un componente o un plano de sección. En
   *Animación › Objeto* elige una propiedad para animar y pulsa *Añadir*.
3. Escribe el estado inicial y el final (*⌖ actual* toma el valor que el
   objeto tiene ahora), la duración, y elige una curva. Un clic en la curva
   pequeña para dibujar la tuya.
4. Pulsa **▶** (o Espacio en el panel). **⏹** lo devuelve todo a su sitio.

Para los objetos que empiezan «al accionarlos», toma la herramienta
*Accionar* (barra o menú) y haz clic en el objeto en el modelo; Esc sale de
la herramienta.

## Instalación

Descarga **`dagadyn-<versión>.rbz`** de la [última
versión](https://github.com/Dagadam/dagadyn/releases/latest) (en *Assets*)
e instálalo desde *Extensiones › Administrador de extensiones › Instalar
extensión*.

Los ajustes se guardan en `%APPDATA%\DagaDyn\settings.json`: una
actualización no los borra. Las animaciones están en los modelos, no en la
extensión.

## Desarrollo

El código, sus comentarios y el registro de cambios están en italiano; cómo
está hecha la extensión por dentro está en [SVILUPPO.md](SVILUPPO.md).

- `installa.bat` copia el código fuente en la carpeta Plugins de cada
  SketchUp que encuentra.
- `tools\run_tests.bat` ejecuta las pruebas (Ruby con un SketchUp simulado;
  la prueba de las curvas necesita también Node.js).
- `ruby tools\crea_rbz.rb` crea el paquete en `dist\`.
- El número de versión está solo en `dagadyn.rb` (`VERSION`); cada versión
  tiene su sección en `CHANGELOG.md`.
- Este README está en varios idiomas (`README.md` en inglés,
  `README.it.md`, `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`,
  `.ru`, `.ja`, `.ko`, `.zh`): un cambio va en todos.

Las contribuciones son bienvenidas: ver
[CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Contacto

Los errores y las ideas mejor como
[issue](https://github.com/Dagadam/dagadyn/issues), donde otros pueden verlos
y seguirlos; los problemas de seguridad pasan por la [política de
seguridad](.github/SECURITY.md). También puedes escribir a
[DagaWASD@icloud.com](mailto:DagaWASD@icloud.com).

Si DagaDyn te resulta útil, puedes apoyar su desarrollo en
[Ko-fi](https://ko-fi.com/dagadam).

## Licencia

[MIT](LICENSE) © 2026 Dagadam. Puedes usar, modificar y redistribuir el
código libremente, también con fines comerciales, siempre que cada copia
conserve el aviso de copyright y el texto de la licencia.
