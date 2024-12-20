#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <engine>
#include <reapi>

#define PLUGIN_VERSION "2.5re"

#if (AMXX_VERSION_NUM < 183) || defined NO_NATIVE_COLORCHAT
	#include <colorchat>
	#include <dhudmessage>
#else
	#define DontChange print_team_default
	#define client_disconnect client_disconnected
#endif

#pragma ctrlchar			'\'
#pragma semicolon			1

#define ID_KEY_WALL			54345678

					//x	//y
#define MESSAGE_MAP_STATUS		-1.0,	0.8				// Позиция сообщении о Закрытии/Открытии карты.


					//r	//green		//blue
#define COLOR_MAP_CLOSE			255,	0,		0		// Цвет сообщения, когда низкий онлайн и карта закрывается. Тип цвета RGB, http://www.colorschemer.com/online.html
#define COLOR_MAP_OPEN			0,	255,		0		// Цвет сообщения, когда онлайн выше требуемого и карта открывается. Тип цвета RGB, http://www.colorschemer.com/online.html

#define MODE_TIME_START			10.0	// Через сколько начать голосование, после нужного количества голосов.
#define MODE_COUNT_START		5	// Отчет до начала голосования
#define VOTE_TIMEWAIT			3	// Через сколько минут после голосования /mode, будет снова доступно.
#define VOTE_RATIO			0.5	// Погрешность для количество голосов, Пример: (Ratio: 0.5, требуется 0.5 * 32 = 16 голосов из 32 игроков)

#define STRONG_PUSH			15.0	// Сила толчка weaponbox (оружия, C4) от стенки
#define MAX_CLIENTS			32

#define PREFIX				"\1[\4Mode\1]"
#define CLASSNAME_WALL			"test_effect" // unused classname in the game
#define SPRITE_WALL			"sprites/mode/wall.spr"

#define Vector(%0,%1,%2)		(Float:{%0,%1,%2})
#define VectorCompare(%0,%1)		(%0[x] == %1[x] && %0[y] == %1[y] && %0[z] == %1[z])
#define VectorDT(%0,%1,%2,%3)		(!(%0[x] > %3[x] || %1[x] < %2[x]) && !(%0[y] > %3[y] || %1[y] < %2[y]) && !(%0[z] > %3[z] || %1[z] < %2[z]))

enum (+= 256222)
{
	TASK_MODE_VOTE = 256222,
	TASK_MODE_START,
	TASK_MODE_INIT,
	TASK_MODE_NOTIFY,
	TASK_MODE_AUTO_MAPCLOSE
};

enum _:coord_s
{
	Float:x,
	Float:y,
	Float:z
};

enum status_s
{
	map_open,
	map_close,
};

enum _:blocked_s
{
	block_none = 0,
	block_vote,
	block_start_vote,
	block_success_vote,
	block_roundnew,
	block_commencing,
	block_admin_change,
	block_permament
};

enum _:vote_s
{
	vote_no,
	vote_yes
};

enum _:server_info_s
{
	status_s:m_iStatus,
	status_s:m_iStatusLast,
	blocked_s:m_iBlocked,
	m_szFile[64],
	m_iAll,
	m_iMaxpl,
	m_iCount,
	m_LoadBox,
	bool:m_bAdvanced,
	bool:m_bInitialized,
	m_iClosedIndex,
	m_iOnline_High,
	m_iOnline_Low,
	m_szMap[32],
	m_iVoting[vote_s],
	m_iVote[MAX_CLIENTS + 1],
	Float:m_fNext,
	Float:m_fWait[MAX_CLIENTS + 1],
};

new g_pServerVar[server_info_s];

enum _:box_data_s
{
	m_iBox,
	m_iCopy,
	m_iType,
	m_iEntid,
	m_iSetting,
	m_iSolid,
	m_iSprite,
	m_iBeamSprite,

	Float:m_fScale
};

new g_pBoxVar[box_data_s];

enum box_vector_s
{
	m_fOrigin,
	m_fAngles,
	m_fMins,
	m_fMaxs
};

new Float:g_pBoxVector[box_vector_s][coord_s];
new HamHook:g_pForwardThink;

// CVars
new pcvar_mode_admin_only,
	pcvar_mode_allow_vote,
	pcvar_mode_allow_change,
	pcvar_mode_force_check_online,
	pcvar_mode_block_startgame,
	pcvar_mode_push_weaponbox,
	pcvar_mode_message_on_touch,
	pcvar_mode_touch_wait,
	pcvar_mode_changemapname;

public plugin_precache()
{
	precache_model(SPRITE_WALL);
	g_pBoxVar[m_iBeamSprite] = precache_model("sprites/smoke.spr");
	get_mapname(g_pServerVar[m_szMap], charsmax(g_pServerVar[m_szMap]));
}

public plugin_init()
{
	register_plugin("Mode 2x2", PLUGIN_VERSION, "s1lent");
	register_cvar("mode2x2_version", PLUGIN_VERSION, FCVAR_SERVER | FCVAR_SPONLY);

	register_menucmd(register_menuid("Main Edit Menu"), 0x3FF, "MainEdit_Handler");
	register_menucmd(register_menuid("Settings Menu"), 0x23F, "Settings_Handler");
	register_menucmd(register_menuid("Properties Menu"), 0x3FF, "Properties_Handler");

	DisableHamForward((g_pForwardThink = RegisterHam(Ham_Think, CLASSNAME_WALL, "CTestEffect__ThinkWall")));

	pcvar_mode_admin_only = register_cvar("mode_admin_only", "0");				// Запрещает второму админу использовать команду "/change", если первый админ его уже использовал для открытия карты и если админ который активировал "/change" - активный и находится в команде.
	pcvar_mode_allow_vote = register_cvar("mode_allow_vote", "1");				// Разрешить использовать команду "/mode"
	pcvar_mode_allow_change = register_cvar("mode_allow_change", "1");			// Разрешить использовать команду "/change"
	pcvar_mode_force_check_online = register_cvar("mode_force_check_online", "1");		// Заставлять проверять онлайн даже при /change, если нет действующих админов в игре, кроме админов в спектаторе, при mode_admin_only, проверяет только одного активного админа.
	pcvar_mode_block_startgame = register_cvar("mode_block_startgame", "0");		// Никогда не ставить стенки при "GameCommencing" или "Restart"
	pcvar_mode_push_weaponbox = register_cvar("mode_push_weaponbox", "1");			// Толкать weaponbox (оружия, C4) от стенки

	pcvar_mode_message_on_touch = register_cvar("mode_messagetouch", "0");			// Сообщать игроку при касании стены о том, что проход закрыт.
	pcvar_mode_touch_wait = register_cvar("mode_messagetouch_time", "5.5");			// Задержка для повторного сообщения при касании стенки игроком.
	pcvar_mode_changemapname = register_cvar("mode_changemapname", "1");

	Load_Config();

	register_clcmd("say /mode", "CMD_Mode", 0, "<Голосование за открытие/закрытие карты>");
	register_clcmd("say /change", "CMD_ModeChange", ADMIN_VOTE, "<Смена режима Mode 2x2, Открыть/Закрыть карту>");

	register_clcmd("say /box", "CMD_MenuBox", ADMIN_RCON, "<Управление объектами, Создание/Изменение/Удаление>");
	register_dictionary("mode.txt");

	// initialized vars
	g_pServerVar[m_iMaxpl] = get_maxplayers();
	g_pServerVar[m_fNext] = _:(get_gametime() + (VOTE_TIMEWAIT * 60.0));
}

public Task_Initialized()
{
	g_pServerVar[m_bInitialized] = true;
	UTIL__ChangeNameOfMap(g_pServerVar[m_iStatus]);
}

public Task_AutoMapClose()
{
	new nActivePlayers = UTIL__GetActivePlayers();
	if (nActivePlayers <= 0)
	{
		DrawBox(g_pServerVar[m_iStatus] = map_close, false);
	}
}

// ready config file
stock Load_Config()
{
	new szCfgDir[128];
	get_configsdir(szCfgDir, charsmax(szCfgDir));
	get_localinfo("amxx_configsdir", g_pServerVar[m_szFile], charsmax(g_pServerVar[m_szFile]));

	add(g_pServerVar[m_szFile], charsmax(g_pServerVar[m_szFile]), "/mode/");
	add(szCfgDir, charsmax(szCfgDir), "/mode.cfg");
	mkdir(g_pServerVar[m_szFile]);

	server_cmd("exec %s", szCfgDir);
	server_exec();

	formatex(g_pServerVar[m_szFile], charsmax(g_pServerVar[m_szFile]), "%s%s.ini", g_pServerVar[m_szFile], g_pServerVar[m_szMap]);

	if (file_exists(g_pServerVar[m_szFile]))
	{
		if (!(g_pServerVar[m_LoadBox] = LoadBox()))
			return;

		DrawBox(g_pServerVar[m_iStatus] = map_open);

		if (get_pcvar_num(pcvar_mode_message_on_touch))
		{
			RegisterHam(Ham_Touch, "player", "CBasePlayer__Touch");
		}

		if (get_pcvar_num(pcvar_mode_push_weaponbox))
		{
			RegisterHam(Ham_Touch, "weaponbox", "CWeaponBox__Touch");
		}

		register_event("HLTV", "EventRoundNew", "a", "1=0", "2=0");
		register_menucmd(register_menuid("Mode Menu"), MENU_KEY_1 | MENU_KEY_2, "Mode_Handler");
		register_event("TextMsg", "EventStartGame", "a", "2=#Game_Commencing", "2=#Game_will_restart_in");

		// when all the configs with 3-rd party plugins already loaded
		if (get_pcvar_num(pcvar_mode_changemapname))
		{
			set_task(3.0, "Task_Initialized", TASK_MODE_INIT);
		}

		// To check if the game is in idle state, no active players.
		// So close the map over time.
		set_task(15.0, "Task_AutoMapClose", TASK_MODE_AUTO_MAPCLOSE);
	}
}

