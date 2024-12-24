#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <fun>
#if AMXX_VERSION_NUM < 183
	#include <colorchat>
	#include <dhudmessage>
#endif

enum _:Teams
{
	TeamTT = 1,
	TeamCT
}

new const VERSION[]  = "1.3.9";
new const g_szConfigFile[] = "TeamBalanceControl.cfg";
const MAXPLAYERS 	 = 32;
const PLAYER_DIFF 	 = 2;
const CHECK_INTERVAL = 15;
const MENU_SIZE 	 = 512;
const VGUIMenu 		 = 114;	// Не трогать!
const OLDMenu 		 = 96;	// Не трогать!
const TeamSpectate 	 = 3

new bool:g_bFirstSpawn = true;
new bool:g_bPlayerToTransfer[MAXPLAYERS + 1];

new Float:g_fPlayerSkill[MAXPLAYERS + 1], g_iPlayerHs[MAXPLAYERS + 1], g_iPlayerKills[MAXPLAYERS + 1], g_iPlayerDeaths[MAXPLAYERS + 1];
new Float:g_fJoinTime[MAXPLAYERS +1], Float:g_fLastTeamChange[MAXPLAYERS +1];

new g_eTeamScore[Teams  + 1];

new g_pSkillDifference, g_pScoreDifference, g_pMinPlayers, g_pAdminNotify, g_pAdminFlag, g_pPlayerNotify, g_pSoundNotify, g_pMenuType, g_pMenuFlood, g_pNoRound;
new g_iNoRound;

new g_iMaxPlayers;


