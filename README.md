# ALGT - Algorithm Logic Verification Tool

An expert system using SWI Prolog and Logtalk for formal verification of imaging algorithms used in medical radiation treatment planning.

## Overview

ALGT provides a comprehensive framework for verifying the correctness of geometric algorithms critical to medical imaging and radiation treatment. Using predicate logic and formal methods, ALGT ensures that complex geometric computations meet strict correctness criteria essential for patient safety.

## Features

- **Geometric Algorithm Verification**: Formal verification of beam volumes, mesh generation, isodensity calculations, and structure projections
- **Model Checking**: Verification of concurrent operations with interleaving analysis
- **Domain-Driven Design**: Event sourcing and domain modeling for imaging workflows
- **Protocol-Based Architecture**: Clean separation of interfaces and implementations using Logtalk protocols
- **Comprehensive Test Suite**: Extensive verification test cases for critical algorithms

## Requirements

- [SWI Prolog](https://www.swi-prolog.org/) (version 7.0 or higher recommended)
- [Logtalk](https://logtalk.org/) (for object-oriented components)

## Installation

1. Install SWI Prolog:
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install swi-prolog
   
   # On macOS with Homebrew
   brew install swi-prolog
   ```

2. Install Logtalk (if not already included with SWI Prolog):
   ```bash
   # Follow instructions at https://logtalk.org/download.html
   ```

3. Clone this repository:
   ```bash
   git clone https://github.com/DLaneAtElekta/ALGT.git
   cd ALGT
   ```

## Usage

### Running Verification Tests

Load and run individual algorithm verification tests:

```bash
swipl -s algt_tests/ALGT_BEAM_VOLUME.pl
```

### Using Logtalk Services

Load Logtalk imaging services:

```bash
logtalk
?- logtalk_load('imaging_services/loader.lgt').
```

### Model Checker

The model checker verifies concurrent operations:

```bash
swipl -s model_checker/model_checker.pl
```

Example usage:
```prolog
?- valid(sequence([capture_image -> img1, update_contour -> img1])).
true.
```

See `model_checker/README.md` for detailed documentation.

## Project Structure

```
ALGT/
├── algt_tests/                    # Algorithm verification test suite
│   ├── ALGT_BEAM_VOLUME.pl       # Beam volume generation tests
│   ├── ALGT_MESH_GEN.pl          # Mesh generation tests
│   ├── ALGT_ISODENSITY.pl        # Isodensity calculation tests
│   └── ...                        # Additional algorithm tests
├── imaging_services/              # Domain services and workflows
│   ├── contracts.lgt              # Protocol definitions
│   ├── image_import_manager.lgt   # Image import coordination
│   ├── image_review_manager.lgt   # Image review workflow
│   ├── trending_manager.lgt       # Trending analysis
│   ├── event_store.lgt            # Event sourcing implementation
│   └── ...                        # Service implementations
├── model_checker/                 # Concurrent operation verification
│   ├── model_checker.pl           # Model checking predicates
│   └── README.md                  # Model checker documentation
├── subject_image_domain_model/    # Domain model for subject images
├── treatment_image_domain_model/  # Domain model for treatment images
├── appointment_domain_model/      # Domain model for appointments
└── docs/                          # Documentation
```

## Key Components

### Algorithm Verification Tests (`algt_tests/`)

Test cases that formally verify geometric algorithms:

- **ALGT_BEAM_VOLUME**: Verifies radiation beam volume generation
- **ALGT_MESH_GEN**: Validates 3D mesh creation and manipulation
- **ALGT_ISODENSITY**: Checks dose distribution calculations
- **ALGT_STRUCT_PROJ**: Verifies geometric structure projections
- **ALGT_MARGIN2D/3D**: Validates margin calculations

Each test defines predicates that assert correctness conditions using geometric tolerances.

### Imaging Services (`imaging_services/`)

Domain services implementing imaging workflows:

- **Protocols (`contracts.lgt`)**: Interface definitions using Logtalk protocols
- **Managers**: Coordinate high-level operations (import, review, trending)
- **Engines**: Implement core processing logic
- **Data Access**: Provide persistence layer abstractions
- **Event Store**: Support event sourcing patterns

### Model Checker (`model_checker/`)

Formal verification tool for concurrent operations:

- Explores all possible interleavings of operations
- Identifies race conditions and state inconsistencies
- Complements functional verification with dynamic behavior analysis

See `model_checker/README.md` for implementation details.

## Development

### Adding New Tests

1. Create a new test file in `algt_tests/`
2. Follow the existing pattern of verification predicates
3. Use appropriate geometric tolerances
4. Document the algorithm being verified

### Extending Services

1. Define protocol in `imaging_services/contracts.lgt`
2. Implement object in a new `.lgt` file
3. Add to the loader if needed
4. Create appropriate tests

## History

ALGT was developed to provide formal verification capabilities for imaging algorithms in medical radiation treatment planning systems. The project combines traditional expert system approaches with modern domain-driven design and formal methods.

## License

Copyright (c) 2015, dg1an3

Licensed under the BSD 2-Clause License. See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please ensure:

- New code includes appropriate verification tests
- Geometric algorithms maintain mathematical rigor
- Protocol contracts are satisfied
- Documentation is updated accordingly

Given the critical nature of medical software, all contributions should prioritize correctness and patient safety.

## For AI Assistants

If you're an AI assistant working with this codebase, please review [CLAUDE.md](CLAUDE.md) for detailed guidance on project structure, conventions, and best practices.
