#include <amxmodx>
#include <reapi>
 
const ACCESS_FLAG = ADMIN_BAN;
 
public plugin_init()
{
    register_plugin("[ReAPI] AdminFreeLook", "1.0", "ReHLDS Team");
 
    if(!is_regamedll()) {
        set_fail_state("ReGameDLL is not available");
        return;
    }
 
    RegisterHookChain(RG_GetForceCamera, "GetForceCamera");
    RegisterHookChain(RG_CBasePlayer_Observer_IsValidTarget, "Observer_IsValidTarget");
}
 
public GetForceCamera(const index)
{
    if (!shouldRunCode())
        return HC_CONTINUE;
    
    if (canFreeLook(index)) {
        SetHookChainReturn(ATYPE_INTEGER, 0);
        return HC_SUPERCEDE;
    }
 
    return HC_CONTINUE;
}

public Observer_IsValidTarget(const this, const iPlayerIndex, bool:bSameTeam)
{
    if (shouldRunCode())
        return HC_CONTINUE;
 
    if (!is_user_connected(iPlayerIndex))
        return HC_CONTINUE;
 
    if (iPlayerIndex == this || get_entvar(iPlayerIndex, var_iuser1) > 0 || (get_entvar(iPlayerIndex, var_effects) & EF_NODRAW) || get_member(iPlayerIndex, m_iTeam) == TEAM_UNASSIGNED)
        return HC_CONTINUE;
 
    // Don't spec observers or players who haven't picked a class yet
    if (bSameTeam && get_member(iPlayerIndex, m_iTeam) != get_member(this, m_iTeam))
        return HC_CONTINUE;
 
    if (canFreeLook(iPlayerIndex)) {
        SetHookChainReturn(ATYPE_INTEGER, iPlayerIndex);
        return HC_SUPERCEDE;
    }
 
    return HC_CONTINUE;
}

stock bool:canFreeLook(const index) {
    return bool:(get_user_flags(index) & ACCESS_FLAG);
}

stock bool:shouldRunCode()
{
    return bool:(Float:get_member_game(m_flFadeToBlackValue) <= 0.0
        && Float:get_member_game(m_flForceCameraValue) > 0.0
        && Float:get_member_game(m_flForceChaseCamValue) > 0.0);
}