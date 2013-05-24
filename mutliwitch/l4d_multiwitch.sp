#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <readyup>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

new Handle:	hEnabled;
new bool:	bEnabled;

new Handle:	hSpawnFreq;
new Float:	fSpawnFreq;

new Handle:	hWitchSpawnTimer;

new bool:readyUpIsAvailable;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("IsInReady");
	return APLRes_Success;
}

public OnPluginStart()
{
	hEnabled = CreateConVar("l4d_multiwitch_enabled", "1", "Enable multiple witch spawning");
	HookConVarChange(hEnabled, Enabled_Changed);
	bEnabled = GetConVarBool(hEnabled);

	hSpawnFreq = CreateConVar("l4d_multiwitch_spawnfreq", "120", "How many seconds before the next witch spawns");
	HookConVarChange(hSpawnFreq, Freq_Changed);
	fSpawnFreq = GetConVarFloat(hSpawnFreq);

	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
}

public OnAllPluginsLoaded()
{
	readyUpIsAvailable = LibraryExists("readyup");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = true;
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast) hWitchSpawnTimer = CreateTimer(fSpawnFreq, WitchSpawn_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast) CloseHandle(hWitchSpawnTimer);

public Enabled_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) bEnabled = GetConVarBool(hEnabled);

public Freq_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) fSpawnFreq = GetConVarFloat(hSpawnFreq);

public Action:WitchSpawn_Timer(Handle:timer)
{
	if (bEnabled && !IsTankInPlay())
	{
		if ((readyUpIsAvailable && !IsInReady()) || !readyUpIsAvailable)
		{
			for (new i = 1; i < MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					new flags = GetCommandFlags("z_spawn");
					SetCommandFlags("z_spawn", flags ^ FCVAR_CHEAT);
					FakeClientCommand(i, "z_spawn witch auto");
					SetCommandFlags("z_spawn", flags);
					return Plugin_Continue;
				}
			}
		}
	}
	return Plugin_Continue;
}
