# Battery Toy

A native SwiftUI iPhone instrument for exploring battery behavior, built with the iOS 27 SDK. Holographic cutaways and a charge orbit reveal structure without imitating a pile of physical objects. Core Motion moves the specular highlight and chromatic edge as the phone tilts; dragging rotates the schematic.

The Lab exposes current, terminal voltage, chemical state of charge, temperature, heat, energy, time acceleration, charge/discharge/rest, and series/parallel configuration. Atlas explains twelve representative examples from an experimental nanostructured cell through AA and coin cells, phone and EV packs, and vanadium flow storage. Compare runs two discharge experiments at equal C-rate and displays normalized voltage.

## Model fidelity

BatteryCore implements coulomb counting, chemistry-specific illustrative open-circuit curves, ohmic resistance, one exact-updated RC polarization branch, a lumped thermal balance, charge-stage controllers, accessible-capacity cutoffs, and balanced series/parallel scaling. Primary cells reject charging. Chemical charge does not increase during voltage relaxation. Aging is an optional, explicitly illustrative throughput rule.

This is a working educational simulator, not a universal predictive model of every battery. The preset parameters are independently chosen teaching values, not fitted manufacturer datasets. Chemical transformations are explained separately from controller phases. Diffusion fields, electrode kinetics, phase fronts, entropy heat, thermal runaway, hysteresis, cell imbalance, pump losses, and calibrated lifetime are not solved. Nanocells and lithium–sulfur are clearly marked as research concepts. See `Documentation/Physics.md` and the in-app equations and primary references.

## Build

```sh
cd '/path/to/developer/Documents/AI Stuff/BatteryToy'
xcodegen generate
open BatteryToy.xcodeproj
```

Select the BatteryToy scheme. Requires iOS 27; Swift 6; no external Swift packages, accounts, or runtime downloads.

Pure Swift model validation:

```sh
swift test --scratch-path /private/tmp/BatteryToyModelBuild
```

The Xcode BatteryToyUITests target exercises native workflows on an iOS simulator. Actual device attitude, haptic feel, optical appearance under movement, and sustained physical-device performance need a phone session; simulator observations do not establish those properties.

## Design and accessibility

The content layer remains dark and legible; native Liquid Glass is used for controls and navigation. Reduce Motion stops continuous transport animation and tilt parallax; Reduce Transparency gives the layer controls opaque surfaces. The layer controls have 44-point targets, VoiceOver labels, and rotation actions. Numerical readings remain stationary while the hologram responds to motion. These choices follow Apple's [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Motion](https://developer.apple.com/design/human-interface-guidelines/motion), and [custom Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) guidance.

## Using the instrument

1. Choose a specimen with the glass selector beside its name or open Atlas.
2. Tap See inside and inspect an electrode or separator.
3. Select Discharge, Rest, or Charge, adjust load and surroundings, and Run. Use 10 min to jump ahead.
4. Pulse a load and switch to Rest to see voltage recovery without a change in chemical SOC.
5. Use Set initial charge to explore precharge and the full-charge taper. A fresh experiment clears the trace.
6. Tilt gently or drag the cell. Light & motion lets you disable tilt and recenter it.
7. Read How it works for material changes, charge protocols, equations, assumptions, and sources.


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
