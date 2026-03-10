/// Treatment Offset — Domain Demo
/// Demonstrates the workflow from unvalidated input to validated domain object,
/// mirroring the Clarion OffsetLib behavior.
module TreatmentOffset.Program

open System
open TreatmentOffset.Domain

let printShift (label: string) (offset: TreatmentOffset) =
    let ap = offset.Shift.AnteriorPosterior
    let si = offset.Shift.SuperiorInferior
    let lr = offset.Shift.LeftRight
    printfn "--- %s ---" label
    printfn "  A/P: %d mm %A" (Millimeters.value ap.Distance) ap.Direction
    printfn "  S/I: %d mm %A" (Millimeters.value si.Distance) si.Direction
    printfn "  L/R: %d mm %A" (Millimeters.value lr.Distance) lr.Direction
    printfn "  Magnitude: %d mm" (Millimeters.value offset.Magnitude)
    printfn "  Source: %A" offset.Source
    printfn ""

[<EntryPoint>]
let main _argv =
    // Example 1: Normal positive values (like entering 5mm Anterior, 3mm Superior, 4mm Left)
    let input1 : UnvalidatedShiftEntry = {
        APValue = 5; APDirection = "Anterior"
        SIValue = 3; SIDirection = "Superior"
        LRValue = 4; LRDirection = "Left"
        DataSource = "CBCT"
        Date = Some (DateTimeOffset(2025, 1, 15, 10, 30, 0, TimeSpan.Zero))
    }

    match Workflow.createTreatmentOffset input1 with
    | Ok offset -> printShift "Normal positive values" offset
    | Error e -> printfn "Error: %A" e

    // Example 2: Negative value triggers sign-flip normalization
    // Entering -5 Anterior should become 5 Posterior (same as Clarion OLSetField)
    let input2 : UnvalidatedShiftEntry = {
        APValue = -5; APDirection = "Anterior"
        SIValue = 10; SIDirection = "Inferior"
        LRValue = -3; LRDirection = "Right"
        DataSource = "Manual"
        Date = Some (DateTimeOffset(2025, 1, 15, 14, 0, 0, TimeSpan.Zero))
    }

    match Workflow.createTreatmentOffset input2 with
    | Ok offset -> printShift "Sign-flip normalization" offset
    | Error e -> printfn "Error: %A" e

    // Example 3: Validation error — bad direction string
    let input3 : UnvalidatedShiftEntry = {
        APValue = 5; APDirection = "Forward"  // invalid
        SIValue = 3; SIDirection = "Superior"
        LRValue = 4; LRDirection = "Left"
        DataSource = "CBCT"
        Date = None
    }

    match Workflow.createTreatmentOffset input3 with
    | Ok offset -> printShift "Should not reach here" offset
    | Error e -> printfn "--- Validation error (expected) ---\n  %A\n" e

    // Example 4: ISqrt verification — 3-4-5 right triangle
    // sqrt(3² + 4² + 0²) = sqrt(25) = 5
    let input4 : UnvalidatedShiftEntry = {
        APValue = 3; APDirection = "Anterior"
        SIValue = 4; SIDirection = "Superior"
        LRValue = 0; LRDirection = "Left"
        DataSource = "kV Imaging"
        Date = Some (DateTimeOffset(2025, 6, 1, 8, 0, 0, TimeSpan.Zero))
    }

    match Workflow.createTreatmentOffset input4 with
    | Ok offset -> printShift "3-4-5 triangle (magnitude=5)" offset
    | Error e -> printfn "Error: %A" e

    0
