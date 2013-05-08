#include <sourcemod>
#include <left4downtown>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

#define COOLDOWN 0.5
#define TEAM_INFECTED 3

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

public Plugin:myinfo =
{
	name = "Jockey Deadstop Fixer",
	author = "CanadaRox",
	description = "Fixes jockeys being instantly killed by deadstops or having deadstops not register if bash-kills are blocked",
	version = "2",
	url = "https://github.com/CanadaRox/sourcemod-plugins/jockey_fix/"
};

public Action:L4D_OnShovedBySurvivor(client, victim, const Float:vector[3])
{
	if (IsPlayerZombie(client) && GetZombieClass(client) == ZC_JOCKEY)
	{
		decl Float:timestamp, Float:duration;
		GetInfectedAbilityTimer(victim, timestamp, duration);
		if (timestamp - GetGameTime() < 0.5)
		{
			SetInfectedAbilityTimer(victim, GetGameTime() + COOLDOWN, COOLDOWN);
		}
	}
}

stock bool:IsPlayerZombie(client) return GetClientTeam(client) == TEAM_INFECTED;
stock ZombieClass:GetZombieClass(client) return ZombieClass:GetEntProp(client, Prop_Send, "m_zombieClass");