public plugin_end()
{
	// reset mapname
	UTIL__ChangeNameOfMap(map_open);

	remove_task(TASK_MODE_VOTE);
	remove_task(TASK_MODE_START);
	remove_task(TASK_MODE_INIT);
	remove_task(TASK_MODE_NOTIFY);
	remove_task(TASK_MODE_AUTO_MAPCLOSE);
}

public plugin_pause()
{
	// hide wall
	if (g_pServerVar[m_iStatus] == map_close)
		DrawBox(g_pServerVar[m_iStatus] = map_open, false);

	// reset mapname
	UTIL__ChangeNameOfMap(map_open);

	remove_task(TASK_MODE_VOTE);
	remove_task(TASK_MODE_START);
	remove_task(TASK_MODE_INIT);
	remove_task(TASK_MODE_NOTIFY);
	remove_task(TASK_MODE_AUTO_MAPCLOSE);
}

public client_disconnect(id)
{
	if (!g_pServerVar[m_LoadBox])
		return;

	if (g_pServerVar[m_iClosedIndex] == id)
		g_pServerVar[m_iClosedIndex] = 0;

	if (g_pServerVar[m_iVote][id])
	{
		--g_pServerVar[m_iAll];
		g_pServerVar[m_iVote][id] = 0;
	}
}

public EventStartGame()
{
	if (!get_pcvar_num(pcvar_mode_block_startgame))
		return;

	g_pServerVar[m_iBlocked] = blocked_s:block_commencing;
	DrawBox(g_pServerVar[m_iStatus] = map_open, false);
}

public EventRoundNew()
{
	new bool:bCvarChange = get_pcvar_num(pcvar_mode_allow_change) != 0;
	new bool:bCvarVote = get_pcvar_num(pcvar_mode_allow_vote) != 0;
	new bool:bCvarStartGame = get_pcvar_num(pcvar_mode_block_startgame) != 0;

	if (bCvarChange && get_pcvar_num(pcvar_mode_force_check_online) != 0 && g_pServerVar[m_iBlocked] > blocked_s:block_admin_change)
	{
		new bool:bBlocked = false;

		new iPlayers[32], iNum, p;
		get_players(iPlayers, iNum, "ch");

		for (new a = 0; a < iNum; ++a)
		{
			p = iPlayers[a];

			if ((get_user_flags(p) & ADMIN_VOTE) && (1 <= get_member(p, m_iTeam) <= 2))
			{
				// if exists admin initiator closed map, trying block is changed mode
				if (get_pcvar_num(pcvar_mode_admin_only) != 0 && g_pServerVar[m_iClosedIndex] != a)
				{
					continue;
				}

				bBlocked = true;
				break;
			}
		}

		if (!bBlocked && g_pServerVar[m_iOnline_Low] >= UTIL__GetActivePlayers())
		{
			g_pServerVar[m_iBlocked] = blocked_s:block_none;
			DrawBox(g_pServerVar[m_iStatus] = map_close);
		}
	}
	else if (!bCvarChange && !bCvarVote && bCvarStartGame)
	{
		if (g_pServerVar[m_iBlocked] == blocked_s:block_commencing)
			g_pServerVar[m_iBlocked] = blocked_s:block_none;
	}
	/*else if (bCvarChange || bCvarVote)*/
	{
		switch (g_pServerVar[m_iBlocked])
		{
			case block_success_vote:
			{
				DrawBox(g_pServerVar[m_iStatus]);
				g_pServerVar[m_iBlocked] = blocked_s:block_roundnew;
			}
			case block_commencing:
			{
				g_pServerVar[m_iBlocked] = blocked_s:block_none;
			}
			case block_admin_change:
			{
				DrawBox(g_pServerVar[m_iStatus]);
				g_pServerVar[m_iBlocked] = blocked_s:block_permament;
			}
			case block_none:
			{
				new nActivePlayers = UTIL__GetActivePlayers();

				// check condition for open map
				if (nActivePlayers >= g_pServerVar[m_iOnline_High])
				{
					if (g_pServerVar[m_iStatus] == map_close)
						DrawBox(g_pServerVar[m_iStatus] = map_open);
				}
				// check condition for close map
				else if (nActivePlayers <= g_pServerVar[m_iOnline_Low])
				{
					if (g_pServerVar[m_iStatus] == map_open)
						DrawBox(g_pServerVar[m_iStatus] = map_close);
				}
			}
		}
	}
}

public CTestEffect__ThinkWall(const this)
{
	if (g_pBoxVar[m_iEntid] != this)
		return HAM_IGNORED;

	new Float:mins[coord_s], Float:maxs[coord_s], Float:pos[coord_s];

	entity_get_vector(this, EV_VEC_origin, pos);
	entity_get_vector(this, EV_VEC_mins, mins);
	entity_get_vector(this, EV_VEC_maxs, maxs);

	mins[x] += pos[x];
	mins[y] += pos[y];
	mins[z] += pos[z];

	maxs[x] += pos[x];
	maxs[y] += pos[y];
	maxs[z] += pos[z];

	new const color[] = { 255, 0, 0 }; // red
	UTIL_DrawLine(maxs[0], maxs[1], maxs[2], mins[0], mins[1], mins[2], { 0, 255, 0 });	// green

	UTIL_DrawLine(maxs[0], maxs[1], maxs[2], mins[0], maxs[1], maxs[2], color);
	UTIL_DrawLine(maxs[0], maxs[1], maxs[2], maxs[0], mins[1], maxs[2], color);
	UTIL_DrawLine(maxs[0], maxs[1], maxs[2], maxs[0], maxs[1], mins[2], color);

	UTIL_DrawLine(mins[0], mins[1], mins[2], maxs[0], mins[1], mins[2], color);
	UTIL_DrawLine(mins[0], mins[1], mins[2], mins[0], maxs[1], mins[2], color);
	UTIL_DrawLine(mins[0], mins[1], mins[2], mins[0], mins[1], maxs[2], color);

	UTIL_DrawLine(mins[0], maxs[1], maxs[2], mins[0], maxs[1], mins[2], color);
	UTIL_DrawLine(mins[0], maxs[1], mins[2], maxs[0], maxs[1], mins[2], color);
	UTIL_DrawLine(maxs[0], maxs[1], mins[2], maxs[0], mins[1], mins[2], color);
	UTIL_DrawLine(maxs[0], mins[1], mins[2], maxs[0], mins[1], maxs[2], color);
	UTIL_DrawLine(maxs[0], mins[1], maxs[2], mins[0], mins[1], maxs[2], color);
	UTIL_DrawLine(mins[0], mins[1], maxs[2], mins[0], maxs[1], maxs[2], color);

	entity_set_float(this, EV_FL_nextthink, get_gametime() + 0.155);
	return HAM_IGNORED;
}

stock UTIL_DrawLine(const Float:x1, const Float:y1, const Float:z1, const Float:x2, const Float:y2, const Float:z2, const color[3])
{
	new vecStart[3], vecEnd[3];

	vecStart[0] = floatround(x1);
	vecStart[1] = floatround(y1);
	vecStart[2] = floatround(z1);

	vecEnd[0] = floatround(x2);
	vecEnd[1] = floatround(y2);
	vecEnd[2] = floatround(z2);

	UTIL_DrawBeamPoints(vecStart, vecEnd, 2, color);
	return 0;
}

stock UTIL_DrawBeamPoints(const vecStart[3], const vecEnd[3], lifetime, const color[3])
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMPOINTS);
	write_coord(vecStart[0]);
	write_coord(vecStart[1]);
	write_coord(vecStart[2]);
	write_coord(vecEnd[0]);
	write_coord(vecEnd[1]);
	write_coord(vecEnd[2]);
	write_short(g_pBoxVar[m_iBeamSprite]);
	write_byte(0);
	write_byte(0);
	write_byte(lifetime);
	write_byte(10);
	write_byte(0);
	write_byte(color[0]);	// red
	write_byte(color[1]);	// green
	write_byte(color[2]);	// blue
	write_byte(255);
	write_byte(0);
	message_end();
}

