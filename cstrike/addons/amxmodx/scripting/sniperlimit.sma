/* AMX Mod X script. 
* 
* Drop AWP with Team Limit and Win limit v1.6 (CS & CS:CZ) 
* By SuicideDog & MattOG/DaSoul & KWo
*
* Modded orignal from JustinHoMi 
*
*Up-To Version 0.5: SuicideDog & JustinHoMi
*******************************************
*
*
* VERSION: 1.0: MattOG
**********************
*
* Combined all 3 plugins (g3sg1/sg550/awp limit) into one.
* Added seperate commands to control Auto's and Awps. (different limits/rounds)
* Fixed bug with old-style menu's still being able to buy guns. (Credit to bAnTAi, I used his Y.A.S.C. plugin to help with the code).
*
* I didn't make it stop bots:
* 1. All bots come with built in weapon restrictions.
* 2. Bots tend not to be AWP whores  ;)
*
*
* VERSION 1.1: MattOG
*********************
* Changed Maxawps/autos and winspreads to cvars to enable on-the-fly changing, and to allow changes to be set in server/amxx/map configs.
*
*
* VERSION: 1.2: MattOG
**********************
*
* Minor bug fix where old style menu's couldn't buy at all. (Thanks to Olie for pointing it out).
*
*
* VERSION: 1.3: SuicideDog/DaSoul
**********************
*
* Added DaSoul's code to allow it to work with PTB correctly
*
* VERSION: 1.4: KWo
**********************
*
* Little bug fixes causing Run Time Errors etc...
* Blocking pickup limited weapon
* Bots are affected by this plugin, too but it doesn't prevent them from buying (they drop limited weapons after buying)
* Optimized usage of cvars by using pcvar functions.
*
**********************
*
* VERSION: 1.5: KWo
*
* Added support for team balancing (if someone has an awp or auto sniper and get switched alive to the opposite team)
*
**********************
*
* VERSION: 1.52: KWo
*
* Added min_players setting (cvar) to allow awps/autos if at least min_players amount in each team is reached
*
**********************
*
* VERSION: 1.53: KWo
*
* Fixed bug with not counting properly awps and autos when droping weapon by engine (i.e. while buying a new weapon)
* Fixed bug with displaying unnecessary message about awps/autos limitation 
* Fixed bug with player blocking from pickup awp/autos when only one of them was really limited by cvars
*
**********************
*
* VERSION: 1.60: KWo
*
* Many functions re-written to fix the stack error problem
*
**********************
* CVARS:
***********
*
* max_awps <xx> - Maximum Awps Allowed
* max_autos <xx> - Maximum Autos Allowed
* winspread_awp <xx> - When This Many Rounds Ahead, No Awps Allowed
* winspread_auto <xx> - When This Many Rounds Ahead, No Autos Allowed
* min_players <xx> - Below this amount of players in team, awp/auto are completly restricted (no matter of max_awps and max_autos)
* autolimit <1/0> - 1 = Restrict Auto, 0 = Don't
* awplimit <1/0> - 1 = Restrict Awp, 0 = Don't
* checkrebuy <1/0> - 1 = Prevent Rebuy Command, 0 = Don't
*
* TIPS:
*     To ALWAYS restrict to X number of awps/autos set winspread_awp/auto to 0 and max_awps/autos to however many awps/autos
*	   To ONLY restrict after X number of rounds ahead, set max_awps/autos to 20 and winspread_awp/autos to however many rounds
*
* KNOWN BUG/ISSUES:
************
* Updating the CVARS in game will only take effect after the following round has finished.
* Bots can buy limitted weapon, but they drop it immediatelly after buying. They cannot pickup dropped limited weapons 
* (like human players), so it's not a big issue.
*
* TO DO:
********
* Dunno, you tell me  ;)  Possibly will look at that following round thing, though it isn't too much hassle so I may not bother. You Decide.
*
*/

#include <amxmodx> 
#include <fakemeta>

#pragma dynamic 8192

new const PLUGINNAME[] = "AWP/AUTO Limit (Team/Win)"
new const VERSION[] = "1.60"
new const AUTHOR[] = "SD/MG/DS/KWo"

