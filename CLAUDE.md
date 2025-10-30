# ALGT - AI Assistant Guide

This document provides guidance for AI assistants (like Claude, GitHub Copilot, etc.) working with the ALGT (Algorithm Logic Verification Tool) codebase.

## Project Overview

ALGT is an expert system built with SWI Prolog and Logtalk for verifying imaging algorithms used in medical radiation treatment planning. The system provides formal verification of geometric algorithms through predicate logic, ensuring correctness and safety in critical medical software.

## Key Technologies

- **SWI Prolog**: Core logic programming language
- **Logtalk**: Object-oriented extension for Prolog
- **Model Checking**: Formal verification of concurrent operations
- **Domain-Driven Design**: Event sourcing and domain modeling

## Project Structure

```
ALGT/
├── algt_tests/          # Algorithm verification test cases
│   ├── ALGT_BEAM_VOLUME.pl
│   ├── ALGT_MESH_GEN.pl
│   └── ...              # Various geometric algorithm tests
├── imaging_services/     # Domain services and workflows
│   ├── contracts.lgt     # Protocol definitions
│   ├── image_import_manager.lgt
│   ├── image_review_manager.lgt
│   ├── trending_manager.lgt
│   └── ...              # Service implementations
├── model_checker/       # Concurrent operation verification
│   ├── model_checker.pl # Model checking predicates
│   └── README.md        # Model checker documentation
├── subject_image_domain_model/
├── treatment_image_domain_model/
├── appointment_domain_model/
└── docs/                # Documentation
```

## Core Concepts

### 1. Algorithm Verification Tests
Located in `algt_tests/`, these test cases verify geometric algorithms:
- **Beam Volume**: Verification of radiation beam volume generation
- **Mesh Generation**: 3D mesh creation and manipulation
- **Isodensity**: Dose distribution calculations
- **Structure Projection**: 2D/3D geometric projections

### 2. Imaging Services
Domain services implementing image import, review, and workflow management:
- **Protocols (contracts.lgt)**: Interface definitions using Logtalk protocols
- **Managers**: Coordinate operations (import, review, trending)
- **Engines**: Core processing logic
- **Data Access**: Persistence layer interfaces
- **Event Store**: Event sourcing implementation

### 3. Model Checker
Verifies interleaved concurrent operations to identify state variations:
- Explores all possible interleavings of capture/update operations
- Identifies race conditions and state inconsistencies
- Augments functional predicates with dynamic behavior modeling

## Development Guidelines

### Working with Prolog/Logtalk

1. **Predicates**: Core computational units in Prolog
   - Format: `predicate_name(Arg1, Arg2, ...) :- Body.`
   - Use descriptive names with underscores

2. **Logtalk Objects**: Encapsulation of predicates
   ```logtalk
   :- object(object_name).
       :- public([public_predicate/1]).
       public_predicate(Arg) :- implementation.
   :- end_object.
   ```

3. **Protocols**: Interface definitions
   ```logtalk
   :- protocol(iprotocol_name).
       :- public([method/2]).
   :- end_protocol.
   ```

### Testing

Tests are located in `algt_tests/` and follow the pattern:
- Load required modules via `:- consult(pl/module).`
- Define verification predicates (e.g., `ok_beam_volume/3`)
- Assert correctness conditions using geometric tolerances
- Use `forall/2` for universal quantification

### Code Style

- Use snake_case for predicate names
- Prefix protocols with `i` (e.g., `iimage_import_manager`)
- Add copyright headers to new files
- Comment complex logical expressions
- Use meaningful variable names (capitalize in Prolog)

## Common Tasks

### Adding a New Service

1. Define protocol in `imaging_services/contracts.lgt`
2. Implement object in new `.lgt` file
3. Add to loader if needed
4. Create tests in `imaging_services/` or appropriate test directory

### Adding Algorithm Verification

1. Create test file in `algt_tests/ALGT_<ALGORITHM_NAME>.pl`
2. Define verification predicates following existing patterns
3. Use geometric tolerances for numeric comparisons
4. Document the algorithm being verified

### Modifying Model Checker

1. Review `model_checker/README.md` for concepts
2. Update predicates in `model_checker.pl`
3. Test with various sequence/fork structures
4. Ensure state analysis correctness

## Running Tests

Since this is a Prolog/Logtalk project, tests are typically run via:
```bash
swipl -s test_file.pl
```

Or load in Logtalk:
```bash
logtalk
?- logtalk_load(test_file).
```

## Important Considerations

1. **Medical Software**: This code relates to radiation treatment planning
   - Correctness is critical for patient safety
   - Geometric calculations must be precise
   - Always maintain test coverage

2. **Formal Verification**: The purpose is proving algorithm correctness
   - Don't weaken assertions without justification
   - Maintain mathematical rigor in predicates
   - Document assumptions and tolerances

3. **Legacy Code**: Some components interface with legacy systems
   - Respect existing interfaces
   - Document compatibility requirements

## Resources

- [SWI Prolog Documentation](https://www.swi-prolog.org/pldoc/doc_for?object=manual)
- [Logtalk Documentation](https://logtalk.org/documentation.html)
- Model Checker: See `model_checker/README.md`

## Questions?

When working on this codebase, consider:
- Does this change maintain correctness guarantees?
- Are geometric tolerances appropriate?
- Is the predicate logic sound?
- Are protocol contracts satisfied?
- Does this align with domain-driven design principles?
