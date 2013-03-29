#pragma semicolon 1

#include <sourcemod>

#define CVAR_MAXLEN 64
#define MAX_MAPNAME_LEN 64

public Plugin:myinfo =
{
	name = "Cvar Control",
	author = "CanadaRox",
	description = "Allows setting cvars per map",
	version = "1",
	url = "http://github.com/CanadaRox/sourcemod-plugins/"
};

enum CvarEntry
{
	Handle:CE_cvar,
	String:CE_oldval[CVAR_MAXLEN],
	String:CE_newval[CVAR_MAXLEN]
}

new Handle:CvarMapTrie;
new Handle:MapArrays;
new bool:bTrackingStarted;

public OnPluginStart()
{
	CvarMapTrie = CreateTrie();
	MapArrays = CreateArray();

	RegServerCmd("cc_addcvar", AddCvar_Cmd, "Add a ConVar to be set by plugin");
	RegServerCmd("cc_setcvars", SetCvars_Cmd, "Starts enforcing ConVars that have been added and stops new ones from being added.");
	RegServerCmd("cc_resetcvars", ResetCvars_Cmd, "Resets enforced ConVars.");

	/* This is the first event I could find for a new map so lets just hope no reads cvars until after! */
	HookEvent("round_start_pre_entity", RoundStartPreEnt_Event, EventHookMode_Pre);
}

public RoundStartPreEnt_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetEnforcedCvars();
}

public Action:SetCvars_Cmd(args)
{
	SetEnforcedCvars();
	bTrackingStarted = true;
}

SetEnforcedCvars()
{
	new cvsetting[CvarEntry];
	decl Handle:mapArray;
	if (GetTrieValue(CvarMapTrie, "global", mapArray))
	{
		for (new i = 0; i < GetArraySize(mapArray); i++)
		{
			GetArrayArray(mapArray, i, cvsetting[0]);
			SetConVarString(cvsetting[CE_cvar], cvsetting[CE_newval]);
		}
	}

	decl String:mapname[MAX_MAPNAME_LEN];
	GetCurrentMap(mapname, sizeof(mapname));
	LowerString(mapname);
	if (GetTrieValue(CvarMapTrie, mapname, mapArray))
	{
		for (new i = 0; i < GetArraySize(mapArray); i++)
		{
			GetArrayArray(mapArray, i, cvsetting[0]);
			SetConVarString(cvsetting[CE_cvar], cvsetting[CE_newval]);
		}
	}
}

public Action:ResetCvars_Cmd(args)
{
	ClearAllCvarSettings();
	return Plugin_Handled;
}

ClearAllCvarSettings()
{
	bTrackingStarted = false;
	new cvsetting[CvarEntry];

	decl Handle:mapArray;
	for (new i = 0; i < GetArraySize(MapArrays); i++)
	{
		mapArray = GetArrayCell(MapArrays, i);
		for (new j = 0; j < GetArraySize(mapArray); j++)
		{
			GetArrayArray(mapArray, i, cvsetting[0]);

			UnhookConVarChange(cvsetting[CE_cvar], ConVarChange);
			SetConVarString(cvsetting[CE_cvar], cvsetting[CE_oldval]);
		}
		CloseHandle(mapArray);
	}
	ClearTrie(CvarMapTrie);
	ClearArray(MapArrays);
}

public Action:AddCvar_Cmd(args)
{
	if (args != 3)
	{
		PrintToServer("Usage: cc_addcvar <mapname or global> <cvar> <newvalue>");
		return Plugin_Handled;
	}

	decl String:mapname[MAX_MAPNAME_LEN], String:cvar[CVAR_MAXLEN], String:newval[CVAR_MAXLEN];
	GetCmdArg(1, mapname, sizeof(mapname));
	GetCmdArg(2, cvar,    sizeof(cvar));
	GetCmdArg(3, newval,  sizeof(newval));


	AddCvar(mapname, cvar, newval);

	return Plugin_Handled;
}

AddCvar(const String:mapname[], const String:cvar[], const String:newval[])
{
	if (bTrackingStarted)
	{
		return;
	}

	if (strlen(mapname) >= MAX_MAPNAME_LEN)
	{
		return;
	}
	else if (strlen(cvar) >= CVAR_MAXLEN)
	{
		return;
	}
	else if (strlen(newval) >= CVAR_MAXLEN)
	{
		return;
	}

	new Handle:newCvar = FindConVar(cvar);

	if (newCvar == INVALID_HANDLE)
	{
		LogError("[Cvar Control] Could not find Cvar Specified (%s)", cvar);
		return;
	}

	new Handle:mapArray;

	if (GetTrieValue(CvarMapTrie, mapname, mapArray))
	{
		if (mapArray == INVALID_HANDLE)
		{
			mapArray = CreateArray(_:CvarEntry);
			SetTrieValue(CvarMapTrie, mapname, mapArray);
			PushArrayCell(MapArrays, mapArray);
			LogMessage("[CC] This shouldn't happen but hopefully was handled okay anyways");
		}
	}
	else
	{
		mapArray = CreateArray(_:CvarEntry);
		SetTrieValue(CvarMapTrie, mapname, mapArray);
		PushArrayCell(MapArrays, mapArray);
		PrintToChatAll("Created new map array");
	}
	decl newEntry[CvarEntry];
	decl String:cvarBuffer[CVAR_MAXLEN];
	new bool:alreadyExists = false;
	for (new i; i < GetArraySize(mapArray) && !alreadyExists; i++)
	{
		GetArrayArray(mapArray, i, newEntry[0]);
		GetConVarName(newEntry[CE_cvar], cvarBuffer, sizeof(cvarBuffer));
		if (StrEqual(cvar, cvarBuffer, false))
		{
			strcopy(newEntry[CE_newval], CVAR_MAXLEN, newval);
			SetArrayArray(mapArray, i, newEntry[0]);
			PrintToChatAll("Already found this cvar, updated to new value");
			alreadyExists = true;
		}
	}

	if (!alreadyExists)
	{
		GetConVarString(newCvar, cvarBuffer, CVAR_MAXLEN);

		newEntry[CE_cvar] = newCvar;
		strcopy(newEntry[CE_oldval], CVAR_MAXLEN, cvarBuffer);
		strcopy(newEntry[CE_newval], CVAR_MAXLEN, newval);

		HookConVarChange(newCvar, ConVarChange);
		PushArrayArray(mapArray, newEntry[0]);
		PrintToChatAll("New cvar, adding to array");
	}
}

public ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (bTrackingStarted)
	{
		decl String:name[CVAR_MAXLEN];
		GetConVarName(convar, name, sizeof(name));
		PrintToChatAll("!!! [Cvar Control] Tracked Server Cvar \"%s\" changed from \"%s\" to \"%s\" !!! ", name, oldValue, newValue);
	}
}

stock LowerString(String:str[])
{
	new length = strlen(str);
	for (new i = 0; i <= length; i++)
	{
		str[i] = CharToLower(str[i]);
	}
}
