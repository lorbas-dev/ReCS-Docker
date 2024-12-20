#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <xs>

#define CHAT_PREFIX "^1[^4AFKControl^1]"

enum _:cvars {
	MAX_AFK_WARNS,
	MAX_SPEC_WARNS,
	Float:TIME_AFK_CHECK,
	MIN_SPEC_PLAYERS_CHECK,
	IMMUNITY_FLAGS,
	TRANSFER_BOMB
}
enum coords {
	Float:ORIGIN[3],
	Float:ANGLES[3]
}
enum warns {
	AFK,
	SPEC
}

new Float:g_fCoords[MAX_PLAYERS + 1][coords];
new g_iPlayerWarn[MAX_PLAYERS + 1][warns];
new bool:g_IsBot[MAX_PLAYERS + 1];

new g_Cvar[cvars];

public plugin_init()
{
	register_plugin("AFK Control ReNew", "1.2(a)", "neygomon");
	register_dictionary("afk_control.txt");

	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "CSGameRules_PlayerSpawn_Post", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true);

	bind_pcvar_num(
		create_cvar(
			"afk_max_afk_warns", 
			"3", 
			.description = fmt("%l", "DESC_MAX_AFK_WARNS"), 
			.has_min = true, 
			.min_val = 1.0
		), 
		g_Cvar[MAX_AFK_WARNS]
	);
	bind_pcvar_num(
		create_cvar(
			"afk_max_spec_warns", 
			"2", 
			.description = fmt("%l", "DESC_MAX_SPEC_WARNS"), 
			.has_min = true, 
			.min_val = 1.0
		), 
		g_Cvar[MAX_SPEC_WARNS]
	);
	bind_pcvar_num(
		create_cvar(
			"afk_min_spec_players", 
			"30", 
			.description = fmt("%l", "DESC_MIN_SPEC_PLRS")
		), 
		g_Cvar[MIN_SPEC_PLAYERS_CHECK]
	);
	bind_pcvar_num(
		create_cvar(
			"afk_transfer_bomb", 
			"1", 
			.description = fmt("%l", "DESC_TRANSFER_BOMB")
		), 
		g_Cvar[TRANSFER_BOMB]
	);
	bind_pcvar_float(
		create_cvar(
			"afk_time_afk_check", 
			"15.0", 
			.description = fmt("%l", "DESC_TIME_AFK_CHECK"), 
			.has_min = true, 
			.min_val = 5.0
		), 
		g_Cvar[TIME_AFK_CHECK]
	);
	
	new pCvar1 = create_cvar(
		"afk_time_spec_check", 
		"15.0", 
		.description = fmt("%l", "DESC_TIME_SPEC_CHECK"), 
		.has_min = true, 
		.min_val = 10.0
	)
	
	new pCvar2 = create_cvar(
		"afk_immunity_flags", 
		"a", 
		.description = fmt("%l", "DESC_IMMUNITY_FLAGS")
	);
	
	AutoExecConfig();
	hook_cvar_change(pCvar2, "hook__cvar_change");
	new szFlags[32]; get_pcvar_string(pCvar2, szFlags, charsmax(szFlags));
	read__flags(szFlags);
	
	set_task_ex(get_pcvar_float(pCvar1), "check_spectators", .flags = SetTask_Repeat);
}

public client_putinserver(id)
{
	g_IsBot[id] = bool:(is_user_hltv(id) || is_user_bot(id));
	g_iPlayerWarn[id][SPEC] = 0;
}

public client_disconnected(id)
	remove_task(id);

public hook__cvar_change(pCvar, szOldValue[], szNewValue[])
	read__flags(szNewValue);

public CSGameRules_PlayerSpawn_Post(const id)
{
	if(g_IsBot[id]/* || !is_user_alive(id)*/ || get_user_flags(id) & g_Cvar[IMMUNITY_FLAGS])
		return;

	g_iPlayerWarn[id][AFK] = 0;
	get_entvar(id, var_origin, g_fCoords[id][ORIGIN]);
	get_entvar(id, var_angles, g_fCoords[id][ANGLES]);
	
	remove_task(id);
	set_task_ex(g_Cvar[TIME_AFK_CHECK], "check_afk", id, .flags = SetTask_Repeat);
}

public CBasePlayer_Killed_Post(const id)
	remove_task(id);

public check_afk(id)
{
	if(!is_user_alive(id))
		remove_task(id);
	else
	{
		static Float:fOrigin[3], Float:fAngles[3];
		get_entvar(id, var_origin, fOrigin);
		get_entvar(id, var_angles, fAngles);
	
		if(!xs_vec_equal(g_fCoords[id][ORIGIN], fOrigin) || !xs_vec_equal(g_fCoords[id][ANGLES], fAngles))
		{
			g_iPlayerWarn[id][AFK] = 0;
			xs_vec_copy(fOrigin, g_fCoords[id][ORIGIN]);
			xs_vec_copy(fAngles, g_fCoords[id][ANGLES]);
		}
		else if(++g_iPlayerWarn[id][AFK] >= g_Cvar[MAX_AFK_WARNS])
		{
			user_kill(id, 1);
			rg_internal_cmd(id, "jointeam", "6");
			rg_send_audio(id, "sound/events/friend_died.wav");
			client_print_color(0, id, "%s %l", CHAT_PREFIX, "MSG_TRANSFER_PLAYER", id);
		}
		else
		{
			if(rg_has_item_by_name(id, "weapon_c4"))
			{
				client_print_color(0, id, "%s %l", CHAT_PREFIX, "MSG_TRANSFER_BOMB", id);
				
				if(g_Cvar[TRANSFER_BOMB])
					rg_transfer_c4(id, 0);
				else	rg_drop_items_by_slot(id, C4_SLOT);
			}
		
			rg_send_audio(id, "sound/events/tutor_msg.wav");
			client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "MSG_PLAYER_CHECK_ACTIVITY", g_iPlayerWarn[id][AFK], g_Cvar[MAX_AFK_WARNS]);
		}
	}
}

public check_spectators()
{
	if(get_playersnum() < g_Cvar[MIN_SPEC_PLAYERS_CHECK])
		return;

	new players[MAX_PLAYERS], pnum; 
	get_players_ex(players, pnum, GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV|GetPlayers_MatchTeam, "SPECTATOR");
	for(new i, id; i < pnum; i++)
	{
		id = players[i];
	
		if(get_user_flags(id) & g_Cvar[IMMUNITY_FLAGS])
			continue;
		
		switch(get_member(id, m_iTeam)) 
		{
			case TEAM_UNASSIGNED, TEAM_SPECTATOR: 
			{
				if(++g_iPlayerWarn[id][SPEC] >= g_Cvar[MAX_SPEC_WARNS])
				{
					client_print_color(0, id, "%s %l", CHAT_PREFIX, "MSG_KICK_SPEC_REASON", id);
					server_cmd("kick #%d %l", get_user_userid(id), "MSG_KICK_PLAYER_REASON");
				}
			}	
		}	
	}
}

read__flags(str[])
	g_Cvar[IMMUNITY_FLAGS] = read_flags(str);