# Contributing

Thanks for looking at Revive the Touchbar.

- **Before a big change:** open an issue so we can agree on the approach.
- **Build:** `./build.sh` (Xcode or the Command Line Tools). It must build with no errors for Apple silicon and Intel.
- **Renderer:** animations are pure functions of time, drawn into `Canvas` in bar-height units. The renderer files (`Model`, `Canvas`, `PixelFont`, `EffectCore`, `Library*`, `Scene`) are Foundation only, with no AppKit, so `tools/effectlab/run.sh` can build them anywhere Swift runs. Keep each animation near or under 2.5 ms per frame (`tools/effectlab/run.sh bench`).
- **Strings:** English text is the key. Add every user-facing string to `i18n/app_strings.py` with all five translations (es, pt-BR, fr, hi, zh-Hans), then run `python3 tools/gen_i18n.py --check`. Text drawn on the bar itself stays in English.
- **Names:** avoid trademarked names in animations.
- **Branches:** work on a branch and open a pull request.

By contributing, you agree that your contribution is licensed under the MIT License (see `LICENSE`).
