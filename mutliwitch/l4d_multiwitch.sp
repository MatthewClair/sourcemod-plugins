#pragma semicolon 1

#include <sourcemod>
#include <l4d2_direct>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>
#undef REQUIRE_PLUGIN
#include <readyup>
#include <pause>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define EXTRA_FLOW 3000.0
#define RESPAWN_FREQ 5.0

new Handle:	hEnabled;
new bool:	bEnabled;

new Handle:	hSpawnFreq;
new Float:	fSpawnFreq;

new Handle:	hWitchSpawnTimer;

new bool:readyUpIsAvailable;
new bool:pauseIsAvailable;

public Plugin:myinfo =
{
	name = "L4D2 Multiwitch",
	author = "CanadaRox",
	description = "A plugin that spawns unlimited witches off of a timer.",
	version = "1",
	url = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/mutliwitch"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("IsInReady");
	MarkNativeAsOptional("IsInPause");
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
	pauseIsAvailable = LibraryExists("pause");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = false;
	if (StrEqual(name, "pause")) pauseIsAvailable = false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = true;
	if (StrEqual(name, "pause")) pauseIsAvailable = true;
}

public OnMapStart()
{
	CreateTimer(RESPAWN_FREQ, WitchRespawn_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnMapEnd()
{
	if (hWitchSpawnTimer != INVALID_HANDLE)
	{
		CloseHandle(hWitchSpawnTimer);
		hWitchSpawnTimer = INVALID_HANDLE;
	}
}

public OnRoundIsLive()
{
	if (fSpawnFreq >= 1.0)
	{
		if (hWitchSpawnTimer != INVALID_HANDLE)
		{
			CloseHandle(hWitchSpawnTimer);
		}
		hWitchSpawnTimer = CreateTimer(fSpawnFreq, WitchSpawn_Timer, _, TIMER_REPEAT);
	}
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!readyUpIsAvailable)
	{
		if (fSpawnFreq >= 1.0)
		{
			if (hWitchSpawnTimer != INVALID_HANDLE)
			{
				CloseHandle(hWitchSpawnTimer);
			}
			hWitchSpawnTimer = CreateTimer(fSpawnFreq, WitchSpawn_Timer, _, TIMER_REPEAT);
		}
	}
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (hWitchSpawnTimer != INVALID_HANDLE)
	{
		CloseHandle(hWitchSpawnTimer);
		hWitchSpawnTimer = INVALID_HANDLE;
	}
}

public Enabled_Changed(Handle:convar, const String:oldValue[], const String:newValue[])
{
	bEnabled = GetConVarBool(hEnabled);
}

public Freq_Changed(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (hWitchSpawnTimer != INVALID_HANDLE)
	{
		CloseHandle(hWitchSpawnTimer);
		hWitchSpawnTimer = INVALID_HANDLE;
	}
	fSpawnFreq = GetConVarFloat(hSpawnFreq);
	if (fSpawnFreq >= 1.0)
	{
		hWitchSpawnTimer = CreateTimer(fSpawnFreq, WitchSpawn_Timer, _, TIMER_REPEAT);
	}
}

public Action:WitchSpawn_Timer(Handle:timer)
{
	if (bEnabled && !IsTankInPlay()
			&& ((pauseIsAvailable && !IsInPause()) || !pauseIsAvailable)
			&& ((readyUpIsAvailable && !IsInReady()) || !readyUpIsAvailable))
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
	return Plugin_Continue;
}

public Action:WitchRespawn_Timer(Handle:timer)
{
	if (bEnabled && !IsTankInPlay()
			&& ((pauseIsAvailable && !IsInPause()) || !pauseIsAvailable)
			&& ((readyUpIsAvailable && !IsInReady()) || !readyUpIsAvailable))
	{
		new psychonic = GetMaxEntities();
		decl String:buffer[64];
		decl Address:pNavArea;
		decl Float:flow;
		new Float:survMaxFlow = GetMaxSurvivorCompletion();
		new witchSpawnCount = 0;
		decl Float:origin[3];
		decl m_nSequence;

		if (survMaxFlow > EXTRA_FLOW)
		{
			for (new entity = MaxClients+1; entity <= psychonic; entity++)
			{
				if (IsValidEntity(entity)
						&& GetEntityClassname(entity, buffer, sizeof(buffer))
						&& StrEqual(buffer, "witch"))
				{
					m_nSequence = GetEntProp(entity, Prop_Send, "m_nSequence");

					/* Wandering witch: */
					/* standing - 2 */
					/* wandering - 10, 11 */
					/* time startle - 30 */

					/* Sitting witch: */
					/* sitting - 4 */
					/* angry - 27 */
					/* full anger - 29 */

					/* Both: */
					/* running - 6 */
					/* jump climbing - 66 */
					/* ladder climbing - 72, 74 */
					/* dying - 74 */

					/* We only want to respawn fully passive witches */
					switch (m_nSequence)
					{
						case 2, 10, 11, 4:
							{
								GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
								pNavArea = L4D2Direct_GetTerrorNavArea(origin);
								flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
								if (survMaxFlow > flow + EXTRA_FLOW)
								{
									AcceptEntityInput(entity, "Kill");
									witchSpawnCount++;
								}
							}
					}
				}
			}
		}

		if (witchSpawnCount)
		{
			for (new client = 1; client <= MaxClients; client++)
			{
				if(IsClientInGame(client))
				{
					new flags = GetCommandFlags("z_spawn");
					SetCommandFlags("z_spawn", flags ^ FCVAR_CHEAT);
					for (new i = 0; i < witchSpawnCount; i++)
					{
						FakeClientCommand(client, "z_spawn witch auto");
					}
					SetCommandFlags("z_spawn", flags);
					break;
				}
			}
		}
	}
}

stock Float:GetMaxSurvivorCompletion()
{
	new Float:flow = 0.0;
	decl Float:tmp_flow;
	decl Float:origin[3];
	decl Address:pNavArea;
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) &&
				L4D2_Team:GetClientTeam(client) == L4D2Team_Survivor)
		{
			GetClientAbsOrigin(client, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea != Address_Null)
			{
				tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				flow = MAX(flow, tmp_flow);
			}
		}
	}
	return flow;
}
