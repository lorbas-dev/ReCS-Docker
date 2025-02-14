/* Plugin generated by AMXX-Studio 
	Original creator: Dunn0
	Remade by: Unkolix & Lorbass
	
Changelog by Lorbass
	v6.0.0 - Disable VIP messages 
		   - read cvars every new round, so server must not change map for changes to take effect
		   - destroy menu on restart and leave of buyzone
		   - cap money at 16000

Changelog by me, Unkolix:
	v5.4.5 - MotD correction, should work perfectly now. + auto contact info + price in motd.
	v5.4.4 - A new cvar to control how to show online vip list. vip_list 0/1/2. off/chat/motd. Thanks to alicx
	v5.4.3 - Edited all cvars, vip_ prefix added. color_msg now changes /vips colors and vip info color.
	v5.4.2 - Added a cvar for vip price show: amx_vipprice "price"
	v5.4.1 - Renewed amx_contactinfo cvar, now it will be shown when player types /vips and in want vip MotD.
	v5.4.0 - If files awpmapnames.ini and mapnames.ini are missing, they are automatically created.
	v5.3.9 - MotD improvement, no need for other .txt files. Example taken from: souvikdas95
	v5.3.8 - Fixed double grenade throw bug, thanks to ConnorMcLeod.
	v5.3.7 - Now you can control the menu number colors with menu_num_color 0/1/2/3.
	v5.3.6 - Fixed C4 not showing on players back.
	v5.3.5 - Not using colorchat.inc anymore, color stock instead! Small error fix. New cvar colored_text_message - control the printed message color.
	v5.3.4 - Now changing VIP models with Fakemeta module. Tag Mismatch fix.
	v5.3.3 - Grenades fix. Optimization.
	v5.3.2 - VIP models added, controled by a cvar vip_models 1/0
	v5.3.1 - Added error message if files awpmapnames.ini and mapnames.ini doesn't exist. Another way not to allow non VIP players
	to pick up snipers, thanks to SeriousSpot.
	v5.3.0 - Terrorists won't get defuse kits now. New bullet damage system (took from Sn!ff3r). 
	A lot of optimization and fixes, thanks to aaarnas. 2 new cvars, bulletdamage_recieved, bulletdamage
	v5.2.9 - Multi-lingual "Back." menu item added.
	v5.2.8 - Fixed menu choices after death and on new round.
	v5.2.7 - Now you can easily change the flag wich gives all the abilities. Thanks to quilhos. Line: 95
	v5.2.6 - Multi-lingual want vip MotD added
	v5.2.5 - Small sniper pickup fix
	v5.2.4 - Now players won't lose their defuse kits after taking weapons from menu
	v5.2.3 - Fixed flashed bug, a little change on motd window
	v5.2.2 - Fixed player_menu_info error
	v5.2.1 - Not using stripweapons include anymore, just to get rid of that shield bug.
	v5.2 - Several fixes, optimization. New cvar to control if only VIP's can pick up snipers.
	v5.1 - Fixed shield bug.
	v5.0 - Multi-lingual added!
	v4.9.2 - New cvar, awp_active. 1 - VIP can get AWP choice; 0 - cann't
	v4.9.1 - AWP choice improvement. New Cvar, awp_menu_round, set the round from which VIP can see AWP choice.
	v4.8 - Fixed VIP menu dilsplay after player death. Thanks to vitorrossi.
	v4.7 - Fixed fading bug/glitch that was removing flashbang effect. Thanks to ConnorMcLeod.
	v4.6 - Fixed log error. Thanks to wickedd.
	v4.5 - OPTIMISATION, thanks to Backstabnoob.
	v4.4 - New Cvars awp_ct and awp_tr, how mant counter-terrorists and terrorists must be in each team to get AWP choice in VIP menu
	v4.3 - New feature, AWP only from sertain amount of players. Thanks to Emp`.
	v4.2 - Added new Cvar, vip_menu_uses. Thanks to Erox902.
	v4.1 - mapnames and awpmapnames consts are now readed from 2 files, awpmanames.ini and mapnames.ini. Thanks to fysiks.
	v4.0 - New feature, awp an't be used in maps that are mentioned in awpmapnames const. UPDATE: awpmapnames.ini
	v3.9 - Added new menu item, AWP.
	v3.8 - Improved v3.7 update. Thanks to Bugsy.
	v3.7 - New feature, VIP menu can't be shown on maps which are listed in mapnames const. UPDATED: mapnames.ini
	v3.6 - Small part is rewrited with drekes help, he made stripweapons.inc
	v3.5 - Fixed triple VIP message. Thanks jimaway!
	v3.4 - Fixed a bug/glitch which didn't let player to have AWP, even on awp maps! Now, they can't buy it, but if they find it, they can have it.
	v3.3 - Completely remade menu
	v3.2 - Fixed a bug/glitch when all VIP players was getting defuse kit on all maps. Now only on maps which has bombsites and only for CT. Thanks ConnorMcLeod
	v3.1 -  Added commands to call VIP menu. Thanks Stereo!
	
	Changelog by original author Dunn0:
	Updates on 3.0version
	Granates bug fixed, give it when round starts only. Removed hamsandwich module becouse i removed event witch was usualess.
	
	Updates on 2.06version
	Fixed C4 Planting just need'ed remove 1 simbol... Remove'd AWP pick up now only VIP can buy awp and non VIP can pick up it from ground. Fixed Bug whit menu was giving in first round I changed some events and it works just fine.
	
	Updates on 2.05version
	Was not working /wantvip , /vips command it got fixed. Was removed "pickup_active 1" cvar (couse was to much commands in registrations. Was removed some useless commands. Now changed that Only VIPS can buy awp weapons but normal players can pick up awp if VIPS drop it.
	
	Updates on 2.04version
	Menu Fixed now it always shows only from 3rd round. Nades , armor will give when u spawn not from round start. Some small fixes on Event_curweapons. 
	Add cvar pickup_active 1 so now if u write pickup_active 0 not vips will can pick up AWP weapons just wont be able to buy.
	
	Updated at 2.03version
	Repaired C4 bug now u can plant it
	
	Updated at 2.02version
	Repaired C4 bug
	
	UPDATE's at 2.01version
	Well i add'ed 2 new cvar's becouse people was asking it
	First is "menu_active 1" so now u can turn off menu when u will one.
	Second is "sniper_active 1" well if u will do it 0 all people will can buy awp.
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>

#define PLUGIN "VIP Plugin"
#define VERSION "6.0.0"
#define AUTHOR "Unkolix + Lorbass"

#define VIP_FLAG ADMIN_LEVEL_H
#define MAXPLAYERS 32 + 1
#define ALPHA_FULLBLINDED 255
#define g_Buffer 1536
#define find_ent_by_class(%1,%2) engfunc(EngFunc_FindEntityByString, %1, "classname", %2)

const m_flFlashedUntil = 514;
const m_flFlashedAt = 515;
const m_flFlashHoldTime = 516;
const m_flFlashDuration = 517;
const m_iFlashAlpha = 518;
const m_flFlashDuration = 517;
new gMenuUsed[33];
new money_per_damage, money_kill_bonus, money_headshot_bonus;
new health_add, health_hs_add, health_max;
new nKiller, nKiller_hp, nHp_add, nHp_max;
new g_sniper_active, g_menu_active, g_map_active, g_awp_active, awp_active;
new g_menu_uses, g_awp_ct, g_awp_tr, g_menu_round, g_awp_menu_round, g_sniper_pickup;
new map_active, CT, TR, menu_round, awp_menu_round, menu_uses;
new CurrentRound;
new bool:g_bHasBombSite;
new bool:g_freezetime;
new bool:bAwpMap = false;
new bool:g_bCurrentMapIsInList = false; 
new bool:g_bCurrentAWPMapIsInList = false;
new bool:g_bRoundEnd;
new iTCount, iCTCount;
new g_type, g_enabled, g_recieved, bool:g_showrecieved, g_hudmsg1, g_hudmsg2;
new g_menu_number_color, menu_number_color;

new const VIPweapons[][] =
{
    //Weapons which normal players can't pick up.
    "awp", "sg550", "g3sg1"
}

new const vipguns[][] =
{
	"weapon_awp", "weaopn_g3sg1", "weapon_sg550"
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_event("HLTV", "event_new_round", "a", "1=0", "2=0");
	register_logevent("LogEvent_RoundStart", 2, "1=Round_Start" );
	register_logevent("LogEvent_RoundEnd", 2, "1=Round_End");
	register_logevent("LogEvent_GameCommencing", 2, "0=World triggered", "1=Game_Commencing");
	register_event("TextMsg","Event_RoundRestart","a","2&#Game_w");
	register_event("StatusIcon", "StatusIcon_buyzone_OFF", "be", "1=0", "2=buyzone"); 
	register_event("DeathMsg", "hook_death", "a", "1>0");
	register_event("DeathMsg","death_msg","a");
	register_event("Damage", "on_damage", "b", "2!0", "3=0", "4!0");
	register_event("Damage","Damage","b");
	RegisterHam(Ham_Spawn, "player", "fwHamPlayerSpawnPost", 1);
	RegisterHam(Ham_Touch, "weaponbox", "fw_TouchWeapon");
	RegisterHam(Ham_Touch, "armoury_entity", "fw_TouchWeapon");
	
	for(new i = 0; i < sizeof VIPweapons; i++)
    register_clcmd(VIPweapons[i], "HandleCmd") //Checks const VIPweapons, that is above plugin_init
	
	money_per_damage 	= register_cvar("vip_money_per_damage","3") //How many $ VIP will get per 1 damage 
	money_kill_bonus 	= register_cvar("vip_money_kill_bonus","200") //How many $ VIP will get per kill
	money_headshot_bonus 	= register_cvar("vip_money_hs_bonus","500") //How many $ VIP will get per head shot kill 
	health_add 		= register_cvar("vip_hp", "15") //How many hp VIP will get per kill 
	health_hs_add 		= register_cvar("vip_hp_hs", "30") //How many hp VIP will get per head shot kill 
	health_max 		= register_cvar("vip_max_hp", "100") //How many hp VIP can have in total 
	g_sniper_active 	= register_cvar("vip_sniper_active", "1") //Who can buy SNIPERS? 0 - everyone, 1 - only VIP
	g_menu_active 		= register_cvar("vip_menu_active", "1") //Will VIP get VIP menu? 0 - won't get the menu, 1 - will get the menu.
	g_map_active 		= register_cvar("vip_map_active", "1") //VIP menu works on the maps in mapnames.ini? 0 - Yes (VIP will get VIP menu), 1 - No
	g_awp_active 		= register_cvar("vip_awp_active", "1") // 1 - VIP can get AWP choice; 0 - cann't
	g_menu_uses 		= register_cvar("vip_menu_uses", "1") // How many times VIP can use VIP menu per round?
	g_awp_ct 		= register_cvar("vip_awp_ct", "5") //How many counter terrorist must be in a team to AWP choice show up
	g_awp_tr 		= register_cvar("vip_awp_tr", "5") //How many terrorist must be in a team to AWP choice show up
	g_menu_round 		= register_cvar("vip_menu_round", "2") //Round from which VIP will get VIP menu
	g_awp_menu_round 	= register_cvar("vip_awp_menu_round", "3") //Round from which VIP will get AWP choice
	g_sniper_pickup 	= register_cvar("vip_sniper_pickup", "1") //0 - everyone can pickup snipers, 1 - only VIP
	g_recieved 		= register_cvar("vip_bulletdamage_recieved","1") //0 - bullet damage disabled, 1 - show damage done, 2 - show damage done, but not via wall
	g_type 			= register_cvar("vip_bulletdamage","1") // Enable or disable showing recieved damage
	g_menu_number_color 	= register_cvar("vip_menu_number_color", "0") //0 - red, 1 - yellow, 2 - white, 3 - grey.

	g_hudmsg1 		= CreateHudSyncObj()
	g_hudmsg2 		= CreateHudSyncObj()
	
	if( find_ent_by_class(-1, "func_bomb_target") || find_ent_by_class(-1, "info_bomb_target") ) //Checks if the map has bombsite
	{
		g_bHasBombSite = true; //If the map has bombsite it is set to true
	}
	
	get_user_msgid("ScreenFade")
	
	register_dictionary( "vip.txt" );
}

public plugin_cfg()
{
	map_active = get_pcvar_num (g_map_active); //Gets the value of g_map_active 
	awp_active = get_pcvar_num (g_awp_active); //Gets the value of g_awp_active 
	CT = get_pcvar_num (g_awp_ct); //Gets the value of g_awp_ct
	TR = get_pcvar_num (g_awp_tr); //Gets the value of g_awp_tr
	menu_round = get_pcvar_num (g_menu_round);
	awp_menu_round = get_pcvar_num (g_awp_menu_round);
	menu_uses = get_pcvar_num (g_menu_uses);
	menu_number_color = get_pcvar_num(g_menu_number_color);
	
	new szmapnames[128], szData[32], szCurrentMap[32], szawpmapnames[128];
	format( szmapnames, 128, "addons/amxmodx/configs/mapnames.ini" )
	if(!file_exists(szmapnames))
	{
		server_print("[VIP] File %s is missing!", szmapnames);
		server_print("[VIP] File %s is created.", szmapnames);
		write_file(szmapnames, "awp_")
		write_file(szmapnames, "cs_deagle")
		write_file(szmapnames, "knf_")
		write_file(szmapnames, "1hp_")
		write_file(szmapnames, "aim")
	}
	if(file_exists(szmapnames)) 
	{
		get_configsdir(szmapnames, charsmax(szmapnames)); // Get the AMX Mod X configs directory (folder). 
		add(szmapnames, charsmax(szmapnames), "/mapnames.ini"); // Add your filename to the filepath. 
		get_mapname(szCurrentMap, charsmax(szCurrentMap)); // Get the current map. 
	     
		new f = fopen(szmapnames, "rt"); // Open the file. 
		while( !feof(f) ) // Loop until it finds the End Of the File (aka EOF). 
		{ 
			fgets(f, szData, charsmax(szData)); // Get all text from current line.
			trim(szData); // Trim off the new line and carriage return characters.
			if( containi(szCurrentMap, szData) != -1 )   // Check if the current map is equal to the map listed on this line. 
			{ 
				g_bCurrentMapIsInList = true; // Set boolean to true so that you know if the map was in the file. 
				break; // Stop looping (reading the file) because you found what you came for. 
			} 
		} 
		fclose(f); // Close the file.
	}
	
	format( szawpmapnames, 128, "addons/amxmodx/configs/awpmapnames.ini" )
	if(!file_exists(szawpmapnames))
	{
		server_print("[VIP] File %s is missing!", szawpmapnames);
		server_print("[VIP] File %s is created.", szawpmapnames);
		write_file(szawpmapnames, "2x2")
		write_file(szawpmapnames, "3x3")
		write_file(szawpmapnames, "4x4")
		write_file(szawpmapnames, "cs_max")
		write_file(szawpmapnames, "aim")
	}
	if(file_exists(szawpmapnames))
	{
		//Now lets check if current map is in awpmapnames.ini
		get_configsdir(szawpmapnames, charsmax(szawpmapnames)); // Get the AMX Mod X configs directory (folder). 
		add(szawpmapnames, charsmax(szawpmapnames), "awpmapnames.ini"); // Add your filename to the filepath. 
		get_mapname(szCurrentMap, charsmax(szCurrentMap)); // Get the current map. 
		
		new f = fopen(szawpmapnames, "rt"); // Open the file. 
		while( !feof(f) ) // Loop until it finds the End Of the File (aka EOF). 
		{ 
			fgets(f, szData, charsmax(szData)); // Get all text from current line. 
			trim(szData); // Trim off the new line and carriage return characters. 
			if( containi(szCurrentMap, szData) != -1 )   // Check if the current map is equal to the map listed on this line. 
			{ 
				g_bCurrentAWPMapIsInList = true; // Set boolean to true so that you know if the map was in the file. 
				break; // Stop looping (reading the file) because you found what you came for. 
			} 
		} 
		fclose(f); // Close the file.
	}
}


public event_new_round(id)
{
	menu_destroy_all();
	plugin_cfg();

	g_freezetime = false; // Freeze time has ended, so lets set it to false
	g_enabled = get_pcvar_num(g_type)
	if(get_pcvar_num(g_recieved)) g_showrecieved = true
}

public LogEvent_RoundStart(id)
{
	g_freezetime = true;
	g_bRoundEnd = false;
	gMenuUsed[id] = 0;
	iTCount = 0;
	iCTCount = 0;
	CurrentRound++;
	new players[32], player, pnum; 
	get_players(players, pnum, "a");
	for ( new i; i < pnum; i++ )
	{
		switch( cs_get_user_team( players[i] ) )
		{
			case CS_TEAM_T: iTCount++;
			case CS_TEAM_CT: iCTCount++;
		}
	}
	for(new i = 0; i < pnum; i++)
	{
		player = players[i];
		if (!get_pcvar_num(g_menu_active))
			return PLUGIN_CONTINUE
		
		if( CurrentRound >= menu_round && get_user_flags(id) & VIP_FLAG )
		{
			Showrod(player);
		}
	}
	return PLUGIN_CONTINUE
}

public menu_destroy_all() 
{
	new players[32], pnum;
	get_players(players, pnum, "a");
	for ( new i; i < pnum; i++ )
	{
		menu_force_destroy(players[i]);
	}
}

public menu_force_destroy(id)
{
	new user_menu, keys;

	get_user_menu(id, user_menu, keys);
	if (user_menu > 0)
	{
		//menu_destroy(user_menu);
		menu_cancel(id);
		show_menu(id, 0, "^n", 1);
	}
}

public LogEvent_RoundEnd()
{
	g_bRoundEnd = true;
}

public StatusIcon_buyzone_OFF(id)
{
	menu_force_destroy(id);
}

public Event_RoundRestart(id)
{
	menu_destroy_all();
	CurrentRound=0;
}

public LogEvent_GameCommencing(id)
{
	menu_destroy_all();
	CurrentRound=0;
}

public hook_death()
{
	new hp_added[64];
	// Killer id
	nKiller = read_data(1)
	if(is_user_alive(nKiller)) 
	{
		if ( (read_data(3) == 1) && (read_data(5) == 0) )
		{
			nHp_add = get_pcvar_num (health_hs_add)
		}
		else
		nHp_add = get_pcvar_num (health_add)
		nHp_max = get_pcvar_num (health_max)
		// Updating Killer HP
		if(!(get_user_flags(nKiller) & VIP_FLAG))
		return;
	
		nKiller_hp = get_user_health(nKiller)
		nKiller_hp += nHp_add
		// Maximum HP check
		if (nKiller_hp > nHp_max) nKiller_hp = nHp_max
		set_user_health(nKiller, nKiller_hp)
		// Hud message "Healed +15/+30 hp"
		if(nKiller_hp < nHp_max)
		{
			format(hp_added, sizeof(hp_added), "%L", nKiller, "HP_ADDED", nHp_add)
			set_hudmessage(0, 255, 0, -1.0, 0.15, 0, 1.0, 1.0, 0.1, 0.1, -1)
			show_hudmessage(nKiller, hp_added)
		}
		// Screen fading
		if(!get_user_flashed(nKiller)) //Checks if user is not flashed
		{
			message_begin(MSG_ONE, get_user_msgid("ScreenFade"), {0,0,0}, nKiller)
			write_short(1<<10)
			write_short(1<<10)
			write_short(0x0000)
			write_byte(0)
			write_byte(0)
			write_byte(200)
			write_byte(75)
			message_end()
		}
	}
}

public death_msg()
{
	if(read_data(1)<=MAXPLAYERS && read_data(1) && read_data(1)!=read_data(2)) cs_set_user_money(read_data(1),cs_get_user_money(read_data(1)) + get_pcvar_num(money_kill_bonus) - 300)
}

public on_damage(id)
{
	if(g_enabled)
	{		
		static attacker; attacker = get_user_attacker(id)
		static damage; damage = read_data(2)		
		if(g_showrecieved)
		{			
			set_hudmessage(255, 0, 0, 0.45, 0.50, 2, 0.1, 4.0, 0.1, 0.1, -1)
			ShowSyncHudMsg(id, g_hudmsg2, "%i^n", damage)		
		}
		if(is_user_connected(attacker))
		{
			switch(g_enabled)
			{
				case 1: {
					set_hudmessage(0, 100, 200, -1.0, 0.55, 2, 0.1, 4.0, 0.02, 0.02, -1)
					ShowSyncHudMsg(attacker, g_hudmsg1, "%i^n", damage)				
				}
				case 2: {
					if(fm_is_ent_visible(attacker,id))
					{
						set_hudmessage(0, 100, 200, -1.0, 0.55, 2, 0.1, 4.0, 0.02, 0.02, -1)
						ShowSyncHudMsg(attacker, g_hudmsg1, "%i^n", damage)				
					}
				}
			}
		}
	}
}

public Damage(id)
{
	new weapon, hitpoint, attacker = get_user_attacker(id,weapon,hitpoint)
	if(attacker<=MAXPLAYERS && is_user_alive(attacker) && attacker!=id)
	if(get_user_flags(id) & VIP_FLAG) 
	{
		new money = read_data(2) * get_pcvar_num(money_per_damage)
		if(hitpoint==1) money += get_pcvar_num(money_headshot_bonus)
		cs_set_user_money(attacker,min(16000, cs_get_user_money(attacker) + money))
	}
}

public fwHamPlayerSpawnPost(id)
{
	gMenuUsed[id] = 0; //Make sure that VIP didn't use VIP menu on his spawn
	if(is_user_alive(id))
	{
		if(get_user_flags(id) & VIP_FLAG)
		{
			if(!g_bCurrentMapIsInList) //Checks if map is not the one written in mapnames.ini, if user is alive and if e has flag H
			{
				give_item(id, "weapon_hegrenade"); //Gives HE grenade
				give_item(id, "weapon_flashbang"); //Gives FB grenade
				give_item(id, "weapon_flashbang"); //Gives BF grenade
				give_item(id, "weapon_smokegrenade"); //Gives SG grenade
				give_item(id, "item_assaultsuit"); //Gives armor
				if(g_bHasBombSite && cs_get_user_team(id) == CS_TEAM_CT) //Checks if current map has bombsite
				{
					give_item(id, "item_thighpack"); //Gives defuse kit
				}
			}
	
		}
	}
}

public fw_TouchWeapon(weapon, id) 
{
	if (!get_pcvar_num(g_sniper_pickup)) //Checks if g_sniper_pickup is disactivated (set to 0)
		return PLUGIN_CONTINUE //If it is, let players pick up snipers
		
	if (!is_user_alive(id) || get_user_flags(id) & VIP_FLAG) 
	{
		return HAM_IGNORED
	}
   
	static classname[32]
	pev(weapon, pev_classname, classname, charsmax(classname))
 
	for(new i = 0; i < sizeof vipguns; i++)
	if (g_bCurrentMapIsInList && equal(classname, vipguns[i])) 
	{
		//Sends a message that snipers are only for VIP
		client_print(id, print_center, "%L", id, "SNIPER_ONLY_FOR_VIP")
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
} 


public cmdvipmenu(id) 
{
	if ( is_user_alive(id) )
	{
		if( get_user_flags(id) & VIP_FLAG )
		{
			if ( CurrentRound < menu_round )
			{
				client_print( id, print_center, "%L", id, "VIP_MENU_ROUND", menu_round ); //Sends a message that VIP can use VIP menu only from specific round
			}
			if ( map_active == 1 ) //Checks if map_active is 1
			{
				if( g_bCurrentMapIsInList ) //Checks if current map is in mapnames list
				{
					client_print( id, print_center, "%L", id, "VIP_MENU_WRONG_MAP" ); //Sends a message that VIP can't use VIP menu on that map
				}
			}
			if ( gMenuUsed[id] >= menu_uses )
			{
				client_print( id, print_center, "%L", id, "VIP_MENU_PER_ROUND", menu_uses ); //Message that VIP can only take VIP menu few time that is set as VIPUsed
			}
			if ( !g_freezetime ) //Checks if freezetime is not over yet and if user is alive and he has flag H
			{
				client_print( id, print_center, "%L", id, "VIP_MENU_ONLY_FROM_ROUND_START" ); //Message that's set in vipplugin.txt as VIP_MENU_ONLY_FROM_ROUND_START
			}
			if(g_freezetime) //Checks if freezetime is over
			{
				if ( gMenuUsed[id] < menu_uses ) //Checks if VIP has already used VIP menu before, the amount of times we set as VIPUsed 
				{
					if( CurrentRound >= menu_round ) //Checks if current round is more or equal to the round that is set as VIPMenuRound
					{	
						if (!get_pcvar_num(g_menu_active)) //Checks if g_menu_active is disactivated (set to 0)
							return PLUGIN_CONTINUE //If so, VIP won't get VIP menu
						Showrod(id) //Shows VIP menu
					}
				}
			}
		}
	}
	else if( get_user_flags(id) & VIP_FLAG ) //Checks if user is death and he have VIP_FLAG
	{
		client_print( id, print_center, "%L", id, "VIP_MENU_MUST_BE_ALIVE" ); //Sends a message that VIP must be alive to use VIP menu
	}
	return PLUGIN_HANDLED;
}

public Showrod(id)
{
	if (get_user_flags(id) & VIP_FLAG) //Checks if player has flag H
	{
		if (map_active) //Checks if map_active is 1
		{
			if( g_bCurrentMapIsInList ) //Checks if current map is in mapnames.ini, if so print the message and cancels the menu showup
			{
				client_print( id, print_center, "%L", id, "VIP_MENU_WRONG_MAP" ); //Sends a message that VIP can't use VIP menu on that map
				return; //Stop VIP from getting the VIP menu
			}
		}
		if( g_bCurrentAWPMapIsInList ) //Checks if map is in awpmapnames.ini
		{
			bAwpMap = true //If so sets bAwpMap to true, so AWP choice would work in maps that are in awpmapnames.ini
		}
		new newmenu[64], choice_1[64], choice_2[64], choice_3[64] 
		format(newmenu, sizeof(newmenu), "%L", id, "NEW_MENU"); //Shows a menu message that's set in vipplugin.txt as NEW_MENU_PRIMARY
		new menu = menu_create(newmenu, "Pressedrod"); //Creates menu that's in Pressedrod
		
		format(choice_1, sizeof(choice_1), "%L", id, "MENU_CHOICE_1"); //Shows a menu message that's set in vipplugin.txt as MENU_CHOICE_PRIMARY_1
		menu_additem(menu, choice_1, "1", 0); //Menu choice/case 1
		format(choice_2, sizeof(choice_2), "%L", id, "MENU_CHOICE_2"); //Shows a menu message that's set in vipplugin.txt as MENU_CHOICE_PRIMARY_2
		menu_additem(menu, choice_2, "2", 0); //Menu choice/case 2
		if ( iTCount >= TR && iCTCount >= CT ) //Checks that each team has 5 or more people to AWP choice appear in the menu
		{
			if (awp_active == 1) //Checks if vips can get awp choice, 0 - no; 1 - yes
			{
				if ( CurrentRound >= awp_menu_round ) //Checks if current round is more or equal to 3, so AWP choice would come out
				{
					if( !bAwpMap ) //Checks if map is not one in awpmapnames.xfg, if so shows the fifth menu item
					{
						format(choice_3, sizeof(choice_3), "%L", id, "MENU_CHOICE_3"); //Shows a menu message that's set in vipplugin.txt as MENU_CHOICE_PRIMARY_5
						menu_additem(menu, choice_3, "3", 0); //Menu choice/case 5
					}
				}
			}
		}		
		new menu_exit_name[64];
		format(menu_exit_name, sizeof(menu_exit_name), "%L", id, "MENU_EXIT_NAME")
		menu_setprop(menu, MPROP_EXITNAME, menu_exit_name)
		menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
		if(menu_number_color == 1) //Checks if menu_number_color is set to 3
		{
			menu_setprop(menu,MPROP_NUMBER_COLOR,"\y"); // ets the number color to yello
		}
		else if(menu_number_color == 2) //Checks if menu_number_color is set to 3
		{
			menu_setprop(menu,MPROP_NUMBER_COLOR,"\w"); //Sets the number color to white
		}
		else if(menu_number_color == 3) //Checks if menu_number_color is set to 3
		{
			menu_setprop(menu,MPROP_NUMBER_COLOR,"\d"); //Sets the number color to grey
		}
		else //In any other case the menu_number_color is set to
		{
			menu_setprop(menu,MPROP_NUMBER_COLOR,"\r"); //Sets the number color to red
		}
		menu_display(id, menu, 0)
	}
}

public HandleCmd(id)
{
    if (!get_pcvar_num(g_sniper_active)) //Checks if g_awp_active is disactivated (set to 0)
        return PLUGIN_CONTINUE //If it is, let players buy snipers
        
    if(get_user_flags(id) & VIP_FLAG)  //Checks if player has flag H
        return PLUGIN_CONTINUE 
        
    client_print( id, print_center, "%L", id, "SNIPER_ONLY_FOR_VIP" ); //Sends a message that snipers are only for VIP
    
    return PLUGIN_HANDLED
}

public Pressedrod(id, menu, item)
{
	if( item == MENU_EXIT ) //Checks if player clicks menu exit (0)
	{
		menu_destroy(menu); //If so the menu will be destroyed
		return PLUGIN_HANDLED;
	}
	new iFlashes = cs_get_user_bpammo( id, CSW_FLASHBANG );
	new HasC4[33], HasHE[33], HasSG[33];
	new weapons = pev(id, pev_weapons)
	HasC4[id] = ( weapons & 1<<CSW_C4 )
	HasHE[id] = ( weapons & 1<<CSW_HEGRENADE ) && cs_get_user_bpammo(id, CSW_HEGRENADE)
	HasSG[id] = ( weapons & 1<<CSW_SMOKEGRENADE ) && cs_get_user_bpammo(id, CSW_SMOKEGRENADE)
	new data[6], szName[64];
	new access, callback;
	menu_item_getinfo(menu, item, access, data,charsmax(data), szName,charsmax(szName), callback);
	new key = str_to_num(data);
	if(is_user_alive(id) && !g_bRoundEnd)
	{
		strip_user_weapons( id );
		switch(key)
		{
		case 1: {  								
				give_item(id,"weapon_m4a1") //Gives M4A1
				cs_set_user_bpammo(id, CSW_M4A1, 90); //Sets M4A1 back pack ammo to 90
				client_print( id, print_center, "%L", id, "CHOSE_M4A1" ); //Shows a message that's set in vipplugin.txt as CHOSE_M4A1
			}
		case 2: { 	
				give_item(id,"weapon_ak47") //Gives AK47
				cs_set_user_bpammo(id, CSW_AK47, 90); //Sets AK47 back pack ammo to 90
				client_print( id, print_center, "%L", id, "CHOSE_AK47" ); //Shows a message that's set in vipplugin.txt as CHOSE_AK47
			}
		case 3: { 
				give_item(id,"weapon_awp") //Gives AWP
				cs_set_user_bpammo(id, CSW_AWP, 30); //Sets AWP back pack ammo to 30
				client_print( id, print_center, "%L", id, "CHOSE_AWP" ); //Shows a message that's set in vipplugin.txt as CHOSE_AWP
			}
		}
		if (HasC4[id])
		{
			give_item(id, "weapon_c4");
			cs_set_user_plant( id );
			set_pev(id, pev_body, 1);
		}
		if (HasHE[id])
		{
			give_item(id, "weapon_hegrenade")
		}
		if (HasSG[id])
		{
			give_item(id, "weapon_smokegrenade");
		}
		if( iFlashes > 0 ) 
		{ 
			give_item( id, "weapon_flashbang" ); 
			cs_set_user_bpammo( id, CSW_FLASHBANG, iFlashes ); 
		} 
		give_item(id,"weapon_knife") //Gives knife
		give_item(id,"weapon_deagle") //Gives deagle
		cs_set_user_bpammo(id, CSW_DEAGLE, 35); //Sets deagle back pack ammo to 35
		if(g_bHasBombSite && cs_get_user_team(id) == CS_TEAM_CT) //Checks if current map has bombsite
		{
			give_item(id, "item_thighpack"); //Gives defuse kit
		}
		gMenuUsed[id]++ //Makes sure that VIP really made a choice
	}
	menu_destroy(menu); //Destroys menu
	return PLUGIN_CONTINUE
}


get_user_flashed(id, &iPercent=0) 
{ 
	new Float:flFlashedAt = get_pdata_float(id, m_flFlashedAt) 

	if( !flFlashedAt ) 
	{ 
		return 0 
	} 
	
	new Float:flGameTime = get_gametime() 
	new Float:flTimeLeft = flGameTime - flFlashedAt 
	new Float:flFlashDuration = get_pdata_float(id, m_flFlashDuration) 
	new Float:flFlashHoldTime = get_pdata_float(id, m_flFlashHoldTime) 
	new Float:flTotalTime = flFlashHoldTime + flFlashDuration 
	
	if( flTimeLeft > flTotalTime ) 
	{ 
		return 0 
	} 
	
	new iFlashAlpha = get_pdata_int(id, m_iFlashAlpha) 

	if( iFlashAlpha == ALPHA_FULLBLINDED ) 
	{ 
		if( get_pdata_float(id, m_flFlashedUntil) - flGameTime > 0.0 ) 
		{ 
			iPercent = 100 
		} 
		else 
		{ 
			iPercent = 100-floatround(((flGameTime - (flFlashedAt + flFlashHoldTime))*100.0)/flFlashDuration) 
		} 
	} 
	else 
	{ 
		iPercent = 100-floatround(((flGameTime - flFlashedAt)*100.0)/flTotalTime) 
	} 

	return iFlashAlpha 
}