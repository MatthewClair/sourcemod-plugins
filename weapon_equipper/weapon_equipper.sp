#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "Weapon Equiper",
	author = "CanadaRox",
	description = "A plugin to test the possibility of tanks with hunting rifles.",
	version = "f(x) = -0.1x - 4",
	url = "http://confogl.googlecode.com/"
}

public OnPluginStart()
{
	RegAdminCmd("sm_createent", CreateEnt_Cmd, ADMFLAG_BAN);
	RegAdminCmd("sm_equipent", EquipEnt_Cmd, ADMFLAG_BAN);
}

public Action:CreateEnt_Cmd(client, args)
{
	if (!args) return Plugin_Handled;
	
	decl String:sbuffer[128];
	GetCmdArg(1, sbuffer, sizeof(sbuffer));
	
	PrintToChat(client, "Now creating %s", sbuffer);
	new entity = CreateEntityByName(sbuffer);
	PrintToChat(client, "%s created as entity %i", sbuffer, entity);
	
	decl Float:clientOrigin[3];
	GetClientAbsOrigin(client, clientOrigin);
	PrintToChat(client, "Now teleporting entity %i", entity);
	TeleportEntity(entity, clientOrigin, NULL_VECTOR, NULL_VECTOR);
	
	PrintToChat(client, "Now dispatching spawn for entity %i", entity);
	DispatchSpawn(entity);
	
	return Plugin_Handled;
}

public Action:EquipEnt_Cmd(client, args)
{
	if (!args) return Plugin_Handled;
	decl String:sbuffer[32];
	
	GetCmdArg(1, sbuffer, sizeof(sbuffer));
	new entity = StringToInt(sbuffer);
	
	EquipPlayerWeapon(client, entity);
	
	return Plugin_Handled;
}