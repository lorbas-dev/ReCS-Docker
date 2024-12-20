#include <amxmodx>
#include <cstrike>
#include <fun>

#pragma semicolon 1

public plugin_init() {
	register_plugin("Reset score", "0.1", "Lorbass");
	register_clcmd("say /rs", "CmdRs");
}

public CmdRs(const id) {
	if(is_user_connected(id)) {
		set_user_frags(id, 0);
		cs_set_user_deaths(id, 0);
		client_print(id, print_chat, "Your score is reset");
	}
	return PLUGIN_HANDLED;
}