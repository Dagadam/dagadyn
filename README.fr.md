# DagaDyn

[English](README.md) · [Italiano](README.it.md) · [Español](README.es.md) · **Français** · [Deutsch](README.de.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Svenska](README.sv.md) · [Polski](README.pl.md) · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [中文](README.zh.md)

Une extension pour SketchUp qui rend les objets dynamiques. Chaque propriété
d'un groupe, d'un composant ou d'un plan de section passe d'un état à un
autre dans le temps que vous choisissez, selon une courbe que vous dessinez,
et vous le voyez se produire dans la scène. Des portes qui s'ouvrent, des
ascenseurs qui montent, des lampes qui s'allument, des coupes qui traversent
un bâtiment.

⬇ **Télécharger** : [dernière version](https://github.com/Dagadam/dagadyn/releases/latest) (toutes les versions : [Releases](https://github.com/Dagadam/dagadyn/releases))

## Ce qu'elle fait

- **Propriétés** : déplacement (depuis la place de l'objet), position,
  rotation, dimensions (largeur, profondeur, hauteur), échelle, couleur,
  opacité, visibilité et balise. Les plans de section se déplacent et
  s'allument ou s'éteignent.
- **États et courbes** : chaque propriété a un état initial, un état final et
  une durée ; d'autres états forment une séquence. Chaque transition suit une
  courbe : linéaire, accélérer, ralentir, dépassement, rebond, élastique,
  paliers, ou la vôtre, dessinée dans l'éditeur de courbes en faisant glisser
  ses points.
- **Timeline** : Lecture, Pause, Stop et une barre pour voir n'importe quel
  instant. Une fois, en boucle ou en aller-retour, à la vitesse voulue.
- **Démarrages** : un objet démarre avec la timeline, après qu'un autre a
  fini (plus une attente), ou **quand on l'actionne** : un clic avec l'outil
  *Actionner*. Il peut recommencer depuis le début à chaque fois, ou avancer
  puis revenir la fois suivante (portes, tiroirs).
- **Le projet ne change pas** : les animations bougent les objets sans
  toucher au modèle. *Stop* remet tout en place et le fichier enregistre
  toujours l'état de repos ; *Garder* laisse les objets tels qu'ils sont
  (Ctrl+Z l'annule).
- **Dans les objets** : les animations sont enregistrées dans le fichier
  `.skp` et copiées avec l'objet. Avec plusieurs objets sélectionnés, une
  modification s'applique à tous, adaptée à la position et aux dimensions de
  chacun.
- **Trajectoires dans la vue** : le parcours des objets qui bougent, avec un
  point pour chaque état (SketchUp 2023 et suivants).
- **Aperçu pendant la modification** : en changeant la valeur d'un état,
  l'objet se montre dans cet état.
- **Avec [DagaWASD](https://github.com/Dagadam/dagawasd)** les objets bougent
  aussi pendant que vous marchez, explorez, rejouez des parcours et exportez
  des vidéos (image par image, au temps de la vidéo). Les plateformes mobiles
  vous emportent et la touche Actionner démarre les objets qui démarrent
  quand on les actionne.
- Panneau en 36 langues, avec les mêmes réglages, thèmes et apparence que
  DagaWASD.
- **Accessibilité** : voir [ACCESSIBILITY.md](.github/ACCESSIBILITY.md).

Configuration requise : SketchUp 2023 ou plus récent. Développée et testée
sous Windows ; sur Mac elle n'a pas encore été testée.

## Utilisation

1. *Extensions › DagaDyn › Panneau des animations…* (ou la barre d'outils).
2. Sélectionnez un groupe, un composant ou un plan de section. Dans
   *Animation › Objet*, choisissez une propriété à animer et appuyez sur
   *Ajouter*.
3. Écrivez l'état initial et l'état final (*⌖ actuel* prend la valeur que
   l'objet a maintenant), la durée, et choisissez une courbe. Un clic sur la
   petite courbe pour dessiner la vôtre.
4. Appuyez sur **▶** (ou Espace dans le panneau). **⏹** remet tout en place.

Pour les objets qui démarrent « quand on les actionne », prenez l'outil
*Actionner* (barre ou menu) et cliquez sur l'objet dans le modèle ; Échap
quitte l'outil.

## Installation

Téléchargez **`dagadyn-<version>.rbz`** depuis la [dernière
version](https://github.com/Dagadam/dagadyn/releases/latest) (sous
*Assets*) et installez-le depuis *Extensions › Gestionnaire d'extensions ›
Installer l'extension*.

Les réglages sont enregistrés dans `%APPDATA%\DagaDyn\settings.json` : une
mise à jour ne les efface pas. Les animations sont dans les modèles, pas
dans l'extension.

## Développement

Le code, ses commentaires et le journal des modifications sont en italien ;
la construction interne de l'extension est décrite dans
[SVILUPPO.md](SVILUPPO.md).

- `installa.bat` copie les sources dans le dossier Plugins de chaque
  SketchUp trouvé.
- `tools\run_tests.bat` lance les tests (Ruby avec un SketchUp simulé ; le
  test des courbes demande aussi Node.js).
- `ruby tools\crea_rbz.rb` crée le paquet dans `dist\`.
- Le numéro de version se trouve uniquement dans `dagadyn.rb` (`VERSION`) ;
  chaque version a sa section dans `CHANGELOG.md`.
- Ce README existe en plusieurs langues (`README.md` en anglais,
  `README.it.md`, `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`,
  `.ru`, `.ja`, `.ko`, `.zh`) : une modification va dans tous.

Les contributions sont les bienvenues : voir
[CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Contact

Les bugs et les idées, de préférence en
[issue](https://github.com/Dagadam/dagadyn/issues), où d'autres peuvent les
voir et les suivre ; les problèmes de sécurité passent par la [politique de
sécurité](.github/SECURITY.md). Vous pouvez aussi écrire à
[DagaWASD@icloud.com](mailto:DagaWASD@icloud.com).

Si DagaDyn vous est utile, vous pouvez soutenir son développement sur
[Ko-fi](https://ko-fi.com/dagadam).

## Licence

[MIT](LICENSE) © 2026 Dagadam. Vous pouvez utiliser, modifier et
redistribuer le code librement, y compris à des fins commerciales, à
condition que chaque copie conserve la mention de copyright et le texte de
la licence.
