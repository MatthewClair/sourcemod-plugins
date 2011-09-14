#include <sourcemod.inc>
#include <sdkhooks>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

public Plugin:myinfo =
{
	name = "Damage Scoring",
	author = "CanadaRox",
	description = "Custom damage scoring based on damage and a static bonus.  (It sounds as bad as vanilla but its not!!)",
	version = "0.9",
	url = "nope"
};

new Handle: hSurvivalBonusCvar;
new         iSurvivalBonusDefault;
new         iSurvivalBonus;

new Handle: hTieBreakBonusCvar;
new         iTieBreakBonusDefault;

new Handle: hPluginEnabled;
new bool:   bPluginEnabled;

new         iHealth[MAXPLAYERS + 1];
new         iTotalDamage[2];

new         iRoundNumber;
new bool:   bInRound;

public OnPluginStart()
{
	// Score Change Triggers
	HookEvent("door_close", DoorClose_Event);
	HookEvent("player_death", PlayerDeath_Event);

	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);

	// Save default Cvar value
	hSurvivalBonusCvar = FindConVar("vs_survival_bonus");
	iSurvivalBonusDefault = GetConVarInt(hSurvivalBonusCvar);

	hTieBreakBonusCvar = FindConVar("vs_tiebreak_bonus");
	iSurvivalBonusDefault = GetConVarInt(hTieBreakBonusCvar);

	// Enable Cvar
	hPluginEnabled = CreateConVar("sm_dmgscore_enabled", "1", "Enable custom scoring based on distance, damage and survival bonus", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	bPluginEnabled = GetConVarBool(hPluginEnabled);
	//HookConVarChange(hPluginEnabled, CvarEnabled_Change);
}

public OnPluginEnd()
{
	SetConVarInt(hSurvivalBonusCvar, iSurvivalBonusDefault);
}

public OnMapStart()
{
	iTotalDamage[0] = 0;
	iTotalDamage[1] = 0;
}

public OnMapEnd()
{
	iRoundNumber = 0;
	bInRound = false;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!bInRound)
	{
		bInRound = true;
		iRoundNumber++;
	}
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bInRound)
	{
		bInRound = false;
		PrintToChatAll("Fist round score should be here!");
	}
	if (iRoundNumber == 2)
	{
		PrintToChatAll("Scores will go here!!");
	}
}

public DoorClose_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetEventBool(event, "checkpoint"))
		SetConVarInt(hSurvivalBonusCvar, CalculateSurvivalBonus());
}

public PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client && IsSurvivor(client))
		SetConVarInt(hSurvivalBonusCvar, CalculateSurvivalBonus());
}

public OnTakeDamage(victim, attacker, inflictor, Float:damage, damagetype)
{
        iHealth[victim] = (GetClientTeam(victim) != 2 || IsPlayerIncap(victim)) ? 0 : (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
        if (iHealth[victim])
        {
                if (!IsPlayerAlive(victim) || IsPlayerIncap(victim))
                {
                        iTotalDamage[iRoundNumber-1] += iHealth[victim];
                }
                else
                {
                        iTotalDamage[iRoundNumber-1] +=  iHealth[victim] - (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim))
                }
        }
}

stock GetDamage()
{
	return iTotalDamage[iRoundNumber-1];
}

stock IsPlayerIncap(client) return GetEntProp(client, Prop_Send, "m_isIncapacitated");

stock GetSurvivorTempHealth(client)
{
        new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_iHealthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
        return (temphp > 0 ? temphp : 0);
}

stock GetSurvivorPermanentHealth(client) return GetEntProp(client, Prop_Send, "m_iHealth");

stock CalculateSurvivalBonus()
{
	new iAliveSurvivors = GetAliveSurvivors();
	return RoundToFloor(( MAX(800.0 - GetDamage(), 0.0) ) / iAliveSurvivors + 25 * iAliveSurvivors);
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

