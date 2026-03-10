module TreatmentOffset.Tests

open System
open Xunit
open TreatmentOffset.Domain

// ============================================================
// Millimeters (domain primitive)
// ============================================================

[<Fact>]
let ``Millimeters rejects negative values`` () =
    match Millimeters.create -1 with
    | Error _ -> ()
    | Ok _ -> Assert.Fail "Should reject negative"

[<Fact>]
let ``Millimeters accepts zero and positive`` () =
    Assert.Equal(Ok (Millimeters.zero), Millimeters.create 0)
    match Millimeters.create 42 with
    | Ok mm -> Assert.Equal(42, Millimeters.value mm)
    | Error e -> Assert.Fail e

// ============================================================
// ISqrt (Newton's method — must match Clarion ISqrt exactly)
// ============================================================

[<Theory>]
[<InlineData(0, 0)>]
[<InlineData(1, 1)>]
[<InlineData(4, 2)>]
[<InlineData(25, 5)>]
[<InlineData(26, 5)>]
[<InlineData(100, 10)>]
[<InlineData(10000, 100)>]
let ``ISqrt matches Clarion integer square root`` (input: int, expected: int) =
    Assert.Equal(expected, Magnitude.isqrt input)

[<Fact>]
let ``ISqrt of negative returns 0`` () =
    Assert.Equal(0, Magnitude.isqrt -5)

// ============================================================
// Sign-flip normalization (core Clarion OLSetField logic)
// ============================================================

[<Fact>]
let ``Positive value keeps original direction`` () =
    let shift = ShiftNormalization.normalize ShiftNormalization.flipAP 5 Anterior
    Assert.Equal(5, Millimeters.value shift.Distance)
    Assert.Equal(Anterior, shift.Direction)

[<Fact>]
let ``Negative value negates and flips direction`` () =
    let shift = ShiftNormalization.normalize ShiftNormalization.flipAP -5 Anterior
    Assert.Equal(5, Millimeters.value shift.Distance)
    Assert.Equal(Posterior, shift.Direction)

[<Fact>]
let ``Negative value flips Posterior to Anterior`` () =
    let shift = ShiftNormalization.normalize ShiftNormalization.flipAP -10 Posterior
    Assert.Equal(10, Millimeters.value shift.Distance)
    Assert.Equal(Anterior, shift.Direction)

[<Fact>]
let ``SI sign-flip works`` () =
    let shift = ShiftNormalization.normalize ShiftNormalization.flipSI -7 Superior
    Assert.Equal(7, Millimeters.value shift.Distance)
    Assert.Equal(Inferior, shift.Direction)

[<Fact>]
let ``LR sign-flip works`` () =
    let shift = ShiftNormalization.normalize ShiftNormalization.flipLR -3 Right
    Assert.Equal(3, Millimeters.value shift.Distance)
    Assert.Equal(Left, shift.Direction)

[<Fact>]
let ``Zero value preserves direction`` () =
    let shift = ShiftNormalization.normalize ShiftNormalization.flipAP 0 Posterior
    Assert.Equal(0, Millimeters.value shift.Distance)
    Assert.Equal(Posterior, shift.Direction)

// ============================================================
// Magnitude calculation (3D Euclidean distance)
// ============================================================

[<Fact>]
let ``Magnitude of 3-4-0 triangle is 5`` () =
    let shift = {
        AnteriorPosterior = { Distance = Millimeters.create 3 |> Result.defaultValue Millimeters.zero; Direction = Anterior }
        SuperiorInferior = { Distance = Millimeters.create 4 |> Result.defaultValue Millimeters.zero; Direction = Superior }
        LeftRight = { Distance = Millimeters.zero; Direction = Left }
    }
    Assert.Equal(5, Millimeters.value (Magnitude.calculate shift))

[<Fact>]
let ``Magnitude of 0-0-0 is 0`` () =
    let shift = {
        AnteriorPosterior = { Distance = Millimeters.zero; Direction = Anterior }
        SuperiorInferior = { Distance = Millimeters.zero; Direction = Superior }
        LeftRight = { Distance = Millimeters.zero; Direction = Left }
    }
    Assert.Equal(0, Millimeters.value (Magnitude.calculate shift))

[<Fact>]
let ``Magnitude of 10-20-30 matches Clarion`` () =
    let shift = {
        AnteriorPosterior = { Distance = Millimeters.create 10 |> Result.defaultValue Millimeters.zero; Direction = Anterior }
        SuperiorInferior = { Distance = Millimeters.create 20 |> Result.defaultValue Millimeters.zero; Direction = Superior }
        LeftRight = { Distance = Millimeters.create 30 |> Result.defaultValue Millimeters.zero; Direction = Left }
    }
    Assert.Equal(37, Millimeters.value (Magnitude.calculate shift))

// ============================================================
// Validation (boundary parsing)
// ============================================================

