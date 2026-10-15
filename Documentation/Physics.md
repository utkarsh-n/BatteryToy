# Battery Toy physics and provenance

Battery Toy is an educational, reduced-order terminal-response simulator with 12 examples. It is not an exhaustive catalog, calibrated cell model, charger-design tool, safety analysis, or prediction of a named commercial device. The examples cover established primary and rechargeable chemistries, research architectures, ideal packs, and a conceptual utility flow plant. Their geometry is a visual explanation, not a microscopic reconstruction.

## What is simulated

Each uniform cell has chemical state of charge `z`, one polarization state `vp`, an illustrative capacity-health multiplier `h`, and one temperature `T`. Current `I` is positive on discharge and negative on charge. For per-cell capacity `Q` in Ah:

```
Qeffective = Q × h
dz/dt = −I / (3600 Qeffective)             discharge
dz/dt = −η I / (3600 Qeffective)           charge
Vcell = U(z) − I R0 − vp
dvp/dt = (I Rp − vp) / τ
vp(t + dt) = I Rp + [vp(t) − I Rp] exp(−dt / τ)
```

`U(z)` is a piecewise-linear, hand-selected illustrative OCV curve. It includes chemistry-specific broad features: an alkaline slope, nickel plateau, LFP plateau, Li–S conversion regions, and a flow-cell SOC dependence. It is not fitted to experimental equilibrium data. In particular, the NiMH near-full voltage hump is a termination-signal proxy, not a validated equilibrium thermodynamic curve. Charging efficiency changes coulomb accumulation. The reported `chemicalWorkWh` is signed work of the modeled electrochemical voltage source, **not** a thermodynamic measurement of stored energy. Nominal Wh is `nominal volts × rated Ah`; usable terminal Wh is separately integrated.

During lead-acid absorption the terminal equation adds an explicitly phenomenological charge-only acceptance resistance `Ra(z)` that rises near saturation. This produces taper under the absorption voltage ceiling without pretending to solve porous-electrode reaction kinetics. It is absent during discharge and rest.

The instantaneous RC resistor loss is `vp² / Rp`. Its time average is integrated analytically; the series resistor contributes `I² R0` and lead-acid acceptance contributes `I² Ra`. The thermal state uses:

```
Cθ dT/dt = Pheat − (T − Tambient) / Rθ
Tnext = Tambient + (T − Tambient) a + Pheat Rθ (1 − a)
a = exp[−dt / (Cθ Rθ)]
```

An additional qualitative NiMH near-full heat term illustrates termination heating. Lead-acid float maintenance has a small current branch; once inventory reaches full, further input becomes maintenance heat rather than additional chemical work. Entropic heat, detailed reaction heat, spatial gradients, venting, gas pressure, thermal runaway, and propagation between cells are not modeled. Temperature and thermal limits are illustrative controller behavior, not safety certification.

## Chemistry and controller phases

| Example | Modeled charging behavior | Distinct chemistry behavior |
| --- | --- | --- |
| Alkaline AA, primary lithium coin | Hard charging prohibition | Primary conversion reactions; no reversible charging assumed |
| NMC and LFP | Low-SOC precharge, CC, voltage-limited CV taper, termination | Lithium intercalation; LFP's plateau does not resolve actual particle phase boundaries |
| Nano solid-state concept, thin-film example | Illustrative device-specific current/voltage limits | Solid conductor passes ions; electron path stays external |
| Sodium-ion example | Illustrative precharge, CC/CV and termination | Na⁺ and hard carbon / Prussian-white example; not hot Na–S |
| NiMH | Constant-current nickel stage, modeled peak / thermal / timer termination | Alloy hydrogen storage and hydroxide reactions; no lithium-style CV stage |
| Lead–acid | Bulk CC, absorption ceiling and taper, lower float ceiling | Acid consumption and lead-sulfate conversion; temperature compensation is a representative coefficient |
| Li–S research | Illustrative current/voltage-controlled charging | Two discharge conversion regions are separate from charger phases |
| Vanadium flow plant | Current control, voltage ceiling, tank SOC cutoff | Pumped inventories; membrane charge balance; stack power and tank energy are separate design choices |

