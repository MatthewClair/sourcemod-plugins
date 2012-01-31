#pragma semicolon 1

#include <sourcemod>
#include <weapons>

public Plugin:myinfo =
{
	name = "L4D Magic Pickups",
	author = "CanadaRox",
	description = "Lots of customization for single pickup weapons",
	version = "AOL",
	url = "https://www.github.com/CanadaRox/sourcemod-plugins/tree/master/l4d_magicpickups"
}

new WeaponId:replacement_wepid[_:WeaponId];

public OnPluginStart()
{
	HookEvent("spawner_give_item", SpawnerGiveItem_Event);

	RegServerCmd("l4d_magicpickup_set", SetReplacement_Cmd, "Sets up a replacement");
	RegServerCmd("l4d_magicpickup_clear", ClearReplacement_Cmd, "Clears all replacements");

	ClearRepArray();

	L4D2Weapons_Init();
}

stock ClearRepArray()
{
	for (new i = 0; i < sizeof(replacement_wepid); i++)
	{
		replacement_wepid[i] = WeaponId:0;
	}
}

public Action:ClearReplacement_Cmd(args)
{
	ClearRepArray();
}

public Action:SetReplacement_Cmd(args)
{
	if (args < 2)
	{
		PrintToServer("Usage: l4d_magicpickup_set <current_wepid> <replacement_wepid> (0 replacement disables the replacement)");
	}

	decl String:sbuff[4];
	decl WeaponId:current_wepid, WeaponId:rep_wepid;

	GetCmdArg(1, sbuff, sizeof(sbuff));
	current_wepid = WeaponId:StringToInt(sbuff);
	GetCmdArg(2, sbuff, sizeof(sbuff));
	rep_wepid = WeaponId:StringToInt(sbuff);

	replacement_wepid[current_wepid] = rep_wepid;
}

public SpawnerGiveItem_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new spawner = GetEventInt(event, "spawner");
	new WeaponId:spawner_wepid = IdentifyWeapon(spawner);
	if (replacement_wepid[spawner_wepid] != WeaponId:0)
		ConvertWeaponSpawn(spawner, replacement_wepid[spawner_wepid]);
}