public CWeaponBox__Touch(const this, const other)
{
	if (!is_valid_ent(other) || entity_get_int(other, EV_INT_impulse) != ID_KEY_WALL)
		return HAM_IGNORED;

	new Float:flAngles[3], Float:flVelocity[3];

	entity_get_vector(other, EV_VEC_angles, flAngles);
	angle_vector(flAngles, ANGLEVECTOR_FORWARD, flVelocity);

	flVelocity[x] = -flVelocity[x] * STRONG_PUSH;
	flVelocity[y] = -flVelocity[y] * STRONG_PUSH;
	flVelocity[z] = -flVelocity[z] * STRONG_PUSH;

	entity_set_vector(this, EV_VEC_velocity, flVelocity);
	return HAM_IGNORED;
}

public CBasePlayer__Touch(const this, const other)
{
	if (!is_valid_ent(other) || entity_get_int(other, EV_INT_impulse) != ID_KEY_WALL)
	{
		return HAM_IGNORED;
	}

	new Float:flCurrentTime = get_gametime();

	if (flCurrentTime > g_pServerVar[m_fWait][this])
	{
		g_pServerVar[m_fWait][this] = _:(flCurrentTime + get_pcvar_float(pcvar_mode_touch_wait));
		client_print_color(this, DontChange, "%L %L", this, "MODE_PREFIX", this, "MODE_MESSAGE_TOUCH");
		return HAM_IGNORED;
	}

	return HAM_IGNORED;
}

public CMD_ModeChange(id, level, cid)
{
	if (!get_pcvar_num(pcvar_mode_allow_change))
		return PLUGIN_CONTINUE;

	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_CONTINUE;

	if (!g_pServerVar[m_LoadBox])
	{
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_NOT_USED");
		return PLUGIN_HANDLED;
	}

	new szName[32];
	get_user_name(id, szName, charsmax(szName));

	if (g_pServerVar[m_iClosedIndex] != id && is_user_connected(g_pServerVar[m_iClosedIndex]))
	{
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_ADMIN_BUSY_CHANGE", szName);
		return PLUGIN_HANDLED;
	}

	switch (g_pServerVar[m_iBlocked])
	{
	case block_vote:
	{
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_VOTE");
		return PLUGIN_HANDLED;
	}
	case block_start_vote:
	{
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_START_VOTE");
		return PLUGIN_HANDLED;
	}
	case block_success_vote:
	{
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_WAIT_NEW_ROUND");
		return PLUGIN_HANDLED;
	}
	case block_admin_change:
	{
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_ADMIN_CHANGED", id, (g_pServerVar[m_iStatus] == map_close) ? "MODE_ADMIN_CLOSED" : "MODE_ADMIN_OPENED");
		return PLUGIN_HANDLED;
	}
	}

	g_pServerVar[m_iBlocked] = blocked_s:block_admin_change;
	g_pServerVar[m_fNext] = _:(get_gametime() + (VOTE_TIMEWAIT * 60.0));
	g_pServerVar[m_iStatus] ^= map_close;

	if (get_pcvar_num(pcvar_mode_admin_only) != 0)
	{
		g_pServerVar[m_iClosedIndex] = (g_pServerVar[m_iStatus] == map_open) ? id : 0;
	}

	new iPlayers[32], iNum, p;
	get_players(iPlayers, iNum, "ch");

	for (new a = 0; a < iNum; ++a)
	{
		p = iPlayers[a];

		if (get_user_flags(p) & ADMIN_VOTE)
		{
			client_print_color(p, DontChange + id, "%L %L", p, "MODE_PREFIX", p, "MODE_ADMIN_CHANGED_ADMINS", szName, p, (g_pServerVar[m_iStatus] == map_close) ? "MODE_ADMIN_CLOSED" : "MODE_ADMIN_OPENED");
		}
	}

	return PLUGIN_HANDLED;
}

public CMD_Mode(id)
{
	if (!get_pcvar_num(pcvar_mode_allow_vote))
		return PLUGIN_CONTINUE;

	if (!g_pServerVar[m_LoadBox])
	{
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_NOT_USED");
		return PLUGIN_HANDLED;
	}

	switch (g_pServerVar[m_iBlocked])
	{
	case block_vote:
	{
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_VOTE");
		return PLUGIN_HANDLED;
	}
	case block_start_vote:
	{
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_START_VOTE");
		return PLUGIN_HANDLED;
	}
	case block_admin_change:
	{
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_ADMIN_CHANGED", id, (g_pServerVar[m_iStatus] == map_close) ? "MODE_ADMIN_CLOSED" : "MODE_ADMIN_OPENED");
		return PLUGIN_HANDLED;
	}
	}

	new Float:flCurrent = get_gametime();
	if (g_pServerVar[m_fNext] > flCurrent)
	{
		new szBuffer[64];
		getChangeleft(id, floatround(g_pServerVar[m_fNext] - flCurrent), szBuffer, charsmax(szBuffer));
		client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_VOTE_LEFT", szBuffer);
		return PLUGIN_HANDLED;
	}
	else
	{
		new iNumRatio = floatround(VOTE_RATIO * UTIL__GetActivePlayers());
		if (g_pServerVar[m_iVote][id])
			client_print_color(id, DontChange, "%L %L", id, "MODE_PREFIX", id, "MODE_VOTE_ALREADY", g_pServerVar[m_iAll], iNumRatio);

		else
		{
			++g_pServerVar[m_iAll];
			g_pServerVar[m_iVote][id] = 1;

			new iPlayers[32], szName[32], iNum;

			get_players(iPlayers, iNum, "ch");
			get_user_name(id, szName, charsmax(szName));

			for (new a = 0; a < iNum; ++a)
			{
				client_print_color(iPlayers[a], DontChange + id, "%L %L", id, "MODE_PREFIX", id, "MODE_VOTED", szName, id, (g_pServerVar[m_iStatus] == map_close) ? "MODE_VOTE_OPENED" : "MODE_VOTE_CLOSED", g_pServerVar[m_iAll], iNumRatio);
			}

			if (iNumRatio <= g_pServerVar[m_iAll])
			{
				g_pServerVar[m_iCount] = MODE_COUNT_START;
				g_pServerVar[m_iBlocked] = blocked_s:block_vote;

				set_task(MODE_TIME_START, "Task_ModeVote", TASK_MODE_START);
				client_print_color(0, DontChange, "%L %L", LANG_PLAYER, "MODE_PREFIX", LANG_PLAYER, "MODE_MESSAGE_VOTE_START", 10);
			}
		}
	}

	return 1;
}

public Task_ModeVote()
{
	new szBuffer[128];

	if (0 < g_pServerVar[m_iCount]--)
	{
		new szSpeak[24];
		num_to_word(g_pServerVar[m_iCount] + 1, szSpeak, charsmax(szSpeak));
		client_cmd(0, "spk \"fvox/%s\"", szSpeak);

		formatex(szBuffer, charsmax(szBuffer), "%L", LANG_PLAYER, "MODE_VOTE_PRESTART_MENU", LANG_PLAYER, (g_pServerVar[m_iStatus] == map_close) ? "MODE_TITLE_OPENED" : "MODE_TITLE_CLOSED", g_pServerVar[m_iCount] + 1);
		show_menu(0, 0x3FF, szBuffer, 2, "Mode Menu");
		set_task(1.0, "Task_ModeVote", TASK_MODE_START);
	}
	else
	{
		g_pServerVar[m_iBlocked] = blocked_s:block_start_vote;
		formatex(szBuffer, charsmax(szBuffer), "%L", LANG_PLAYER, "MODE_VOTE_POSTSTART_MENU", LANG_PLAYER, (g_pServerVar[m_iStatus] == map_close) ? "MODE_TITLE_OPENED" : "MODE_TITLE_CLOSED");
		show_menu(0, MENU_KEY_1 | MENU_KEY_2, szBuffer, 18, "Mode Menu");
		set_task(20.0, "Task_ResultVote", TASK_MODE_VOTE);
	}
}

public Mode_Handler(id, key)
{
	if (!get_pcvar_num(pcvar_mode_allow_vote))
		return PLUGIN_CONTINUE;

	if (g_pServerVar[m_iBlocked] == blocked_s:block_vote)
	{
		client_cmd(id, "slot%d", key + 1);
		return PLUGIN_HANDLED;
	}

	new szName[32];
	get_user_name(id, szName, charsmax(szName));

	client_print_color(0, DontChange + id, "%L", id, "MODE_VOTE_FORMAT", szName, id, key ? "MODE_VOTE_NO" : "MODE_VOTE_YES");
	++g_pServerVar[m_iVoting][key];

	return PLUGIN_HANDLED;
}

