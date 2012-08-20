#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define GAMEDATA_FILE       "l4d2_zcs"
#define TEAM_SURVIVOR       2
#define TEAM_INFECTED       3
#define GHOSTTIMER_OFFSET   0.1
#define CHANGECLASS_DELAY   0.1
#define CLASSBLOCK_DELAY    10.0

#define TEAM_CLASS(%1)      (%1 == ZC_SMOKER ? "Smoker" : (%1 == ZC_BOOMER ? "Boomer" : (%1 == ZC_HUNTER ? "Hunter" :(%1 == ZC_SPITTER ? "Spitter" : (%1 == ZC_JOCKEY ? "Jockey" : (%1 == ZC_CHARGER ? "Charger" : (%1 == ZC_WITCH ? "Witch" : (%1 == ZC_TANK ? "Tank" : "None"))))))))

enum ZombieClass
{
	ZC_NONE = 0,
	ZC_SMOKER,
	ZC_BOOMER,
	ZC_HUNTER,
	ZC_SPITTER,
	ZC_JOCKEY,
	ZC_CHARGER,
	ZC_WITCH,
	ZC_TANK,
	ZC_NOTINFECTED
};

// SDKTools stuff
new Handle:         g_hSetClass;
new Handle:         g_hCreateAbility;
new Handle:         g_hGameConf;
new                 g_oAbility;

new Handle:         g_hSpawnGhostTimer[MAXPLAYERS + 1];
new bool:           g_bInRound;
new ZombieClass:    g_ZC_ZombieClass[MAXPLAYERS + 1] = ZC_NONE;
new ZombieClass:    g_ZC_LastZombieDeath = ZC_NONE;
new ZombieClass:    g_ZC_NextClass[MAXPLAYERS + 1] = {ZC_NONE,...};
new bool:           g_bIsHoldingKey[MAXPLAYERS + 1] = {false,...};
new bool:           g_bIsChangingClass[MAXPLAYERS + 1] = {false,...};
new bool:           g_bIsClassTimeBlocked[ZombieClass] = {false,...};
new Handle:         g_hClassBlockTimer[ZombieClass];
new bool:           g_bLateLoad;

public Plugin:myinfo =
{
	name = "Zombo Manager",
	author = "CanadaRox",
	description = "Manages Zombos in a more predictable and controlable fashion than the built in ZombieManager",
	version = "-0",
	url = "https://github.com/CanadaRox/sourcemod-plugins"
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax)
{
	g_bLateLoad = late;
}

