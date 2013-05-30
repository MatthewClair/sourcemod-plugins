#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>

public Plugin:myinfo =
{
	name = "Smart AI Rock",
	author = "CanadaRox",
	description = "Prevents AI tanks from throwing underhand rocks since he can't aim them correctly",
	version = "1",
	url = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/smart_ai_rock"
};

public Action:L4D2_OnSelectTankAttack(client, &sequence)
{
	PrintToChatAll("seq: %d", sequence);
	if (IsFakeClient(client) && sequence == 50)
	{
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		PrintToChatAll("new seq: %d\n", sequence);
		return Plugin_Handled;
	}
	PrintToChatAll("no change");
	return Plugin_Continue;
}