public Task_ResultVote()
{
	g_pServerVar[m_iAll] = 0;
	g_pServerVar[m_fNext] = _:(get_gametime() + (VOTE_TIMEWAIT * 60.0));

	arrayset(g_pServerVar[m_iVote], 0, g_pServerVar[m_iMaxpl]);

	if (g_pServerVar[m_iVoting][vote_no] > g_pServerVar[m_iVoting][vote_yes])
	{
		g_pServerVar[m_iBlocked] = blocked_s:block_success_vote;
		g_pServerVar[m_iStatus] ^= map_close;

		client_print_color(0, DontChange, "%L %L", LANG_PLAYER, "MODE_PREFIX", LANG_PLAYER, "MODE_VOTE_RESULT",
			g_pServerVar[m_iVoting][vote_no],
			g_pServerVar[m_iVoting][vote_yes],
			g_pServerVar[m_iVoting][vote_no] + g_pServerVar[m_iVoting][vote_yes]);

		client_print_color(0,DontChange, "%L %L",
			LANG_PLAYER, "MODE_PREFIX",
			LANG_PLAYER, "MODE_VOTE_SUCCESS",
			LANG_PLAYER, (g_pServerVar[m_iStatus] == map_close) ? "MODE_RESULT_CLOSED" : "MODE_RESULT_OPENED");
	}
	else if (g_pServerVar[m_iVoting][vote_no] < g_pServerVar[m_iVoting][vote_yes])
	{
		g_pServerVar[m_iBlocked] = blocked_s:block_none;

		client_print_color(0, DontChange, "%L %L", LANG_PLAYER, "MODE_PREFIX", LANG_PLAYER, "MODE_VOTE_RESULT",
			g_pServerVar[m_iVoting][vote_no],
			g_pServerVar[m_iVoting][vote_yes],
			g_pServerVar[m_iVoting][vote_no] + g_pServerVar[m_iVoting][vote_yes]);

		client_print_color(0, DontChange, "%L %L", LANG_PLAYER, "MODE_PREFIX", LANG_PLAYER, "MODE_VOTE_FAILED");
	}
	else
	{
		g_pServerVar[m_iBlocked] = blocked_s:block_none;
		client_print_color(0, DontChange, "%L %L", LANG_PLAYER, "MODE_PREFIX", LANG_PLAYER, "MODE_VOTE_FAILED");
	}
}

public CMD_MenuBox(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_CONTINUE;

	if (g_pForwardThink)
		EnableHamForward(g_pForwardThink);

	return Menu_MainEdit(id);
}

stock Menu_MainEdit(id)
{
	new szBuffer[512];
	formatex(szBuffer, charsmax(szBuffer),
		"%L", id, "MODE_DEV_MENU_MAIN",
		g_pBoxVar[m_iBox],
		g_pBoxVar[m_iEntid] > 0 ? "\\d" : "\\w",
		g_pBoxVar[m_iBox] == 0 ? "\\d" : "\\w",
		g_pBoxVar[m_iBox] == 0 ? "\\d" : "\\w",
		id, (g_pBoxVar[m_iEntid] == 0) ? "MODE_DEV_CHANGE" : "MODE_DEV_SAVE",
		(g_pBoxVar[m_iEntid] == 0) ? "\\d" : "\\w",
		(g_pBoxVar[m_iBox] == 0 || g_pBoxVar[m_iEntid] > 0) ? "\\d" : "\\w",
		(g_pBoxVar[m_iCopy] == 0) ? "\\d" : "\\w",
		(g_pBoxVar[m_iBox] == 0 || g_pBoxVar[m_iEntid] > 0) ? "\\d" : "\\w"
	);

	return show_menu(id, 0x3FF, szBuffer, -1, "Main Edit Menu");
}

public MainEdit_Handler(id, key)
{
	switch (key)
	{
		case 0:
		{
			if (g_pBoxVar[m_iEntid] > 0)
			{
				client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_5");
				return Menu_MainEdit(id);
			}

			new Float:p_origin[coord_s], pEnt = CreateBox();
			entity_get_vector(id, EV_VEC_origin, p_origin);

			++g_pBoxVar[m_iBox];
			g_pBoxVar[m_iEntid] = pEnt;
			p_origin[z] += 32.0;

			EnableHamForward(g_pForwardThink);
			entity_set_vector(pEnt, EV_VEC_origin, p_origin);
			entity_set_vector(pEnt, EV_VEC_rendercolor, Vector(255.0, 100.0, 100.0));
		}
		case 1:
		{
			new pEnt, dummy;
			get_user_aiming(id, pEnt, dummy);

			if (is_valid_ent(pEnt))
			{
				new szClassname[32];
				entity_get_string(pEnt, EV_SZ_classname, szClassname, charsmax(szClassname));
				if (!strcmp(szClassname, CLASSNAME_WALL))
				{
					if (--g_pBoxVar[m_iBox] < 0)
						g_pBoxVar[m_iBox] = 0;

					if (g_pBoxVar[m_iEntid] == pEnt)
						g_pBoxVar[m_iEntid] = 0;

					remove_entity(pEnt);
					client_print(id, print_center, "%L", id, "MODE_DEV_SUCCESS_1", "SOLID_BBOX");
				}
				else client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_1");
			}
			else if (is_valid_ent(g_pBoxVar[m_iEntid]))
			{
				pEnt = g_pBoxVar[m_iEntid];
				new Float:v_absmins[coord_s], Float:v_absmaxs[coord_s], Float:e_absmin[coord_s], Float:e_absmax[coord_s];

				entity_get_vector(id, EV_VEC_absmin, v_absmins);
				entity_get_vector(id, EV_VEC_absmax, v_absmaxs);

				v_absmins[x] += 1.0;
				v_absmins[y] += 1.0;
				v_absmins[z] += 3.0;

				v_absmaxs[x] -= 1.0;
				v_absmaxs[y] -= 1.0;
				v_absmaxs[z] -= 17.0;

				entity_get_vector(pEnt, EV_VEC_absmin, e_absmin);
				entity_get_vector(pEnt, EV_VEC_absmax, e_absmax);

				if (VectorDT(e_absmin, e_absmax, v_absmins, v_absmaxs))
				{
					--g_pBoxVar[m_iBox];
					g_pBoxVar[m_iEntid] = 0;
					client_print(id, print_center, "%L", id, "MODE_DEV_SUCCESS_1", (entity_get_int(pEnt, EV_INT_solid) == SOLID_NOT) ? "SOLID_NOT" : "SOLID_BBOX");
					remove_entity(pEnt);
				}
			}
			else client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_1");

			if (!g_pBoxVar[m_iEntid])
			{
				DisableHamForward(g_pForwardThink);
			}
		}
		case 2:
		{
			if (is_valid_ent(g_pBoxVar[m_iEntid]))
			{
				entity_set_int(g_pBoxVar[m_iEntid], EV_INT_solid, SOLID_BBOX);
				entity_set_vector(g_pBoxVar[m_iEntid], EV_VEC_rendercolor, Vector(0.0, 0.0, 0.0));
				entity_set_size(g_pBoxVar[m_iEntid], g_pBoxVector[m_fMins], g_pBoxVector[m_fMaxs]);
				entity_set_float(g_pBoxVar[m_iEntid], EV_FL_nextthink, 0.0);

				g_pBoxVar[m_iEntid] = 0;
				g_pBoxVar[m_fScale] = _:0.250;

				g_pBoxVector[m_fMaxs][x] = 32.0;
				g_pBoxVector[m_fMaxs][y] = 32.0;
				g_pBoxVector[m_fMaxs][z] = 32.0;

				g_pBoxVector[m_fMins][x] = -32.0;
				g_pBoxVector[m_fMins][y] = -32.0;
				g_pBoxVector[m_fMins][z] = -32.0;

				g_pBoxVector[m_fOrigin][x] = 0.0;
				g_pBoxVector[m_fOrigin][y] = 0.0;
				g_pBoxVector[m_fOrigin][z] = 0.0;

				g_pBoxVector[m_fAngles][x] = 0.0;
				g_pBoxVector[m_fAngles][y] = 0.0;
				g_pBoxVector[m_fAngles][z] = 0.0;

				DisableHamForward(g_pForwardThink);
				client_print(id, print_center, "%L", id, "MODE_DEV_SUCCESS_4");
			}
			else
			{
				new pEnt,body;
				get_user_aiming(id, pEnt, body);

				if (is_valid_ent(pEnt))
				{
					new szClassname[32];
					entity_get_string(pEnt, EV_SZ_classname, szClassname, charsmax(szClassname));
					if (!strcmp(szClassname, CLASSNAME_WALL))
					{
						g_pBoxVar[m_iEntid] = pEnt;

						entity_get_vector(pEnt, EV_VEC_mins, g_pBoxVector[m_fMins]);
						entity_get_vector(pEnt, EV_VEC_maxs, g_pBoxVector[m_fMaxs]);

						entity_get_vector(pEnt, EV_VEC_origin, g_pBoxVector[m_fOrigin]);
						entity_get_vector(pEnt, EV_VEC_angles, g_pBoxVector[m_fAngles]);

						g_pBoxVar[m_fScale] = _:(entity_get_float(pEnt, EV_FL_scale));

						EnableHamForward(g_pForwardThink);
						entity_set_int(pEnt, EV_INT_solid, SOLID_NOT);
						entity_set_float(pEnt, EV_FL_nextthink, get_gametime() + 0.1);
						entity_set_vector(pEnt, EV_VEC_rendercolor, Vector(255.0, 100.0, 100.0));
						entity_set_size(pEnt, g_pBoxVector[m_fMins], g_pBoxVector[m_fMaxs]);
						client_print(id, print_center, "%L", id, "MODE_DEV_SUCCESS_5");
					}
					else client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_1");
				}
				else client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_1");
			}
		}
		case 3:
		{
			if (!g_pBoxVar[m_iEntid])
			{
				client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_4");
				return Menu_MainEdit(id);
			}

			return showPropertiesMenu(id);
		}
		case 4:
		{
			return Menu_Settings(id);
		}
		case 5:
		{
			if (g_pBoxVar[m_iEntid] > 0)
			{
				client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_5");
				return Menu_MainEdit(id);
			}

			new pEnt, dummy;
			get_user_aiming(id, pEnt, dummy);

			if (is_valid_ent(pEnt))
			{
				new szClassname[32];
				entity_get_string(pEnt, EV_SZ_classname, szClassname, charsmax(szClassname));
				if (!strcmp(szClassname, CLASSNAME_WALL))
				{
					if (g_pBoxVar[m_iCopy] == pEnt)
					{
						client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_2");
						return Menu_MainEdit(id);
					}

					g_pBoxVar[m_iCopy] = pEnt;
					client_print(id, print_center, "%L", id, "MODE_DEV_SUCCESS_2");
				}
				else client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_1");
			}
			else client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_1");
		}
		case 6:
		{
			if (g_pBoxVar[m_iEntid] > 0)
			{
				client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_5");
				return Menu_MainEdit(id);
			}

			if (!is_valid_ent(g_pBoxVar[m_iCopy]))
			{
				client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_3");
				return Menu_MainEdit(id);
			}

			new Float:p_origin[coord_s], pEnt = CreateBox();
			entity_get_vector(id, EV_VEC_origin, p_origin);

			++g_pBoxVar[m_iBox];
			g_pBoxVar[m_iEntid] = pEnt;
			p_origin[z] += 32.0;

			entity_get_vector(g_pBoxVar[m_iCopy], EV_VEC_mins, g_pBoxVector[m_fMins]);
			entity_get_vector(g_pBoxVar[m_iCopy], EV_VEC_maxs, g_pBoxVector[m_fMaxs]);
			entity_get_vector(g_pBoxVar[m_iCopy], EV_VEC_angles, g_pBoxVector[m_fAngles]);

			g_pBoxVar[m_fScale] = _:(entity_get_float(g_pBoxVar[m_iCopy], EV_FL_scale));
			g_pBoxVar[m_iSprite] = floatround(entity_get_float(g_pBoxVar[m_iCopy], EV_FL_frame));

			entity_set_vector(pEnt, EV_VEC_origin, p_origin);
			entity_set_vector(pEnt, EV_VEC_rendercolor, Vector(255.0, 100.0, 100.0));

			entity_set_vector(pEnt, EV_VEC_mins, g_pBoxVector[m_fMins]);
			entity_set_vector(pEnt, EV_VEC_maxs, g_pBoxVector[m_fMaxs]);
			entity_set_vector(pEnt, EV_VEC_angles, g_pBoxVector[m_fAngles]);

			new iFlags = entity_get_int(g_pBoxVar[m_iCopy], EV_INT_effects);

			entity_set_int(pEnt, EV_INT_effects, iFlags);
			entity_set_float(pEnt, EV_FL_scale, g_pBoxVar[m_fScale]);
			entity_set_float(pEnt, EV_FL_frame, float(g_pBoxVar[m_iSprite]));
		}
		case 8:
		{
			if (!g_pBoxVar[m_iBox])
				client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_4");

			else if (g_pBoxVar[m_iEntid])
				client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_5");

			else boxSave(id);
		}
		case 9:
		{
			return PLUGIN_HANDLED;
		}
	}

	return Menu_MainEdit(id);
}

