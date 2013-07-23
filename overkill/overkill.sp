#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CLASSNAME_LENGTH 64

public Plugin:myinfo =
{
	name = "Infected Overkill",
	author = "CanadaRox",
	description = "Enables overkill damage to apply to incapped survivors",
	version = "1",
	url = ""
};

new bool:isLateLoad;
new Float:health[MAXPLAYERS+1] = { -1.0, ...};
new Handle:pain_pills_decay_rate;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	isLateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	if (isLateLoad)
	{
		for (new client = 1; client < MaxClients + 1; client++)
		{
			if (IsClientInGame(client))
			{
				OnClientConnected(client);
			}
		}
	}

	pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
}

public OnClientConnected(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public OnTakeDamage(victim, attacker, inflictor, Float:damage, damagetype)
{
	if (victim > 0 && victim <= MaxClients && GetClientTeam(victim) == 2 &&
			attacker > 0 && attacker <= MaxClients && !IsPlayerIncap(victim))
	{
		health[victim] = GetSurvivorHealth(victim);
	}
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
	if (GetClientTeam(victim) == 2 && IsPlayerIncap(victim) && health[victim] > 0)
	{
		decl String:sClassname[CLASSNAME_LENGTH];
		GetEntityClassname(inflictor, sClassname, CLASSNAME_LENGTH);
		if (!StrEqual(sClassname, "prop_physics") && !StrEqual(sClassname, "witch"))
		{
			new Float:overkillDamage = damage - health[victim];
			SDKHooks_TakeDamage(victim, attacker, attacker, overkillDamage);
		}
		health[victim] = -1.0;
	}
}

stock Float:GetSurvivorHealth(client) return GetPermHealth(client) + GetTempHealth(client);
stock GetPermHealth(client) return GetEntProp(client, Prop_Send, "m_iHealth");
stock bool:IsPlayerIncap(client) return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
stock Float:GetTempHealth(client) return GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(pain_pills_decay_rate));