public plugin_init()
{
	register_plugin("Team Balance Control", VERSION, "gyxoBka");
	register_cvar("team_balance", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED);
	
	register_logevent("LogEvent_JoinTeam", 3, "1=joined team")
	
	register_event("DeathMsg", "EventDeath", "a");
	register_event("TeamScore", "EventScore", "a");
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	register_event("TextMsg", "EventClear", "a", "2&#Game_C", "2&#Game_w");
	
	register_clcmd("chooseteam", "ShowMenu");
	register_menucmd(register_menuid("Team Menu"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_5|MENU_KEY_6|MENU_KEY_0, "TeamMenuHandler");
	register_message(OLDMenu, "mShowMenu");
	register_message(VGUIMenu, "mShowMenu");
	
	#if AMXX_VERSION_NUM < 183
	register_dictionary_colored("TeamBalanceControl.txt");
	#else
	register_dictionary("TeamBalanceControl.txt");
	#endif
	
	g_pSkillDifference = register_cvar("tbc_skilldiff", "45");
	g_pScoreDifference = register_cvar("tbc_scorediff", "4");
	g_pMinPlayers = register_cvar("tbc_minplayers", "8");
	g_pAdminNotify = register_cvar("tbc_admnotify", "1");
	g_pAdminFlag = register_cvar("tbc_admflag", "a");
	g_pPlayerNotify = register_cvar("tbc_plnotify", "1");
	g_pSoundNotify = register_cvar("tbc_sndnotify", "1");
	g_pMenuType = register_cvar("tbc_menutype", "2");
	g_pMenuFlood = register_cvar("tbc_usemenu", "10");
	g_pNoRound = register_cvar("tbc_noround", "0");
	
	g_iMaxPlayers = get_maxplayers();
}

public plugin_cfg()
{
	new szFilePath[64]
	get_localinfo("amxx_configsdir", szFilePath, charsmax(szFilePath));
	formatex(szFilePath, charsmax(szFilePath), "%s/%s",szFilePath, g_szConfigFile);
	server_cmd("exec %s", szFilePath);
	
	g_iNoRound = get_pcvar_num(g_pNoRound);
}

public Event_NewRound()
{
	if(g_bFirstSpawn)
	{
		g_bFirstSpawn = false;
		return;
	}
	
	CheckTeamsToEqualNum();
	
	if(!g_iNoRound)
	{
		new iDifference;
		static iNextCheck;
		
		iNextCheck--;
		
		CheckTeamsScore(iDifference);
		
		if(iNextCheck <= 0 && iDifference >= get_pcvar_num(g_pScoreDifference))
		{
			if(iNextCheck == 0)
			{
				iNextCheck = (iDifference/2) + 1;
			}
			
			new Float:fSkillTT, Float:fSkillCT, iCTNum, iTTNum;
			CalculateSkills(fSkillTT, fSkillCT, iCTNum, iTTNum);
			
			new iMinPlayers = get_pcvar_num(g_pMinPlayers);
			if(iMinPlayers < 6)
			{
				iMinPlayers = 6;
			}

			if(iCTNum + iTTNum >= iMinPlayers)
			{
				CheckTeamSkill(fSkillTT, fSkillCT);
			}
		}
	}
	
	arrayset(g_bPlayerToTransfer, 0, MAXPLAYERS + 1);
}

public client_putinserver(id)
{
	g_bPlayerToTransfer[id] = false;
	g_fLastTeamChange[id] = 0.0;
	g_fJoinTime[id] = 0.0;
}

public client_disconnect(id)
{
	g_bPlayerToTransfer[id] = false;
	g_fLastTeamChange[id] = 0.0;
	g_fJoinTime[id] = 0.0;
}

public EventClear()
{
	arrayset(g_eTeamScore, 0, Teams  + 1);
	arrayset(g_iPlayerHs, 0, MAXPLAYERS + 1);
	arrayset(g_iPlayerKills, 0, MAXPLAYERS + 1);
	arrayset(g_iPlayerDeaths, 0, MAXPLAYERS + 1);
	arrayset(g_bPlayerToTransfer, 0, MAXPLAYERS + 1);
}

public LogEvent_JoinTeam()
{
	new szLogPlayer[80], szName[32], id;
	read_logargv(0, szLogPlayer, charsmax(szLogPlayer));
	parse_loguser(szLogPlayer, szName, charsmax(szName));
	id = get_user_index(szName);
	
	g_fJoinTime[id] = get_gametime();
}

public EventScore() 
{ 
	new szTeam[1];
	read_data(1, szTeam, 1);

	if(szTeam[0] == 'C') g_eTeamScore[TeamCT] = read_data(2);
	else g_eTeamScore[TeamTT] = read_data(2);
}

public EventDeath()
{
	if(!g_iNoRound)
	{
		new iKiller = read_data(1);
		
		if(read_data(3))
		{
			g_iPlayerHs[iKiller]++;
		}
		
		g_iPlayerKills[iKiller]++;
		g_iPlayerDeaths[read_data(2)]++;
	}
	else
	{
		static iKills; 
		iKills++;
		
		if(!(iKills % CHECK_INTERVAL))
		{
			CheckTeamsToEqualNum();
		}
	}
}

CheckTeamsScore(&iDifference)
{
	if(g_eTeamScore[TeamCT] > g_eTeamScore[TeamTT])
	{
		iDifference = g_eTeamScore[TeamCT] - g_eTeamScore[TeamTT];
	}
	
	if(g_eTeamScore[TeamTT] > g_eTeamScore[TeamCT])
	{
		iDifference = g_eTeamScore[TeamTT] - g_eTeamScore[TeamCT];
	}
}

CalculateSkills(&Float:fSkillTT, &Float:fSkillCT, &iCTNum, &iTTNum)
{
	new iKills, iDeaths, iHs;
	new iHsCT, iKillsCT, iDeathsCT;
	new iHsTT, iKillsTT, iDeathsTT;
	
	for(new id = 1; id <= g_iMaxPlayers; id++)
	{
		if(!is_user_connected(id)) continue;
		
		switch(cs_get_user_team(id))
		{
			case CS_TEAM_CT:
			{
				iCTNum++
				
				iHs = g_iPlayerHs[id];
				iKills = g_iPlayerKills[id];
				iDeaths = g_iPlayerDeaths[id];
				
				iHsCT += iHs;
				iKillsCT += iKills;
				iDeathsCT += iDeaths;
				
				g_fPlayerSkill[id] = get_skill(iKills, iDeaths, iHs);
			}
			case CS_TEAM_T:
			{
				iTTNum++
				
				iHs = g_iPlayerHs[id];
				iKills = g_iPlayerKills[id];
				iDeaths = g_iPlayerDeaths[id];
				
				iHsTT += iHs;
				iKillsTT += iKills;
				iDeathsTT += iDeaths;
				
				g_fPlayerSkill[id] = get_skill(iKills, iDeaths, iHs);
			}
			default: continue;
		}
	}
	
	fSkillCT = get_skill(iKillsCT, iDeathsCT, iHsCT);
	fSkillTT = get_skill(iKillsTT, iDeathsTT, iHsTT);
}

CheckTeamSkill(Float:fSkillTT, Float:fSkillCT)
{
	new Float:fCTResult, Float:fTTResult;
	new Float:fPercent, Float:fTemp;
	new Float:fDifference = get_pcvar_float(g_pSkillDifference);
	if(fSkillTT > fSkillCT)
	{
		fPercent = fSkillCT/100.0;
		fTemp = fSkillTT/fPercent;
		fTTResult = fTemp - 100.0;
		if(fTTResult > fDifference)
		{
			// Balance is needed
			BalanceTeamBySkill(TeamTT);
		}
	}
	else if(fSkillCT > fSkillTT)
	{
		fPercent = fSkillTT/100.0;
		fTemp = fSkillCT/fPercent;
		fCTResult = fTemp - 100.0;
		if(fCTResult > fDifference)
		{
			// Balance is needed
			BalanceTeamBySkill(TeamCT);
		}
	}
	else return; // Balance isn't needed, because teams are equal
}

CheckTeamsToEqualNum()
{
	new iNums[Teams  + 1];
	new iTTNum, iCTNum;
	new iPlayers[Teams  + 1][32];
	new iNumToSwap, iTeamToSwap;
	
	for(new id = 1; id <= g_iMaxPlayers; id++)
	{
		if(!is_user_connected(id)) continue;
		
		switch(cs_get_user_team(id))
		{
			case CS_TEAM_CT: iPlayers[TeamCT][iNums[TeamCT]++] = id;
			case CS_TEAM_T: iPlayers[TeamTT][iNums[TeamTT]++] = id;
			default: continue;
		}
	}
	
	iTTNum = iNums[TeamTT];
	iCTNum = iNums[TeamCT];
	
	//Узнаем сколько игроков нужно перевести
	if(iTTNum > iCTNum)
	{
		iNumToSwap = ( iTTNum - iCTNum ) / 2;
		iTeamToSwap = TeamTT;
	}
	else if(iCTNum > iTTNum)
	{
		iNumToSwap = (iCTNum - iTTNum) / 2;
		iTeamToSwap = TeamCT;
	}
	else return PLUGIN_CONTINUE;	// Balance isn't needed, because teams are equal
	
	if(!iNumToSwap) return PLUGIN_CONTINUE;		// Balance isn't needed
	
	new iPlayer, iNum, iLastPlayer;
	iNum = iNums[iTeamToSwap];
	
	do
	{
		--iNumToSwap;
		
		for(new i; i < iNum; i++)
		{
			iPlayer = iPlayers[iTeamToSwap][i];
			
			if(g_bPlayerToTransfer[iPlayer]) continue;
			
			if(g_fJoinTime[iPlayer] >= g_fJoinTime[iLastPlayer])
			{
				iLastPlayer = iPlayer;
			}
		}
		
		if(!iLastPlayer) return PLUGIN_CONTINUE;
		
		g_bPlayerToTransfer[iLastPlayer] = true;
		TransferPlayer(iLastPlayer);
		iLastPlayer = 0;
	}
	while(iNumToSwap)
	
	return PLUGIN_CONTINUE;
}

BalanceTeamBySkill(const iLeadingTeam)
{
	new iNum[Teams  + 1];
	new iCTPlayers[32], iTTPlayers[32];
	
	for(new id = 1; id <= g_iMaxPlayers; id++)
	{
		if(!is_user_connected(id)) continue;
		
		switch(cs_get_user_team(id))
		{
			case CS_TEAM_CT: iCTPlayers[iNum[TeamCT]++] = id;
			case CS_TEAM_T: iTTPlayers[iNum[TeamTT]++] = id;
			default: continue;
		}
	}
	
	new iPlayerPos[Teams + 1][32];

	OrderPlayers(iNum[TeamCT], TeamCT, iCTPlayers, iPlayerPos);
	OrderPlayers(iNum[TeamTT], TeamTT, iTTPlayers, iPlayerPos);
	
	new iLeadNum = iNum[iLeadingTeam];
	new Float:fCoeff = GetTeamCoeff(iLeadNum);
	new iLeadPos, iLosePos;
	new iLoseTeam = iLeadingTeam == TeamTT ? TeamCT : TeamTT;
	new iStartLosePos = iNum[iLoseTeam] - 1;
	new iStartLeadPos = floatround(iLeadNum/fCoeff, floatround_floor);
	
	new iTeamLeadId, iTeamLoseId;
	new iTransferedNum;
	
	new bool:TransferIsNeeded = true;

	while(TransferIsNeeded)
	{
		iLeadPos = iLeadNum - (iStartLeadPos + iTransferedNum);
		iLosePos = iStartLosePos - iTransferedNum;
		
		if(iLeadPos < 0) break;
		
		iTeamLeadId = iPlayerPos[iLeadingTeam][iLeadPos];
		iTeamLoseId = iPlayerPos[iLoseTeam][iLosePos];
		
		if(g_bPlayerToTransfer[iTeamLoseId])
		{
			iTeamLoseId = iPlayerPos[iLoseTeam][--iLosePos];
		}
		
		iPlayerPos[iLeadingTeam][iLeadPos] = iTeamLoseId;
		iPlayerPos[iLoseTeam][iLosePos] = iTeamLeadId;
		
		TransferPlayer(iTeamLeadId);
		TransferPlayer(iTeamLoseId);
		
		TransferIsNeeded = CheckSkillsChanges(iPlayerPos, iNum, iLeadingTeam, iLoseTeam, iTransferedNum);
	}
	
	return PLUGIN_CONTINUE;
}

bool:CheckSkillsChanges(iPlayerPos[Teams  + 1][32], iNum[Teams  + 1], const iLeadTeam, const iLoseTeam, &iTransferedNum)
{
	new iRankPos, iPlayer;
	new iHsLead, iKillsLead, iDeathsLead;
	new iHsLose, iKillsLose, iDeathsLose;
	
	do
	{
		iPlayer = iPlayerPos[iLeadTeam][iRankPos++];
		
		iHsLead += g_iPlayerHs[iPlayer];
		iKillsLead += g_iPlayerKills[iPlayer];
		iDeathsLead += g_iPlayerDeaths[iPlayer];
		
	}
	while(iNum[iLeadTeam] > iRankPos)
	
	iRankPos = 0;
	
	do
	{
		iPlayer = iPlayerPos[iLoseTeam][iRankPos++];
		
		iHsLose += g_iPlayerHs[iPlayer];
		iKillsLose += g_iPlayerKills[iPlayer];
		iDeathsLose += g_iPlayerDeaths[iPlayer];
		
	}
	while(iNum[iLoseTeam] > iRankPos)
	
	new Float:fSkillLead = get_skill(iKillsLead, iDeathsLead, iHsLead);
	new Float:fSkillLose = get_skill(iKillsLose, iDeathsLose, iHsLose);
	
	new Float:fPercent = fSkillLose/100.0;
	new Float:fTemp = fSkillLead/fPercent;
	new Float:fTeamResult = fTemp - 100.0;
	
	if(fTeamResult > get_pcvar_float(g_pSkillDifference) && iTransferedNum <= PLAYER_DIFF)
	{
		// Need balance too
		iTransferedNum++;
		return true;
	}
	
	return false;
}

OrderPlayers(const iNum, const iTeam, iPlayers[], iPlayerPos[Teams  + 1][32])
{
	new iMaxSkillId, Float:fMax, iMaxPos, iPlayer, iTemp;
	
	while(iNum > iTemp)
	{
		for(new i = 0; i < iNum; i++)
		{
			iPlayer = iPlayers[i];
			if(!iPlayer) 
			{
				continue;
			}
			if(g_fPlayerSkill[iPlayer] >= fMax)
			{
				fMax = g_fPlayerSkill[iPlayer];
				iMaxSkillId = iPlayer;
				iMaxPos = i;
			}
		}
		if(iMaxSkillId > 0) 		// for safety
		{
			iPlayerPos[iTeam][iTemp++] = iMaxSkillId;
			iPlayers[iMaxPos] = 0;
			iMaxSkillId = 0;
			fMax = 0.0;
		}
		else
		{
			log_to_file("TeamBalanceControl.txt", "Smthg was wrong, when tried to pos players");
			log_to_file("TeamBalanceControl.txt", "TeamNum: %d  iPos: %d", iNum, iTemp);
			return PLUGIN_CONTINUE;
		}
	}
	
	return PLUGIN_CONTINUE;
}

Float:GetTeamCoeff(const iTeamNum)
{
	new Float:fTemp;
	
	switch(iTeamNum)
	{
		case 4..10: fTemp = 2.0;
		case 11: fTemp = 2.2;
		case 12: fTemp = 2.4;
		case 13..16: fTemp = 2.5;
	}
	
	return fTemp;
}

TransferPlayer(const id)
{
	new CsTeams:iTeam;
		
	if(is_user_connected(id))
	{
		iTeam = cs_get_user_team(id);

		if(CS_TEAM_T <= iTeam <= CS_TEAM_CT)
		{
			set_player_team(id, iTeam == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T);
			
			if(is_user_bot(id)) return;
			
			new szName[32];
			get_user_name(id, szName, charsmax(szName));
			
			if(get_pcvar_num(g_pPlayerNotify))
			{
				set_dhudmessage(244, 118, 88, 0.19, -0.29, 2, _, 5.0, 0.07);
				show_dhudmessage(id, "%L %L", id, "TB_INFO", szName, id, iTeam == CS_TEAM_T ? "TB_CT" : "TB_TT");
			}
			else client_print_color(id, 0, "^1%L ^1%L ^1%L", id, "TB_PREFIX", id, "TB_INFO", szName, id, iTeam == CS_TEAM_T ? "TB_CT" : "TB_TT");
			
			if(get_pcvar_num(g_pSoundNotify))
			{
				client_cmd(id, "spk buttons/button2");
			}
			
			if(get_pcvar_num(g_pAdminNotify))
			{
				new szFlags[15];
				get_pcvar_string(g_pAdminFlag, szFlags, charsmax(szFlags));
				
				for(new i = 1; i <= g_iMaxPlayers; i++)
				{
					if(i == id) continue;
					
					if(get_user_flags(i) & read_flags(szFlags))
						client_print_color(i, 0, "^1%L ^1%L ^1%L", i, "TB_PREFIX",  i, "TB_ADMIN_INFO", szName, i, iTeam == CS_TEAM_T ? "TB_CT" : "TB_TT");
				}
			}
		}
	}
}

set_player_team(const id, CsTeams:iTeam)
{
	switch(iTeam)
	{
		case CS_TEAM_T: 
		{
			if(cs_get_user_defuse(id))
			{
				cs_set_user_defuse(id, 0);
			}
		}
		case CS_TEAM_CT:
		{
			if(user_has_weapon(id, CSW_C4))
			{
				engclient_cmd(id, "drop", "weapon_c4");
			}
		}
	}
	
	cs_set_user_team(id, iTeam);
}

public TeamMenuHandler(id, iKey)
{
	if(iKey == 9) return PLUGIN_HANDLED;
	
	switch(get_pcvar_num(g_pMenuType))
	{
		case 1: AutoMenuJoin(id, iKey);
		default: FullJoin(id, iKey);
	}
	
	set_pdata_int(id, 125, get_pdata_int(id, 125) & ~(1<<8));
	
	return PLUGIN_HANDLED;
}

public mShowMenu(const msg, const nDest, const id)
{
	if(msg == OLDMenu)
	{
		static szArg4[20]; get_msg_arg_string(4, szArg4, charsmax(szArg4));
		if(contain(szArg4, "Team_Select") == -1)
			return PLUGIN_CONTINUE;
	}
	else if(get_msg_arg_int(1) != 2)
		return PLUGIN_CONTINUE;
		
	if(get_pcvar_num(g_pMenuType) == 0)
		return PLUGIN_CONTINUE;
	
	if(get_pcvar_num(g_pMenuFlood) && cs_get_user_team(id))
	{
		new Float:fNextChoose = g_fLastTeamChange[id] + get_pcvar_float(g_pMenuFlood);
		new Float:fCurTime = get_gametime();
		
		if(fNextChoose > fCurTime)
		{
			client_print_color(id, 0, "^1%L ^1%L", id, "TB_PREFIX", id, "TB_RESTRICT_OPEN_MENU", floatround(fNextChoose - fCurTime));
			return PLUGIN_HANDLED;
		}
	}
	
	set_pdata_int(id, 205, 0);
	ShowMenu(id);
	
	return PLUGIN_HANDLED;
}

public ShowMenu(id)
{
	if(get_pcvar_num(g_pMenuType) == 0)
		return PLUGIN_CONTINUE;
		
	if(get_pcvar_num(g_pMenuFlood) && cs_get_user_team(id))
	{
		new Float:fNextChoose = g_fLastTeamChange[id] + get_pcvar_float(g_pMenuFlood);
		new Float:fCurTime = get_gametime();
		
		if(fNextChoose > fCurTime)
		{
			client_print_color(id, 0, "^1%L ^1%L", id, "TB_PREFIX", id, "TB_RESTRICT_OPEN_MENU", floatround(fNextChoose - fCurTime));
			return PLUGIN_HANDLED;
		}
	}
		
	new szMenu[MENU_SIZE];
	new iKeys = MENU_KEY_0;
	
	new iTeamTT, iTeamCT;
	
	CalculateTeamNum(iTeamTT, iTeamCT);
	
	switch(get_pcvar_num(g_pMenuType))
	{
		case 1: FormatAutoJoinMenu(id, szMenu, iKeys);
		default: FormatFullMenu(id, szMenu, iKeys, iTeamTT, iTeamCT);
	}
	
	return show_menu(id, iKeys, szMenu, -1, "Team Menu");
}

CalculateTeamNum(&iTeamTT, &iTeamCT)
{
	for(new id = 1; id <= g_iMaxPlayers; id++)
	{
		if(!is_user_connected(id)) continue;
		
		switch(cs_get_user_team(id))
		{
			case CS_TEAM_CT: iTeamCT++;
			case CS_TEAM_T: iTeamTT++;
		}
	}
}

FormatAutoJoinMenu(const id, szMenu[MENU_SIZE], &iKeys)
{
	new iLen = formatex(szMenu, charsmax(szMenu), "%L", id, "TB_MENU_HEADER");
	
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_AUTO_MENU");
	iKeys |= MENU_KEY_1;
	
	if(_:cs_get_user_team(id) == TeamSpectate)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_CANT_SPECTATE");
	else
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_CAN_SPECTATE");
		iKeys |= MENU_KEY_6;
	}
	
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_MENU_EXIT");
}