stock showPropertiesMenu(id)
{
	new szBuffer[512];
	new iLen = formatex(szBuffer, charsmax(szBuffer), "%L", id, "MODE_DEV_MENU_TITLE");

	switch (g_pBoxVar[m_iSetting])
	{
		case 0:
		{
			new Float:iSize = (g_pBoxVar[m_iType] == 0) ? 10.0 : (g_pBoxVar[m_iType] == 1) ? 5.0 : (g_pBoxVar[m_iType] == 2) ? 1.0 : 0.1;
			iLen += formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "%L", id,"MODE_DEV_MENU_COORD",
				g_pBoxVector[m_fOrigin][x],
				g_pBoxVector[m_fOrigin][y],
				g_pBoxVector[m_fOrigin][z], iSize);
		}
		case 1:
		{
			new Float:iSize = (g_pBoxVar[m_iType] == 0) ? 45.0 : (g_pBoxVar[m_iType] == 1) ? 15.0 : (g_pBoxVar[m_iType] == 2) ? 1.0 : 0.5;
			iLen += formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "%L", id,"MODE_DEV_MENU_ANGLES",
				g_pBoxVector[m_fAngles][x],
				g_pBoxVector[m_fAngles][y],
				g_pBoxVector[m_fAngles][z], iSize);
		}
		case 2,3:
		{
			new Float:iSize = (g_pBoxVar[m_iType] == 0) ? 10.0 : (g_pBoxVar[m_iType] == 1) ? 5.0 : (g_pBoxVar[m_iType] == 2) ? 1.0 : 0.5;
			iLen += formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "%L", id,"MODE_DEV_MENU_SIZE",
				g_pBoxVector[m_fMins][x],
				g_pBoxVector[m_fMins][y],
				g_pBoxVector[m_fMins][z],
				g_pBoxVector[m_fMaxs][x],
				g_pBoxVector[m_fMaxs][y],
				g_pBoxVector[m_fMaxs][z], iSize);
		}
		case 4:
		{
			new Float:iSize = ((g_pBoxVar[m_iType] == 0) ? 0.5 : (g_pBoxVar[m_iType] == 1) ? 0.1 : (g_pBoxVar[m_iType] == 2) ? 0.0101 : 0.0051);
			switch (g_pBoxVar[m_iType])
			{
				case 0,1:
					iLen += formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "%L", id,"MODE_DEV_MENU_SCALE_1",
					g_pBoxVar[m_fScale], iSize, iSize, iSize);
				case 2:
					iLen += formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "%L", id,"MODE_DEV_MENU_SCALE_2",
					g_pBoxVar[m_fScale], iSize, iSize, iSize);

				case 3:
					iLen += formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "%L", id,"MODE_DEV_MENU_SCALE_3",
					g_pBoxVar[m_fScale], iSize, iSize, iSize);
			}
		}
	}

	formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "%L", id, "MODE_DEV_MENU_ADDON", id,
	(g_pBoxVar[m_iSetting] == 0) ?
		"MODE_DEV_COORD"
			:
		(g_pBoxVar[m_iSetting] == 1) ?
			"MODE_DEV_ANGLES"
				:
			(g_pBoxVar[m_iSetting] == 2 && g_pServerVar[m_bAdvanced]) ?
				"MODE_DEV_MINS"
					:
				(g_pBoxVar[m_iSetting] == 3 && g_pServerVar[m_bAdvanced]) ?
					"MODE_DEV_MAXS"
						:
					(g_pBoxVar[m_iSetting] == 3) ?
						"MODE_DEV_SIZE"
							:
						"MODE_DEV_SPRITE",
	id,(g_pBoxVar[m_iSprite] == 0) ?
		"MODE_DEV_TITLE"
			:
		(g_pBoxVar[m_iSprite] == 1) ?
			"MODE_DEV_WALL"
				:
			"MODE_DEV_NULL"
	);

	return show_menu(id, (g_pBoxVar[m_iSetting] < 4) ? 0x3FF : 0x3C3, szBuffer, -1, "Properties Menu");
}

