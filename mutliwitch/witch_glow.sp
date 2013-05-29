#pragma semicolon 1

#include <sourcemod>

new Handle:wg_min_range;
new Float:minRangeSquared;

public Plugin:myinfo =
{
	name = "Witch Glows",
	author = "CanadaRox",
	description = "Sets glows on witches when survivors are far away",
	version = "1.1",
	url = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/mutliwitch"
};

public OnPluginStart()
{
	HookEvent("witch_spawn", WitchSpawn_Event);
	HookEvent("witch_harasser_set", WitchHarasserSet_Event);

	wg_min_range = CreateConVar("wg_min_range", "500", "Glows will not show if a survivor is this close to the witch", FCVAR_NONE, true, 0.0);
	HookConVarChange(wg_min_range, MinRangeChange);
	new Float:tmp = GetConVarFloat(wg_min_range);
	minRangeSquared = tmp * tmp;
}

public MinRangeChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new Float:v = StringToFloat(newValue);
	minRangeSquared = v*v;
}

public OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		new psychonic = GetEntityCount();
		decl Float:clientOrigin[3];
		GetClientAbsOrigin(client, clientOrigin);
		decl Float:witchOrigin[3];
		decl String:buffer[32];
		for (new entity = MaxClients + 1; entity < psychonic; entity++)
		{
			if (IsValidEntity(entity)
					&& GetEntityClassname(entity, buffer, sizeof(buffer))
					&& StrEqual(buffer, "witch"))
			{
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", witchOrigin);
				if (GetVectorDistance(clientOrigin, witchOrigin, true) < minRangeSquared)
				{
					SetEntProp(entity, Prop_Send, "m_iGlowType", 0);
				}
			}
		}
	}
}

public WitchSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new witch = GetEventInt(event, "witchid");
	SetEntProp(witch, Prop_Send, "m_iGlowType", 3);
	SetEntProp(witch, Prop_Send, "m_glowColorOverride", 0xFFFFFF);
}

public WitchHarasserSet_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new witch = GetEventInt(event, "witchid");
	SetEntProp(witch, Prop_Send, "m_iGlowType", 0);
}