CC/CV current is solved by bisection against the predicted end-of-substep terminal voltage, so the model respects its voltage ceiling. Lithium-type termination occurs below 0.03 C once modeled SOC exceeds 95%. Lead absorption progresses to a near-full threshold before float. The NiMH example tracks the modeled peak and stops on a 5 mV fall near full, a temperature-rise proxy, a timer, or the full-inventory bound. These numbers are teaching-controller settings; they are not generic instructions for real batteries. The lead example uses 2.40 V/cell absorption and 2.275 V/cell float at 25 °C, with a representative −3 mV/°C/cell coefficient. Its six-cell float target is 13.65 V at that temperature.

Discharge is constant-current until a voltage or available-inventory cutoff. Voltage crossing time is solved within the substep; the remainder of the interval relaxes with the load disconnected. Cutoff stays latched until operating mode or requested rate changes. Rest relaxes `vp` and cools the cell without changing chemical SOC. A lower subsequent load can use charge left behind by an earlier cutoff; rebound never manufactures charge.

Cold conditions increase resistance within bounded factors. A reversible accessible-inventory factor raises cutoff SOC when cold. Alkaline, primary coin and lead examples also include a phenomenological rate-dependent availability penalty related to rated-drain capacity effects. Those factors affect the cutoff, not coulomb counting. Warming restores access to existing inventory. The model does not simulate molecular diffusion or directly implement a complete Peukert electrochemical model.

## Packs and scale

For `Ns` identical series cells and `Np` ideal parallel strings:

```
Vpack = Ns Vcell
Ipack = Np Icell
Qpack = Np Qcell
Rpack = Ns Rcell / Np
Epack ≈ Ns Np Qcell Vnominal
Pheat,pack = Ns Np Pheat,cell
```

Each member sees the same SOC and thermal state. This excludes imbalance, individual-cell BMS logic, contactor and wiring resistance, inverter losses, and spatial cooling differences. Parameters are chosen independently for each example; a nanocell's resistance and thermal mass are not scaled into a grid plant. The EV example is a conceptual 128-series, 150 Ah LFP pack (61.44 kWh nominal), not a named vehicle.

The flow example is a conceptual 40-series, four-parallel stack equivalent with 5,000 Ah tank-equivalent inventory per modeled branch: 1 MWh nominal and a limited power envelope. Its independent tank inventory and stack resistance are selected teaching parameters. It does not model pump power, concentration fields, membrane crossover, mixing, shunt currents, or plumbing; real flow efficiency and power are not predicted by this ideal equivalent.

The 1 nAh nanocell is explicitly a **conceptual absolute scale** inspired by conformal solid-electrolyte research. It is not the Maryland liquid-electrolyte nanopore battery and does not claim measured nanocell voltage or capacity. The thin-film 50 μAh example is also an illustrative architecture rather than a commercial part specification.

## Numerical bounds and health

A call advances at most 86,400 simulated seconds. Adaptive substeps limit SOC movement, use an analytic RC update and analytic constant-coefficient thermal update, and solve voltage constraints within the interval. Invalid duration does not advance; non-finite control values fall back to safe finite values. Current requests are limited by each preset's explicitly illustrative envelope. Ambient, cooling, resistance factors, SOC, and optional health are bounded.

Aging is opt-in. `equivalentCycles` is half the cumulative absolute SOC travel. A hand-selected fade coefficient changes health with throughput and simple heat / rate stress. Health stops at 50%. This is **illustrative capacity fade**, not predicted cycle life, calendar aging, lithium plating, SEI growth, sulfation, or polysulfide-shuttle transport. Real materials, device geometry, charge policy and use history are required for those predictions.

## Primary-source references

Sources support chemistry mechanisms and selected published ratings or controller concepts. They do not calibrate the catalog's hand-selected OCV, resistance, cooling, aging, and cutoff curves.