FormatFullMenu(const id, szMenu[MENU_SIZE], &iKeys, const iTeamTT, const iTeamCT)
{
	new iPlayerTeam = _:cs_get_user_team(id);
	new iLen = formatex(szMenu, charsmax(szMenu), "%L", id, "TB_MENU_HEADER");
	
	if((iTeamTT - iTeamCT) >= PLAYER_DIFF || iPlayerTeam == TeamTT)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_CANT_JOIN_TT", iTeamTT);
	else
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_CAN_JOIN_TT", iTeamTT);
		iKeys |= MENU_KEY_1;
	}
	
	if((iTeamCT - iTeamTT) >= PLAYER_DIFF || iPlayerTeam == TeamCT)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_CANT_JOIN_СT", iTeamCT);
	else
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_CAN_JOIN_СT", iTeamCT);
		iKeys |= MENU_KEY_2;
	}
	
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_AUTO_CHOOSE");
	iKeys |= MENU_KEY_5;
	
	if(iPlayerTeam == TeamSpectate)
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_CANT_SPECTATE");
	else
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_CAN_SPECTATE");
		iKeys |= MENU_KEY_6;
	}
	
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", id, "TB_MENU_EXIT");
}

FullJoin(const id, const iKey)
{
	switch(iKey)
	{
		case 0: engclient_cmd(id, "jointeam", "1");
		case 1: engclient_cmd(id, "jointeam", "2");
		case 4: AutoChoose(id);
		case 5:
		{
			user_kill(id, 1);
			engclient_cmd(id, "jointeam", "6");
		}
	}
	
	g_fLastTeamChange[id] = get_gametime();
}

