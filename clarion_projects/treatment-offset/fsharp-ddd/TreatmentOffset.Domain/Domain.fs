/// Treatment Offset Domain Model
/// Following "Domain Modeling Made Functional" by Scott Wlaschin
///
/// Mirrors the Clarion TreatmentOffset form logic, but uses F# types
/// to make illegal states unrepresentable.
module TreatmentOffset.Domain

open System

// ============================================================
// Simple Types (domain primitives as single-case unions)
// ============================================================

/// Non-negative distance in millimeters
type Millimeters = private Millimeters of int

module Millimeters =
    let create (value: int) =
        if value < 0 then Error "Millimeters cannot be negative"
        else Ok (Millimeters value)

    let zero = Millimeters 0
    let value (Millimeters mm) = mm

// ============================================================
// Domain Types
// ============================================================

/// Anterior-Posterior direction
type APDirection = Anterior | Posterior

/// Superior-Inferior direction
type SIDirection = Superior | Inferior

/// Left-Right direction
type LRDirection = Left | Right

/// A directional shift: magnitude (always >= 0) paired with direction.
/// The Clarion code stores these as separate LONG fields + sign-flip
/// normalization. Here, the type system guarantees the invariant.
type DirectionalShift<'Direction> = {
    Distance: Millimeters
    Direction: 'Direction
}

/// The three anatomical axes, each with its own direction type.
/// Making each axis a distinct type prevents mixing AP with LR, etc.
type PatientShift = {
    AnteriorPosterior: DirectionalShift<APDirection>
    SuperiorInferior: DirectionalShift<SIDirection>
    LeftRight: DirectionalShift<LRDirection>
}

/// Where the offset measurement came from
type DataSource =
    | CBCT
    | KVImaging
    | Portal
    | Manual

/// A complete treatment offset record
type TreatmentOffset = {
    Shift: PatientShift
    Magnitude: Millimeters
    RecordedAt: DateTimeOffset
    Source: DataSource
}

// ============================================================
// Unvalidated Types (at the system boundary)
// ============================================================

/// Raw input from UI or external system — not yet validated.
/// In Wlaschin's terms, this is the "unvalidated" form.
type UnvalidatedShiftEntry = {
    APValue: int        // may be negative (sign-flip needed)
    APDirection: string // "Anterior" or "Posterior"
    SIValue: int
    SIDirection: string
    LRValue: int
    LRDirection: string
    DataSource: string
    Date: DateTimeOffset option
}

// ============================================================
// Domain Errors
// ============================================================

type ValidationError =
    | InvalidDirection of axis: string * value: string
    | InvalidDataSource of string
    | NegativeAfterNormalization of axis: string

type DomainError =
    | Validation of ValidationError

// ============================================================
// Pure Domain Logic
// ============================================================

module ShiftNormalization =
    /// Normalize a signed shift value: if negative, negate and flip direction.
    /// This is the core sign-flip logic from the Clarion code:
    ///   IF val < 0
    ///     Value = 0 - val
    ///     IF Dir = 1 THEN Dir = 2 ELSE Dir = 1.
    let normalize (flipDirection: 'D -> 'D) (value: int) (direction: 'D) : DirectionalShift<'D> =
        if value < 0 then
            { Distance = Millimeters.create (abs value) |> Result.defaultValue Millimeters.zero
              Direction = flipDirection direction }
        else
            { Distance = Millimeters.create value |> Result.defaultValue Millimeters.zero
              Direction = direction }

    let flipAP = function Anterior -> Posterior | Posterior -> Anterior
    let flipSI = function Superior -> Inferior | Inferior -> Superior
    let flipLR = function Left -> Right | Right -> Left

module Magnitude =
    /// Integer square root via Newton's method.
    /// Direct translation of the Clarion ISqrt procedure.
    let isqrt (n: int) : int =
        if n <= 0 then 0
        else
            let mutable x = n
            let mutable x1 = (x + 1) / 2
            while x1 < x do
                x <- x1
                x1 <- (x + n / x) / 2
            x

    /// Calculate 3D Euclidean magnitude: sqrt(ap² + si² + lr²)
    let calculate (shift: PatientShift) : Millimeters =
        let ap = Millimeters.value shift.AnteriorPosterior.Distance
        let si = Millimeters.value shift.SuperiorInferior.Distance
        let lr = Millimeters.value shift.LeftRight.Distance
        let sumSquares = ap * ap + si * si + lr * lr
        Millimeters.create (isqrt sumSquares) |> Result.defaultValue Millimeters.zero

// ============================================================
// Validation (at the boundary)
// ============================================================

module Validation =
    let parseAPDirection = function
        | "Anterior" -> Ok Anterior
        | "Posterior" -> Ok Posterior
        | s -> Error (InvalidDirection ("A/P", s))

    let parseSIDirection = function
        | "Superior" -> Ok Superior
        | "Inferior" -> Ok Inferior
        | s -> Error (InvalidDirection ("S/I", s))

    let parseLRDirection = function
        | "Left" -> Ok Left
        | "Right" -> Ok Right
        | s -> Error (InvalidDirection ("L/R", s))

    let parseDataSource = function
        | "CBCT" -> Ok CBCT
        | "kV Imaging" -> Ok KVImaging
        | "Portal" -> Ok Portal
        | "Manual" -> Ok Manual
        | s -> Error (InvalidDataSource s)

// ============================================================
// Workflow: Create Treatment Offset
// ============================================================

module Workflow =
    open ShiftNormalization

    /// The main workflow: validate raw input -> domain object.
    /// In Wlaschin's terms: UnvalidatedInput -> Result<ValidatedOutput, Error>
    let createTreatmentOffset (input: UnvalidatedShiftEntry) : Result<TreatmentOffset, ValidationError> =
        // Parse directions (validation at the boundary)
        let apDirResult = Validation.parseAPDirection input.APDirection
        let siDirResult = Validation.parseSIDirection input.SIDirection
        let lrDirResult = Validation.parseLRDirection input.LRDirection
        let sourceResult = Validation.parseDataSource input.DataSource

        match apDirResult, siDirResult, lrDirResult, sourceResult with
        | Ok apDir, Ok siDir, Ok lrDir, Ok source ->
            // Normalize shifts (sign-flip for negative values)
            let apShift = normalize flipAP input.APValue apDir
            let siShift = normalize flipSI input.SIValue siDir
            let lrShift = normalize flipLR input.LRValue lrDir

            let shift = {
                AnteriorPosterior = apShift
                SuperiorInferior = siShift
                LeftRight = lrShift
            }

            let magnitude = Magnitude.calculate shift
            let recordedAt = input.Date |> Option.defaultValue DateTimeOffset.Now

            Ok {
                Shift = shift
                Magnitude = magnitude
                RecordedAt = recordedAt
                Source = source
            }
        | Error e, _, _, _ -> Error e
        | _, Error e, _, _ -> Error e
        | _, _, Error e, _ -> Error e
        | _, _, _, Error e -> Error e
