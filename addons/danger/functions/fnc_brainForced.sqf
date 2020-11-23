#include "script_component.hpp"
/*
 * Author: nkenny
 * Actions on forced movement
 *
 * Arguments:
 * 0: unit toggled <OBJECT>
 *
 * Return Value:
 * Bool
 *
 * Example:
 * [bob] call lambs_danger_fnc_brainForced;
 *
 * Public: No
*/
params ["_unit"];

// timeout
private _timeout = time + 2;

// unconscious or dead
if !(_unit call EFUNC(main,isAlive)) exitWith {
    -1
};

// fleeing
if (fleeing _unit) exitWith {
    [_unit] call FUNC(doFleeing);
    _timeout
};

// vehicles are simpler
if (!isNull objectParent _unit) exitWith {
    _timeout + 6
};

// suppression -- high go prone
if (getSuppression _unit > 0.9) exitWith {
    _unit setUnitPosWeak "DOWN";
    _timeout
};

// mid -- go crouched
if (getSuppression _unit > 0) then {
    _unit setUnitPosWeak "MIDDLE";
};

// attack speed
if ((currentCommand _unit) isEqualTo "ATTACK") then {

    // attacking
    _unit setVariable [QGVAR(currentTask), "Attacking", EGVAR(main,debug_functions)];

    // tactical movement speed
    [_unit, _unit findNearestEnemy _unit] call FUNC(assaultSpeed);
};

// end
_timeout
