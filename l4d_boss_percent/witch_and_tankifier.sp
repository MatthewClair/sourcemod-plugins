#pragma semicolon 1


#define MIN_BOSS_VARIANCE (0.1)

#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
#include <l4d2lib>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>
#include <left4downtown>

public Plugin:myinfo =
{
	name = "Witch and Tankifier!",
	author = "CanadaRox",
	version = "1",
	description = "Sets a tank and witch spawn point on every map with a minimum 0.05 flow variation"
};

new Handle:g_hVsBossBuffer;
new Handle:g_hVsBossFlowMax;
new Handle:g_hVsBossFlowMin;
new Handle:hStaticTankMaps;
new Handle:hStaticWitchMaps;

public OnPluginStart()
{
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");
	g_hVsBossFlowMax = FindConVar("versus_boss_flow_max");
	g_hVsBossFlowMin = FindConVar("versus_boss_flow_min");

	hStaticTankMaps = CreateTrie();
	hStaticWitchMaps = CreateTrie();

	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);

	RegServerCmd("static_witch_map", StaticWitch_Command);
	RegServerCmd("static_tank_map", StaticTank_Command);
	RegServerCmd("reset_static_maps", Reset_Command);
}

public Action:StaticWitch_Command(args)
{
	decl String:mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hStaticWitchMaps, mapname, true);
}

public Action:StaticTank_Command(args)
{
	decl String:mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hStaticTankMaps, mapname, true);
}

public Action:Reset_Command(args)
{
	ClearTrie(hStaticWitchMaps);
	ClearTrie(hStaticTankMaps);
}

public RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.5, AdjustBossFlow);
}

public Action:AdjustBossFlow(Handle:timer)
{
	if (InSecondHalfOfRound()) return;

	decl String:sCurMap[64];
	decl dummy;
	GetCurrentMap(sCurMap, sizeof(sCurMap));

	new Float:fCvarMinFlow = GetConVarFloat(g_hVsBossFlowMin);
	new Float:fCvarMaxFlow = GetConVarFloat(g_hVsBossFlowMax);

	new Float:fTankFlow = -1.0;

	if (!GetTrieValue(hStaticTankMaps, sCurMap, dummy))
	{
		new Float:fMinBanFlow = L4D2_GetMapValueInt("tank_ban_flow_min", -1) / 100.0;
		new Float:fMaxBanFlow = L4D2_GetMapValueInt("tank_ban_flow_max", -1) / 100.0;
		new Float:fBanRange = fMaxBanFlow - fMinBanFlow;

		fTankFlow = GetRandomFloat(fCvarMinFlow, fCvarMaxFlow - fBanRange);
		if (fTankFlow > fMinBanFlow && fTankFlow < fMaxBanFlow)
		{
			fTankFlow += fBanRange;
		}
		L4D2Direct_SetVSTankToSpawnThisRound(0, true);
		L4D2Direct_SetVSTankToSpawnThisRound(1, true);
		L4D2Direct_SetVSTankFlowPercent(0, fTankFlow);
		L4D2Direct_SetVSTankFlowPercent(1, fTankFlow);
	}


	if (!GetTrieValue(hStaticWitchMaps, sCurMap, dummy))
	{
		new iMinWitchFlow = L4D2_GetMapValueInt("witch_flow_min", -1);
		new iMaxWitchFlow = L4D2_GetMapValueInt("witch_flow_max", -1);
		new Float:fMinWitchFlow = iMinWitchFlow == -1 ? fCvarMinFlow : iMinWitchFlow / 100.0;
		new Float:fMaxWitchFlow = iMaxWitchFlow == -1 ? fCvarMaxFlow : iMaxWitchFlow / 100.0;
		new Float:witchFlowRange = fMaxWitchFlow - fMinWitchFlow;
		new bool:adjustFlow = fTankFlow > 0 && fTankFlow > fMinWitchFlow && fTankFlow < fMaxWitchFlow;
		if (adjustFlow)
		{
			witchFlowRange -= MIN_BOSS_VARIANCE;
		}
		new Float:fWitchFlow = GetRandomFloat(fMinWitchFlow, fMinWitchFlow + witchFlowRange);
		if (adjustFlow && (fTankFlow - MIN_BOSS_VARIANCE/2) < fWitchFlow && (fTankFlow + MIN_BOSS_VARIANCE/2) > fWitchFlow)
		{
			fWitchFlow += MIN_BOSS_VARIANCE;
		}
		L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
		L4D2Direct_SetVSWitchFlowPercent(0, fWitchFlow);
		L4D2Direct_SetVSWitchFlowPercent(1, fWitchFlow);
	}
}

stock Float:GetTankFlow(round)
{
	return L4D2Direct_GetVSTankFlowPercent(round) - Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();
}

stock Float:GetWitchFlow(round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round) - Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();
}
