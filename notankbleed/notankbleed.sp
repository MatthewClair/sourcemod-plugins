#pragma semicolon 1

#include <sourcemod>
#include <l4d2util>

public Plugin:myinfo =
{
	name = "No Tank Bleed",
	author = "CanadaRox",
	description = "Stop temp health from decaying during a tank fight",
	version = "1",
	url = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/notankbleed"
};

new Float:defaultRate;
new Handle:pain_pills_decay_rate;

public OnPluginStart()
{
	pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
	defaultRate = GetConVarFloat(pain_pills_decay_rate);
}

public OnTankSpawn(iTank)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			SetSurvivorTempHealth(client, GetSurvivorTempHealth(client));
		}
	}
	SetConVarFloat(pain_pills_decay_rate, 0.0);
}

public OnTankDeath(iOldTank)
{
	if (NumTanksInPlay() <= 1) /* This is 1 when the last tank dies */
	{
		for (new client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
			{
				SetSurvivorTempHealth(client, GetSurvivorTempHealth(client));
			}
		}
	}
	SetConVarFloat(pain_pills_decay_rate, defaultRate);
}


stock GetSurvivorTempHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return temphp > 0 ? temphp : 0;
}

stock SetSurvivorTempHealth(client, hp)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	new Float:newOverheal = hp * 1.0;
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}