public Properties_Handler(id, key)
{
	if (key == 9)
	{
		return Menu_MainEdit(id);
	}

	entity_get_vector(g_pBoxVar[m_iEntid], EV_VEC_origin, g_pBoxVector[m_fOrigin]);
	entity_get_vector(g_pBoxVar[m_iEntid], EV_VEC_angles, g_pBoxVector[m_fAngles]);
	entity_get_vector(g_pBoxVar[m_iEntid], EV_VEC_maxs, g_pBoxVector[m_fMaxs]);
	g_pBoxVar[m_fScale] = _:(entity_get_float(g_pBoxVar[m_iEntid], EV_FL_scale));

	switch (g_pBoxVar[m_iSetting])
	{
		case 0:
		{
			new Float:iSize = (g_pBoxVar[m_iType] == 0) ? 10.0 : (g_pBoxVar[m_iType] == 1) ? 5.0 : (g_pBoxVar[m_iType] == 2) ? 1.0 : 0.1;

			switch (key)
			{
				case 0:	g_pBoxVector[m_fOrigin][x] += iSize;
				case 1:	g_pBoxVector[m_fOrigin][y] += iSize;
				case 2:	g_pBoxVector[m_fOrigin][z] += iSize;
				case 3:	g_pBoxVector[m_fOrigin][x] -= iSize;
				case 4:	g_pBoxVector[m_fOrigin][y] -= iSize;
				case 5:	g_pBoxVector[m_fOrigin][z] -= iSize;
				case 6:
				{
					if (++g_pBoxVar[m_iType] > 3)
						g_pBoxVar[m_iType] = 0;
				}
				case 7:
				{
					if (++g_pBoxVar[m_iSetting] > 4)
						g_pBoxVar[m_iSetting] = 0;

					g_pBoxVar[m_iSetting] = (g_pBoxVar[m_iSprite] > 1 && g_pBoxVar[m_iSetting] == 1) ? 2 + ((g_pServerVar[m_bAdvanced] == false) ? 1 : 0) : g_pBoxVar[m_iSetting];
				}
			}
		}
		case 1:
		{
			new Float:iSize = (g_pBoxVar[m_iType] == 0) ? 45.0 : (g_pBoxVar[m_iType] == 1) ? 15.0 : (g_pBoxVar[m_iType] == 2) ? 1.0 : 0.5;

			switch (key)
			{
				case 0: g_pBoxVector[m_fAngles][x] += iSize;
				case 1: g_pBoxVector[m_fAngles][y] += iSize;
				case 2: g_pBoxVector[m_fAngles][z] += iSize;
				case 3: g_pBoxVector[m_fAngles][x] -= iSize;
				case 4: g_pBoxVector[m_fAngles][y] -= iSize;
				case 5: g_pBoxVector[m_fAngles][z] -= iSize;
				case 6:
				{
					if (++g_pBoxVar[m_iType] > 3)
						g_pBoxVar[m_iType] = 0;
				}
				case 7:
				{
					if (++g_pBoxVar[m_iSetting] > 4)
						g_pBoxVar[m_iSetting] = 0;

					g_pBoxVar[m_iSetting] = (g_pBoxVar[m_iSetting] == 2 && g_pServerVar[m_bAdvanced] == false) ? 3 : g_pBoxVar[m_iSetting];
				}
			}
		}
		case 2:
		{
			new Float:iSize = (g_pBoxVar[m_iType] == 0) ? 10.0 : (g_pBoxVar[m_iType] == 1) ? 5.0 : (g_pBoxVar[m_iType] == 2) ? 1.0 : 0.5;

			switch (key)
			{
				case 0: g_pBoxVector[m_fMins][x] -= iSize;
				case 1: g_pBoxVector[m_fMins][y] -= iSize;
				case 2: g_pBoxVector[m_fMins][z] -= iSize;
				case 3: g_pBoxVector[m_fMins][x] += iSize;
				case 4: g_pBoxVector[m_fMins][y] += iSize;
				case 5: g_pBoxVector[m_fMins][z] += iSize;
				case 6:
				{
					if (++g_pBoxVar[m_iType] > 3)
						g_pBoxVar[m_iType] = 0;
				}
				case 7:
				{
					if (++g_pBoxVar[m_iSetting] > 4)
						g_pBoxVar[m_iSetting] = 0;
				}
			}
		}
		case 3:
		{
			new Float:iSize = (g_pBoxVar[m_iType] == 0) ? 10.0 : (g_pBoxVar[m_iType] == 1) ? 5.0 : (g_pBoxVar[m_iType] == 2) ? 1.0 : 0.5;

			switch (key)
			{
				case 0: g_pBoxVector[m_fMaxs][x] += iSize;
				case 1: g_pBoxVector[m_fMaxs][y] += iSize;
				case 2: g_pBoxVector[m_fMaxs][z] += iSize;
				case 3: g_pBoxVector[m_fMaxs][x] -= iSize;
				case 4: g_pBoxVector[m_fMaxs][y] -= iSize;
				case 5: g_pBoxVector[m_fMaxs][z] -= iSize;
				case 6:
				{
					if (++g_pBoxVar[m_iType] > 3)
						g_pBoxVar[m_iType] = 0;
				}
				case 7:
				{
					if (++g_pBoxVar[m_iSetting] > 4)
						g_pBoxVar[m_iSetting] = 0;

					g_pBoxVar[m_iSetting] = (g_pBoxVar[m_iSprite] > 1 && g_pBoxVar[m_iSetting] == 4) ? 0 : g_pBoxVar[m_iSetting];
				}
			}
		}
		case 4:
		{
			new Float:iSize = (g_pBoxVar[m_iType] == 0) ? 0.5 : (g_pBoxVar[m_iType] == 1) ? 0.1 : (g_pBoxVar[m_iType] == 2) ? 0.0101 : 0.0051;

			if (iSize > g_pBoxVar[m_fScale])
			{
				if (++g_pBoxVar[m_iType] > 3)
					g_pBoxVar[m_iType] = 0;

				iSize = (g_pBoxVar[m_iType] == 0) ? 0.5 : (g_pBoxVar[m_iType] == 1) ? 0.1 : (g_pBoxVar[m_iType] == 2) ? 0.0101 : 0.0051;
			}
			switch (key)
			{
				case 0:	g_pBoxVar[m_fScale] += iSize;
				case 1: g_pBoxVar[m_fScale] -= iSize;
				case 6:
				{
					if (++g_pBoxVar[m_iType] > 3)
						g_pBoxVar[m_iType] = 0;
				}
				case 7:
				{
					if (++g_pBoxVar[m_iSetting] > 4)
						g_pBoxVar[m_iSetting] = 0;
				}
			}
		}
	}
	switch (key)
	{
		case 8:
		{
			if (is_valid_ent(g_pBoxVar[m_iEntid]))
			{
				if (++g_pBoxVar[m_iSprite] > 2)
					g_pBoxVar[m_iSprite] = 0;

				new iFlags = entity_get_int(g_pBoxVar[m_iEntid], EV_INT_effects);

				if (g_pBoxVar[m_iSprite] > 1)
					entity_set_int(g_pBoxVar[m_iEntid], EV_INT_effects, iFlags | EF_NODRAW);

				else if (iFlags & EF_NODRAW)
					entity_set_int(g_pBoxVar[m_iEntid], EV_INT_effects, iFlags &~ EF_NODRAW);

				entity_set_float(g_pBoxVar[m_iEntid], EV_FL_frame, float(g_pBoxVar[m_iSprite]));
			}
		}
	}
	if (g_pBoxVar[m_fScale] < 0.0051)
		g_pBoxVar[m_fScale] = _:0.0051;

	if (g_pServerVar[m_bAdvanced])
	{
		if (g_pBoxVector[m_fMins][x] > 0.0)
			g_pBoxVector[m_fMins][x] = 0.0;

		else if (g_pBoxVector[m_fMins][y] > 0.0)
			g_pBoxVector[m_fMins][y] = 0.0;

		else if (g_pBoxVector[m_fMins][z] > 0.0)
			g_pBoxVector[m_fMins][z] = 0.0;

		if (g_pBoxVector[m_fMaxs][x] < 0.0)
			g_pBoxVector[m_fMaxs][x] = 0.0;

		else if (g_pBoxVector[m_fMaxs][y] < 0.0)
			g_pBoxVector[m_fMaxs][y] = 0.0;

		else if (g_pBoxVector[m_fMaxs][z] < 0.0)
			g_pBoxVector[m_fMaxs][z] = 0.0;

	}
	else
	{
		if (g_pBoxVector[m_fMaxs][x] < 1.0)
			g_pBoxVector[m_fMaxs][x] = 1.0;

		else if (g_pBoxVector[m_fMaxs][y] < 1.0)
			g_pBoxVector[m_fMaxs][y] = 1.0;

		else if (g_pBoxVector[m_fMaxs][z] < 1.0)
			g_pBoxVector[m_fMaxs][z] = 1.0;
	}

	if (g_pBoxVector[m_fAngles][x] >= 360.0 || g_pBoxVector[m_fAngles][x] <= -360.0)
		g_pBoxVector[m_fAngles][x] = 0.0;

	if (g_pBoxVector[m_fAngles][y] >= 360.0 || g_pBoxVector[m_fAngles][y] <= -360.0)
		g_pBoxVector[m_fAngles][y] = 0.0;

	if (g_pBoxVector[m_fAngles][z] >= 360.0 || g_pBoxVector[m_fAngles][z] <= -360.0)
		g_pBoxVector[m_fAngles][z] = 0.0;

	if (!g_pServerVar[m_bAdvanced])
	{
		g_pBoxVector[m_fMins][x] = -g_pBoxVector[m_fMaxs][x];
		g_pBoxVector[m_fMins][y] = -g_pBoxVector[m_fMaxs][y];
		g_pBoxVector[m_fMins][z] = -g_pBoxVector[m_fMaxs][z];
	}

	entity_set_float(g_pBoxVar[m_iEntid], EV_FL_scale, g_pBoxVar[m_fScale]);
	entity_set_vector(g_pBoxVar[m_iEntid], EV_VEC_angles, g_pBoxVector[m_fAngles]);
	entity_set_float(g_pBoxVar[m_iEntid], EV_FL_nextthink, get_gametime() + 0.1);
	entity_set_int(g_pBoxVar[m_iEntid], EV_INT_solid, g_pBoxVar[m_iSolid] ? SOLID_BBOX : SOLID_NOT);

	entity_set_size(g_pBoxVar[m_iEntid], g_pBoxVector[m_fMins], g_pBoxVector[m_fMaxs]);
	entity_set_vector(g_pBoxVar[m_iEntid], EV_VEC_origin, g_pBoxVector[m_fOrigin]);

	return showPropertiesMenu(id);
}

