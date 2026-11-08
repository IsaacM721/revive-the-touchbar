<p align="center"><img src="assets/banner.png" alt="Revive the Touchbar" width="100%"></p>

Leia em: [English](README.md) · [Español](README.es.md) · **Português (Brasil)** · [Français](README.fr.md) · [हिन्दी](README.hi.md) · [简体中文](README.zh-CN.md)

# Revive the Touchbar

**Iluminação RGB para a Touch Bar do MacBook Pro. Gratuito e de código aberto.**

Um app da barra de menus que transforma sua Touch Bar em uma faixa de luz viva: 49 animações em seis prateleiras, animações novas toda semana e seus próprios textos e GIFs.

<p align="center"><a href="https://revivethetouchbar.com"><b>Baixar para Mac</b></a> &nbsp;·&nbsp; <a href="https://revivethetouchbar.com">Site</a></p>

## Veja em movimento

<p align="center"><img src="assets/hero.gif" alt="" width="720"></p>

[Assista à demo completa (MP4)](assets/demo-all-effects.mp4)

## O que vem dentro

- 49 animações: luz ambiente, retrô, games, produtividade, memes e as suas.
- Animações novas toda semana, direto no app.
- Seu texto e seu GIF na barra.
- Velocidade, brilho, cor e um botão giratório estilo hardware para o formato dos cantos. Salve visuais como predefinições.

## Comece

1. Baixe o app em [revivethetouchbar.com](https://revivethetouchbar.com).
2. Abra o DMG e arraste **Revive the Touchbar** para Aplicativos.
3. Abra o app. Ele fica na barra de menus; abra Configurações para escolher uma animação.

## Compilar a partir do código

Você precisa do Xcode ou das Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/IsaacM721/revive-the-touchbar.git
cd revive-the-touchbar
./build.sh
open "build/Revive the Touchbar.app"
```

A compilação é universal (Apple silicon e Intel) e com assinatura ad hoc. O motor de animações é Swift puro; `tools/effectlab/run.sh` renderiza e mede cada animação sem o app.

## Requisitos

- Um MacBook Pro com Touch Bar
- macOS 13 Ventura ou posterior

## Perguntas

**Por que não está na Mac App Store?**

Ele mostra a própria Touch Bar usando um recurso do sistema que a Apple não oferece nas ferramentas públicas para desenvolvedores, então é distribuído diretamente. A versão do site é assinada e notarizada pela Apple.

**Posso desligar?**

Sim. Use a chave Iluminação no item da barra de menus e sua Touch Bar volta ao normal.

## Contribuir

Issues e pull requests são bem-vindos. Leia antes o [CONTRIBUTING.md](CONTRIBUTING.md).

## Licença

MIT. Veja [LICENSE](LICENSE). Revive the Touchbar é um projeto independente, sem afiliação ou endosso da Apple Inc. MacBook Pro e Touch Bar são marcas registradas da Apple Inc.

## Ajuda

Bugs e ideias: [abra um issue](../../issues/new/choose). Problemas de segurança: veja [SECURITY.md](SECURITY.md).
