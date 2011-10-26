#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <adt_array>
#include <adt_trie>

#define MAX_WEAPON_NAME_LENGTH 32
#define MAX_WEAPONS 8
#define GAMEDATA_FILE      "give_test"
#define GAMEDATA_USE_AMMO  "CWeaponAmmoSpawn_Use"

public Plugin:myinfo =
{
	name = "L4D Weapon Limits",
	author = "CanadaRox",
	description = "Restrict weapons individually or together",
	version = "1.0",
	url = "https://www.github.com/CanadaRox/sourcemod-plugins/tree/master/weapon_limits"
}

enum LE
{
	LE_iLimit,
	/*String:LE_sWeaponNames[MAX_WEAPONS][MAX_WEAPON_NAME_LENGTH]*/
	String:LE_sWeaponName0[MAX_WEAPON_NAME_LENGTH],
	String:LE_sWeaponName1[MAX_WEAPON_NAME_LENGTH],
	String:LE_sWeaponName2[MAX_WEAPON_NAME_LENGTH],
	String:LE_sWeaponName3[MAX_WEAPON_NAME_LENGTH],
	String:LE_sWeaponName4[MAX_WEAPON_NAME_LENGTH],
	String:LE_sWeaponName5[MAX_WEAPON_NAME_LENGTH],
	String:LE_sWeaponName6[MAX_WEAPON_NAME_LENGTH],
	String:LE_sWeaponName7[MAX_WEAPON_NAME_LENGTH]
}

enum TrieArrayEntry
{
	TAE_iLimit,
	Handle:TAE_hTrie
}

new Handle:hSDKGiveDefaultAmmo;
new Handle:hEntryList;
new Handle:hTrieArray;
new bIsLocked;
new iAmmoPile;

public OnPluginStart()
{
	hEntryList = CreateArray(_:LE);

	/* Preparing SDK Call */
	/* {{{ */
	new Handle:conf = LoadGameConfigFile(GAMEDATA_FILE);

	if (conf == INVALID_HANDLE)
		ThrowError("Gamedata missing: %s", GAMEDATA_FILE);

	StartPrepSDKCall(SDKCall_Entity);

	if (!PrepSDKCall_SetFromConf(conf, SDKConf_Signature, GAMEDATA_USE_AMMO))
		ThrowError("Gamedata missing signature: %s", GAMEDATA_USE_AMMO);

	// Client that used the ammo spawn
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	hSDKGiveDefaultAmmo = EndPrepSDKCall();
	/* }}} */

	RegServerCmd("l4d_wlimits_add", AddLimit_Cmd, "Add a weapon limit");
	RegServerCmd("l4d_wlimits_lock", LockLimits_Cmd, "Locks the limits to improve search speeds");
	RegServerCmd("l4d_wlimits_clear", ClearLimits_Cmd, "Clears all weapon limits (limits must be locked to be cleared)");
}

public OnPluginEnd()
{
	ClearLimits();
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUse);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_WeaponCanUse, WeaponCanUse);
}

public Action:WeaponCanUse(client, weapon)
{
	decl String:primary_name[64];
	GetEdictClassname(weapon, primary_name, sizeof(primary_name));

	decl arrayEntry[TrieArrayEntry], tmp;
	new size = GetArraySize(hTrieArray);
	for (new i = 0; i < size; ++i)
	{
		GetArrayArray(hTrieArray, i, arrayEntry[0]);
		if (GetTrieValue(arrayEntry[TAE_hTrie], primary_name, tmp)
			&& GetWeaponCount(arrayEntry[TAE_hTrie]) >= arrayEntry[TAE_iLimit])
			{
				GiveDefaultAmmo(client);
				return Plugin_Handled;
			}
	}
	return Plugin_Continue;
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(2.0, RoundStartDelay_Timer);
}

public Action:RoundStartDelay_Timer(Handle:timer)
{
	FindAmmoSpawn();
}

public Action:AddLimit_Cmd(args)
{
	if (bIsLocked || args < 2 || args > 9) return;
	decl String:sTempBuff[MAX_WEAPON_NAME_LENGTH];

	if (!GetCmdArg(1, sTempBuff, sizeof(sTempBuff))) return;

	decl newEntry[LE];
	newEntry[LE_iLimit] = StringToInt(sTempBuff);

	/*for (new i = 2; i < args; ++i)*/
	/*{*/
	GetCmdArg(2, sTempBuff, sizeof(sTempBuff));
	strcopy(newEntry[LE_sWeaponName0], MAX_WEAPON_NAME_LENGTH, sTempBuff);
	if (args >= 3)
	{
		GetCmdArg(3, sTempBuff, sizeof(sTempBuff));
		strcopy(newEntry[LE_sWeaponName1], MAX_WEAPON_NAME_LENGTH, sTempBuff);
	}
	else
	{
		strcopy(newEntry[LE_sWeaponName1], MAX_WEAPON_NAME_LENGTH, "");
	}
	if (args >= 4)
	{
		GetCmdArg(4, sTempBuff, sizeof(sTempBuff));
		strcopy(newEntry[LE_sWeaponName2], MAX_WEAPON_NAME_LENGTH, sTempBuff);
	}
	else
	{
		strcopy(newEntry[LE_sWeaponName2], MAX_WEAPON_NAME_LENGTH, "");
	}
	if (args >= 5)
	{
		GetCmdArg(5, sTempBuff, sizeof(sTempBuff));
		strcopy(newEntry[LE_sWeaponName3], MAX_WEAPON_NAME_LENGTH, sTempBuff);
	}
	else
	{
		strcopy(newEntry[LE_sWeaponName3], MAX_WEAPON_NAME_LENGTH, "");
	}
	if (args >= 6)
	{
		GetCmdArg(6, sTempBuff, sizeof(sTempBuff));
		strcopy(newEntry[LE_sWeaponName4], MAX_WEAPON_NAME_LENGTH, sTempBuff);
	}
	else
	{
		strcopy(newEntry[LE_sWeaponName4], MAX_WEAPON_NAME_LENGTH, "");
	}
	if (args >= 7)
	{
		GetCmdArg(7, sTempBuff, sizeof(sTempBuff));
		strcopy(newEntry[LE_sWeaponName5], MAX_WEAPON_NAME_LENGTH, sTempBuff);
	}
	else
	{
		strcopy(newEntry[LE_sWeaponName5], MAX_WEAPON_NAME_LENGTH, "");
	}
	if (args >= 8)
	{
		GetCmdArg(8, sTempBuff, sizeof(sTempBuff));
		strcopy(newEntry[LE_sWeaponName6], MAX_WEAPON_NAME_LENGTH, sTempBuff);
	}
	else
	{
		strcopy(newEntry[LE_sWeaponName6], MAX_WEAPON_NAME_LENGTH, "");
	}
	if (args >= 9)
	{
		GetCmdArg(9, sTempBuff, sizeof(sTempBuff));
		strcopy(newEntry[LE_sWeaponName7], MAX_WEAPON_NAME_LENGTH, sTempBuff);
	}
	else
	{
		strcopy(newEntry[LE_sWeaponName7], MAX_WEAPON_NAME_LENGTH, "");
	}
	/*}*/

	PushArrayArray(hEntryList, newEntry[0]);
}

