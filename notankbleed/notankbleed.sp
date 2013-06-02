#pragma semicolon 1

#include <sourcemod>
#include <l4d2util>

public Plugin:myinfo =
{
	name = "No Tank Bleed",
	author = "CanadaRox",
	description = "Stop temp health from decaying during a tank fight",
	version = "2",
	url = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/notankbleed"
};

new Float:defaultRate;
new Handle:pain_pills_decay_rate;

public OnPluginStart()
{
	pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
	defaultRate = GetConVarFloat(pain_pills_decay_rate);

#if defined DEBUG
	RegConsoleCmd("sm_temptest", TempTest_Cmd);
#endif

	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
}

public OnPluginEnd()
{
	SetConVarFloat(pain_pills_decay_rate, defaultRate);
}

#if defined DEGUB
public Action:TempTest_Cmd(client, args)
{
	new Float:currentTemp = GetSurvivorTempHealth(client);
	PrintToChat(client, "Current temp: %f", currentTemp);
	SetSurvivorTempHealth(client, currentTemp);
	PrintToChat(client, "New temp: %f", GetSurvivorTempHealth(client));
}
#endif

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetNewRate(defaultRate);
}

public OnTankSpawn(iTank)
{
	SetNewRate(0.0);
}

public OnTankDeath(iOldTank)
{
	if (NumTanksInPlay() <= 1) /* This is 1 when the last tank dies */
	{
		SetNewRate(defaultRate);
	}
}

stock SetNewRate(Float:rate = 0.0)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			SetSurvivorTempHealth(client, GetSurvivorTempHealth(client));
		}
	}
	SetConVarFloat(pain_pills_decay_rate, rate);
}


stock Float:GetSurvivorTempHealth(client)
{
	new Float:tmp =  GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")));
	return tmp > 0.0 ? tmp : 0.0;
}

stock SetSurvivorTempHealth(client, Float:newOverheal)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}