stock Menu_Settings(id)
{
	new szMenu[512];
	formatex(szMenu, charsmax(szMenu), "%L", id, "MODE_DEV_MENU_CONFIG",
		id, (g_pBoxVar[m_iEntid] == 0) ? "MODE_DEV_SOLID_D" : "MODE_DEV_SOLID",
		g_pBoxVar[m_iSolid] ? "SOLID_BBOX" : "SOLID_NOT",
		(g_pBoxVar[m_iBox] == 0) ? "\\d" : "\\w",
		id, (g_pServerVar[m_iStatus] == map_close) ? "MODE_DEV_HIDE" : "MODE_DEV_SHOW",
		g_pServerVar[m_iOnline_Low], g_pServerVar[m_iOnline_High],
		id, entity_get_int(id, EV_INT_movetype) == MOVETYPE_NOCLIP ? "MODE_DEV_YES" : "MODE_DEV_NO",
		id, g_pServerVar[m_bAdvanced] ? "MODE_DEV_YES" : "MODE_DEV_NO");

	return show_menu(id, 0x23F, szMenu, -1, "Settings Menu");
}

public Settings_Handler(id, key)
{
	switch (key)
	{
		case 0:
		{
			if (!g_pBoxVar[m_iEntid])
			{
				client_print(id, print_center, "%L", id, "MODE_DEV_FAILED_4");
				return Menu_Settings(id);
			}

			entity_set_float(g_pBoxVar[m_iEntid], EV_FL_nextthink, get_gametime() + 0.1);
			entity_set_int(g_pBoxVar[m_iEntid], EV_INT_solid, (g_pBoxVar[m_iSolid] ^= 1) ? SOLID_BBOX : SOLID_NOT);
			entity_set_size(g_pBoxVar[m_iEntid], g_pBoxVector[m_fMins], g_pBoxVector[m_fMaxs]);

			client_print(id,print_center, "%L", id, "MODE_DEV_SUCCESS_6", g_pBoxVar[m_iSolid] ? "SOLID_BBOX" : "SOLID_NOT");
		}
		case 1:
		{
			if (g_pBoxVar[m_iBox])
				DrawBoxDev((g_pServerVar[m_iStatus] ^= map_close));
		}
		case 2:
		{
			if (++g_pServerVar[m_iOnline_Low] > g_pServerVar[m_iOnline_High])
				g_pServerVar[m_iOnline_Low] = 0;
		}
		case 3:
		{
			if (++g_pServerVar[m_iOnline_High] > g_pServerVar[m_iMaxpl])
				g_pServerVar[m_iOnline_High] = g_pServerVar[m_iOnline_Low];
		}
		case 4:
		{
			if (is_user_alive(id))
			{
				entity_set_int(id, EV_INT_movetype, (entity_get_int(id, EV_INT_movetype) == MOVETYPE_NOCLIP) ? MOVETYPE_WALK : MOVETYPE_NOCLIP);
			}
		}
 		case 5: g_pServerVar[m_bAdvanced] ^= true;
		case 9:	return Menu_MainEdit(id);
	}

	return Menu_Settings(id);
}

stock getChangeleft(id, time, output[], lenght)
{
	if (time > 0)
	{
		new minute = 0, second = 0;

		second = time;

		minute = second / 60;
		second -= (minute * 60);

		new szBuffer[2][33], ending[22], num = -1;

		if (minute > 0)
		{
			getEnding(minute, "MODE_MINUT", "MODE_MINUTE", "MODE_MINUTES", 21, ending);
			formatex(szBuffer[++num], charsmax(szBuffer[]), "%i %L", minute, id, ending);
		}
		if (second > 0)
		{
			getEnding(second, "MODE_SECOND", "MODE_SECUNDE", "MODE_SECONDS", 21, ending);
			formatex(szBuffer[++num], charsmax(szBuffer[]), "%i %L", second, id, ending);
		}
		switch (num)
		{
		case 0: formatex(output, lenght, "%s", szBuffer[0]);
		case 1: formatex(output, lenght, "%L", id, "MODE_AND", szBuffer[0], szBuffer[1]);
		}
	}
	else formatex(output, lenght, "0 %L", id, "MODE_SECOND");
}

stock getEnding(num, const a[], const b[], const c[], lenght, output[])
{
	new num100 = num % 100, num10 = num % 10, szBuffer[22];
	if (num100 >= 5 && num100 <= 20 || num10 == 0 || num10 >= 5 && num10 <= 9)
		copy(szBuffer, 21, a);

	else if (num10 == 1)
		copy(szBuffer, 21, b);

	else if (num10 >= 2 && num10 <= 4)
		copy(szBuffer, 21, c);

	return formatex(output, lenght, "%s", szBuffer);
}

stock boxSave(id)
{
	delete_file(g_pServerVar[m_szFile]);

	new szBuffer[1024], Float:frame, Float:p_origin[coord_s], Float:p_angles[coord_s], Float:p_mins[coord_s], Float:p_maxs[coord_s], Float:p_scale, p_sprite, count, pEnt = -1;
	if (g_pServerVar[m_iOnline_High] != 0)
		formatex(szBuffer, charsmax(szBuffer),"ONLINE=%d,%d", g_pServerVar[m_iOnline_Low], g_pServerVar[m_iOnline_High]);
	else
		formatex(szBuffer, charsmax(szBuffer),"ONLINE=%d", g_pServerVar[m_iOnline_Low]);

	write_file(g_pServerVar[m_szFile], szBuffer, 0);

	while ((pEnt = find_ent_by_class(pEnt, CLASSNAME_WALL)))
	{
		if (g_pBoxVar[m_iEntid] == pEnt)
			continue;

		entity_get_vector(pEnt, EV_VEC_origin, p_origin);
		entity_get_vector(pEnt, EV_VEC_angles, p_angles);
		entity_get_vector(pEnt, EV_VEC_mins, p_mins);
		entity_get_vector(pEnt, EV_VEC_maxs, p_maxs);

		p_scale = entity_get_float(pEnt, EV_FL_scale);
		frame = entity_get_float(pEnt, EV_FL_frame);

		p_sprite = floatround(frame);

		formatex(szBuffer, charsmax(szBuffer),
			"\"%f\" \"%f\" \"%f\" \"%f\" \"%f\" \"%f\" \"%f\" \"%f\" \"%f\" \"%f\" \"%f\" \"%f\" \"%f\" \"%d\"",
			p_origin[x], p_origin[y], p_origin[z],
			p_angles[x], p_angles[y], p_angles[z],
			p_mins[x], p_mins[y], p_mins[z],
			p_maxs[x], p_maxs[y], p_maxs[z],
			p_scale,
			p_sprite
		);

		write_file(g_pServerVar[m_szFile], szBuffer, -1);
		++count;
	}

	if (id && count > 0)
	{
		client_print(id,print_center, "%L", id, "MODE_DEV_SUCCESS_3");
	}
}

stock bool:LoadBox()
{
	new szBuffer[2048], szKey[32], szValue[32], p_origin[coord_s][6], p_angles[coord_s][6], p_mins[coord_s][6], p_maxs[coord_s][6], p_scale[6], p_sprite[6];
	new file = fopen(g_pServerVar[m_szFile], "r");
	if (!file)
	{
		return false;
	}

	while (!feof(file))
	{
		fgets(file, szBuffer, charsmax(szBuffer));

		if (szBuffer[0] == EOS || szBuffer[0] == ';')
			continue;

		trim(szBuffer);
		strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');

		if (!strcmp(szKey, "ONLINE"))
		{
			new szOnlineLow[5], szOnlineHigh[5];
			strtok(szValue, szOnlineLow, charsmax(szOnlineLow), szOnlineHigh, charsmax(szOnlineHigh), ',');

			g_pServerVar[m_iOnline_Low] = str_to_num(szOnlineLow);
			g_pServerVar[m_iOnline_High] = str_to_num(szOnlineHigh);

			if (g_pServerVar[m_iOnline_High] == 0)
				g_pServerVar[m_iOnline_High] = g_pServerVar[m_iOnline_Low];

			if (g_pServerVar[m_iOnline_Low] > g_pServerVar[m_iOnline_High])
				g_pServerVar[m_iOnline_Low] = g_pServerVar[m_iOnline_High];

			continue;
		}

		// parse data on line
		parse(szBuffer,
			p_origin[x],	5, p_origin[y],	5, p_origin[z],	5,	// origin
			p_angles[x],	5, p_angles[y],	5, p_angles[z],	5,	// angles
			p_mins[x],	5, p_mins[y],	5, p_mins[z],	5,	// mins
			p_maxs[x],	5, p_maxs[y],	5, p_maxs[z],	5,	// maxs
			p_scale,	5,					// scale
			p_sprite,	5);					// sprite

		g_pBoxVector[m_fOrigin][x] = str_to_float(p_origin[x]);
		g_pBoxVector[m_fOrigin][y] = str_to_float(p_origin[y]);
		g_pBoxVector[m_fOrigin][z] = str_to_float(p_origin[z]);

		g_pBoxVector[m_fAngles][x] = str_to_float(p_angles[x]);
		g_pBoxVector[m_fAngles][y] = str_to_float(p_angles[y]);
		g_pBoxVector[m_fAngles][z] = str_to_float(p_angles[z]);

		g_pBoxVector[m_fMins][x] = str_to_float(p_mins[x]);
		g_pBoxVector[m_fMins][y] = str_to_float(p_mins[y]);
		g_pBoxVector[m_fMins][z] = str_to_float(p_mins[z]);

		g_pBoxVector[m_fMaxs][x] = str_to_float(p_maxs[x]);
		g_pBoxVector[m_fMaxs][y] = str_to_float(p_maxs[y]);
		g_pBoxVector[m_fMaxs][z] = str_to_float(p_maxs[z]);

		g_pBoxVar[m_fScale] = _:(str_to_float(p_scale));
		g_pBoxVar[m_iSprite] = str_to_num(p_sprite);

		CreateBox(true);
		++g_pBoxVar[m_iBox];
	}

	fclose(file);
	return g_pBoxVar[m_iBox] > 0 ? true : false;
}

