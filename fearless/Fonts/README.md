# Bundled font resources

- `sora-{Regular,SemiBold,Bold,ExtraBold}.otf`: Sora **2.000**, copied byte-for-byte from the corresponding `sora_*.otf` resources in the Fearless Android integration repository. The filenames stay stable for Interface Builder; PostScript names are now `Sora-*`. [Upstream](https://github.com/sora-xor/sora-font). The bundled `Sora-OFL.txt` is the unchanged Sora licence text from the existing web `@fontsource-variable/sora` dependency.
- `JetBrainsMono-{Regular,Medium}.ttf`: JetBrains Mono **2.304** from the [official tagged release](https://github.com/JetBrains/JetBrainsMono/releases/tag/v2.304). `JetBrainsMono-OFL.txt` is copied unchanged from that release archive.

The complete licence texts are included in the application resources and readable offline under About → Font licences. The source/evidence record contains file hashes, binary version and PostScript names, glyph coverage and provenance.

Legacy `UIFont` styles continue to use Sora until those screens are rebuilt. New `UIFont.fw` styles use Sora only for Latin title roles, system fonts for body and every amount, and JetBrains Mono for addresses/raw data. Non-Latin titles and CJK HUD use the system body face. Font registration must not be treated as proof that every font contains every currency, spacing or language glyph.
