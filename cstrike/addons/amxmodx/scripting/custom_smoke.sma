#include <amxmodx>
#include <engine>
#include <fakemeta>

#if !defined write_coord_f
    #define write_coord_f(%1)   engfunc( EngFunc_WriteCoord, %1 )
#endif

#define VERSION "1.07"
#define SMOKE_SPRITE "sprites/gas_puff_gray_opaque.spr"

new const g_szClassname[] = "custom_smoke";
new g_fwid
new g_evCreateSmoke;
new g_szSmokeSprite;
new g_Cvar_Enabled;
new g_Cvar_Duration;
new g_Cvar_CountSprites;
new g_Clear;
new g_iCvar_Enebled;
new g_iCountSprites;

public plugin_init( )
{
    register_plugin( "Custom Smoke", VERSION, "bionext" );

    g_Clear = 0;
    g_iCvar_Enebled = 0;
    g_Cvar_Enabled = register_cvar( "sv_customsmoke", "1" );
    g_Cvar_Duration = register_cvar( "sv_smokeduration", "10.0" );
    g_Cvar_CountSprites = register_cvar( "sv_smokespritescount", "30" );

    unregister_forward(FM_PrecacheEvent, g_fwid, 1);

    register_think( g_szClassname, "FwdThink_BlackSmoke" );
    register_forward(FM_PlaybackEvent, "FwdPlaybackEvent");
    register_logevent("FwdClear", 2, "1=Round_End");
    register_logevent("FwdStart", 2, "1=Round_Start");
    register_event("TextMsg", "FwdClear", "a", "2=#Game_will_restart_in","2=#Game_Commencing");
}

public FwdClear( )
{
    g_Clear = 1;
}

public FwdStart( )
{
    g_iCvar_Enebled = get_pcvar_num( g_Cvar_Enabled );
    g_Clear = 0;
}

public plugin_precache( )
{
    g_szSmokeSprite = precache_model( SMOKE_SPRITE );
    g_fwid = register_forward(FM_PrecacheEvent, "FwdPrecacheEvent", 1);
    force_unmodified(force_exactfile, {0,0,0},{0,0,0}, SMOKE_SPRITE);
}

public FwdPlaybackEvent( iFlags , iEntity , iEventindex, Float:fDelay, Float:vOrigin[3], Float:vAngles[3], Float:fParam1, Float:fParam2, iParam1, iParam2, iBparam1, iBparam2 )
{
    if(iEventindex != g_evCreateSmoke || iBparam2 || !g_iCvar_Enebled)
        return FMRES_IGNORED;

    new iEnt = create_entity( "info_target" );

    if( !iEnt )
        return FMRES_IGNORED;
  
    g_iCountSprites = get_pcvar_num( g_Cvar_CountSprites );
    new Float:fDuration = get_pcvar_float( g_Cvar_Duration );
          
    entity_set_string( iEnt, EV_SZ_classname, g_szClassname );
    entity_set_float( iEnt, EV_FL_nextthink, get_gametime( ));
    entity_set_vector( iEnt, EV_VEC_origin, vOrigin );
    entity_set_float( iEnt, EV_FL_animtime, fDuration );

    return FMRES_SUPERCEDE;
}

public FwdPrecacheEvent(type, const name[])
{
    if (equal("events/createsmoke.sc", name))
    {
        g_evCreateSmoke = get_orig_retval();
        return FMRES_HANDLED;
    }

    return FMRES_IGNORED;
}

public FwdThink_BlackSmoke( iEntity )
{
    if( !is_valid_ent( iEntity ) )
        return PLUGIN_CONTINUE;

    if( g_Clear > 0 )
    {
        entity_set_int( iEntity,EV_INT_flags, FL_KILLME );
        return PLUGIN_CONTINUE;
    }

    new Float:vOrigin[3];
    entity_get_vector( iEntity, EV_VEC_origin, vOrigin );

    message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
    write_byte( TE_FIREFIELD );
    write_coord_f( vOrigin[ 0 ] );
    write_coord_f( vOrigin[ 1 ] );
    write_coord_f( vOrigin[ 2 ] + 50 );
    write_short( 100 );
    write_short( g_szSmokeSprite );
    write_byte( g_iCountSprites );
    write_byte( TEFIRE_FLAG_ALPHA );
    write_byte( 11 );
    message_end();

    message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
    write_byte( TE_FIREFIELD );
    write_coord_f( vOrigin[ 0 ] );
    write_coord_f( vOrigin[ 1 ] );
    write_coord_f( vOrigin[ 2 ] + 50 );
    write_short( 150 );
    write_short( g_szSmokeSprite );
    write_byte( 5 );
    write_byte( TEFIRE_FLAG_ALPHA | TEFIRE_FLAG_SOMEFLOAT );
    write_byte( 11 );
    message_end( );

    new Float:time = entity_get_float(iEntity,EV_FL_animtime);
    time = time - 0.25;

    if( time > 0.0 )
    {
        entity_set_float( iEntity, EV_FL_nextthink, get_gametime( ) + 0.25 );
        entity_set_float( iEntity, EV_FL_animtime, time );
    }
    else
    {
        entity_set_int( iEntity,EV_INT_flags, FL_KILLME );
    }

    return PLUGIN_CONTINUE;
}