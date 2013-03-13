#include <sourcemod.inc>
#include <sdkhooks>
#include <sdktools>
#include <left4downtown>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

public Plugin:myinfo =
{
	name = "Damage Scoring",
	author = "CanadaRox",
	description = "Custom damage scoring based on damage and a static bonus.  (It sounds as bad as vanilla but its not!!)",
	version = "0.999",
	url = "https://github.com/CanadaRox/sourcemod-plugins"
};

new Handle: hSurvivalBonusCvar;
new         iSurvivalBonusDefault;

new Handle: hTieBreakBonusCvar;
new         iTieBreakBonusDefault;

new Handle: hStaticBonusCvar;
new Handle: hMaxDamageCvar;
new Handle: hDamageMultiCvar;

new         iHealth[MAXPLAYERS + 1];
new         bTookDamage[MAXPLAYERS + 1];
new         iTotalDamage[2];
new         iFirstRoundBonus;
new         iFirstRoundSurvivors;

public OnPluginStart()
{
	// Score Change Triggers
	HookEvent("door_close", DoorClose_Event);
	HookEvent("player_death", PlayerDeath_Event);
	HookEvent("finale_vehicle_leaving", FinaleVehicleLeaving_Event, EventHookMode_PostNoCopy);
	HookEvent("player_ledge_grab", PlayerLedgeGrab_Event);

	HookEvent("round_end", RoundEnd_Event);

	// Save default Cvar value
	hSurvivalBonusCvar = FindConVar("vs_survival_bonus");
	iSurvivalBonusDefault = GetConVarInt(hSurvivalBonusCvar);

	hTieBreakBonusCvar = FindConVar("vs_tiebreak_bonus");
	iTieBreakBonusDefault = GetConVarInt(hTieBreakBonusCvar);

	// Configuration Cvars
	hStaticBonusCvar = CreateConVar("sm_static_bonus", "25.0", "Extra static bonus that is awarded per survivor for completing the map", FCVAR_PLUGIN, true, 0.0);
	hMaxDamageCvar = CreateConVar("sm_max_damage", "800.0", "Max damage used for calculation (controls x in [x - damage])", FCVAR_PLUGIN);
	hDamageMultiCvar = CreateConVar("sm_damage_multi", "1.0", "Multiplier to apply to damage before subtracting it from the max damage", FCVAR_PLUGIN, true, 0.0);

	// Chat cleaning
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	RegConsoleCmd("sm_damage", Damage_Cmd, "Prints the damage taken by both teams");
	RegConsoleCmd("sm_health", Damage_Cmd, "Prints the damage taken by both teams (Legacy option since I'll get yelled at without it!)");
}

public OnPluginEnd()
{
	SetConVarInt(hSurvivalBonusCvar, iSurvivalBonusDefault);
	SetConVarInt(hTieBreakBonusCvar, iTieBreakBonusDefault);
}

public OnMapStart()
{
	iTotalDamage[0] = 0;
	iTotalDamage[1] = 0;
	iFirstRoundBonus = 0;
	iFirstRoundSurvivors = 0;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public Action:Damage_Cmd(client, args)
{
	if (client)
	{
		PrintToChat(client, "Round 1 -> Damage: %d, Bonus: %d", iTotalDamage[0], iFirstRoundBonus);
		PrintToChat(client, "Round 1 -> Damage: %d, Bonus: %d", iTotalDamage[1], CalculateSurvivalBonus());
	}
	else
	{
		PrintToServer("Round 1 -> Damage: %d, Bonus: %d", iTotalDamage[0], iFirstRoundBonus);
		PrintToServer("Round 1 -> Damage: %d, Bonus: %d", iTotalDamage[1], CalculateSurvivalBonus());
	}

	return Plugin_Handled;
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new reason = GetEventInt(event, "reason");
	if (reason == 5)
	{
		PrintToChatAll("\x04Round 1 Bonus: \x01 %d", iFirstRoundBonus);

		if (GameRules_GetProp("m_bInSecondHalfOfRound"))
		{
			PrintToChatAll("\x04Round 2 Bonus: %d", GetConVarInt(hSurvivalBonusCvar));
		}
	}
}

public DoorClose_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetEventBool(event, "checkpoint"))
	{
		SetConVarInt(hSurvivalBonusCvar, CalculateSurvivalBonus());

		iFirstRoundSurvivors = GetAliveSurvivors();
		iFirstRoundBonus = GetConVarInt(hSurvivalBonusCvar) * iFirstRoundSurvivors;
	}
}

public PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client && IsSurvivor(client))
	{
		SetConVarInt(hSurvivalBonusCvar, CalculateSurvivalBonus());

		iFirstRoundBonus = GetConVarInt(hSurvivalBonusCvar);
		iFirstRoundSurvivors = GetAliveSurvivors();
	}
}

public FinaleVehicleLeaving_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && IsSurvivor(i) && IsPlayerIncap(i))
		{
			ForcePlayerSuicide(i);
		}
	}

	SetConVarInt(hSurvivalBonusCvar, CalculateSurvivalBonus());

	iFirstRoundBonus = GetConVarInt(hSurvivalBonusCvar);
	iFirstRoundSurvivors = GetAliveSurvivors();
}

public OnTakeDamage(victim, attacker, inflictor, Float:damage, damagetype)
{
	iHealth[victim] = (!IsSurvivor(victim) || IsPlayerIncap(victim)) ? 0 : (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
	bTookDamage[victim] = true;
}

public PlayerLedgeGrab_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new health = GetEntData(client, 14804, 4);
	new temphealth = GetEntData(client, 14808, 4);

	iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += health + temphealth;
}

public Action:L4D2_OnRevived(client)
{
	new health = GetSurvivorPermanentHealth(client);
	new temphealth = GetSurvivorTempHealth(client);

	iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] -= (health + temphealth);
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
	if (iHealth[victim])
	{
		if (!IsPlayerAlive(victim) || (IsPlayerIncap(victim) && !IsPlayerHanging(victim)))
		{
			iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += iHealth[victim];
		}
		else if (!IsPlayerHanging(victim))
		{
			iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += iHealth[victim] - (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
		}
		iHealth[victim] = (!IsSurvivor(victim) || IsPlayerIncap(victim)) ? 0 : (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
	}
}

public Action:Command_Say(client, const String:command[], args)
{
	if (IsChatTrigger())
	{
		decl String:sMessage[MAX_NAME_LENGTH];
		GetCmdArg(1, sMessage, sizeof(sMessage));

		if (StrEqual(sMessage, "!damage")) return Plugin_Handled;
		else if (StrEqual (sMessage, "!sm_damage")) return Plugin_Handled;
		else if (StrEqual (sMessage, "!health")) return Plugin_Handled;
		else if (StrEqual (sMessage, "!sm_health")) return Plugin_Handled;
	}

	return Plugin_Continue;
}

stock GetDamage(round=-1)
{
	return (round == -1) ? iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] : iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")];
}

stock bool:IsPlayerIncap(client) return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
stock bool:IsPlayerHanging(client) return bool:GetEntProp(client, Prop_Send, "m_isHangingFromLedge");

stock GetSurvivorTempHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}

stock GetSurvivorPermanentHealth(client) return GetEntProp(client, Prop_Send, "m_iHealth");

stock CalculateSurvivalBonus()
{
	return RoundToFloor(( MAX(GetConVarFloat(hMaxDamageCvar) - GetDamage() * GetConVarFloat(hDamageMultiCvar), 0.0) ) / 4 + GetConVarFloat(hStaticBonusCvar));
}

stock GetAliveSurvivors()
{
	new iAliveCount;
	new iSurvivorCount;
	for (new i = 1; i < MaxClients && iSurvivorCount < 4; i++)
	{
		if (IsSurvivor(i))
		{
			iSurvivorCount++;
			if (IsPlayerAlive(i)) iAliveCount++;
		}
	}
	return iAliveCount;
}

stock bool:IsSurvivor(client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2;
}
