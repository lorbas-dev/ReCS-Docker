#include <amxmodx>
#include <amxmisc>
#include <reapi>

#pragma semicolon 1

#if REAPI_VERSION_MAJOR < 5 && REAPI_VERSION_MINOR < 3
	#error You must be update ReAPI to 5.3.x.x or higher
#endif

// You can comment out something to take off the restriction.
#define LOCK_SAY					// Don't allows invisible spectator say.
//#define AUTO_INVISIBLE_SPECTATOR	// When someone join to spectator it's make invisible automatically

new HookChain:g_hSV_WriteFullClientUpdate;
new bool:g_bPlayerInVisible[MAX_CLIENTS + 1];

public plugin_init()
{
	register_plugin("Invisible Spectator", "1.0", "ReHLDS Team");

	if (!is_rehlds())
	{
		pause("ad");
		set_fail_state("This plugin is not available, ReHLDS required.");
		return;
	}

#if defined LOCK_SAY
	register_clcmd("say", "Host_Say");
	register_clcmd("say_team", "Host_Say");
#endif

#if defined AUTO_INVISIBLE_SPECTATOR
	register_event("TeamInfo", "Event_TeamInfo", "a", "2=TERRORIST", "2=CT", "2=SPECTATOR");
#else
	register_event("TeamInfo", "Event_TeamInfo", "a", "2=TERRORIST", "2=CT");
	register_clcmd("amx_spectate", "ClCmd_Spectate", ADMIN_BAN, "Makes the spectator invisible.");
#endif

	DisableHookChain((g_hSV_WriteFullClientUpdate = RegisterHookChain(RH_SV_WriteFullClientUpdate, "SV_WriteFullClientUpdate")));
}

public SV_WriteFullClientUpdate(const id, buffer, const receiver)
{
	if (g_bPlayerInVisible[id])
	{
		set_key_value(buffer, "", "");
		//set_key_value(buffer, "name",  "");
		//set_key_value(buffer, "model", "");
		//set_key_value(buffer, "*sid",  "");
	}
}

public client_putinserver(id)
{
	g_bPlayerInVisible[id] = false;
}

public Event_TeamInfo()
{
	new id = read_data(1);

#if defined AUTO_INVISIBLE_SPECTATOR
	new bool:bState = g_bPlayerInVisible[id];

	new szTeamName[2];
	read_data(2, szTeamName, charsmax(szTeamName));
	switch (szTeamName[0])
	{
		case 'C', 'T':
		{
			// Reset the invisible state
			g_bPlayerInVisible[id] = false;
		}
		case 'S':
		{
			g_bPlayerInVisible[id] = true;
		}
	}

	if (g_bPlayerInVisible[id] != bState)
	{
		if (!TryDisableHookChain())
		{
			// let's me enable to hookchain, true optimization
			EnableHookChain(g_hSV_WriteFullClientUpdate);
		}
#else
	if (g_bPlayerInVisible[id])
	{
		// Reset the invisible state
		g_bPlayerInVisible[id] = false;
#endif
		// Force update user info
		rh_update_user_info(id);
	}
}

#if defined LOCK_SAY
public Host_Say(id)
{
	if (g_bPlayerInVisible[id])
	{
		client_print(id, print_chat, "You are an invisible spectator, better to be quiet!");
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}
#endif

#if !defined AUTO_INVISIBLE_SPECTATOR
public ClCmd_Spectate(id, level, cid)
{
	if (!cmd_access(id, level, cid, 0))
		return PLUGIN_CONTINUE;

	// Only spectator can be invisible
	if (get_member(id, m_iTeam) != TEAM_SPECTATOR)
	{
		client_print(id, print_chat, "You must be the spectator before you become invisible.");
		return PLUGIN_HANDLED;
	}

	g_bPlayerInVisible[id] ^= true;
	client_print(id, print_chat, "You are now %s.", g_bPlayerInVisible[id] ? "invisible" : "visible");

	if (!TryDisableHookChain())
	{
		// let's me enable to hookchain, true optimization
		EnableHookChain(g_hSV_WriteFullClientUpdate);
	}

	rh_update_user_info(id);
	return PLUGIN_HANDLED;
}
#endif

stock bool:TryDisableHookChain()
{
	// Make sure that there no one uses invisible spectator
	new iPlayers[MAX_CLIENTS], iNum, nCount;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; ++i)
	{
		if (g_bPlayerInVisible[iPlayers[i]])
			++nCount;
	}

	if (nCount <= 0)
	{
		DisableHookChain(g_hSV_WriteFullClientUpdate);
		return true;
	}

	return false;
}

#if defined client_disconnected
public client_disconnected(id)
#else
public client_disconnect(id)
#endif
{
	if (g_bPlayerInVisible[id])
	{
		g_bPlayerInVisible[id] = false;
		TryDisableHookChain();
	}
}
