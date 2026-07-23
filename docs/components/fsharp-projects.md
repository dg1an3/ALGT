---
title: F# projects
layout: default
parent: Components
nav_order: 7
---

# F# projects

F# verification and domain demonstrations — a second implementation language for
parts of the platform, useful for cross-checking the Prolog/Logtalk results and
exploring statically typed realizations of the domain models.

**Location:** [`fsharp_projects/`](https://github.com/DLaneAtElekta/ALGT/tree/main/fsharp_projects)
· **Tooling:** .NET SDK 8+

| Project | Purpose |
|---|---|
| `fsharp_hello_world` | Smoke test |
| `fsharp_features` | Language-feature demonstrations |
| `fsharp_logic_lib` | Logic/verification library |
| `fsharp_domain_demo` | Domain-model demo |
| `fsharp_fuel_inventory` | Worked inventory example |

See also the [F# simulator]({{ site.baseurl }}/components/simulators.html) under
`simulators/fsharp/unified/`.