new plist[33] = { 0, ... }   // 0 = no awp; 1 = carrying awp 
new plist2[33] = {0, ... }   // 0 = no auto; 1 = carrying auto
new awp_count[3]         // 1 = T; 2 = CT 
new auto_count[3]        // 1 = T; 2 = CT
new ctscore = 0 
new tscore = 0  
new gl_maxplayers

/* PCvars */
new pv_awplimit
new pv_max_awps
new pv_winspread_awp
new pv_autolimit
new pv_max_autos
new pv_winspread_auto
new pv_checkrebuy
new pv_minplayers

/* handles restricting the menu */
public menu_awp(id,key)
{
	if (get_pcvar_num(pv_awplimit) != 1) return PLUGIN_CONTINUE
	
	new team = get_user_team(id)
	new winspread_awp = get_pcvar_num(pv_winspread_awp)
	new min_players = get_pcvar_num(pv_minplayers)
	new team1_num, team2_num, score_dif
	new players[32]

	get_players(players,team1_num,"e","TERRORIST")
	get_players(players,team2_num,"e","CT")

	if ((team1_num < min_players) || (team2_num < min_players))
	{
		engclient_cmd(id,"menuselect","10")
		client_print(id,print_center,"Not enough people in one team to allow AWP's (Ts:%d, CTs:%d, MIN:%d).", team1_num, team2_num, min_players)
		return PLUGIN_HANDLED
	}

	if (winspread_awp)
	{
		if (team == 2)
			score_dif = ctscore - tscore
		else if (team == 1)
			score_dif = tscore - ctscore

		if (score_dif >= winspread_awp)
		{	
			engclient_cmd(id,"menuselect","10")
			client_print(id,print_center,"You are on the winning team and cannot use AWP's (ScDif:%d, WsAWP:%d).", score_dif, winspread_awp)
			return PLUGIN_HANDLED
		}
	}

	if (awp_count[team] >= get_pcvar_num(pv_max_awps))
	{
		engclient_cmd(id,"menuselect","10")
		client_print(id,print_center,"Too many people on your team have AWP's (%d/%d).", awp_count[team], get_pcvar_num(pv_max_awps))
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE
}

/* handles restricting the menu */
public menu_auto(id,key)
{
	if (get_pcvar_num(pv_autolimit) != 1) return PLUGIN_CONTINUE

	new team = get_user_team(id)
	new winspread_auto = get_pcvar_num(pv_winspread_auto)
	new min_players = get_pcvar_num(pv_minplayers)
	new team1_num, team2_num, score_dif
	new players[32]

	get_players(players,team1_num,"e","TERRORIST")
	get_players(players,team2_num,"e","CT")

	if ((team1_num < min_players) || (team2_num < min_players))
	{
		engclient_cmd(id,"menuselect","10")
		client_print(id,print_center,"Not enough people in one team to allow AUTO's (Ts:%d, CTs:%d, MIN:%d).", team1_num, team2_num, min_players)
		return PLUGIN_HANDLED
	}

	if (winspread_auto)
	{
		if (team == 2)
			score_dif = ctscore - tscore
		else if (team == 1)
			score_dif = tscore - ctscore

		if (score_dif >= winspread_auto)
		{
			engclient_cmd(id,"menuselect","10")
			client_print(id,print_center,"You are on the winning team and cannot use AUTO's (ScDif:%d, WsAuto:%d).", score_dif, winspread_auto)
			return PLUGIN_HANDLED
		}
	}

	if (auto_count[team] >= get_pcvar_num(pv_max_autos))
	{
		engclient_cmd(id,"menuselect","10")
		client_print(id,print_center,"Too many people on your team have AUTO's (%d/%d).", auto_count[team], get_pcvar_num(pv_max_autos))
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE
}

/* handles if they script the AWP buy*/
public cmdawp(id)
{
	if (get_pcvar_num(pv_awplimit) != 1) return PLUGIN_CONTINUE

	new team = get_user_team(id)

	if ((team < 1) || (team > 2)) return PLUGIN_CONTINUE

	new winspread_awp = get_pcvar_num(pv_winspread_awp)
	new name[32]
	get_user_name(id,name,31)
	new min_players = get_pcvar_num(pv_minplayers)
	new team1_num, team2_num, score_dif
	new players[32]

	get_players(players,team1_num,"e","TERRORIST")
	get_players(players,team2_num,"e","CT")

	if ((team1_num < min_players) || (team2_num < min_players))
	{
		client_print(id,print_center,"Not enough people in one team to allow AWP's (Ts:%d, CTs:%d, MIN:%d).", team1_num, team2_num, min_players)
		return PLUGIN_HANDLED
	}

	if (winspread_awp)
	{
		if (team == 2)
			score_dif = ctscore - tscore
		else if (team == 1)
			score_dif = tscore - ctscore

		if (score_dif >= winspread_awp)
		{
			client_print(id,print_center,"You are on the winning team and cannot use AWP's (ScDif:%d, WsAWP:%d).", score_dif, winspread_awp)
			return PLUGIN_HANDLED
		}
	}

	if (awp_count[team] >= get_pcvar_num(pv_max_awps))
	{
		client_print(id,print_center,"Too many people on your team have AWP's (%d/%d).", awp_count[team], get_pcvar_num(pv_max_awps))
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

/* handles if they script the AUTO buy*/ 
public cmdauto(id) 
{ 
	if (get_pcvar_num(pv_autolimit) != 1) return PLUGIN_CONTINUE

	new team = get_user_team(id) 
	new winspread_auto = get_pcvar_num(pv_winspread_auto)
	new min_players = get_pcvar_num(pv_minplayers)
	new team1_num, team2_num, score_dif
	new players[32]

	get_players(players,team1_num,"e","TERRORIST")
	get_players(players,team2_num,"e","CT")

	if ((team1_num < min_players) || (team2_num < min_players))
	{
		client_print(id,print_center,"Not enough people in one team to allow AUTO's (Ts:%d, CTs:%d, MIN:%d).", team1_num, team2_num, min_players)
		return PLUGIN_HANDLED
	}

	if (winspread_auto)
	{
		if (team == 2)
			score_dif = ctscore - tscore
		else if (team == 1)
			score_dif = tscore - ctscore

		if (score_dif >= winspread_auto)
		{
			client_print(id,print_center,"You are on the winning team and cannot use AUTO's (ScDif:%d, WsAuto:%d).", score_dif, winspread_auto)
			return PLUGIN_HANDLED
		}
	}

	if (auto_count[team] >= get_pcvar_num(pv_max_autos))
	{
		client_print(id,print_center,"Too many people on your team have AUTO's (%d/%d).", auto_count[team], get_pcvar_num(pv_max_autos))
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}


/* handles when a player drops his weapon */ 
public handle_drop_weapon(id)
{
	if (!is_user_connected(id)) 
		return PLUGIN_CONTINUE
	
	new tmp1,tmp2 
	new curweapon = get_user_weapon(id,tmp1,tmp2)
	new team = get_user_team(id)

/* handles when a player drops their awp */	
	if (curweapon == CSW_AWP)
	{
		if ((plist[id]==1) && (awp_count[team] > 0))
			awp_count[team]--
		plist[id] = 0			
		return PLUGIN_CONTINUE
	}
/* handles when a player drops his auto */ 
	else if ((curweapon == CSW_SG550) || (curweapon == CSW_G3SG1))
	{
		if ((plist2[id]==1) && (auto_count[team] > 0))
			auto_count[team]--
		plist2[id] = 0
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
} 

public handle_pickup_weapon(id)
{
	if (!is_user_connected(id) || !pev_valid(id)) 
		return PLUGIN_CONTINUE

	new team = get_user_team(id)
	new wpflags = pev(id, pev_weapons)

	new bool:awp_exists = false
	new bool:auto1_exists = false
	new bool:auto2_exists = false
	
	if (wpflags & (1 << CSW_AWP))
		awp_exists = true
	if (wpflags & (1 << CSW_SG550))
		auto1_exists = true
	if (wpflags & (1 << CSW_G3SG1))
		auto2_exists = true

	if ((!awp_exists) && (plist[id] == 1))
	{
		plist[id] = 0
		if (awp_count[team] > 0)
			awp_count[team]--
	}
	else if ((awp_exists) && (plist[id] != 1))
	{
		handle_pickup_awp(id)
	}

	if ((!auto1_exists) && (!auto2_exists) && (plist2[id] == 1))
	{
		plist2[id] = 0
		if (auto_count[team] > 0)
			auto_count[team]--
	}
	else if ((auto1_exists) && (plist2[id] != 1))
	{
		handle_pickup_sg550(id)
	}
	else if ((auto2_exists) && (plist2[id] != 1))
	{
		handle_pickup_g3sg1(id)
	}

	return PLUGIN_CONTINUE
}

/* handles when a player picks up an awp */ 
public handle_pickup_awp(id)
{ 
	new team = get_user_team(id)
	new winspread_awp = get_pcvar_num(pv_winspread_awp)
	new name[32]
	get_user_name(id,name,31)
	new min_players = get_pcvar_num(pv_minplayers)
	new team1_num, team2_num, score_dif
	new players[32]

	get_players(players,team1_num,"e","TERRORIST")
	get_players(players,team2_num,"e","CT")

	if (get_pcvar_num(pv_awplimit) == 1)
	{
		if ((team1_num < min_players) || (team2_num < min_players))
		{
			set_task(0.5, "drop_awp", id)
			client_print(id,print_center,"Not enough people in one team to allow AWP's (Ts:%d, CTs:%d, MIN:%d).", team1_num, team2_num, min_players)
			return
		}

		if (winspread_awp)
		{
			if (team == 2)
				score_dif = ctscore - tscore
			else if (team == 1)
				score_dif = tscore - ctscore

			if (score_dif >= winspread_awp)
			{
				client_print(id,print_center,"You are on the winning team and cannot use AWP's (ScDif:%d, WsAWP:%d).", score_dif, winspread_awp)
				set_task(0.5, "drop_awp", id)
				return
			}
		}

		if (awp_count[team] >= get_pcvar_num(pv_max_awps)) 
		{
			client_print(id,print_center,"Too many people on your team have AWP's (%d/%d).", awp_count[team], get_pcvar_num(pv_max_awps))
			set_task(0.5, "drop_awp", id)
			return
		}
	}
	
	if (plist[id] != 1)
	{
		plist[id] = 1
		awp_count[team]++
//		client_print(id,print_chat,"You have bought or picked-up an awp. There is %d awps in Your team.", awp_count[team])
//		log_message("The player %s bought or picked-up an awp. There is %d awps in his team %d.", name, awp_count[team], team)
	} 
}

public drop_awp(id)
{
	new team, wpflags
	if (is_user_alive(id))
	{
		wpflags = pev(id, pev_weapons)
		if (wpflags & (1 << CSW_AWP))
		{
			engclient_cmd(id, "drop", "weapon_awp")

			if (plist[id] == 1)
			{
				team = get_user_team(id)
				if (awp_count[team] > 0)
					awp_count[team]--
				plist[id] = 0
			}
		}
	}
}

/* handles when a player picks up a g3sg1 */ 
public handle_pickup_g3sg1(id)
{
	new team = get_user_team(id)
	new winspread_auto = get_pcvar_num(pv_winspread_auto)
	new min_players = get_pcvar_num(pv_minplayers)
	new team1_num, team2_num, score_dif
	new players[32]

	get_players(players,team1_num,"e","TERRORIST")
	get_players(players,team2_num,"e","CT")

	if (get_pcvar_num(pv_autolimit) == 1)
	{
		if ((team1_num < min_players) || (team2_num < min_players))
		{
			client_print(id,print_center,"Not enough people in one team to allow AUTO's (Ts:%d, CTs:%d, MIN:%d).", team1_num, team2_num, min_players)
			set_task(0.5, "drop_g3sg1", id)
			return
		}

		if (winspread_auto)
		{
			if (team == 2)
				score_dif = ctscore - tscore
			else if (team == 1)
				score_dif = tscore - ctscore

			if (score_dif >= winspread_auto)
			{
				client_print(id,print_center,"You are on the winning team and cannot use AUTO's (ScDif:%d, WsAuto:%d).", score_dif, winspread_auto)
				set_task(0.5, "drop_g3sg1", id)
				return
			}
		}

		if (auto_count[team] >= get_pcvar_num(pv_max_autos))
		{
			client_print(id,print_center,"Too many people on your team have AUTO's (%d/%d).", auto_count[team], get_pcvar_num(pv_max_autos))
			set_task(0.5, "drop_g3sg1", id)
			return
		}
	}
	
	if (plist2[id] != 1)
	{
		plist2[id] = 1
		auto_count[team]++
	}
}

public drop_g3sg1(id)
{
	new team, wpflags
	if (is_user_alive(id))
	{
		wpflags = pev(id, pev_weapons)
		if (wpflags & (1 << CSW_G3SG1))
		{
			engclient_cmd(id, "drop", "weapon_g3sg1")

			if (plist2[id] == 1)
			{
				team = get_user_team(id)
				if (auto_count[team] > 0)
					auto_count[team]--
				plist2[id] = 0
			}
		}
	}
}

/* handles when a player picks up a sg550 */ 
public handle_pickup_sg550(id)
{
	new team = get_user_team(id)
	new winspread_auto = get_pcvar_num(pv_winspread_auto)
	new min_players = get_pcvar_num(pv_minplayers)
	new team1_num, team2_num, score_dif
	new players[32]

	get_players(players,team1_num,"e","TERRORIST")
	get_players(players,team2_num,"e","CT")

	if (get_pcvar_num(pv_autolimit) == 1)
	{
		if ((team1_num < min_players) || (team2_num < min_players))
		{
			client_print(id,print_center,"Not enough people in one team to allow AUTO's (Ts:%d, CTs:%d, MIN:%d).", team1_num, team2_num, min_players)
			set_task(0.5, "drop_sg550", id)
			return
		}

		if (winspread_auto)
		{
			if (team == 2)
				score_dif = ctscore - tscore
			else if (team == 1)
				score_dif = tscore - ctscore

			if (score_dif >= winspread_auto)
			{
				client_print(id,print_center,"You are on the winning team and cannot use AUTO's (ScDif:%d, WsAuto:%d).", score_dif, winspread_auto)
				set_task(0.5, "drop_sg550", id)
				return
			}
		}


		if (auto_count[team] >= get_pcvar_num(pv_max_autos))
		{
			client_print(id,print_center,"Too many people on your team have AUTO's (%d/%d).", auto_count[team], get_pcvar_num(pv_max_autos))
			set_task(0.5, "drop_sg550", id)
			return
		}
	}
	
	if (plist2[id] != 1)
	{
		plist2[id] = 1
		auto_count[team]++
	}
}

public drop_sg550(id)
{
	new team, wpflags
	if (is_user_alive(id))
	{
		wpflags = pev(id, pev_weapons)
		if (wpflags & (1 << CSW_SG550))
		{
			engclient_cmd(id, "drop", "weapon_sg550")

			if (plist2[id] == 1)
			{
				team = get_user_team(id)
				if (auto_count[team] > 0)
					auto_count[team]--
				plist2[id] = 0
			}
		}
	}
}

/* removes awp and auto when player dies */ 
public handle_death() 
{
	if ((get_pcvar_num(pv_awplimit) != 1) && (get_pcvar_num(pv_autolimit) != 1))
		return PLUGIN_CONTINUE
  
	new idx = read_data(2)
	if ((idx < 1) || (idx > gl_maxplayers))
		return PLUGIN_CONTINUE

	if (plist[idx] == 1)
	{
		new team = get_user_team(idx)
		if (awp_count[team] > 0)
			awp_count[team]--
		plist[idx] = 0
	}

	if (plist2[idx] == 1)
	{
		new team = get_user_team(idx)
		if (auto_count[team] > 0)
			auto_count[team]--
		plist2[idx] = 0
	}

	return PLUGIN_CONTINUE
}

/* clear vars when player connects */ 
public client_connect(id)
{
	if ((id > 0) && (id <= gl_maxplayers))
	{
		plist[id] = 0
		plist2[id] = 0
	}
	return PLUGIN_CONTINUE
}

/* clear vars when player disconnects */ 
public client_disconnect(id)
{
	new team
	if ((id > 0) && (id <= gl_maxplayers))
	{
		if (plist[id] == 1)
		{
			team = get_user_team(id)
			if (awp_count[team] > 0)
				awp_count[team]--
		}
		if (plist2[id] == 1)
		{
			team = get_user_team(id)
			if (auto_count[team] > 0)
				auto_count[team]--
		}	
		plist[id] = 0
		plist2[id] = 0
	}
	return PLUGIN_CONTINUE
}

public team_score()
{ 
	if ((get_pcvar_num(pv_awplimit) != 1) && (get_pcvar_num(pv_autolimit) != 1))
		return PLUGIN_CONTINUE

	new team[32]
	read_data(1,team,32)

	if (equal(team,"CT"))
	{ 
		ctscore = read_data(2)
	}
	else if (equal(team,"TERRORIST"))
	{
		tscore = read_data(2)
	}
	return PLUGIN_CONTINUE
} 

public check_winning_team(id) 
{ 
	if ((get_pcvar_num(pv_awplimit) != 1) && (get_pcvar_num(pv_autolimit) != 1)) return PLUGIN_CONTINUE
	if ((id < 1) || (id > gl_maxplayers)) return PLUGIN_CONTINUE
	if (!is_user_alive(id)) return PLUGIN_CONTINUE

	new team = get_user_team(id)
	new winspread_awp = get_pcvar_num(pv_winspread_awp)
	new winspread_auto = get_pcvar_num(pv_winspread_auto)
	new wpflags, score_dif

	if (plist[id] == 1) 
	{		
		if (winspread_awp)
		{
			if (team == 2)
				score_dif = ctscore - tscore
			else if (team == 1)
				score_dif = tscore - ctscore

			if (score_dif >= winspread_awp)
			{
				client_print(id,print_center,"You are on the winning team and cannot use AWP's (ScDif:%d, WsAWP:%d).", score_dif, winspread_awp)

				engclient_cmd(id, "drop", "weapon_awp")
				plist[id] = 0
				if (awp_count[team] > 0)
					awp_count[team]--
			}
		}
	}
	if (plist2[id] == 1) 
	{
		if (winspread_auto)
		{
			if (team == 2)
				score_dif = ctscore - tscore
			else if (team == 1)
				score_dif = tscore - ctscore

			if (score_dif >= winspread_auto)
			{
				client_print(id,print_center,"You are on the winning team and cannot use AUTO's (ScDif:%d, WsAuto:%d).", score_dif, winspread_auto)
				wpflags = pev(id, pev_weapons)
				if (wpflags & (1 << CSW_SG550))
				{
					engclient_cmd(id, "drop", "weapon_sg550")
					plist2[id] = 0
					if (auto_count[team] > 0)
						auto_count[team]--
				}
				if (wpflags & (1 << CSW_G3SG1))
				{
					engclient_cmd(id, "drop", "weapon_g3sg1")
					plist2[id] = 0
					if (auto_count[team] > 0)
						auto_count[team]--
				}
			}
		}
	}
	return PLUGIN_CONTINUE
}

/*
* 1 = T's: AWP Key 4, AUTOSNIPER Key 5
* 2 = CT's: AWP Key 5, AUTOSNIPER Key 4
*/
public via_me(id,key)
{
	new team = get_user_team(id)

	if ((team==1 && key==5) || (team==2 && key==4))
		menu_auto(id, key)
	if ((team==1 && key==4) || (team==2 && key==5))
		menu_awp(id, key)

	return PLUGIN_CONTINUE
}

public check_rebuy(id)
{
	if (get_pcvar_num(pv_checkrebuy) != 1) return PLUGIN_CONTINUE
	client_print(id,print_center,"Sorry Rebuy command is blocked on this server")

	return PLUGIN_HANDLED
}

public total_snipers()
{
	new players[32], numPlayerCount, idxPlayer, id, wpflags

	// 1 = T; 2 = CT 
	awp_count[1] = 0
	auto_count[1] = 0

	get_players(players, numPlayerCount,"he","TERRORIST")
	for(idxPlayer = 0; idxPlayer < numPlayerCount; idxPlayer++)
	{
		id = players[idxPlayer]

		if (!is_user_alive(id)) continue
		if (!pev_valid(id)) continue
		
		wpflags = pev(id, pev_weapons)
		
		plist[id] = 0
		plist2[id] = 0
		
		if (wpflags & (1 << CSW_AWP))
		{
			plist[id] = 1
			awp_count[1]++
		}
		if ((wpflags & (1 << CSW_SG550)) || (wpflags & (1 << CSW_G3SG1)))
		{
			plist2[id] = 1
			auto_count[1]++
		} 
	} 

	awp_count[2] = 0
	auto_count[2] = 0
	
	get_players(players, numPlayerCount,"he","CT")
	for(idxPlayer = 0; idxPlayer < numPlayerCount; idxPlayer++)
	{
		id = players[idxPlayer]

		if (!is_user_alive(id)) continue
		if (!pev_valid(id)) continue

		plist[id] = 0
		plist2[id] = 0
		
		if (wpflags & (1 << CSW_AWP))
		{
			plist[id] = 1
			awp_count[2]++
		}
		if ((wpflags & (1 << CSW_SG550)) || (wpflags & (1 << CSW_G3SG1)))
		{
			plist2[id] = 1
			auto_count[2]++
		} 
	} 
}

public round_start()
{
	total_snipers()  
}

public hook_touch(ptr, ptd)
{
	static ptrClass[32]
	static ptdClass[32]
	static ptrModel[128]
	static team
	static min_players
	static team1_num, team2_num, score_dif
	static players[32]
	static winspread_awp
	static winspread_auto
	static wpflags

	if ((get_pcvar_num(pv_awplimit) != 1) && (get_pcvar_num(pv_autolimit) != 1))
		return PLUGIN_CONTINUE

	if (ptd > gl_maxplayers || ptd < 1 || ptr < 1 )
		return PLUGIN_CONTINUE
		
	if ( (!pev_valid(ptr)) || (!pev_valid(ptd)) )
		return PLUGIN_CONTINUE

	if (!is_user_connected(ptd))
		return PLUGIN_CONTINUE

	pev(ptr, pev_classname, ptrClass, 31)
	pev(ptr, pev_model, ptrModel, 127)
	pev(ptd, pev_classname, ptdClass, 31)
	
	if ((!equal(ptrClass, "weaponbox")) && (!equal(ptrClass, "armoury_entity"))
		&& (!equal(ptrClass, "csdmw_",6)))
		return PLUGIN_CONTINUE

	if (equal(ptdClass, "player"))
	{
		team = get_user_team(ptd)
		min_players = get_pcvar_num(pv_minplayers)
		get_players(players,team1_num,"e","TERRORIST")
		get_players(players,team2_num,"e","CT")
		wpflags = pev(ptd, pev_weapons)

		if ((equal(ptrModel, "models/w_awp.mdl")) && (get_pcvar_num(pv_awplimit) == 1))
		{			
			if (!(wpflags & (1 << CSW_AWP)))
			{
				if ((team1_num < min_players) || (team2_num < min_players))
				{
					client_print(ptd,print_center,"Not enough people in one team to allow AWP's (Ts:%d, CTs:%d, MIN:%d).", team1_num, team2_num, min_players)
					return FMRES_SUPERCEDE
				}

				if (awp_count[team] >= get_pcvar_num(pv_max_awps))
				{
					client_print(ptd,print_center,"Too many people on your team have AWP's (%d/%d).", awp_count[team], get_pcvar_num(pv_max_awps))
					return FMRES_SUPERCEDE
				}

				winspread_awp = get_pcvar_num(pv_winspread_awp)
				if (winspread_awp)
				{
					score_dif = 0
					if (team == 2)
						score_dif = ctscore - tscore
					else if (team == 1)
						score_dif = tscore - ctscore

					if (score_dif >= winspread_awp)
					{
						client_print(ptd,print_center,"You are on the winning team and cannot use AWP's (ScDif:%d, WsAWP:%d).", score_dif, winspread_awp)
						return FMRES_SUPERCEDE
					}
				}
			}
			return PLUGIN_CONTINUE
		}
		
		if (((equal(ptrModel, "models/w_g3sg1.mdl")) || (equal(ptrModel, "models/w_sg550.mdl")))
			&& (get_pcvar_num(pv_autolimit) == 1))
		{
			if (!(wpflags & (1 << CSW_SG550)) && !(wpflags & (1 << CSW_SG550)))
			{
				if ((team1_num < min_players) || (team2_num < min_players))
				{
					client_print(ptd,print_center,"Not enough people in one team to allow AUTO's (Ts:%d, CTs:%d, MIN:%d).", team1_num, team2_num, min_players)
					return FMRES_SUPERCEDE
				}

				if (auto_count[team] >= get_pcvar_num(pv_max_autos))
				{
					client_print(ptd,print_center,"Too many people on your team have AUTO's (%d/%d).", auto_count[team], get_pcvar_num(pv_max_autos))
					return FMRES_SUPERCEDE
				}

				winspread_auto = get_pcvar_num(pv_winspread_auto)
				if (winspread_auto)
				{
					score_dif = 0
					if (team == 2)
						score_dif = ctscore - tscore
					else if (team == 1)
						score_dif = tscore - ctscore

					if (score_dif >= winspread_auto)
					{
						client_print(ptd,print_center,"You are on the winning team and cannot use AUTO's (ScDif:%d, WsAuto:%d).", score_dif, winspread_auto)
						return FMRES_SUPERCEDE
					}
				}
			}
			return PLUGIN_CONTINUE
		}
	}	
	return PLUGIN_CONTINUE
}

public team_assign() 
{
	new id = read_data(1)
	if ((id < 1) || (id > gl_maxplayers))
		return PLUGIN_CONTINUE
	if (!is_user_connected(id) || !is_user_alive(id) || (!plist[id] && !plist2[id]))
		return PLUGIN_CONTINUE

	total_snipers()

	return PLUGIN_CONTINUE
}

public plugin_init()
{
	register_plugin(PLUGINNAME,VERSION,AUTHOR)
	register_menucmd(-31,(1<<4),"via_me" )                                    //  T: AWP, CT: Sig SG-550 Sniper       - VGUI
	register_menucmd(-31,(1<<5),"via_me" )                                    // CT: AWP, T:  H&K G3SG-1 Sniper Rifle - VGUI
	register_menucmd(register_menuid("BuyRifle",1),(1<<4),"via_me" )          //  T: AWP, CT: Sig SG-550 Sniper       - STANDARD
	register_menucmd(register_menuid("BuyRifle",1),(1<<5),"via_me" )          // CT: AWP, T:  H&K G3SG-1 Sniper Rifle - STANDARD
	register_clcmd("drop","handle_drop_weapon")

	register_clcmd("awp","cmdawp") 
	register_clcmd("magnum","cmdawp")
	register_clcmd("g3sg1","cmdauto")
	register_clcmd("d3au1","cmdauto")
	register_clcmd("sg550","cmdauto")
	register_clcmd("krieg550","cmdauto")
	register_clcmd("rebuy","check_rebuy")

	pv_awplimit = register_cvar("awplimit","1")
	pv_autolimit = register_cvar("autolimit","1")
	pv_checkrebuy = register_cvar("checkrebuy","1")
	pv_max_awps = register_cvar("max_awps","2")
	pv_max_autos = register_cvar("max_autos","1")
	pv_minplayers = register_cvar("min_players","5")
	pv_winspread_awp = register_cvar("winspread_awp","3")
	pv_winspread_auto = register_cvar("winspread_auto","2")

	register_event("TeamScore", "team_score", "a")
	register_event("TeamInfo","team_assign","a")
	register_event("WeapPickup","handle_pickup_weapon","b")
	register_event("DeathMsg","handle_death","a") 

	register_event("ResetHUD","check_winning_team","be") 

	register_logevent("round_start", 2, "1=Round_Start")
	register_forward(FM_Touch, "hook_touch")
	gl_maxplayers = get_maxplayers()
}