public Action:LockLimits_Cmd(args)
{
	if (bIsLocked)
	{
		PrintToServer("Weapon limits already locked");
	}
	else
	{
		bIsLocked = true;
		InitTries();
	}
}

public Action:ClearLimits_Cmd(args)
{
	if (!bIsLocked)
	{
		PrintToServer("Weapon limits already unlocked");
	}
	else
	{
		bIsLocked = false;
		ClearLimits();
	}
}

InitTries()
{
	hTrieArray = CreateArray(_:TrieArrayEntry);
	new size = GetArraySize(hEntryList);
	decl arrayEntry[LE];
	decl tempEntry[TrieArrayEntry];
	/*decl j;*/
	for (new i = 0; i < size; ++i)
	{
		GetArrayArray(hEntryList, i, arrayEntry[0]);
		tempEntry[TAE_iLimit] = arrayEntry[LE_iLimit];

		tempEntry[TAE_hTrie] = CreateTrie();
		SetTrieValue(tempEntry[TAE_hTrie], arrayEntry[LE_sWeaponName0], 0);
		SetTrieValue(tempEntry[TAE_hTrie], arrayEntry[LE_sWeaponName1], 0);
		SetTrieValue(tempEntry[TAE_hTrie], arrayEntry[LE_sWeaponName2], 0);
		SetTrieValue(tempEntry[TAE_hTrie], arrayEntry[LE_sWeaponName3], 0);
		SetTrieValue(tempEntry[TAE_hTrie], arrayEntry[LE_sWeaponName4], 0);
		SetTrieValue(tempEntry[TAE_hTrie], arrayEntry[LE_sWeaponName5], 0);
		SetTrieValue(tempEntry[TAE_hTrie], arrayEntry[LE_sWeaponName6], 0);
		SetTrieValue(tempEntry[TAE_hTrie], arrayEntry[LE_sWeaponName7], 0);
		PushArrayArray(hTrieArray, tempEntry[0]);
		/*for (j = 0; j < MAX_WEAPONS; ++j)*/
		/*{*/
			/*SetTrieValue(tempEntry[TAE_hTrie], arrayEntry[LE_sWeaponNames[j]]);*/
		/*}*/
	}
	CloseHandle(hEntryList);
}

ClearLimits()
{
	if (hTrieArray != INVALID_HANDLE)
	{
		decl arrayEntry[TrieArrayEntry];
		new size = GetArraySize(hTrieArray);
		for (new i = 0; i < size; ++i)
		{
			GetArrayArray(hTrieArray, i, arrayEntry[0]);
			CloseHandle(arrayEntry[TAE_hTrie]);
		}
		CloseHandle(hTrieArray);
	}
}

stock GetWeaponCount(Handle:hTrie)
{
	new count;
	decl wep, String:classname[64], tmp;
	for (new i = 1; i < MaxClients + 1; ++i)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			wep = GetPlayerWeaponSlot(i, 0);
			if (IsValidEntity(wep))
			{
				GetEdictClassname(wep, classname, sizeof(classname));
				if (GetTrieValue(hTrie, classname, tmp))
				{
					++count;
				}
			}
		}
	}
	return count;
}

stock GiveDefaultAmmo(client)
{
	if (iAmmoPile != -1) 
		SDKCall(hSDKGiveDefaultAmmo, iAmmoPile, client);
}

stock FindAmmoSpawn()
{
	new psychonic = GetEntityCount();
	decl String:classname[64];
	for (new i = MaxClients; i < psychonic; ++i)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, classname, sizeof(classname));
			if (StrEqual(classname, "weapon_ammo_spawn"))
			{
				return i;
			}
		}
	}
	//We have to make an ammo pile!
	return MakeAmmoPile();
}

stock MakeAmmoPile()
{
	new ammo = CreateEntityByName("weapon_ammo_spawn");
	DispatchSpawn(ammo);
	LogMessage("No ammo pile found, creating one: %d", iAmmoPile);
	return ammo;
}
