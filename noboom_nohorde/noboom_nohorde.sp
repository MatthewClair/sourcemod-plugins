#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>

public Plugin:myinfo =
{
	name = "NoBoom, NoHorde",
	author = "CanadaRox",
	description = "A plugin designed to reset the horde timer if a boomer dies without successfully landing a boom.",
	version = "1",
	url = "http://github.com/CanadaRox/sourcemod-plugins/"
};

new bool:hasBoomerSpawned = false;
new bool:hasBoomerBoomed = false;

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn_Event);
	HookEvent("player_now_it", PlayerNowIt_Event);
	HookEvent("player_death", PlayerDeath_Event);

	HookEvent("round_start", Reset_Event);
	HookEvent("round_end", Reset_Event);
}

public Reset_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	hasBoomerSpawned = false;
	hasBoomerBoomed = false;
}

public PlayerSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client && IsClientInGame(client) && !IsFakeClient(client) &&
			GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 2)
	{
		hasBoomerSpawned = true;
	}
}

public PlayerNowIt_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new bool:by_boomer = GetEventBool(event, "by_boomer");

	if (by_boomer && hasBoomerSpawned)
	{
		hasBoomerBoomed = true;
	}
}

public PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client && IsClientInGame(client) &&
			GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 2 &&
			hasBoomerSpawned && !hasBoomerBoomed)
	{
		L4D2_CTimerReset(L4D2CT_MobSpawnTimer);
	}
	hasBoomerSpawned = false;
	hasBoomerBoomed = false;
}
