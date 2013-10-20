#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>
#include <sdktools>
#include "damage_tracking"

#define TEAM_SURVIVOR   2
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

public Plugin:myinfo =
{
	name = "Damage Scoring",
	author = "CanadaRox",
	description = "Custom scoring system based on damage survivors take while standing.",
	version = "1",
	url = "https://github.com/CanadaRox/sourcemod-plugins"
};

new Handle:vs_survival_bonus;
new Handle:vs_tiebreak_bonus;
new Handle:survivor_limit;

new Handle:sm_static_bonus;
new Handle:sm_max_damage;
new Handle:sm_max_damage_mapmulti;
new Handle:sm_damage_multi;

new bool:bHasWiped[2];
new bool:bRoundOver[2];
new iStoreBonus[2];
new iStoreSurvivors[2];

new vs_survival_bonusDefault;
new vs_tiebreak_bonusDefault;

public OnPluginStart()
{
	vs_survival_bonus = FindConVar("vs_survival_bonus");
	vs_survival_bonusDefault = GetConVarInt(vs_survival_bonus);
	vs_tiebreak_bonus = FindConVar("vs_tiebreak_bonus");
	vs_tiebreak_bonusDefault = GetConVarInt(vs_tiebreak_bonus);

	sm_static_bonus = CreateConVar("sm_static_bonus", "25.0",
			"Extra static bonus that is awarded per survivor for completing the map",
			FCVAR_PLUGIN, true, 0.0);
	sm_max_damage = CreateConVar("sm_max_damage", "800.0",
			"Max damage used for calculation (controls x in [x - damage])",
			FCVAR_PLUGIN, true, 0.0);
	sm_max_damage_mapmulti = CreateConVar("sm_max_damage_mapmulti", "-1",
			"Max damage is sm_max_damage if negative, else (this * map distance) is max damage",
			FCVAR_PLUGIN);
	sm_damage_multi = CreateConVar("sm_damage_multi", "1.0",
			"Multiplier to apply to damage before subtracting it from the max damage",
			FCVAR_PLUGIN, true, 0.0);

	HookEvent("door_close", DoorClose_Event);
	HookEvent("player_death", PlayerDeath_Event);
	HookEvent("finale_vehicle_leaving", FinaleVehicleLeaving_Event, EventHookMode_PostNoCopy);

	HookEvent("round_End", RoundEnd_Event);

	RegConsoleCmd("sm_damage", Damage_Cmd, "Prints the damage taken by both teams");
	RegConsoleCmd("sm_health", Damage_Cmd, "Prints the damage taken by both teams (Legacy option since I'll get yelled at without it!)");
}

public OnPluginEnd()
{
	SetConVarInt(vs_survival_bonus, vs_survival_bonusDefault);
	SetConVarInt(vs_tiebreak_bonus, vs_tiebreak_bonusDefault);
}

public OnMapStart()
{
	for (new i = 0; i < 2; i++)
	{
		iStoreBonus[i] = 0;
		iStoreSurvivors[i] = 0;
		bRoundOver[i] = false;
		bHasWiped[i] = false;
	}
}

public Action:Damage_Cmd(client, args)
{
	DisplayBonus(client);
	return Plugin_Handled;
}

public DoorClose_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetEventBool(event, "checkpoint"))
	{
		SetConVarInt(vs_survival_bonus, CalculateSurvivalBonus(GetRoundNum()));
		StoreBonus();
	}
}

public PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client && IsSurvivor(client))
	{
		SetConVarInt(vs_survival_bonus, CalculateSurvivalBonus(GetRoundNum()));
		StoreBonus();
	}
}

public FinaleVehicleLeaving_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetConVarInt(vs_survival_bonus, CalculateSurvivalBonus(GetRoundNum()));
	StoreBonus();
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	// set whether the round was a wipe or not
	if (!GetUprightSurvivors()) {
		bHasWiped[GameRules_GetProp("m_bInSecondHalfOfRound")] = true;
	}

	// when round is over, 
	bRoundOver[GameRules_GetProp("m_bInSecondHalfOfRound")] = true;

	new reason = GetEventInt(event, "reason");
	if (reason == 5)
	{
		DisplayBonus();
	}
}

