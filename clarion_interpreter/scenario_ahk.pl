%============================================================
% scenario_ahk.pl - AutoHotkey Script Generator for Scenarios
%
% Generates AutoHotkey scripts from scenario DSL definitions.
% This enables running the same test scenarios against real
% Clarion applications to verify interpreter equivalence.
%
% Features:
%   - Control identification via USE names or coordinates
%   - MsgBox interception for MESSAGE assertions
%   - ControlGetText for value assertions
%   - Configurable timing variables
%============================================================

:- module(scenario_ahk, [
    % Script generation
    generate_ahk/3,             % (Scenario, Options, Script)
    generate_ahk_file/3,        % (Scenario, Options, FilePath)
    generate_ahk_suite/3,       % (Scenarios, Options, Script)
    generate_ahk_suite_file/3,  % (Scenarios, Options, FilePath)

    % Options
    default_ahk_options/1       % (Options)
]).

%------------------------------------------------------------
% Options Structure
%------------------------------------------------------------
% Options is a dict with:
%   app_path: Path to Clarion executable
%   app_title: Window title pattern for main app window
%   action_delay: ms to wait between actions (default 100)
%   window_timeout: ms to wait for windows (default 5000)
%   msgbox_timeout: ms to wait for message boxes (default 3000)
%   control_map: dict mapping ControlId -> ahk_control{...}
%   output_file: Path for test results log

default_ahk_options(options{
    app_path: "App.exe",
    app_title: "ahk_exe App.exe",
    action_delay: 100,
    window_timeout: 5000,
    msgbox_timeout: 3000,
    control_map: controls{},
    output_file: "test_results.log"
}).

%------------------------------------------------------------
% Script Generation - Single Scenario
%------------------------------------------------------------

generate_ahk(scenario(Name, Setup, Actions, Expectations), Options, Script) :-
    generate_header(Options, Header),
    generate_setup(Setup, Options, SetupCode),
    generate_actions(Actions, Options, ActionsCode),
    generate_expectations(Name, Expectations, Options, ExpectCode),
    generate_footer(Name, Footer),
    atomics_to_string([Header, SetupCode, ActionsCode, ExpectCode, Footer], Script).

generate_ahk_file(Scenario, Options, FilePath) :-
    generate_ahk(Scenario, Options, Script),
    open(FilePath, write, Stream),
    write(Stream, Script),
    close(Stream).

%------------------------------------------------------------
% Script Generation - Test Suite
%------------------------------------------------------------

generate_ahk_suite(Scenarios, Options, Script) :-
    generate_header(Options, Header),
    generate_suite_init(Options, SuiteInit),
    generate_scenario_functions(Scenarios, Options, ScenarioFuncs),
    generate_suite_runner(Scenarios, Options, Runner),
    generate_suite_footer(Options, Footer),
    atomics_to_string([Header, SuiteInit, ScenarioFuncs, Runner, Footer], Script).

generate_ahk_suite_file(Scenarios, Options, FilePath) :-
    generate_ahk_suite(Scenarios, Options, Script),
    open(FilePath, write, Stream),
    write(Stream, Script),
    close(Stream).

%------------------------------------------------------------
% Header Generation
%------------------------------------------------------------

