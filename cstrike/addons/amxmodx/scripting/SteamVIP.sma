#include <amxmodx>
#include <amxmisc>

#define VERSION "1.0"

#define VIP_FLAGS "t"

public plugin_init()
{
	register_plugin("Steam Free VIP", VERSION, "Lorbass & Huehue")

}

public client_authorized(id)
{
	if (!is_user_admin(id) && is_user_steam(id))
	{
		/* We must add delay to show chat message, otherwise plugin works fine without delay and chat message.. */
		set_task(10.0, "Delayed_AddSteamFreeFlags", id)
	}
}

public Delayed_AddSteamFreeFlags(id)
{
	if (!is_user_connected(id))
		return

	remove_user_flags(id, read_flags("z"))
	set_user_flags(id, read_flags(VIP_FLAGS))

	client_print(id, print_chat, "You have received a free VIP for having a Steam Acount!")
}

bool:is_user_steam(id)
{
    /*
        new auth[65];
        get_user_authid(id,auth,64);
        if(contain(auth, "STEAM_0:0:") != -1 || contain(auth, "STEAM_0:1:") != -1)
            return true;

        return false;
    */

	static iPointer

	if (iPointer || (iPointer = get_cvar_pointer("dp_r_id_provider")))
	{
		server_cmd("dp_clientinfo %d", id); server_exec()
		return get_pcvar_num(iPointer) == 2
	}
	return false
}