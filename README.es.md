<p align="center"><img src="assets/banner.png" alt="Revive the Touchbar" width="100%"></p>

Léelo en: [English](README.md) · **Español** · [Português (Brasil)](README.pt-BR.md) · [Français](README.fr.md) · [हिन्दी](README.hi.md) · [简体中文](README.zh-CN.md)

# Revive the Touchbar

**Iluminación RGB para la Touch Bar del MacBook Pro. Gratis y de código abierto.**

Una app de la barra de menús que convierte tu Touch Bar en una tira de luz viva: 49 animaciones en seis estantes, animaciones nuevas cada semana y tus propios textos y GIF.

<p align="center"><a href="https://revivethetouchbar.com"><b>Descargar para Mac</b></a> &nbsp;·&nbsp; <a href="https://revivethetouchbar.com">Sitio web</a></p>

## Míralo en movimiento

<p align="center"><img src="assets/hero.gif" alt="" width="720"></p>

[Ver la demo completa (MP4)](assets/demo-all-effects.mp4)

## Qué incluye

- 49 animaciones: luz ambiental, retro, gaming, productividad, memes y las tuyas.
- Animaciones nuevas cada semana, directo en la app.
- Tu texto y tu GIF en la barra.
- Un botón **fn** para F1–F12 y controles invisibles: desliza sobre la iluminación para el brillo de la pantalla (izquierda) y el volumen (derecha).
- Velocidad, brillo, color y una perilla estilo hardware para la forma de las esquinas. Guarda tus estilos como preajustes.

## Empieza

1. Descarga la app en [revivethetouchbar.com](https://revivethetouchbar.com).
2. Abre el DMG y arrastra **Revive the Touchbar** a Aplicaciones.
3. Ábrela. Vive en la barra de menús; abre Ajustes para elegir una animación.

## Compilar desde el código

Necesitas Xcode o las Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/IsaacM721/revive-the-touchbar.git
cd revive-the-touchbar
./build.sh
open "build/Revive the Touchbar.app"
```

La compilación es universal (Apple silicon e Intel) y con firma ad hoc. El motor de animaciones es Swift puro; `tools/effectlab/run.sh` renderiza y mide cada animación sin la app.

## Requisitos

- Un MacBook Pro con Touch Bar
- macOS 13 Ventura o posterior

## Preguntas

**¿Por qué no está en la Mac App Store?**

Muestra su propia Touch Bar con una función del sistema que Apple no ofrece en sus herramientas públicas para desarrolladores, así que se distribuye directamente. La versión del sitio web está firmada y notarizada por Apple.

**¿Puedo apagarla?**

Sí. Usa el interruptor Iluminación en el menú de la barra y tu Touch Bar vuelve a la normalidad.

## Contribuir

Los issues y pull requests son bienvenidos. Lee primero [CONTRIBUTING.md](CONTRIBUTING.md).

## Licencia

MIT. Consulta [LICENSE](LICENSE). Revive the Touchbar es un proyecto independiente, sin afiliación ni respaldo de Apple Inc. MacBook Pro y Touch Bar son marcas comerciales de Apple Inc.

## Ayuda

Errores e ideas: [abre un issue](../../issues/new/choose). Problemas de seguridad: consulta [SECURITY.md](SECURITY.md).
