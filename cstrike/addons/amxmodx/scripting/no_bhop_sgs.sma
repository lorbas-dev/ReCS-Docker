#include <amxmodx>
#include <reapi>

#pragma semicolon 1

new g_iPlayerGround[MAX_PLAYERS + 1];

public plugin_init()
{
    register_plugin("No Bhop and SGS/DDRun", "1.1", "Denzer");

    //RegisterHookChain(RG_CBasePlayer_Jump, "CBasePlayer_Jump");
    RegisterHookChain(RG_CBasePlayer_Duck, "CBasePlayer_Duck");
    RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink");
}

public client_putinserver(id)
{
    g_iPlayerGround[id] = 0;
}

public CBasePlayer_Jump(id)
{
    if(g_iPlayerGround[id] && g_iPlayerGround[id] < 5)
        set_entvar(id, var_oldbuttons, get_entvar(id, var_oldbuttons) | IN_JUMP);
}

public CBasePlayer_Duck(id)
{
    if(g_iPlayerGround[id] && g_iPlayerGround[id] < 5)
        set_entvar(id, var_oldbuttons, get_entvar(id, var_oldbuttons) | IN_DUCK);
}

public CBasePlayer_PreThink(id)
{
    if(get_entvar(id, var_flags) & FL_ONGROUND)
        g_iPlayerGround[id]++;
    else
        g_iPlayerGround[id] = 0;
}