#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>

public Plugin:myinfo =
{
	name = "Map Distance Unifier",
	author = "CanadaRox",
	description = "Sets every map to the same max distance",
	version = "1",
	url = "https://github.com/CanadaRox/sourcemod-plugins/unified_dist/"
};

new Handle:hMapDist;

public OnPluginStart()
{
	hMapDist = CreateConVar("map_dist", "200", "Set custom map distance for every map");
}

public OnMapStart()
{
	L4D_SetVersusMaxCompletionScore(GetConVarInt(hMapDist));
}
