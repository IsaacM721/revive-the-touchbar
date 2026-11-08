<p align="center"><img src="assets/banner.png" alt="Revive the Touchbar" width="100%"></p>

Lire en: [English](README.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · **Français** · [हिन्दी](README.hi.md) · [简体中文](README.zh-CN.md)

# Revive the Touchbar

**Éclairage RGB pour la Touch Bar du MacBook Pro. Gratuit et open source.**

Une app de barre des menus qui transforme votre Touch Bar en bande lumineuse vivante : 49 animations sur six étagères, de nouvelles animations chaque semaine, et vos propres textes et GIF.

<p align="center"><a href="https://revivethetouchbar.com"><b>Télécharger pour Mac</b></a> &nbsp;·&nbsp; <a href="https://revivethetouchbar.com">Site web</a></p>

## En mouvement

<p align="center"><img src="assets/hero.gif" alt="" width="720"></p>

[Voir la démo complète (MP4)](assets/demo-all-effects.mp4)

## Ce qu’il contient

- 49 animations : lumière d’ambiance, rétro, jeu, productivité, mèmes et les vôtres.
- De nouvelles animations chaque semaine, directement dans l’app.
- Votre texte et votre GIF sur la barre.
- Un bouton **fn** pour F1–F12 et des curseurs invisibles : glissez sur l’éclairage pour la luminosité de l’écran (à gauche) et le volume (à droite).
- Vitesse, luminosité, couleur et un bouton façon matériel pour la forme des coins. Enregistrez vos réglages en préréglages.

## Pour commencer

1. Téléchargez l’app sur [revivethetouchbar.com](https://revivethetouchbar.com).
2. Ouvrez le DMG et glissez **Revive the Touchbar** dans Applications.
3. Lancez-la. Elle vit dans la barre des menus ; ouvrez les Réglages pour choisir une animation.

## Compiler depuis les sources

Il vous faut Xcode ou les Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/IsaacM721/revive-the-touchbar.git
cd revive-the-touchbar
./build.sh
open "build/Revive the Touchbar.app"
```

La compilation est universelle (Apple silicon et Intel) et signée ad hoc. Le moteur d’animation est en Swift pur ; `tools/effectlab/run.sh` rend et mesure chaque animation sans l’app.

## Configuration requise

- Un MacBook Pro avec Touch Bar
- macOS 13 Ventura ou ultérieur

## Questions

**Pourquoi n’est-elle pas sur le Mac App Store ?**

Elle affiche sa propre Touch Bar grâce à une fonction du système qu’Apple ne propose pas dans ses outils publics pour développeurs ; elle est donc distribuée directement. La version du site est signée et notariée par Apple.

**Puis-je l’éteindre ?**

Oui. Utilisez l’interrupteur Éclairage dans le menu de la barre, et votre Touch Bar redevient normale.

## Contribuer

Les issues et pull requests sont bienvenues. Lisez d’abord [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence

MIT. Voir [LICENSE](LICENSE). Revive the Touchbar est un projet indépendant, ni affilié ni approuvé par Apple Inc. MacBook Pro et Touch Bar sont des marques d’Apple Inc.

## Aide

Bugs et idées : [ouvrez une issue](../../issues/new/choose). Problèmes de sécurité : voir [SECURITY.md](SECURITY.md).
