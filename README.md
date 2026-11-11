# KayKit Palette Adjust

A Godot 4 material for recolouring palette-textured models one swatch at a time.

I made this for the [KayKit](https://kaylousberg.com) asset packs by **Kay Lousberg**. KayKit models are all coloured from one palette texture, a grid of colour swatches, and this lets you tweak each swatch on its own without touching the texture. (Not an official KayKit thing, just a fan-made tool.)

![Darkening one swatch on a KayKit floor tile](docs/demo.gif)

## What you can change per swatch

Hue, saturation, contrast, brightness, metallic, roughness, emission and emission colour.

Swatches are picked by where they sit in the texture, not by colour, so two similar greys never affect each other.

## Requirements

Godot 4.4 or newer.

## Install

Copy `addons/palette_adjust` into your project. There's no plugin to enable.

## Use

1. Select a MeshInstance3D. In **Surface Material Override → 0** (or **Geometry → Material Override**) choose **New PaletteAdjustMaterial**.
2. Set **Palette Texture** to the model's texture (e.g. `dungeon_texture.png`).
3. Keep the mesh selected and press **Detect Slots Used By Selected Mesh**. Only the swatches that model uses are listed. Tick **Show All Slots** to see the rest.
4. Open a **Slot** and adjust it. Every setting starts at 0 (unchanged).

Slots are numbered left to right, top to bottom, starting at 1. KayKit palettes are 8 × 4; change **Columns** and **Rows** for other layouts (up to 64 slots).

## License

CC0, so use it however you like, commercial projects included, no credit needed.

One polite ask: please don't repackage and sell the addon on its own. If it's missing something you need, open an issue or a feature request instead and I'll happily take a look.