stock UTIL__GetActivePlayers()
{
	new iNum = 0;
	for (new nIndex = 1; nIndex <= g_pServerVar[m_iMaxpl]; ++nIndex)
	{
		if (!is_user_connected(nIndex) || !(1 <= get_member(nIndex, m_iTeam) <= 2))
			continue;

		++iNum;
	}

	return iNum;
}

stock DrawBoxDev(status_s:st)
{
	new pEnt = -1;
	while ((pEnt = find_ent_by_class(pEnt, CLASSNAME_WALL)))
	{
		entity_set_int(pEnt, EV_INT_solid, st == map_close ? SOLID_BBOX : SOLID_NOT);

		if (g_pBoxVar[m_iEntid] == pEnt || entity_get_float(pEnt, EV_FL_frame) > 1.0)
			continue;

		new iFlags = entity_get_int(pEnt, EV_INT_effects);
		entity_set_int(pEnt, EV_INT_effects, st == map_close ? (iFlags &~ EF_NODRAW) : (iFlags | EF_NODRAW));
	}
}

stock DrawBox(status_s:st, bool:bShow = true)
{
	new pEnt = -1;
	while ((pEnt = find_ent_by_class(pEnt, CLASSNAME_WALL)))
	{
		entity_set_int(pEnt, EV_INT_solid, (st == map_close) ? SOLID_BBOX : SOLID_NOT);

		if (entity_get_float(pEnt, EV_FL_frame) > 1)
			continue;

		new iFlags = entity_get_int(pEnt, EV_INT_effects);
		entity_set_int(pEnt, EV_INT_effects, (st == map_close) ? iFlags &~ EF_NODRAW : iFlags | EF_NODRAW);
	}

	if (g_pServerVar[m_bInitialized])
	{
		UTIL__ChangeNameOfMap(st);
	}

	new arg[2];
	arg[0] = _:st;

	switch (st)
	{
		case map_open:
		{
			g_pServerVar[m_iAll] = 0;
			arrayset(g_pServerVar[m_iVote], 0, g_pServerVar[m_iMaxpl]);

			if (bShow)
			{
				g_pServerVar[m_iAll] = 0;
				set_task(0.7, "Task_NotifyStatusMap", TASK_MODE_NOTIFY, arg, sizeof(arg));
			}
		}
		case map_close:
		{
			if (bShow)
			{
				g_pServerVar[m_iAll] = 0;
				set_task(0.7, "Task_NotifyStatusMap", TASK_MODE_NOTIFY, arg, sizeof(arg));
			}
		}
	}

	UTIL__MoveSpawnSpot(st);
	g_pServerVar[m_iStatusLast] = st;
}

public Task_NotifyStatusMap(arg[])
{
	if (arg[0] == any:map_open)
	{
		set_dhudmessage(COLOR_MAP_OPEN, MESSAGE_MAP_STATUS, 2, 0.1, 2.0, 0.05, 0.2);
		show_dhudmessage(0, "%L", LANG_PLAYER, "MODE_MESSAGE_MAP_OPENED");
	}
	else
	{
		set_dhudmessage(COLOR_MAP_CLOSE, MESSAGE_MAP_STATUS, 2, 0.1, 2.0, 0.05, 0.2);
		show_dhudmessage(0, "%L", LANG_PLAYER, "MODE_MESSAGE_MAP_CLOSED");
	}
}

stock CreateBox(bool:bParse = false)
{
	new pEnt = create_entity(CLASSNAME_WALL);

	if (!pEnt)
	{
		return 0;
	}

	entity_set_int(pEnt, EV_INT_movetype, MOVETYPE_FLY);
	entity_set_int(pEnt, EV_INT_impulse, ID_KEY_WALL);

	if (bParse)
	{
		entity_set_model(pEnt, SPRITE_WALL);
		entity_set_size(pEnt, g_pBoxVector[m_fMins], g_pBoxVector[m_fMaxs]);

		entity_set_float(pEnt, EV_FL_scale, g_pBoxVar[m_fScale]);
		entity_set_vector(pEnt, EV_VEC_angles, g_pBoxVector[m_fAngles]);
		entity_set_int(pEnt, EV_INT_solid, SOLID_BBOX);

		if (g_pBoxVar[m_iSprite] > 1)
			entity_set_int(pEnt, EV_INT_effects, entity_get_int(pEnt, EV_INT_effects) | EF_NODRAW);

		g_pBoxVar[m_iSprite] = 1; // never show text

		entity_set_float(pEnt, EV_FL_frame, float(g_pBoxVar[m_iSprite]));
		entity_set_int(pEnt, EV_INT_rendermode, kRenderTransAdd);
		entity_set_float(pEnt, EV_FL_renderamt, 175.0);
		entity_set_vector(pEnt, EV_VEC_origin, g_pBoxVector[m_fOrigin]);
	}
	else
	{
		g_pBoxVector[m_fAngles][x] = 0.0;
		g_pBoxVector[m_fAngles][y] = 0.0;
		g_pBoxVector[m_fAngles][z] = 0.0;

		g_pBoxVector[m_fMaxs][x] = 32.0;
		g_pBoxVector[m_fMaxs][y] = 32.0;
		g_pBoxVector[m_fMaxs][z] = 32.0;

		g_pBoxVector[m_fMins][x] = -32.0;
		g_pBoxVector[m_fMins][y] = -32.0;
		g_pBoxVector[m_fMins][z] = -32.0;

		g_pBoxVar[m_fScale] = _:0.250;

		entity_set_model(pEnt, SPRITE_WALL);
		entity_set_size(pEnt, g_pBoxVector[m_fMins], g_pBoxVector[m_fMaxs]);

		entity_set_float(pEnt, EV_FL_scale, g_pBoxVar[m_fScale]);
		entity_set_vector(pEnt, EV_VEC_angles, g_pBoxVector[m_fAngles]);
		entity_set_int(pEnt, EV_INT_solid, SOLID_NOT);

		entity_set_float(pEnt, EV_FL_frame, float(g_pBoxVar[m_iSprite]));

		entity_set_int(pEnt, EV_INT_rendermode, kRenderTransAdd);
		entity_set_float(pEnt, EV_FL_renderamt, 175.0);

		entity_set_float(pEnt, EV_FL_nextthink, get_gametime() + 0.1);

		return pEnt;
	}

	return 0;
}

stock UTIL__ChangeNameOfMap(status_s:st)
{
	if (!get_pcvar_num(pcvar_mode_changemapname))
		return;

	switch (st)
	{
	// reset mapname
	case map_open:
		rh_reset_mapname();
	case map_close:
	{
		new szPrefix2x2[32];
		formatex(szPrefix2x2, charsmax(szPrefix2x2), "%s_2x2", g_pServerVar[m_szMap]);
		rh_set_mapname(szPrefix2x2);
	}
	}
}

new const Float:g_vecSpawnSpot[][coord_s] =
{
	// original spot spawn
	{-1024.0, -800.0, 176.0},
	{-1024.0, -704.0, 176.0},
	{-1024.0, -896.0, 192.0},

	{-826.0, -970.0, 200.0},
	{-726.0, -970.0, 200.0},
	{-626.0, -970.0, 200.0}
};

stock UTIL__MoveSpawnSpot(status_s:st)
{
	// If the status has not changed
	if (g_pServerVar[m_iStatusLast] == st)
		return;

	// To move the origin of the T spawn on de_dust2, which are beyond the arch.
	if (!strcmp(g_pServerVar[m_szMap], "de_dust2"))
	{
		new ent = -1;
		new direction = (st == map_open) ? -1 : 1;
		new index = (st == map_open) ? 3 : 0;

		while ((ent = find_ent_by_class(ent, "info_player_deathmatch")))
		{
			new Float:vecSpot[3];
			entity_get_vector(ent, EV_VEC_origin, vecSpot);

			for (new i = 0 + index; i < 3 + index; ++i)
			{
				if (VectorCompare(vecSpot, g_vecSpawnSpot[i]))
				{
					entity_set_vector(ent, EV_VEC_origin, g_vecSpawnSpot[i + 3 * direction]);
					break;
				}
			}
		}
	}
}
