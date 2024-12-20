#include <amxmodx>
#include <amxmisc>
#include <engine>

#if AMXX_VERSION_NUM < 183 || !defined set_dhudmessage
	#tryinclude <dhudmessage>

	#if !defined _dhudmessage_included
		#error "dhudmessage.inc" is missing in your "scripting/include" folder. Download it from: "https://amxx-bg.info/inc/"
	#endif
#endif

new const PLUGIN_VERSION[] = "3.1"
new const SYM_NEWLINE[] = "%n%"

#if !defined MAX_NAME_LENGTH
	const MAX_NAME_LENGTH = 32
#endif

const Float:TIMER_THINK   = 1.0
const MAX_POSITION_VALUES = 2
const MAX_RGB_VALUES      = 3
const MAX_STYLE_LENGTH    = 64
const MAX_TIMER_LENGTH    = 256
const MAX_FILENAME_LENGTH = 256

enum _:RGBColors
{
	RED,
	GREEN,
	BLUE
}

enum _:Sections
{
	SECTION_NONE,
	SECTION_SETTINGS,
	SECTION_STYLES
}

enum _:MessageTypes
{
	MSGTYPE_HUD,
	MSGTYPE_DHUD,
	MSGTYPE_CENTER
}

enum _:StyleModes
{
	STYLEMODE_MANUAL,
	STYLEMODE_CONSECUTIVE,
	STYLEMODE_RANDOM
}

enum _:ColorModes
{
	COLORMODE_ONE_COLOR,
	COLORMODE_COLOR_CYCLE,
	COLORMODE_RANDOM
}

enum _:Settings
{
	STYLE_MODE,
	TIMER_STYLE,
	COLOR_MODE,
	STARTING_COLOR[MAX_RGB_VALUES],
	Float:STARTING_POSITION[MAX_POSITION_VALUES],
	bool:ENABLE_POSITION_CYCLE,
	MESSAGE_TYPE,
	bool:OVERWRITE_ROUND_TIMER,
	TIMER_SYNC,
	START_MESSAGE_AT,
	START_VOICE_AT,
	VOICE_SPEAKER[MAX_NAME_LENGTH]
}

enum _:Styles
{
	Begin[MAX_STYLE_LENGTH],
	Add[MAX_STYLE_LENGTH],
	End[MAX_STYLE_LENGTH],
	ReplaceSymbol[MAX_STYLE_LENGTH],
	ReplaceWith[MAX_STYLE_LENGTH],
	bool:DoReplace
}

new g_eSettings[Settings]
new g_eTimer[Styles]
new g_szTimer[MAX_TIMER_LENGTH]

new Array:g_aStyles
new Array:g_aPositionCycle
new Trie:g_tColorCycle
new Float:g_fTimerPosition[MAX_POSITION_VALUES]
new bool:g_bPlanted
new bool:g_bRefreshColors

new g_iTimerColor[MAX_RGB_VALUES]
new g_iCurrentStyle
new g_iCurrentTimer
new g_iCurrentPosition
new g_iMessage
new g_iMaxStyles
new g_iMaxTimer
new g_iMaxPositions
new g_iTimerEntity
new g_iShowTimer
new g_iRoundTime
new g_pC4Timer

public plugin_init()
{
	register_plugin("Style C4 Timer", PLUGIN_VERSION, "OciXCrom")
	register_cvar("StyleC4Timer", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)

	g_iTimerEntity = create_entity("info_target")

	if(!g_iTimerEntity)
	{
		set_fail_state("Unable to create timer entity")
	}

	new const TIMER_ENTITY_NAME[] = "stylec4timer_entity"
	entity_set_string(g_iTimerEntity, EV_SZ_classname, TIMER_ENTITY_NAME)
	register_think(TIMER_ENTITY_NAME, "timer_display")

	register_event("HLTV", "timer_adjust", "a", "1=0", "2=0")
	register_logevent("timer_create", 3, "2=Planted_The_Bomb")
	register_logevent("timer_remove", 3, "2=Defused_The_Bomb")
	register_logevent("timer_remove", 6, "3=Target_Saved")
	register_logevent("timer_remove", 6, "3=Target_Bombed")
	register_logevent("timer_remove", 2, "1=Round_Start")
	register_logevent("timer_remove", 2, "1=Round_End")
	register_logevent("timer_remove", 2, "1&Restart_Round_")

	g_pC4Timer = get_cvar_pointer("mp_c4timer")
	g_aStyles = ArrayCreate(Styles)

	ReadFile()
}