public OnPluginStart()
{
	if (g_bLateLoad)
	{
		for (new client = 1; client < MaxClients + 1; client++)
		{
			if (IsClientInGame(client))
			{
				SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
				SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
				g_bInRound = true; // Should be correct most of the time
			}
		}
	}

	g_hGameConf = LoadGameConfigFile(GAMEDATA_FILE);
	if (g_hGameConf == INVALID_HANDLE)
		SetFailState("Zombo Manager Error: Unable to load gamedata file");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "SetClass");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSetClass = EndPrepSDKCall();
	if (g_hSetClass == INVALID_HANDLE)
		SetFailState("Zombo Manager Error: Unable to to find SetClass signature.");

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CreateAbility");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hCreateAbility = EndPrepSDKCall();
	if (g_hCreateAbility == INVALID_HANDLE)
		SetFailState("Zombo Manager Error: Unable to find CreateAbility signature.");

	g_oAbility = GameConfGetOffset(g_hGameConf, "oAbility");

	CloseHandle(g_hGameConf);

	HookEvent("ghost_spawn_time", GhostSpawnTime_Event);
	HookEvent("player_team", PlayerTeam_Event);
	HookEvent("tank_frustrated", TankFrustrated_Event);
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_zombo", ZomboCmd);
	RegConsoleCmd("sm_zm_debug", DebugCmd);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public OnTakeDamage(victim, attacker, inflictor, Float:damage, damagetype)
{
	if (IsPlayerZombie(victim))
	{
		g_ZC_ZombieClass[victim] = GetZombieClass(victim);
	}
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
	if (IsPlayerZombie(victim) && !IsPlayerAlive(victim))
	{
		g_ZC_LastZombieDeath = g_ZC_ZombieClass[victim];
		g_bIsClassTimeBlocked[g_ZC_LastZombieDeath] = true;
		g_hClassBlockTimer[g_ZC_LastZombieDeath] = CreateTimer(CLASSBLOCK_DELAY, UnblockClass_Timer, g_ZC_LastZombieDeath, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:UnblockClass_Timer(Handle:timer, any:class)
{
	g_bIsClassTimeBlocked[class] = false;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsClientInGame(client) && !IsFakeClient(client) && IsPlayerZombie(client) && IsPlayerGhost(client))
	{
		if (buttons & IN_ZOOM)
		{
			if (!g_bIsHoldingKey[client] && !g_bIsChangingClass[client])
			{
				g_bIsHoldingKey[client] = true;
				g_bIsChangingClass[client] = true;

				new ZombieClass:nextclass = g_ZC_NextClass[client];
				while (nextclass == g_ZC_LastZombieDeath || g_bIsClassTimeBlocked[nextclass])
				{
					if (nextclass == g_ZC_LastZombieDeath) nextclass = ZombieClass:(_:nextclass % 6 + 1);
				}
				SetZombieClass(client, nextclass);
				g_ZC_NextClass[client] = ZombieClass:(_:nextclass % 6 + 1);
				CreateTimer(CHANGECLASS_DELAY, ChangingClassDelay_Timer, client, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		else
		{
			g_bIsHoldingKey[client] = false;
		}
	}
}

public Action:ChangingClassDelay_Timer(Handle:timer, any:client)
{
	g_bIsChangingClass[client] = false;
}

public Action:ZomboCmd(client, args)
{
	PrintToChat(client, "Blocked SI: %s", TEAM_CLASS(g_ZC_LastZombieDeath));
	return Plugin_Handled;
}

public Action:DebugCmd(client, args)
{
	PrintToChat(client, "Alive=%d, Infected=%d, Ghost=%d", IsPlayerAlive(client), IsPlayerZombie(client), IsPlayerGhost(client));
	PrintToChat(client, "m_zombieClass=%s, g_ZC_NextZombie=%s", TEAM_CLASS(GetZombieClass(client)), TEAM_CLASS(g_ZC_NextClass[client]));
	PrintToChat(client, "g_bIsChangingClass=%d, g_bIsHoldingKey=%d", g_bIsHoldingKey[client], g_bIsHoldingKey[client]);

	return Plugin_Handled;
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bInRound = true;
	g_ZC_LastZombieDeath = ZC_NONE;
	for (new ZombieClass:class; class < ZombieClass; class++)
	{
		if (g_hClassBlockTimer[class] != INVALID_HANDLE) CloseHandle(g_hClassBlockTimer[class]);
	}
	for (new client = 1; client < MaxClients + 1; client++)
	{
		if (g_hSpawnGhostTimer[client] != INVALID_HANDLE) CloseHandle(g_hSpawnGhostTimer[client]);
	}
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bInRound = false;
}

public TankFrustrated_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_bInRound)
	{
		g_hSpawnGhostTimer[client] = CreateTimer(GHOSTTIMER_OFFSET, SpawnDelay_Timer, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
}

public PlayerTeam_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new newteam = GetEventInt(event, "team");
	if (client && IsClientInGame(client))
	{
		if (newteam == TEAM_INFECTED)
		{
			g_hSpawnGhostTimer[client] = CreateTimer(GHOSTTIMER_OFFSET, SpawnDelay_Timer, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}
	}
}

public GhostSpawnTime_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new Float:fSpawnDelay = GetEventFloat(event, "spawntime");
	g_hSpawnGhostTimer[client] = CreateTimer(fSpawnDelay + GHOSTTIMER_OFFSET, SpawnDelay_Timer, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action:SpawnDelay_Timer(Handle:timer, any:client)
{
	if (IsClientInGame(client))
	{
		if (IsPlayerZombie(client) && IsPlayerGhost(client))
		{
			new ZombieClass:class = GetSafeSpawnClass(client);
			g_ZC_NextClass[client] = ZombieClass:(_:class % 6 + 1);
			SetZombieClass(client, class);
			return Plugin_Stop;
		}
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

stock ZombieClass:GetSafeSpawnClass(client)
{
	new bool:bClassFree[ZombieClass] =
	{
		false,
		true,
		true,
		true,
		true,
		true,
		true,
		false,
		false,
		false
	};
		
	decl ZombieClass:class;
	bClassFree[g_ZC_LastZombieDeath] = false;
	for (class = ZC_NONE; class < ZombieClass; class++)
	{
		if (g_bIsClassTimeBlocked[class]) bClassFree[class] = false;
	}
	for (new i = 1; i < MaxClients + 1; i++)
	{
		if (IsClientInGame(i) && IsPlayerZombie(i) && IsPlayerAlive(i) && i != client)
		{
			class = GetZombieClass(i);
			if (class != ZC_TANK)
			{
				bClassFree[class] = false;
			}
		}
	}
	for (class = ZC_SMOKER; class <= ZC_CHARGER; class++)
	{
		if (bClassFree[class]) return class;
	}
	return ZC_NONE;
}

stock SetZombieClass(client, ZombieClass:zombie)
{
	decl WeaponIndex;
	while ((WeaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
	{
		RemovePlayerItem(client, WeaponIndex);
		RemoveEdict(WeaponIndex);
	}

	SDKCall(g_hSetClass, client, _:zombie);
	AcceptEntityInput(MakeCompatEntRef(GetEntProp(client, Prop_Send, "m_customAbility")), "Kill");
	SetEntProp(client, Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, client), g_oAbility));
}

stock bool:IsPlayerGhost(client) return bool:GetEntProp(client, Prop_Send, "m_isGhost");

stock bool:IsPlayerZombie(client) return GetClientTeam(client) == TEAM_INFECTED;

stock ZombieClass:GetZombieClass(client) return ZombieClass:GetEntProp(client, Prop_Send, "m_zombieClass");