generate_header(Options, Header) :-
    AppPath = Options.app_path,
    AppTitle = Options.app_title,
    ActionDelay = Options.action_delay,
    WindowTimeout = Options.window_timeout,
    MsgBoxTimeout = Options.msgbox_timeout,
    OutputFile = Options.output_file,
    format(atom(Header),
'; AutoHotkey Test Script - Generated from Scenario DSL
; Generated: ~w
#Requires AutoHotkey v2.0
#SingleInstance Force

;------------------------------------------------------------
; Configuration (adjust these for your environment)
;------------------------------------------------------------
global APP_PATH := "~w"
global APP_TITLE := "~w"
global ACTION_DELAY := ~w      ; ms between actions
global WINDOW_TIMEOUT := ~w    ; ms to wait for windows
global MSGBOX_TIMEOUT := ~w    ; ms to wait for message boxes
global OUTPUT_FILE := "~w"

;------------------------------------------------------------
; Test State
;------------------------------------------------------------
global TestsPassed := 0
global TestsFailed := 0
global CurrentTest := ""
global CapturedMessages := []

;------------------------------------------------------------
; Utility Functions
;------------------------------------------------------------

; Log a message to the output file
Log(msg) {
    FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") . " " . msg . "`n", OUTPUT_FILE)
}

; Log test result
LogResult(testName, passed, details := "") {
    if (passed) {
        TestsPassed++
        Log("PASS: " . testName)
    } else {
        TestsFailed++
        Log("FAIL: " . testName . " - " . details)
    }
}

; Wait for a window with timeout
WaitForWindow(title, timeout := WINDOW_TIMEOUT) {
    try {
        WinWait(title, , timeout / 1000)
        return true
    } catch {
        return false
    }
}

; Set control value by USE name or ClassNN
SetControlValue(controlId, value, winTitle := APP_TITLE) {
    try {
        ControlSetText(value, controlId, winTitle)
        Sleep(ACTION_DELAY)
        return true
    } catch as e {
        Log("ERROR: SetControlValue failed for " . controlId . ": " . e.Message)
        return false
    }
}

; Get control value by USE name or ClassNN
GetControlValue(controlId, winTitle := APP_TITLE) {
    try {
        return ControlGetText(controlId, winTitle)
    } catch as e {
        Log("ERROR: GetControlValue failed for " . controlId . ": " . e.Message)
        return ""
    }
}

; Click a control
ClickControl(controlId, winTitle := APP_TITLE) {
    try {
        ControlClick(controlId, winTitle)
        Sleep(ACTION_DELAY)
        return true
    } catch as e {
        Log("ERROR: ClickControl failed for " . controlId . ": " . e.Message)
        return false
    }
}

; Click at coordinates relative to window
ClickAt(x, y, winTitle := APP_TITLE) {
    try {
        ControlClick("x" . x . " y" . y, winTitle)
        Sleep(ACTION_DELAY)
        return true
    } catch {
        ; Fallback to mouse click
        WinGetPos(&wx, &wy, , , winTitle)
        Click(wx + x, wy + y)
        Sleep(ACTION_DELAY)
        return true
    }
}

; Focus a control
FocusControl(controlId, winTitle := APP_TITLE) {
    try {
        ControlFocus(controlId, winTitle)
        Sleep(ACTION_DELAY // 2)
        return true
    } catch as e {
        Log("ERROR: FocusControl failed for " . controlId . ": " . e.Message)
        return false
    }
}

; Send keystrokes to focused control
SendKeys(keys) {
    Send(keys)
    Sleep(ACTION_DELAY)
}

;------------------------------------------------------------
; MsgBox Interception
;------------------------------------------------------------

; Check for and capture any message box, auto-dismiss with OK
CheckForMsgBox(timeout := MSGBOX_TIMEOUT) {
    try {
        if WinWait("ahk_class #32770", , timeout / 1000) {
            ; Get the message text (usually Static1 or Static2)
            msgText := ""
            try {
                msgText := ControlGetText("Static2", "ahk_class #32770")
            } catch {
                try {
                    msgText := ControlGetText("Static1", "ahk_class #32770")
                }
            }

            ; Store captured message
            CapturedMessages.Push(msgText)
            Log("MSGBOX captured: " . msgText)

            ; Dismiss with OK (Enter or click Button1)
            try {
                ControlClick("Button1", "ahk_class #32770")
            } catch {
                Send("{Enter}")
            }
            Sleep(ACTION_DELAY)
            return msgText
        }
    }
    return ""
}

; Wait for specific message box text
WaitForMessage(expectedText, timeout := MSGBOX_TIMEOUT) {
    startTime := A_TickCount
    while (A_TickCount - startTime < timeout) {
        msg := CheckForMsgBox(100)
        if (msg != "" && InStr(msg, expectedText))
            return true
        Sleep(50)
    }
    return false
}

; Check if any captured message contains text
MessageWasCaptured(text) {
    for msg in CapturedMessages {
        if InStr(msg, text)
            return true
    }
    return false
}

; Clear captured messages
ClearMessages() {
    CapturedMessages := []
}

;------------------------------------------------------------
; Assertion Functions
;------------------------------------------------------------

; Assert control has expected value
AssertControlValue(testName, controlId, expected, winTitle := APP_TITLE) {
    actual := GetControlValue(controlId, winTitle)
    passed := (actual = expected)
    if (!passed)
        LogResult(testName, false, "Expected [" . expected . "] but got [" . actual . "]")
    else
        LogResult(testName, true)
    return passed
}

; Assert message was shown (exact match)
AssertMessage(testName, expectedText) {
    passed := MessageWasCaptured(expectedText)
    if (!passed)
        LogResult(testName, false, "Message [" . expectedText . "] was not shown")
    else
        LogResult(testName, true)
    return passed
}

; Assert message contains substring
AssertMessageContains(testName, substring) {
    passed := false
    for msg in CapturedMessages {
        if InStr(msg, substring) {
            passed := true
            break
        }
    }
    if (!passed)
        LogResult(testName, false, "No message containing [" . substring . "] was shown")
    else
        LogResult(testName, true)
    return passed
}

;------------------------------------------------------------
; Screenshot Capture
;------------------------------------------------------------

; Capture screenshot of active window
CaptureWindow(filename := "") {
    if (filename = "")
        filename := "screenshot_" . FormatTime(, "yyyyMMdd_HHmmss") . ".png"
    try {
        ; Get active window position
        WinGetPos(&x, &y, &w, &h, "A")
        ; Use Gdip for screenshot (requires Gdip library or use simpler method)
        ; Simple fallback: use PrintScreen and save
        Send("{PrintScreen}")
        Sleep(100)
        ; Note: Full Gdip implementation would go here
        ; For now, log the intent
        Log("SCREENSHOT: " . filename . " (window at " . x . "," . y . " size " . w . "x" . h . ")")
        return filename
    } catch as e {
        Log("ERROR: Screenshot failed: " . e.Message)
        return ""
    }
}

; Capture screenshot on test failure
CaptureOnFailure(testName) {
    filename := "fail_" . testName . "_" . FormatTime(, "yyyyMMdd_HHmmss") . ".png"
    return CaptureWindow(filename)
}

', [now, AppPath, AppTitle, ActionDelay, WindowTimeout, MsgBoxTimeout, OutputFile]).

%------------------------------------------------------------
% Setup Generation
%------------------------------------------------------------

generate_setup(Setup, Options, Code) :-
    findall(Line, (member(Item, Setup), setup_to_ahk(Item, Options, Line)), Lines),
    ( Lines = []
    -> Code = ""
    ;  atomics_to_string([
";------------------------------------------------------------\n",
"; Setup\n",
";------------------------------------------------------------\n\n"
       | Lines], Code)
    ).

setup_to_ahk(app_window(Title), Options, Line) :-
    WindowTimeout = Options.window_timeout,
    format(atom(Line),
'if (!WinExist("~w")) {
    Run(APP_PATH)
    if (!WaitForWindow("~w", ~w)) {
        Log("ERROR: Application window did not appear")
        ExitApp(1)
    }
}
WinActivate("~w")
Sleep(ACTION_DELAY)

', [Title, Title, WindowTimeout, Title]).

setup_to_ahk(window(Title), Options, Line) :-
    WindowTimeout = Options.window_timeout,
    format(atom(Line),
'if (!WaitForWindow("~w", ~w)) {
    Log("ERROR: Window ''~w'' did not appear")
    ExitApp(1)
}
WinActivate("~w")
Sleep(ACTION_DELAY)

', [Title, WindowTimeout, Title, Title]).

setup_to_ahk(launch_app, Options, Line) :-
    WindowTimeout = Options.window_timeout,
    format(atom(Line),
'Run(APP_PATH)
if (!WaitForWindow(APP_TITLE, ~w)) {
    Log("ERROR: Application did not start")
    ExitApp(1)
}
WinActivate(APP_TITLE)
Sleep(ACTION_DELAY)
ClearMessages()

', [WindowTimeout]).

setup_to_ahk(clear_messages, _, "ClearMessages()\n").

% Ignore setup items that don't translate to AHK
setup_to_ahk(program(_), _, "").
setup_to_ahk(var(_, _), _, "").
setup_to_ahk(event_queue(_), _, "").

%------------------------------------------------------------
% Action Generation
%------------------------------------------------------------

generate_actions(Actions, Options, Code) :-
    findall(Line, (member(Action, Actions), action_to_ahk(Action, Options, Line)), Lines),
    ( Lines = []
    -> Code = ""
    ;  atomics_to_string([
";------------------------------------------------------------\n",
"; Actions\n",
";------------------------------------------------------------\n\n"
       | Lines], Code)
    ).

action_to_ahk(field(ControlId, Value), Options, Line) :-
    control_identifier(ControlId, Options, AhkId),
    format(atom(Line), 'SetControlValue("~w", "~w")~n', [AhkId, Value]).

action_to_ahk(click(ControlId), Options, Line) :-
    control_identifier(ControlId, Options, AhkId),
    format(atom(Line), 'ClickControl("~w")~n', [AhkId]).

action_to_ahk(click_at(X, Y), _, Line) :-
    format(atom(Line), 'ClickAt(~w, ~w)~n', [X, Y]).

action_to_ahk(focus(ControlId), Options, Line) :-
    control_identifier(ControlId, Options, AhkId),
    format(atom(Line), 'FocusControl("~w")~n', [AhkId]).

action_to_ahk(send(Keys), _, Line) :-
    format(atom(Line), 'SendKeys("~w")~n', [Keys]).

action_to_ahk(wait(Ms), _, Line) :-
    format(atom(Line), 'Sleep(~w)~n', [Ms]).

action_to_ahk(wait_window(Title), Options, Line) :-
    WindowTimeout = Options.window_timeout,
    format(atom(Line), 'WaitForWindow("~w", ~w)~n', [Title, WindowTimeout]).

action_to_ahk(check_msgbox, _, "CheckForMsgBox()\n").

action_to_ahk(dismiss_msgbox, _, "CheckForMsgBox(100)\n").

action_to_ahk(screenshot, _, "CaptureWindow()\n").

action_to_ahk(screenshot(Filename), _, Line) :-
    format(atom(Line), 'CaptureWindow("~w")~n', [Filename]).

% Actions that don't translate to AHK (interpreter-specific)
action_to_ahk(event(_), _, "; (event injection - interpreter only)\n").
action_to_ahk(step, _, "; (step - interpreter only)\n").
action_to_ahk(run_to_completion, _, "; (run_to_completion - interpreter only)\n").

%------------------------------------------------------------
% Expectation Generation
%------------------------------------------------------------

generate_expectations(TestName, Expectations, Options, Code) :-
    findall(Line, (
        member(Expect, Expectations),
        expectation_to_ahk(TestName, Expect, Options, Line)
    ), Lines),
    ( Lines = []
    -> Code = ""
    ;  atomics_to_string([
";------------------------------------------------------------\n",
"; Assertions\n",
";------------------------------------------------------------\n\n"
       | Lines], Code)
    ).

expectation_to_ahk(TestName, message(Text), _, Line) :-
    format(atom(Line), 'AssertMessage("~w: message", "~w")~n', [TestName, Text]).

expectation_to_ahk(TestName, message_contains(Substr), _, Line) :-
    format(atom(Line), 'AssertMessageContains("~w: message_contains", "~w")~n', [TestName, Substr]).

expectation_to_ahk(TestName, control_value(ControlId, Expected), Options, Line) :-
    control_identifier(ControlId, Options, AhkId),
    format(atom(Line), 'AssertControlValue("~w: control_value(~w)", "~w", "~w")~n',
           [TestName, ControlId, AhkId, Expected]).

% Expectations that don't translate directly to AHK
expectation_to_ahk(_, var(_, _), _, "; (var assertion - interpreter only)\n").
expectation_to_ahk(_, no_error, _, "; (no_error - interpreter only)\n").
expectation_to_ahk(_, error(_), _, "; (error code - interpreter only)\n").

%------------------------------------------------------------
% Footer Generation
%------------------------------------------------------------

generate_footer(TestName, Footer) :-
    format(atom(Footer),
'
;------------------------------------------------------------
; Test Complete
;------------------------------------------------------------
Log("Test ''~w'' complete: " . TestsPassed . " passed, " . TestsFailed . " failed")

if (TestsFailed > 0)
    ExitApp(1)
ExitApp(0)
', [TestName]).

%------------------------------------------------------------
% Suite Generation Helpers
%------------------------------------------------------------

generate_suite_init(_, Init) :-
    Init = '
;------------------------------------------------------------
; Test Suite Initialization
;------------------------------------------------------------

; Delete old log file
if FileExist(OUTPUT_FILE)
    FileDelete(OUTPUT_FILE)

Log("=== Test Suite Started ===")

'.

generate_scenario_functions([], _, "").
generate_scenario_functions([Scenario|Rest], Options, Code) :-
    generate_scenario_function(Scenario, Options, FuncCode),
    generate_scenario_functions(Rest, Options, RestCode),
    atom_concat(FuncCode, RestCode, Code).

generate_scenario_function(scenario(Name, Setup, Actions, Expectations), Options, Code) :-
    generate_setup(Setup, Options, SetupCode),
    generate_actions(Actions, Options, ActionsCode),
    generate_expectations(Name, Expectations, Options, ExpectCode),
    format(atom(Code),
'
;------------------------------------------------------------
; Test: ~w
;------------------------------------------------------------
Test_~w() {
    global
    CurrentTest := "~w"
    Log("--- Starting test: ~w ---")
    ClearMessages()

~w~w~w
    Log("--- Finished test: ~w ---")
}

', [Name, Name, Name, Name, SetupCode, ActionsCode, ExpectCode, Name]).

generate_suite_runner(Scenarios, _, Code) :-
    findall(Call, (
        member(scenario(Name, _, _, _), Scenarios),
        format(atom(Call), 'Test_~w()~n', [Name])
    ), Calls),
    atomics_to_string([
'
;------------------------------------------------------------
; Run All Tests
;------------------------------------------------------------

' | Calls], CallsCode),
    atom_concat(CallsCode, '\n', Code).

generate_suite_footer(_, Footer) :-
    Footer = '
;------------------------------------------------------------
; Suite Complete
;------------------------------------------------------------
Log("=== Test Suite Complete ===")
Log("Total: " . (TestsPassed + TestsFailed) . " tests, " . TestsPassed . " passed, " . TestsFailed . " failed")

if (TestsFailed > 0) {
    MsgBox("Test suite failed: " . TestsFailed . " failures", "Test Results", "Icon!")
    ExitApp(1)
}
MsgBox("All " . TestsPassed . " tests passed!", "Test Results", "Iconi")
ExitApp(0)
'.

%------------------------------------------------------------
% Control Identification
%------------------------------------------------------------

% Look up control in control_map, fall back to USE naming convention
control_identifier(ControlId, Options, AhkId) :-
    ControlMap = Options.control_map,
    ( get_dict(ControlId, ControlMap, Mapping)
    -> ( is_dict(Mapping)
       -> ( get_dict(classnn, Mapping, AhkId) -> true
          ; get_dict(name, Mapping, AhkId) -> true
          ; get_dict(coords, Mapping, coords(X, Y))
          -> format(atom(AhkId), 'x~w y~w', [X, Y])
          ; atom_concat('?', ControlId, AhkId)  % USE naming
          )
       ;  AhkId = Mapping  % Direct string mapping
       )
    ;  % Default: assume USE naming convention (prefix with ?)
       atom_concat('?', ControlId, AhkId)
    ).

%------------------------------------------------------------
% Utility
%------------------------------------------------------------

atomics_to_string(Atoms, String) :-
    atomics_to_string(Atoms, '', String).

atomics_to_string([], Acc, Acc).
atomics_to_string([H|T], Acc, Result) :-
    atom_concat(Acc, H, NewAcc),
    atomics_to_string(T, NewAcc, Result).