public plugin_cfg()
{
	timer_adjust()
}

public plugin_end()
{
	ArrayDestroy(g_aStyles)

	if(g_eSettings[COLOR_MODE] == COLORMODE_COLOR_CYCLE)
	{
		TrieDestroy(g_tColorCycle)
	}

	if(g_eSettings[ENABLE_POSITION_CYCLE])
	{
		ArrayDestroy(g_aPositionCycle)
	}
}

ReadFile()
{
	new szFilename[MAX_FILENAME_LENGTH]
	get_configsdir(szFilename, charsmax(szFilename))
	add(szFilename, charsmax(szFilename), "/StyleC4Timer.ini")

	new iFilePointer = fopen(szFilename, "rt")

	if(iFilePointer)
	{
		new szData[MAX_FILENAME_LENGTH], szKey[MAX_NAME_LENGTH], szValue[MAX_FILENAME_LENGTH - MAX_NAME_LENGTH], szMap[MAX_NAME_LENGTH]
		new eStyle[Styles], bool:bRead = true, iSection = SECTION_NONE, szTemp[4][5], iSize, i
		get_mapname(szMap, charsmax(szMap))

		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)

			switch(szData[0])
			{
				case EOS, ';': continue
				case '-':
				{
					iSize = strlen(szData)

					if(szData[iSize - 1] == '-')
					{
						szData[0] = ' '
						szData[iSize - 1] = ' '
						trim(szData)

						if(contain(szData, "*") != -1)
						{
							strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '*')
							copy(szValue, strlen(szKey), szMap)
							bRead = equal(szValue, szKey) != 0
						}
						else
						{
							static const szAll[] = "#all"
							bRead = equal(szData, szAll) || equali(szData, szMap)
						}
					}
					else continue
				}
				case '[':
				{
					iSize = strlen(szData)

					if(szData[iSize - 1] == ']')
					{
						switch(szData[2])
						{
							case 'E', 'e': iSection = SECTION_SETTINGS
							case 'T', 't': iSection = SECTION_STYLES
							default: iSection = SECTION_NONE
						}
					}
					else continue
				}
				case '{':
				{
					if(iSection == SECTION_STYLES)
					{
						g_iMaxStyles++
					}
				}
				case '}':
				{
					if(iSection == SECTION_STYLES)
					{
						eStyle[DoReplace] = eStyle[ReplaceWith][0] != 0
						ArrayPushArray(g_aStyles, eStyle)

						eStyle[Begin][0] = EOS
						eStyle[Add][0] = EOS
						eStyle[End][0] = EOS
						eStyle[ReplaceSymbol][0] = EOS
						eStyle[ReplaceWith][0] = EOS
					}
				}
				default:
				{
					if(!bRead)
					{
						continue
					}

					switch(iSection)
					{
						case SECTION_SETTINGS:
						{
							strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
							trim(szKey); trim(szValue)

							if(equal(szKey, "STYLE_MODE"))
							{
								g_eSettings[STYLE_MODE] = clamp(str_to_num(szValue), STYLEMODE_MANUAL, STYLEMODE_RANDOM)
							}
							else if(equal(szKey, "TIMER_STYLE"))
							{
								g_eSettings[TIMER_STYLE] = str_to_num(szValue)
							}
							else if(equal(szKey, "COLOR_MODE"))
							{
								g_eSettings[COLOR_MODE] = clamp(str_to_num(szValue), COLORMODE_ONE_COLOR, COLORMODE_RANDOM)

								if(g_eSettings[COLOR_MODE] == COLORMODE_COLOR_CYCLE)
								{
									g_tColorCycle = TrieCreate()
								}
							}
							else if(equal(szKey, "STARTING_COLOR"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]), szTemp[2], charsmax(szTemp[]))

								for(i = 0; i < MAX_RGB_VALUES; i++)
								{
									g_eSettings[STARTING_COLOR][i] = clamp(str_to_num(szTemp[i]), -1, 255)
								}
							}
							else if(equal(szKey, "COLOR_CYCLE"))
							{
								if(g_eSettings[COLOR_MODE] != COLORMODE_COLOR_CYCLE)
								{
									continue
								}

								while(szValue[0] != 0 && strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ','))
								{
									trim(szKey); trim(szValue)
									strtok(szKey, szTemp[0], charsmax(szTemp[]), szKey, charsmax(szKey), ' ')
									TrieSetString(g_tColorCycle, szTemp[0], szKey)
								}
							}
							else if(equal(szKey, "STARTING_POSITION"))
							{
								parse(szValue, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]))

								for(i = 0; i < MAX_POSITION_VALUES; i++)
								{
									g_eSettings[STARTING_POSITION][i] = _:floatclamp(str_to_float(szTemp[i]), -1.0, 1.0)
								}
							}
							else if(equal(szKey, "ENABLE_POSITION_CYCLE"))
							{
								g_eSettings[ENABLE_POSITION_CYCLE] = _:clamp(str_to_num(szValue), false, true)

								if(g_eSettings[ENABLE_POSITION_CYCLE])
								{
									g_aPositionCycle = ArrayCreate(MAX_POSITION_VALUES)
								}
							}
							else if(equal(szKey, "POSITION_CYCLE"))
							{
								if(!g_eSettings[ENABLE_POSITION_CYCLE])
								{
									continue
								}

								static Float:fPosition[MAX_POSITION_VALUES]

								while(szValue[0] != 0 && strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ','))
								{
									trim(szKey); trim(szValue)
									parse(szKey, szTemp[0], charsmax(szTemp[]), szTemp[1], charsmax(szTemp[]))

									for(new i; i < MAX_POSITION_VALUES; i++)
									{
										fPosition[i] = str_to_float(szTemp[i])
									}

									g_iMaxPositions++
									ArrayPushArray(g_aPositionCycle, fPosition)
								}
							}
							else if(equal(szKey, "MESSAGE_TYPE"))
							{
								g_eSettings[MESSAGE_TYPE] = clamp(str_to_num(szValue), MSGTYPE_HUD, MSGTYPE_CENTER)

								if(g_eSettings[MESSAGE_TYPE] == MSGTYPE_HUD)
								{
									g_iMessage = CreateHudSyncObj()
								}
							}
							else if(equal(szKey, "OVERWRITE_ROUND_TIMER"))
							{
								g_eSettings[OVERWRITE_ROUND_TIMER] = _:clamp(str_to_num(szValue), false, true)

								if(g_eSettings[OVERWRITE_ROUND_TIMER])
								{
									g_iShowTimer = get_user_msgid("ShowTimer")
									g_iRoundTime = get_user_msgid("RoundTime")
								}
							}
							else if(equal(szKey, "TIMER_SYNC"))
							{
								g_eSettings[TIMER_SYNC] = str_to_num(szValue)
							}
							else if(equal(szKey, "START_MESSAGE_AT"))
							{
								g_eSettings[START_MESSAGE_AT] = str_to_num(szValue)
							}
							else if(equal(szKey, "START_VOICE_AT"))
							{
								g_eSettings[START_VOICE_AT] = str_to_num(szValue)
							}
							else if(equal(szKey, "VOICE_SPEAKER"))
							{
								copy(g_eSettings[VOICE_SPEAKER], charsmax(g_eSettings[VOICE_SPEAKER]), szValue)
							}
						}
						case SECTION_STYLES:
						{
							replace_all(szData, charsmax(szData), SYM_NEWLINE, "^n")
							strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), ':')
							trim(szKey); trim(szValue)
							remove_quotes(szValue)

							if(equali(szKey, "begin"))
							{
								copy(eStyle[Begin], charsmax(eStyle[Begin]), szValue)
							}
							else if(equali(szKey, "add"))
							{
								copy(eStyle[Add], charsmax(eStyle[Add]), szValue)
							}
							else if(equali(szKey, "end"))
							{
								copy(eStyle[End], charsmax(eStyle[End]), szValue)
							}
							else if(equali(szKey, "replace symbol"))
							{
								copy(eStyle[ReplaceSymbol], charsmax(eStyle[ReplaceSymbol]), szValue)
							}
							else if(equali(szKey, "replace with"))
							{
								copy(eStyle[ReplaceWith], charsmax(eStyle[ReplaceWith]), szValue)
							}
						}
					}
				}
			}
		}

		fclose(iFilePointer)

		if(!g_iMaxStyles)
		{
			set_fail_state("No styles found in the configuration file")
		}

		g_eSettings[TIMER_STYLE] = clamp(g_eSettings[TIMER_STYLE], 0, g_iMaxStyles - 1)

		if(g_eSettings[STYLE_MODE] == STYLEMODE_MANUAL)
		{
			ArrayGetArray(g_aStyles, g_eSettings[TIMER_STYLE], g_eTimer)
		}

		if(g_eSettings[MESSAGE_TYPE] != MSGTYPE_CENTER)
		{
			if(g_eSettings[COLOR_MODE] != COLORMODE_RANDOM)
			{
				timer_refresh_colors()

				if(g_eSettings[COLOR_MODE] == COLORMODE_COLOR_CYCLE)
				{
					g_bRefreshColors = true
				}
			}

			if(!g_eSettings[ENABLE_POSITION_CYCLE])
			{
				for(new i; i < MAX_POSITION_VALUES; i++)
				{
					g_fTimerPosition[i] = g_eSettings[STARTING_POSITION][i]
				}
			}
		}
	}
	else
	{
		set_fail_state("Unable to locate or open configuration file")
	}
}

