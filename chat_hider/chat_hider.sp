#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <readyup>

#define R_NORMAL (1 << 0)
#define R_READY  (1 << 1)

public Plugin:myinfo =
{
	name = "Chat Hider",
	author = "CanadaRox",
	description = "Hides specific strings from showing up in chat",
	version = "1",
	url = "https://github.com/CanadaRox/sourcemod-plugins/"
};

new Handle:filterTrie;
new bool:readyUpIsAvailable;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("IsInReady");
	return APLRes_Success;
}

public OnPluginStart()
{
	filterTrie = CreateTrie();

	RegAdminCmd("sm_addfilter", AddFilter_Cmd, ADMFLAG_KICK);
	RegAdminCmd("sm_rmfilter", RmFilter_Cmd, ADMFLAG_KICK);
	RegAdminCmd("sm_clearfilter", ClearFilter_Cmd, ADMFLAG_KICK);

	AddCommandListener(Say_Cmd, "say");
	AddCommandListener(Say_Cmd, "say_team");
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

public Action:AddFilter_Cmd(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_addfilter <filter> <rule>");
		return Plugin_Handled;
	}
	decl String:filter[32];
	GetCmdArg(2, filter, sizeof(filter));
	new rule = StringToInt(filter);
	GetCmdArg(1, filter, sizeof(filter));
	SetTrieValue(filterTrie, filter, rule)
	ReplyToCommand(client, "%s added to filter list with rule %d", filter, rule);
	return Plugin_Handled;
}

public Action:RmFilter_Cmd(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_addfilter <filter> <rule>");
		return Plugin_Handled;
	}
	decl String:filter[32];
	GetCmdArg(1, filter, sizeof(filter));
	if (RemoveFromTrie(filterTrie, filter))
	{ 
		ReplyToCommand(client, "%s removed from filter list", filter);
	}
	else
	{
		ReplyToCommand(client, "%s not found in filter list", filter);
	}
	return Plugin_Handled;
}

public Action:ClearFilter_Cmd(client, args)
{
	ClearTrie(filterTrie);
	ReplyToCommand(client, "Filter list cleared");
}

public Action:Say_Cmd(client, const String:command[], argc)
{
	decl String:arg_buffer[32];
	GetCmdArg(1, arg_buffer, sizeof(arg_buffer));
	decl rule;
	if (GetTrieValue(filterTrie, arg_buffer, rule))
	{
		if (rule & 2 && readyUpIsAvailable && IsInReady())
		{
			return Plugin_Stop;
		}
		 /*If it doesn't match any other rule it is considered "normal" */
		else if (rule & 1)
		{
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}
