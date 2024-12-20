#include <amxmodx>
#include <reapi>

// const BLINDED_PARTLY = 200
// const BLINDED_FULLY = 255

public plugin_init()
{
    register_plugin("[ReAPI] No Team Flash", "0.0.2", "unknown")

    RegisterHookChain(RG_PlayerBlind, "PlayerBlind", .post = false)
}

public PlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, const alpha, Float:color[3])
{
    return (index != attacker && get_member(index, m_iTeam) == get_member(attacker, m_iTeam)) ? HC_SUPERCEDE : HC_CONTINUE
} 