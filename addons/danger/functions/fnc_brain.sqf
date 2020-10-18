#include "script_component.hpp"
/*
 * Author: nkenny
 * evaluates danger causes and returns most dangerous state and appropriate response
 *
 * Arguments:
 * 0: unit doing the avaluation <OBJECT>
 * 1: danger queue <ARRAY>
  *
 * Return Value:
 * array
 *
 * Example:
 * [bob, []] call lambs_danger_fnc_dangerBrain;
 *
 * Public: No
*/

/*
    DESIGN
        Immediate actions
        2 Hit
        9 BulletClose

        Hide actions
        0 Enemy detected (but far)
        4 Explosion
        7 Scream

        Engage actions
        0 Enemy detected (but near or known)
        1 Fire
        3 Enemy near
        8 CanFire

        Assess actions
        5 DeadBodyGroup
        6 DeadBody
        10 Assess
*/
#define ACTION_IMMEDIATE 0
#define ACTION_HIDE 1
#define ACTION_ENGAGE 2
#define ACTION_ASSESS 3

params ["_unit", ["_queue", []]];

// init ~ immediate action, hide, engage, assess
private _return = [false, false, false, false];
private _group = group _unit;

// empty queue ~ exit with assess!
if (_queue isEqualTo []) exitWith {
    private _causeArray = [DANGER_ASSESS, getPosASL _unit, time + GVAR(dangerUntil), assignedTarget _unit];
    _unit setVariable [QEGVAR(main,FSMDangerCauseData), _causeArray, EGVAR(main,debug_functions)];    // debug variable
    [false, false, false, true, _causeArray]
};

// modify priorities ~ own function!
private _priorities = [_unit] call FUNC(brainAdjust);

// pick the most relevant danger cause
private _priority = -1;
private _index = -1;
{
    private _cause = _x select 0;
    if ((_priorities select _cause) > _priority) then {
        _index = _forEachIndex;
        _priority = _priorities select _cause;
    };
} foreach _queue;

// select cause
private _causeArray = _queue select _index;
_causeArray params ["_dangerCause", "_dangerPos", "", "_dangerCausedBy"]; // "_dangerUntil" - skipped for future use -nkenny

// debug variable
_unit setVariable [QEGVAR(main,FSMDangerCauseData), _causeArray, EGVAR(main,debug_functions)];

// Immediate actions
if (_dangerCause in [DANGER_HIT, DANGER_BULLETCLOSE]) then {
    _return set [ACTION_IMMEDIATE, true];
};

// hide actions
private _panic = RND(GVAR(panicChance)) && {getSuppression _unit > 0.9};
if (_dangerCause in [DANGER_ENEMYDETECTED, DANGER_EXPLOSION, DANGER_SCREAM] || _panic) then {
    _return set [ACTION_HIDE, true];

    // callout
    if (_panic) then {
        [_unit, "Stealth", "panic", 55] call EFUNC(main,doCallout);
    };

    // enemy near? don't hide
    if (_dangerCause isEqualTo DANGER_ENEMYDETECTED && {(_unit distance2D _dangerCausedBy) < (GVAR(cqbRange) * 1.4)}) then {
        _return set [ACTION_HIDE, false];
    };
};

// engage actions   // should check all friendly sides?
if (_dangerCause in [DANGER_ENEMYDETECTED, DANGER_FIRE, DANGER_ENEMYNEAR, DANGER_CANFIRE]) then {
    _return set [ACTION_ENGAGE, !((side _group) isEqualTo side (group _dangerCausedBy))];
    _return set [ACTION_HIDE, _unit knowsAbout _dangerCausedBy < 0.1];    // hide if target unknown!
};

// assess actions
if (_dangerCause in [DANGER_DEADBODYGROUP, DANGER_DEADBODY]) then {
    _return set [ACTION_ASSESS, true];
};

// gesture + share information
if (RND(0.6) && { (_group getVariable [QGVAR(contact), 0]) < time }) then {
    [_unit, ["gestureFreeze", "gesturePoint"] select (_unit distance2D _dangerPos < 50)] call EFUNC(main,doGesture);
    [_unit, ["Combat", "Stealth"] select (behaviour _unit isEqualTo "STEALTH"), "contact", 100] call EFUNC(main,doCallout);
    [_unit, _dangerCausedBy, GVAR(radioShout), true] call FUNC(shareInformation);
};

// modify return
_return pushBack _causeArray;

// end
_return
