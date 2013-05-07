#include <l4d2util_infected>
#include <left4downtown>

#define COOLDOWN 0.5

public Plugin:myinfo =
{
	name = "Jockey Deadstop Fixer",
	author = "CanadaRox",
	description = "Fixes jockeys being instantly killed by deadstops or having deadstops not register if bash-kills are blocked",
	version = "1",
	url = "https://github.com/CanadaRox/sourcemod-plugins/jockey_fix/"
};

public Action:L4D_OnShovedBySurvivor(client, victim, const Float:vector[3])
{
	SetInfectedAbilityTimer(victim, GetGameTime() + COOLDOWN, COOLDOWN);
}