public timer_adjust()
{
	g_iMaxTimer = get_pcvar_num(g_pC4Timer) + g_eSettings[TIMER_SYNC]
}

public timer_create()
{
	if(g_bPlanted)
	{
		return
	}

	g_bPlanted = true
	g_szTimer[0] = EOS
	g_iCurrentTimer = g_iMaxTimer

	switch(g_eSettings[STYLE_MODE])
	{
		case STYLEMODE_CONSECUTIVE:
		{
			ArrayGetArray(g_aStyles, g_iCurrentStyle++, g_eTimer)

			if(g_iCurrentStyle == g_iMaxStyles)
			{
				g_iCurrentStyle = 0
			}
		}
		case STYLEMODE_RANDOM:
		{
			ArrayGetArray(g_aStyles, random(g_iMaxStyles), g_eTimer)
		}
	}

	if(g_bRefreshColors)
	{
		timer_refresh_colors()
	}

	if(g_eTimer[DoReplace])
	{
		timer_add(g_eTimer[Begin])

		for(new i; i < g_iCurrentTimer; i++)
		{
			timer_add(g_eTimer[Add])
		}

		timer_add(g_eTimer[End])
	}
	else
	{
		formatex(g_szTimer, charsmax(g_szTimer), g_eTimer[Begin], g_iCurrentTimer)
	}

	timer_display(g_iTimerEntity)
}

