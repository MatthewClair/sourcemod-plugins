#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <left4downtown>
#include <l4d2_direct>

#define TEAM_SURVIVOR   2

public Plugin:myinfo =
{
	name = "Damage Tracking",
	author = "CanadaRox",
	description = "Tracks per survivor damage taken",
	version = "1",
	url = ""
};

new characterDamageArray[2][4];
new characterIncapCountArray[2][4];
new characterIncapDamageArray[2][4];
new iHealth[MAXPLAYERS + 1];
new iIncapHealth[MAXPLAYERS + 1];

// Game Cvars
new Handle:pain_pills_decay_rate;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("DamageTracking_GetCharacterDamage", Native_GetCharDamage);
	CreateNative("DamageTracking_GetRoundDamage", Native_GetRoundDamage);
	CreateNative("DamageTracking_GetCharacterIncapCount", Native_GetCharacterIncapCount);
	CreateNative("DamageTracking_GetRoundIncapCount", Native_GetRoundIncapCount);
	CreateNative("DamageTracking_GetCharacterIncapDamage", Native_GetCharacterIncapDamage);
	CreateNative("DamageTracking_GetRoundIncapDamage", Native_GetRoundIncapDamage);
	RegPluginLibrary("damage_tracking");

	return APLRes_Success;
}

public Native_GetCharDamage(Handle:plugin, numParams)
{
	new round = GetNativeCell(1);
	new character = GetNativeCell(2);
	if (round < 0 || round > 1 || character < 0 || character > 3)
	{
		return -1;
	}

	return characterDamageArray[round][character];
}

public Native_GetRoundDamage(Handle:plugin, numParams)
{
	new round = GetNativeCell(1);
	if (round < 0 || round > 1)
	{
		return -1;
	}

	new totalDamage = 0;
	for (new character = 0; character < 4; character++)
	{
		totalDamage += characterDamageArray[round][character];
	}
	return totalDamage;
}

public Native_GetCharacterIncapCount(Handle:plugin, numParams)
{
	new round = GetNativeCell(1);
	new character = GetNativeCell(2);
	if (round < 0 || round > 1 || character < 0 || character > 3)
	{
		return -1;
	}

	return characterIncapCountArray[round][character];
}

public Native_GetRoundIncapCount(Handle:plugin, numParams)
{
	new round = GetNativeCell(1);
	if (round < 0 || round > 1)
	{
		return -1;
	}

	new totalIncaps = 0;
	for (new character = 0; character < 4; character++)
	{
		totalIncaps += characterIncapCountArray[round][character];
	}
	return totalIncaps;
}

public Native_GetCharacterIncapDamage(Handle:plugin, numParams)
{
	new round = GetNativeCell(1);
	new character = GetNativeCell(2);
	if (round < 0 || round > 1 || character < 0 || character > 3)
	{
		return -1;
	}

	return characterIncapDamageArray[round][character];
}

public Native_GetRoundIncapDamage(Handle:plugin, numParams)
{
	new round = GetNativeCell(1);
	if (round < 0 || round > 1)
	{
		return -1;
	}

	new totalIncapDamage = 0;
	for (new character = 0; character < 4; character++)
	{
		totalIncapDamage += characterIncapDamageArray[round][character];
	}
	return totalIncapDamage;
}

public OnPluginStart()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
	pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");

	HookEvent("player_ledge_grab", PlayerLedgeGrab_Event);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_dt_debug", Debug_Cmd);
	RegConsoleCmd("sm_get_health", GetHealth_Cmd);
}

public Action:GetHealth_Cmd(client, args)
{
	PrintToChat(client, "perm: %d, temp: %d", GetSurvivorPermanentHealth(client), GetSurvivorTempHealth(client));
	return Plugin_Handled;
}