stock CalculateSurvivalBonus(round)
{
	new Float:sm_max_damage_mapmultiVal = GetConVarFloat(sm_max_damage_mapmulti);
	new Float:maxDamage =  sm_max_damage_mapmultiVal < 0 ?
		GetConVarFloat(sm_max_damage) :
		sm_max_damage_mapmultiVal * L4D_GetVersusMaxCompletionScore();

	return RoundToFloor(
			MAX(maxDamage - GetDamage(round) * GetConVarFloat(sm_damage_multi), 0.0)/4
			+ GetConVarFloat(sm_static_bonus));
}

stock bool:IsSurvivor(client)
{
	return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

stock bool:IsClientAndInGame(index)
{
	return (index > 0 && index <= MaxClients && IsClientInGame(index));
}

stock GetDamage(round)
{
	if (round < 0 || round > 1)
		return -1;

	return DamageTracking_GetRoundDamage(round);
}

stock GetRoundNum()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

stock GetUprightSurvivors()
{
	new iAliveCount;
	new iSurvivorCount;
	new maxSurvs = (survivor_limit != INVALID_HANDLE) ? GetConVarInt(survivor_limit) : 4;
	for (new i = 1; i <= MaxClients && iSurvivorCount < maxSurvs; i++)
	{
		if (IsSurvivor(i))
		{
			iSurvivorCount++;
			if (IsPlayerAlive(i) && !IsPlayerIncap(i) && !IsPlayerLedgedAtAll(i))
			{
				iAliveCount++;
			}
		}
	}
	return iAliveCount;
}

stock bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}
stock bool:IsPlayerHanging(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}
stock bool:IsPlayerLedgedAtAll(client)
{
	return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

stock DisplayBonus(client=-1)
{
	decl String:msgPartHdr[48];
	decl String:msgPartDmg[48];

	for (new round = 0; round <= GameRules_GetProp("m_bInSecondHalfOfRound"); round++)
	{
		if (bRoundOver[round])
		{
			FormatEx(msgPartHdr, sizeof(msgPartHdr), "Round \x05%i\x01 Bonus", round+1);
		}
		else
		{
			FormatEx(msgPartHdr, sizeof(msgPartHdr), "Current Bonus");
		}

		if (bHasWiped[round])
		{
			FormatEx(msgPartDmg, sizeof(msgPartDmg), "\x03wipe\x01 (\x05%d\x01 damage)",
					DamageTracking_GetRoundDamage(round));
		}
		else
		{
			FormatEx(msgPartDmg, sizeof(msgPartDmg), "\x04%d\x01 (\x05%d\x01 damage)",
					(bRoundOver[round]) ? iStoreBonus[round] : CalculateSurvivalBonus(round) * GetAliveSurvivors(),
					DamageTracking_GetRoundDamage(round));
		}
	}

	if (client == -1)
	{
		PrintToChatAll("Map Distance: \x05%d\x01", L4D_GetVersusMaxCompletionScore());
		PrintToChatAll("\x01%s: %s", msgPartHdr, msgPartDmg);
	}
	else if (client)
	{
		PrintToChat(client, "Map Distance: \x05%d\x01", L4D_GetVersusMaxCompletionScore());
		PrintToChat(client, "\x01%s: %s", msgPartHdr, msgPartDmg);
	}
	else
	{
		PrintToServer("Map Distance: \x05%d\x01", L4D_GetVersusMaxCompletionScore());
		PrintToServer("\x01%s: %s", msgPartHdr, msgPartDmg);
	}
}

stock GetAliveSurvivors()
{
	new iAliveCount;
	new iSurvivorCount;
	new maxSurvs = (survivor_limit != INVALID_HANDLE) ? GetConVarInt(survivor_limit) : 4;
	for (new i = 1; i <= MaxClients && iSurvivorCount < maxSurvs; i++)
	{
		if (IsSurvivor(i))
		{
			iSurvivorCount++;
			if (IsPlayerAlive(i)) iAliveCount++;
		}
	}
	return iAliveCount;
}

stock StoreBonus()
{
	// store bonus for display
	new round = GameRules_GetProp("m_bInSecondHalfOfRound");
	new aliveSurvs = GetAliveSurvivors();

	iStoreBonus[round] = GetConVarInt(vs_survival_bonus) * aliveSurvs;
	iStoreSurvivors[round] = GetAliveSurvivors();
}
