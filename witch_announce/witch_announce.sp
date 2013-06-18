#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

public Plugin:myinfo =
{
	name = "Witch Announce++",
	author = "CanadaRox",
	description = "Prints damage done to witches!",
	version = "1",
	url = ""
};

new Handle:witchTrie;
new bool:g_bLateLoad;

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax)
{
	g_bLateLoad = late;
}

public OnPluginStart()
{
	witchTrie = CreateTrie();

	HookEvent("witch_spawn", WitchSpawn_Event);
	HookEvent("witch_killed", WitchKilled_Event);

	if (g_bLateLoad)
	{
		for (new client = 1; client < MaxClients + 1; client++)
		{
			if (IsClientInGame(client))
			{
				SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}
}

public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public WitchSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new witch = GetEventInt(event, "witchid");
	SDKHook(witch, SDKHook_OnTakeDamagePost, OnTakeDamage_Post);
}

public WitchKilled_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new witch = GetEventInt(event, "witchid");
	SDKUnhook(witch, SDKHook_OnTakeDamagePost, OnTakeDamage_Post);
	PrintWitchDamageAndRemove(witch);
}

public OnEntityDestroyed(entity)
{
	SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamage_Post);
	decl String:witch_key[10];
	FormatEx(witch_key, sizeof(witch_key), "%x", entity);
	RemoveFromTrie(witchTrie, witch_key);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (victim > 0 && victim <= MaxClients && IsClientInGame(victim) && GetClientTeam(victim) == 2)
	{
		decl String:classname[64];
		GetEdictClassname(attacker, classname, sizeof(classname));
		if (StrEqual(classname, "witch"))
		{
			/* This assumes that a "fail" happens when a witch hits a non-incap */
			if (!IsPlayerIncap(victim))
			{
				PrintWitchDamageAndRemove(attacker);
			}
		}
	}
}

public OnTakeDamage_Post(victim, attacker, inflictor, Float:damage, damagetype)
{
	decl String:classname[64];
	GetEdictClassname(victim, classname, sizeof(classname));
	if (StrEqual(classname, "witch"))
	{
		decl String:witch_key[10];
		FormatEx(witch_key, sizeof(witch_key), "%x", victim);
		decl witch_dmg_array[MaxClients+1];
		if (!GetTrieArray(witchTrie, witch_key, witch_dmg_array, MaxClients+1))
		{
			for (new i = 0; i <= MaxClients; i++)
			{
				if (i == attacker)
				{
					witch_dmg_array[i] = RoundToFloor(damage);
				}
				else
				{
					witch_dmg_array[i] = 0;
				}
			}
			if (!SetTrieArray(witchTrie, witch_key, witch_dmg_array, MaxClients+1, false))
			{
				return;
			}
		}
		else
		{
			witch_dmg_array[attacker] += RoundToFloor(damage);
			SetTrieArray(witchTrie, witch_key, witch_dmg_array, MaxClients+1, true);
		}
	}
	return;
}

PrintWitchDamageAndRemove(witch)
{
	decl witch_dmg_array[MaxClients+1];

	decl String:witch_key[10];
	FormatEx(witch_key, sizeof(witch_key), "%x", witch);
	if (GetTrieArray(witchTrie, witch_key, witch_dmg_array, MaxClients+1))
	{
		for (new client = 1; client <= MaxClients; client++)
		{
			if (witch_dmg_array[client] > 0)
			{
				if(IsClientInGame(client))
				{
					PrintToChatAll("%N: %d", client, witch_dmg_array[client]);
				}
				else
				{
					PrintToChatAll("Unknown: %d", client, witch_dmg_array[client]);
				}
			}
		}
	}
	SDKUnhook(witch, SDKHook_OnTakeDamagePost, OnTakeDamage_Post);
	RemoveFromTrie(witchTrie, witch_key);
}

stock bool:IsPlayerIncap(client) return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