AutoMenuJoin(const id, const iKey)
{
	switch(iKey)
	{
		case 0: AutoChoose(id);
		case 5: 
		{
			user_kill(id, 1);
			engclient_cmd(id, "jointeam", "6");
		}
	}
	
	g_fLastTeamChange[id] = get_gametime();
}

AutoChoose(const id)
{
	new iTeamTT, iTeamCT;
	new iPlayerTeam = _:cs_get_user_team(id);
	CalculateTeamNum(iTeamTT, iTeamCT);
	
	if(iTeamTT > iTeamCT)
	{
		if(iPlayerTeam != TeamCT) 
			engclient_cmd(id, "jointeam", "2");
	}
	else if(iTeamCT > iTeamTT)
	{
		if(iPlayerTeam != TeamTT) 
			engclient_cmd(id, "jointeam", "1");
	}
	else 
	{
		new iNewTeam = random(10) % 2 ? TeamCT : TeamTT;
		
		engclient_cmd(id, "jointeam", (iNewTeam == TeamCT) ? "2" : "1");
	}
}

Float:get_skill(iKills, iDeaths, iHeadShots)
{
	new Float:fSkill;
	if(iDeaths == 0) 
	{
		iDeaths = 1;
	}
	fSkill = (float(iKills)+ float(iHeadShots))/float(iDeaths);
	
	return fSkill;
}