timer_add(const szString[])
{
	add(g_szTimer, charsmax(g_szTimer), szString)
}

public timer_display(iEnt)
{
	if(g_bPlanted)
	{
		if(g_iCurrentTimer >= 0)
		{
			if(g_eSettings[START_MESSAGE_AT] && g_eSettings[START_MESSAGE_AT] < g_iCurrentTimer)
			{
				goto @AFTER_MESSAGE
			}

			if(g_eSettings[MESSAGE_TYPE] != MSGTYPE_CENTER)
			{
				switch(g_eSettings[COLOR_MODE])
				{
					case COLORMODE_COLOR_CYCLE:
					{
						new szTimer[5]
						num_to_str(g_iCurrentTimer, szTimer, charsmax(szTimer))

						if(TrieKeyExists(g_tColorCycle, szTimer))
						{
							new szColor[12], szRGB[MAX_RGB_VALUES][4]
							TrieGetString(g_tColorCycle, szTimer, szColor, charsmax(szColor))
							parse(szColor, szRGB[0], charsmax(szRGB[]), szRGB[1], charsmax(szRGB[]), szRGB[2], charsmax(szRGB[]))

							for(new i; i < MAX_RGB_VALUES; i++)
							{
								g_iTimerColor[i] = str_to_num(szRGB[i])
							}
						}
					}
					case COLORMODE_RANDOM:
					{
						for(new i; i < MAX_RGB_VALUES; i++)
						{
							g_iTimerColor[i] = random(256)
						}
					}
				}

				if(g_eSettings[ENABLE_POSITION_CYCLE])
				{
					ArrayGetArray(g_aPositionCycle, g_iCurrentPosition++, g_fTimerPosition)

					if(g_iCurrentPosition == g_iMaxPositions)
					{
						g_iCurrentPosition = 0
					}
				}
			}

			switch(g_eSettings[MESSAGE_TYPE])
			{
				case MSGTYPE_HUD:
				{
					set_hudmessage(g_iTimerColor[0], g_iTimerColor[1], g_iTimerColor[2], g_fTimerPosition[0], g_fTimerPosition[1], 0, 1.0, 1.0, 0.01, 0.01)
					ShowSyncHudMsg(0, g_iMessage, g_szTimer, g_iCurrentTimer)
				}
				case MSGTYPE_DHUD:
				{
					set_dhudmessage(g_iTimerColor[0], g_iTimerColor[1], g_iTimerColor[2], g_fTimerPosition[0], g_fTimerPosition[1], 0, 1.0, 1.0, 0.01, 0.01)
					show_dhudmessage(0, g_szTimer, g_iCurrentTimer)
				}
				case MSGTYPE_CENTER:
				{
					client_print(0, print_center, g_szTimer, g_iCurrentTimer)
				}
			}

			@AFTER_MESSAGE:

			if(0 < g_iCurrentTimer <= g_eSettings[START_VOICE_AT])
			{
				new szSpeaker[MAX_NAME_LENGTH]
				num_to_word(g_iCurrentTimer, szSpeaker, charsmax(szSpeaker))
				client_cmd(0, "spk ^"%s/%s.wav", g_eSettings[VOICE_SPEAKER], szSpeaker)
			}

			if(g_eSettings[OVERWRITE_ROUND_TIMER])
			{
				message_begin(MSG_ALL, g_iShowTimer)
				message_end()

				message_begin(MSG_ALL, g_iRoundTime)
				write_short(g_iCurrentTimer + 1)
				message_end()
			}

			g_iCurrentTimer--

			if(g_eTimer[DoReplace])
			{
				replace(g_szTimer, charsmax(g_szTimer), g_eTimer[ReplaceSymbol], g_eTimer[ReplaceWith])
			}
			else
			{
				formatex(g_szTimer, charsmax(g_szTimer), g_eTimer[Begin], g_iCurrentTimer)
			}

			entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + TIMER_THINK)
		}
	}
}

public timer_remove()
{
	if(g_bPlanted)
	{
		g_bPlanted = false
		g_iCurrentTimer = -1
	}
}

timer_refresh_colors()
{
	for(new i; i < MAX_RGB_VALUES; i++)
	{
		g_iTimerColor[i] = g_eSettings[STARTING_COLOR][i]
	}
}