[<Theory>]
[<InlineData("Anterior")>]
[<InlineData("Posterior")>]
let ``Valid AP directions parse`` (dir: string) =
    Assert.True((Validation.parseAPDirection dir).IsOk)

[<Fact>]
let ``Invalid AP direction fails`` () =
    match Validation.parseAPDirection "Forward" with
    | Error (InvalidDirection ("A/P", "Forward")) -> ()
    | other -> Assert.Fail $"Expected InvalidDirection, got {other}"

[<Theory>]
[<InlineData("CBCT")>]
[<InlineData("kV Imaging")>]
[<InlineData("Portal")>]
[<InlineData("Manual")>]
let ``Valid data sources parse`` (src: string) =
    Assert.True((Validation.parseDataSource src).IsOk)

[<Fact>]
let ``Invalid data source fails`` () =
    match Validation.parseDataSource "Laser" with
    | Error (InvalidDataSource "Laser") -> ()
    | other -> Assert.Fail $"Expected InvalidDataSource, got {other}"

// ============================================================
// Full workflow (end-to-end: matches Clarion OLSetField + OLCalcBtn)
// ============================================================

[<Fact>]
let ``Workflow: positive values produce correct offset`` () =
    let input : UnvalidatedShiftEntry = {
        APValue = 5; APDirection = "Anterior"
        SIValue = 3; SIDirection = "Superior"
        LRValue = 4; LRDirection = "Left"
        DataSource = "CBCT"
        Date = Some (DateTimeOffset(2025, 1, 15, 10, 0, 0, TimeSpan.Zero))
    }
    match Workflow.createTreatmentOffset input with
    | Ok offset ->
        Assert.Equal(5, Millimeters.value offset.Shift.AnteriorPosterior.Distance)
        Assert.Equal(Anterior, offset.Shift.AnteriorPosterior.Direction)
        Assert.Equal(3, Millimeters.value offset.Shift.SuperiorInferior.Distance)
        Assert.Equal(4, Millimeters.value offset.Shift.LeftRight.Distance)
        Assert.Equal(7, Millimeters.value offset.Magnitude)
        Assert.Equal(CBCT, offset.Source)
    | Error e -> Assert.Fail $"Unexpected error: {e}"

[<Fact>]
let ``Workflow: negative AP flips to Posterior`` () =
    let input : UnvalidatedShiftEntry = {
        APValue = -5; APDirection = "Anterior"
        SIValue = 0; SIDirection = "Superior"
        LRValue = 0; LRDirection = "Left"
        DataSource = "Manual"
        Date = None
    }
    match Workflow.createTreatmentOffset input with
    | Ok offset ->
        Assert.Equal(5, Millimeters.value offset.Shift.AnteriorPosterior.Distance)
        Assert.Equal(Posterior, offset.Shift.AnteriorPosterior.Direction)
        Assert.Equal(5, Millimeters.value offset.Magnitude)
    | Error e -> Assert.Fail $"Unexpected error: {e}"

[<Fact>]
let ``Workflow: all negative values flip all directions`` () =
    let input : UnvalidatedShiftEntry = {
        APValue = -10; APDirection = "Anterior"
        SIValue = -20; SIDirection = "Superior"
        LRValue = -30; LRDirection = "Left"
        DataSource = "Portal"
        Date = Some (DateTimeOffset(2025, 6, 1, 8, 0, 0, TimeSpan.Zero))
    }
    match Workflow.createTreatmentOffset input with
    | Ok offset ->
        Assert.Equal(Posterior, offset.Shift.AnteriorPosterior.Direction)
        Assert.Equal(Inferior, offset.Shift.SuperiorInferior.Direction)
        Assert.Equal(Right, offset.Shift.LeftRight.Direction)
        Assert.Equal(37, Millimeters.value offset.Magnitude)
    | Error e -> Assert.Fail $"Unexpected error: {e}"

[<Fact>]
let ``Workflow: invalid direction returns validation error`` () =
    let input : UnvalidatedShiftEntry = {
        APValue = 5; APDirection = "Forward"
        SIValue = 3; SIDirection = "Superior"
        LRValue = 4; LRDirection = "Left"
        DataSource = "CBCT"
        Date = None
    }
    match Workflow.createTreatmentOffset input with
    | Error (InvalidDirection ("A/P", "Forward")) -> ()
    | other -> Assert.Fail $"Expected InvalidDirection, got {other}"

[<Fact>]
let ``Workflow: invalid data source returns validation error`` () =
    let input : UnvalidatedShiftEntry = {
        APValue = 5; APDirection = "Anterior"
        SIValue = 3; SIDirection = "Superior"
        LRValue = 4; LRDirection = "Left"
        DataSource = "Laser"
        Date = None
    }
    match Workflow.createTreatmentOffset input with
    | Error (InvalidDataSource "Laser") -> ()
    | other -> Assert.Fail $"Expected InvalidDataSource, got {other}"
