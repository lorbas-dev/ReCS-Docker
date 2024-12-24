// Copyright © 2016 Vaqtincha

/**
*	Credits:
*	- Adidasman - за подсказки
*	- wopox1337 - за поддержку топика
*/


#include <amxmodx>
#include <reapi>

// const BLINDED_PARTLY = 200
// const BLINDED_FULLY = 255

public plugin_init()
{
	register_plugin("[ReAPI] No Team Flash lite", "0.0.3", "Vaqtincha")

	RegisterHookChain(RG_PlayerBlind, "PlayerBlind", .post = false)
}

public PlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, const alpha, Float:color[3])
{
	// server_print("INFLICTOR: %d", inflictor)
	if (index != attacker && get_member(index, m_iTeam) == get_member(attacker, m_iTeam))
	{
		// don't let a 3rd party to know that this the player is blind
		set_member(index, m_blindAlpha, 0);
		//set_member(index, m_blindStartTime, 0);
		//set_member(index, m_blindHoldTime, 0);
		return HC_SUPERCEDE;
	}

	return HC_CONTINUE;
}