public Action:Debug_Cmd(client, args)
{
	for (new i = 0; i < 4; i++)
	{
		PrintToChat(client, "Damage: %d",
				characterDamageArray[GetRoundNum()][i]);
		PrintToChat(client, "Incap damage: %d",
				characterIncapDamageArray[GetRoundNum()][i]);
		PrintToChat(client, "Incap count: %d",
				characterIncapCountArray[GetRoundNum()][i]);
		if (i != 4)
			PrintToChat(client, "========");
	}
	return Plugin_Handled;
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

public OnMapStart()
{
	for (new i = 0; i < 1; i++)
	{
		for (new j = 0; j < 4; j++)
		{
			characterDamageArray[i][j] = 0;
			characterIncapCountArray[i][j] = 0;
			characterIncapDamageArray[i][j] = 0;
		}
	}
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 0; i < 1; i++)
	{
		for (new j = 0; j < 4; j++)
		{
			characterDamageArray[i][j] = 0;
			characterIncapCountArray[i][j] = 0;
			characterIncapDamageArray[i][j] = 0;
		}
	}
}

public OnTakeDamage(victim, attacker, inflictor, Float:damage, damagetype)
{
	iHealth[victim] = (IsSurvivor(victim) && !IsPlayerIncap(victim)) ?
		GetSurvivorHealth(victim) : 0;
	iIncapHealth[victim] =
		(IsSurvivor(victim) && IsPlayerIncap(victim) && !IsPlayerHanging(victim)) ?
		GetSurvivorPermanentHealth(victim) : 0;
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
	if (iHealth[victim])
	{
		/* If the survivor got incapped or killed but not hung */
		if (!IsPlayerAlive(victim))
		{
			characterDamageArray[GetRoundNum()][GetCharacterId(victim)] += iHealth[victim];
		}
		else if((IsPlayerIncap(victim) && !IsPlayerHanging(victim)))
		{
			characterDamageArray[GetRoundNum()][GetCharacterId(victim)] += iHealth[victim];
			characterIncapCountArray[GetRoundNum()][GetCharacterId(victim)]++;
		}
		/* If the survivor didn't get hung */
		else if (!IsPlayerHanging(victim))
		{
			characterDamageArray[GetRoundNum()][GetCharacterId(victim)]
				+= iHealth[victim] - GetSurvivorHealth(victim);
		}
		iHealth[victim] = (IsSurvivor(victim) && !IsPlayerIncap(victim)) ?
			GetSurvivorHealth(victim) : 0;
	}
	else if (iIncapHealth[victim])
	{
		if (!IsPlayerAlive(victim))
		{
			characterIncapDamageArray[GetRoundNum()][GetCharacterId(victim)]
				+= iIncapHealth[victim];
		}
		else
		{
			characterIncapDamageArray[GetRoundNum()][GetCharacterId(victim)]
				+= iIncapHealth[victim] - GetSurvivorPermanentHealth(victim);
		}
		iIncapHealth[victim] =
			(IsSurvivor(victim) && IsPlayerIncap(victim) && !IsPlayerHanging(victim)) ?
			GetSurvivorPermanentHealth(victim) : 0;
	}
}

public PlayerLedgeGrab_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new health = L4D2Direct_GetPreIncapHealth(client);
	new temphealth = L4D2Direct_GetPreIncapHealthBuffer(client);

	characterDamageArray[GetRoundNum()][GetCharacterId(client)] += health + temphealth;
}

public Action:L4D2_OnRevived(client)
{
	new health = GetSurvivorPermanentHealth(client);
	new temphealth = GetSurvivorTempHealth(client);

	characterDamageArray[GetRoundNum()][GetCharacterId(client)] -= (health + temphealth);
}

stock GetCharacterId(client)
{
	return GetEntProp(client, Prop_Send, "m_survivorCharacter");
}

stock GetRoundNum()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

stock bool:IsSurvivor(client)
{
	return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

stock GetSurvivorHealth(client)
{
	return GetSurvivorPermanentHealth(client) + GetSurvivorTempHealth(client);
}

stock GetSurvivorPermanentHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock GetSurvivorTempHealth(client)
{
	new temphp = RoundToFloor(GetEntPropFloat(client, Prop_Send, "m_healthBuffer")
			- (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime"))
			* GetConVarFloat(pain_pills_decay_rate));
	return temphp > 0 ? temphp : 0;
}

stock bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

stock bool:IsPlayerHanging(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

stock bool:IsClientAndInGame(index)
{
	return index > 0 && index <= MaxClients && IsClientInGame(index);
}
