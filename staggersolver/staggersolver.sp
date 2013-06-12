#pragma semicolon 1

#include <sourcemod>

public Plugin:myinfo =
{
	name = "Super Stagger Solver",
	author = "CanadaRox",
	description = "Blocks all button presses during stumbles",
	version = "(^.^)",
};

public Action:OnPlayerRunCmd(client, &buttons)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetEntPropFloat(client, Prop_Send, "m_staggerDist") > 0.0)
	{
		if (GetEdictFlags(client) & FL_ONGROUND)
		{
			buttons = 0;
		}
		else
		{
			SetEntPropFloat(client, Prop_Send, "m_staggerDist", 0.0);
		}
	}
	return Plugin_Continue;
}