- [Pearse et al., nanoscale solid-state batteries](https://arxiv.org/abs/1702.04009): conformal ALD-grown solid conductor; LiCoO₂ / silicon device examples. The app's absolute nanocell capacity is conceptual.
- [ORNL LiPON interface research](https://www.ornl.gov/research-highlight/deposition-and-confinement-li-metal-along-artificial-lipon-lipon-interface): thin-film architecture and interface limitations.
- [Energizer E91 AA datasheet](https://data.energizer.com/pdfs/e91.pdf) and [alkaline handbook](https://data.energizer.com/pdfs/alkaline_appman.pdf): Zn/MnO₂, nominal 1.5 V, and current-dependent discharge capacity. The app's 2.5 Ah value is a representative rated-drain example.
- [Panasonic CR2032 specifications](https://energy.panasonic.com/na/business/products/lithium/coin-cr-standard/models/CR2032): primary 3 V coin, 225 mAh and 0.2 mA standard drain. The app deliberately permits exploratory loads only inside a chosen teaching envelope.
- [Energizer NiMH handbook](https://data.energizer.com/pdfs/nickelmetalhydride_appman.pdf), [TI BQ2002T](https://www.ti.com/product/BQ2002T), and [TI termination explanation](https://e2e.ti.com/support/power-management-group/power-management/f/power-management-forum/74822/bq2002---charging-and-termination): nickel reactions and peak / thermal charge termination.
- [GS Yuasa charging instructions](https://www.gs-yuasa.com/en/ps-eubr/pdf/Instructions_and_safety_information_for_Industrial_lead-acid_batteries.pdf) and [traction guide](https://www.gs-yuasa.com/jp/products/traction_batteries/pdf/V_en.pdf): lead-acid chemistry and differing cyclic / standby voltage regimes.
- [TI BQ25629](https://www.ti.com/product/BQ25629): lithium trickle / precharge / CC / CV / termination controller concepts. Device register limits are not universal cell specifications.
- [DOE electrode-material discussion](https://www.energy.gov/congressional/articles/senate-energy-and-natural-resources-committee-september-17-2019) and [NMC calendar-loss research](https://arxiv.org/abs/2103.02166): NMC / graphite architecture and dependence of aging on conditions.
- [LFP phase-transition research](https://arxiv.org/abs/1808.06164): phase behavior behind the broad LFP plateau; the app does not resolve those physical fields.
- [CATL sodium-ion architecture](https://www.catl.com/en/news/665.html) and [DOE sodium assessment](https://www.energy.gov/sites/default/files/2023-07/Technology%20Strategy%20Assessment%20-%20Sodium%20Batteries.pdf): sodium-family distinctions. Marketing performance is not used as model calibration.
- [ORNL Li–S shuttle research](https://www.ornl.gov/research-highlight/high-energy-lithium-sulfur-batteries) and [two-stage sulfur conversion research](https://impact.ornl.gov/en/publications/fast-reversible-lithium-storage-with-a-sulfurlong-chain-polysulfi/): conversion regions, shuttle mechanisms and limitations.
- [DOE flow assessment](https://www.energy.gov/sites/default/files/2023-07/Technology%20Strategy%20Assessment%20-%20Flow%20Batteries.pdf) and [DOE vanadium schematic](https://www.energy.gov/oe/articles/potential-benefits-high-power-high-capacity-batteries-january-2020): separate tanks, stack, pumped active fluids and membrane charge balance.

## Verification

Independent Swift package tests check analytic coulomb balance, charge efficiency, exponential rest recovery, signed voltage / power behavior, terminal-work balance including RC stored energy, ideal series / parallel scaling, primary charge rejection, discharge cutoff, lithium CC/CV transitions and ceilings, NiMH termination, lead absorption / float voltage / full-inventory energy balance, temperature holds, thermal relaxation, opt-in aging, reset, finite invalid-input behavior, mixed-mode operation across every preset, and accelerated versus fine charge stepping.

These tests establish implementation behavior and numerical invariants. They do not establish experimental cell accuracy, physical device interactions, charger safety, or measured battery lifetime.
