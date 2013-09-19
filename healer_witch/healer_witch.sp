#pragma semicolon 1

#include <sourcemod>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))

public Plugin:myinfo =
{
	name = "Healer Witch",
	author = "CanadaRox",
	description = "Heals the survivor when they kill a witch",
	version = "1",
	url = ""
};

new Handle:hw_max_health;
new Handle:hw_cap_health;
new Handle:hw_perm_gain;
new Handle:hw_temp_gain;
new Handle:pain_pills_decay_rate;

public OnPluginStart()
{
	pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
	HookEvent("witch_killed", WitchKilled_Event);

	hw_max_health = CreateConVar("hw_max_health", "100", "Max health that a survivor can have after gaining health", FCVAR_PLUGIN, true, 100.0);
	hw_cap_health = CreateConVar("hw_cap_health", "1", "Whether to cap the health survivors can gain from this plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	hw_perm_gain = CreateConVar("hw_perm_gain", "5", "Amount of perm health to gain for killing a witch", FCVAR_PLUGIN, true, 0.0);
	hw_temp_gain = CreateConVar("hw_temp_gain", "10", "Amount of temp health to gain for killing a witch", FCVAR_PLUGIN, true, 0.0);
}

public WitchKilled_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsPlayerIncap(client))
	{
		IncreaseHealth(client);
	}
}

IncreaseHealth(client)
{
	new bool:capped = GetConVarBool(hw_cap_health);
	new targetHealth = GetSurvivorPermHealth(client) + GetConVarInt(hw_perm_gain);
	new Float:targetTemp = GetSurvivorTempHealth(client) + GetConVarInt(hw_temp_gain);

	if (capped)
	{
		new maxHealth = GetConVarInt(hw_max_health);
		targetHealth = MIN(targetHealth, maxHealth);

		new Float:totalHealth = targetHealth + targetTemp;
		totalHealth = MIN(totalHealth, float(maxHealth));
		targetTemp = totalHealth - targetHealth;
	}

	SetSurvivorPermHealth(client, targetHealth);
	SetSurvivorTempHealth(client, targetTemp);
}

stock GetSurvivorPermHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock SetSurvivorPermHealth(client, health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}

stock Float:GetSurvivorTempHealth(client)
{
	new Float:tmp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(pain_pills_decay_rate));
	return tmp > 0 ? tmp : 0.0;
}

stock SetSurvivorTempHealth(client, Float:newOverheal)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

stock bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}
