#include <sourcemod>
#include "../weapons.inc"
#include <sdktools>

new bool:hasDeagle[MAXPLAYERS];

public Plugin:myinfo =
{
	name = "L4D2 Dedeagle Incapper",
	author = "CanadaRox",
	description = "Dedeagles incapped players that have deagles and then redeagles them when they are unincapacitated",
	version = "cat",
	url = "https://github.com/CanadaRox/sourcemod-plugins"
};

public OnPluginStart()
{
	HookEvent("player_incapacitated", PlayerIncap_Event);
	HookEvent("revive_success", PlayerRescued_Event);
	HookEvent("player_death", PlayerDeath_Event);

	L4D2Weapons_Init();
}

public PlayerIncap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{

	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	new secondary = GetPlayerWeaponSlot(client, 1);

	new WeaponId:secondary_wepid = IdentifyWeapon(secondary);

	if (secondary_wepid == WEPID_PISTOL_MAGNUM)
	{
		hasDeagle[client] = true;
		AcceptEntityInput(secondary, "Kill");
		GivePlayerItem(client, "weapon_pistol");
	}
}

public PlayerRescued_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (hasDeagle[client])
	{
		hasDeagle[client] = false;
		AcceptEntityInput(GetPlayerWeaponSlot(client, 1), "Kill");
		GivePlayerItem(client, "weapon_pistol_magnum");
	}
}

public PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientInGame(client))
	{
		if (hasDeagle[client])
		{
			hasDeagle[client] = false;
			AcceptEntityInput(GetPlayerWeaponSlot(client, 1), "Kill");
		}
	}
}
